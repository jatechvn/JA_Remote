part of 'wol_scripts.dart';

String _buildLinuxCommand({required bool applyFix, String? sudoPassword}) {
  final rootBody = _linuxRootScriptBody(applyFix: applyFix);
  final rootB64 = base64.encode(utf8.encode(rootBody));

  final outerScript =
      '''
#!/usr/bin/env bash
set -u
APPLY_FIX=${applyFix ? '1' : '0'}
ROOT_B64='$rootB64'
SUDO_PW=""
if [ -n "\${JA_SUDO_PW_B64:-}" ]; then
  SUDO_PW=\$(printf '%s' "\$JA_SUDO_PW_B64" | base64 -d 2>/dev/null || true)
fi

if [ "\$(id -u)" -eq 0 ]; then
  echo "\$ROOT_B64" | base64 -d | bash
  exit 0
fi

if sudo -n true 2>/dev/null; then
  sudo -n bash -c "echo '\$ROOT_B64' | base64 -d | bash"
  exit 0
fi

if [ -n "\$SUDO_PW" ] && printf '%s\\n' "\$SUDO_PW" | sudo -S -k -p '' true 2>/dev/null; then
  printf '%s\\n' "\$SUDO_PW" | sudo -S -k -p '' bash -c "echo '\$ROOT_B64' | base64 -d | bash"
  exit 0
fi

if [ "\$APPLY_FIX" -eq 1 ]; then
  echo '${WolScripts.outputPrefix}{"os":"linux","hasSudo":false,"authRequired":true,"error":"Sudo password required or incorrect for WoL remediation."}'
  exit 0
fi

${_linuxUnprivilegedCheckBody()}
''';

  final outerB64 = base64.encode(utf8.encode(outerScript));
  final pw = sudoPassword ?? '';
  if (pw.isEmpty) {
    return "echo '$outerB64' | base64 -d | bash";
  }
  final pwB64 = base64.encode(utf8.encode(pw));
  return "JA_SUDO_PW_B64='$pwB64' bash -c 'echo $outerB64 | base64 -d | bash'";
}

String _linuxNicDetectSnippet() {
  return r'''
IFACE=""
for d in /sys/class/net/*; do
  n=$(basename "$d")
  case "$n" in lo|wl*|docker*|veth*|br-*|virbr*|tun*|tap*|tailscale*) continue ;; esac
  [ -e "$d/device" ] || continue
  [ "$(cat "$d/type" 2>/dev/null || echo 0)" = "1" ] || continue
  if [ "$(cat "$d/carrier" 2>/dev/null || echo 0)" = "1" ]; then IFACE="$n"; break; fi
  [ -z "$IFACE" ] && IFACE="$n"
done
USB_ONLY=0
if [ -n "$IFACE" ]; then
  readlink -f "/sys/class/net/$IFACE/device" 2>/dev/null | grep -qi "/usb" && USB_ONLY=1
fi
CONN_UUID=""
if [ -n "$IFACE" ] && command -v nmcli >/dev/null 2>&1; then
  CONN_UUID=$(nmcli -t -f UUID,DEVICE connection show --active 2>/dev/null | awk -F: -v d="$IFACE" '$2==d {print $1; exit}')
fi
''';
}

String _linuxRootScriptBody({required bool applyFix}) {
  return '''
#!/usr/bin/env bash
set -u
APPLY_FIX=${applyFix ? '1' : '0'}
ACTIONS=""
add_action() { ACTIONS="\${ACTIONS}\${ACTIONS:+||}\$1"; }

${_linuxNicDetectSnippet()}

modprobe hp-bioscfg 2>/dev/null || true
udevadm settle --timeout=2 2>/dev/null || true
BIOS_WOL=""
BIOS_S5=""
BIOS_ATTR_EXPOSED=0
BIOS_PASS_SET=0
if [ -d /sys/class/firmware-attributes ]; then
  for a in /sys/class/firmware-attributes/*/authentication/*; do
    [ -d "\$a" ] || continue
    [ "\$(cat "\$a/is_enabled" 2>/dev/null || echo 0)" = "1" ] && BIOS_PASS_SET=1
  done
  while IFS= read -r a; do
    bn=\$(basename "\$a")
    cv=\$(cat "\$a/current_value" 2>/dev/null || true)
    pv=\$(cat "\$a/possible_values" 2>/dev/null || true)
    case "\$bn" in
      *"Wake on LAN"*|*"Wake On LAN"*)
        BIOS_ATTR_EXPOSED=1
        BIOS_WOL="\$cv"
        if [ "\$APPLY_FIX" -eq 1 ] && [ "\$BIOS_PASS_SET" -eq 0 ] && [ "\$cv" = "Disable" ]; then
          if echo "\$pv" | tr ';' '\\n' | grep -Fxq "Boot to Hard Drive"; then
            echo "Boot to Hard Drive" > "\$a/current_value" 2>/dev/null && { BIOS_WOL="Boot to Hard Drive"; add_action "BIOS: Wake on LAN -> Boot to Hard Drive"; }
          elif echo "\$pv" | tr ';' '\\n' | grep -Fxq "Enable"; then
            echo "Enable" > "\$a/current_value" 2>/dev/null && { BIOS_WOL="Enable"; add_action "BIOS: Wake on LAN -> Enable"; }
          fi
        fi
        ;;
      "S5 Maximum Power Savings"|"Deep Sleep")
        BIOS_ATTR_EXPOSED=1
        BIOS_S5="\$cv"
        if [ "\$APPLY_FIX" -eq 1 ] && [ "\$BIOS_PASS_SET" -eq 0 ] && [ "\$cv" = "Enable" ]; then
          echo "Disable" > "\$a/current_value" 2>/dev/null && { BIOS_S5="Disable"; add_action "BIOS: \$bn -> Disable"; }
        fi
        ;;
    esac
  done < <(find /sys/class/firmware-attributes -mindepth 3 -maxdepth 4 -type d 2>/dev/null)
fi

ensure_offline_ethtool_ctl() {
  if [ ! -x /usr/local/sbin/ja-wol-ethtool ] && command -v python3 >/dev/null 2>&1; then
    mkdir -p /usr/local/sbin
    cat << 'PYEOF' > /usr/local/sbin/ja-wol-ethtool
#!/usr/bin/env python3
import ctypes, fcntl, socket, struct, sys

SIOCETHTOOL = 0x8946
ETHTOOL_GWOL = 0x00000005
ETHTOOL_SWOL = 0x00000006
WAKE_MAGIC = 0x20

class Wol(ctypes.Structure):
    _fields_ = [('cmd', ctypes.c_uint32), ('supported', ctypes.c_uint32),
                ('wolopts', ctypes.c_uint32), ('sopass', ctypes.c_uint8 * 6)]

def ioctl_wol(iface, set_magic=False):
    wol = Wol(cmd=ETHTOOL_GWOL)
    ifr = struct.pack('16sP', iface.encode('ascii'), ctypes.addressof(wol)) + b'\\x00' * 16
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        fcntl.ioctl(s.fileno(), SIOCETHTOOL, ifr[:32])
        if set_magic:
            wol.cmd = ETHTOOL_SWOL
            wol.wolopts = WAKE_MAGIC
            fcntl.ioctl(s.fileno(), SIOCETHTOOL, ifr[:32])
            wol.cmd = ETHTOOL_GWOL
            fcntl.ioctl(s.fileno(), SIOCETHTOOL, ifr[:32])
        flags = [(1<<0,'p'),(1<<1,'u'),(1<<2,'m'),(1<<3,'b'),(1<<4,'a'),(1<<5,'g'),(1<<6,'s'),(1<<7,'f')]
        sup = ''.join(c for b,c in flags if wol.supported & b) or 'd'
        cur = ''.join(c for b,c in flags if wol.wolopts & b) or 'd'
        print(f"{sup}:{cur}")
    finally:
        s.close()

if __name__ == '__main__':
    if len(sys.argv) < 2: sys.exit(1)
    ioctl_wol(sys.argv[1], set_magic=(len(sys.argv) >= 3 and sys.argv[2] == 'wol-g'))
PYEOF
    chmod 0755 /usr/local/sbin/ja-wol-ethtool
    add_action 'Installed offline ioctl helper /usr/local/sbin/ja-wol-ethtool'
  fi
}

ETH_BIN=\$(command -v ethtool || true)
[ -z "\$ETH_BIN" ] && [ -x /usr/sbin/ethtool ] && ETH_BIN=/usr/sbin/ethtool
[ -z "\$ETH_BIN" ] && [ -x /sbin/ethtool ] && ETH_BIN=/sbin/ethtool

if [ "\$APPLY_FIX" -eq 1 ] && [ -n "\$IFACE" ] && [ "\$USB_ONLY" -eq 0 ]; then
  if [ -n "\$ETH_BIN" ]; then
    "\$ETH_BIN" -s "\$IFACE" wol g 2>/dev/null && add_action "ethtool -s \$IFACE wol g"
    "\$ETH_BIN" --set-eee "\$IFACE" eee off 2>/dev/null && add_action "ethtool --set-eee \$IFACE eee off" || true
    CTL_CMD="\$ETH_BIN"
  else
    ensure_offline_ethtool_ctl
    if [ -x /usr/local/sbin/ja-wol-ethtool ]; then
      /usr/local/sbin/ja-wol-ethtool "\$IFACE" wol-g >/dev/null 2>&1 && add_action "ioctl \$IFACE wol=g (offline)"
    fi
    CTL_CMD="/usr/local/sbin/ja-wol-ethtool"
  fi

  if [ -w "/sys/class/net/\$IFACE/device/power/wakeup" ]; then
    echo enabled > "/sys/class/net/\$IFACE/device/power/wakeup" 2>/dev/null && add_action "sysfs power/wakeup -> enabled"
  fi

  if [ -n "\$CONN_UUID" ]; then
    nmcli connection modify "\$CONN_UUID" 802-3-ethernet.wake-on-lan magic 2>/dev/null && add_action "NetworkManager wake-on-lan=magic"
  fi

  mkdir -p /etc/NetworkManager/conf.d
  printf '[connection-ja-wol]\\nmatch-device=type:ethernet\\nethernet.wake-on-lan=64\\n' > /etc/NetworkManager/conf.d/90-ja-wol.conf
  chmod 0644 /etc/NetworkManager/conf.d/90-ja-wol.conf
  nmcli general reload conf 2>/dev/null || true
  add_action "Wrote /etc/NetworkManager/conf.d/90-ja-wol.conf"

  EXEC_SET="\$CTL_CMD -s \$IFACE wol g"
  if [ "\$CTL_CMD" = "/usr/local/sbin/ja-wol-ethtool" ]; then
    EXEC_SET="/usr/local/sbin/ja-wol-ethtool \$IFACE wol-g"
  fi
  cat << SVCEOF > "/etc/systemd/system/wol-\$IFACE.service"
[Unit]
Description=Keep Wake-on-LAN (Magic Packet) enabled on \$IFACE across boot and shutdown
After=network-online.target NetworkManager.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=\$EXEC_SET
ExecStop=\$EXEC_SET

[Install]
WantedBy=multi-user.target
SVCEOF
  chmod 0644 "/etc/systemd/system/wol-\$IFACE.service"
  systemctl daemon-reload 2>/dev/null || true
  systemctl enable --now "wol-\$IFACE.service" 2>/dev/null || true
  add_action "Enabled wol-\$IFACE.service"

  if [ -d /etc/tlp.d ]; then
    printf 'WOL_DISABLE="N"\\n' > /etc/tlp.d/90-ja-wol.conf
    chmod 0644 /etc/tlp.d/90-ja-wol.conf
    add_action "Wrote /etc/tlp.d/90-ja-wol.conf"
  fi
fi

export JA_WOL_HAS_SUDO=1
export JA_WOL_IFACE="\$IFACE"
export JA_WOL_USB_ONLY="\$USB_ONLY"
export JA_WOL_BIOS_EXPOSED="\$BIOS_ATTR_EXPOSED"
export JA_WOL_BIOS_PASS="\$BIOS_PASS_SET"
export JA_WOL_BIOS_WOL="\$BIOS_WOL"
export JA_WOL_BIOS_S5="\$BIOS_S5"
export JA_WOL_CONN_UUID="\$CONN_UUID"
export JA_WOL_ACTIONS="\$ACTIONS"
${_linuxPythonEmitter()}
''';
}

String _linuxUnprivilegedCheckBody() {
  return '''
${_linuxNicDetectSnippet()}
export JA_WOL_HAS_SUDO=0
export JA_WOL_IFACE="\$IFACE"
export JA_WOL_USB_ONLY="\$USB_ONLY"
export JA_WOL_BIOS_EXPOSED=0
export JA_WOL_BIOS_PASS=0
export JA_WOL_BIOS_WOL=""
export JA_WOL_BIOS_S5=""
export JA_WOL_CONN_UUID="\$CONN_UUID"
export JA_WOL_ACTIONS=""
${_linuxPythonEmitter()}
''';
}

String _linuxPythonEmitter() {
  return r'''
python3 - << 'PYJSON'
import ctypes, fcntl, json, os, re, shutil, socket, struct, subprocess

def rd(path):
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            return f.read().strip()
    except Exception:
        return ''

def sh(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True).strip()
    except subprocess.CalledProcessError as e:
        return (e.output or '').strip()
    except Exception:
        return ''

iface = os.environ.get('JA_WOL_IFACE', '')
has_sudo = os.environ.get('JA_WOL_HAS_SUDO', '0') == '1'
usb_only = os.environ.get('JA_WOL_USB_ONLY', '0') == '1'
conn_uuid = os.environ.get('JA_WOL_CONN_UUID', '')
actions_raw = os.environ.get('JA_WOL_ACTIONS', '')

host = socket.gethostname()
model = f"{rd('/sys/class/dmi/id/sys_vendor')} {rd('/sys/class/dmi/id/product_name')}".strip()
bios = f"{rd('/sys/class/dmi/id/bios_vendor')} {rd('/sys/class/dmi/id/bios_version')} ({rd('/sys/class/dmi/id/bios_date')})".strip()
mac = rd(f'/sys/class/net/{iface}/address').upper().replace(':', '-') if iface else ''
ip_str = ''
if iface:
    ip_out = sh(['ip', '-4', '-o', 'addr', 'show', 'dev', iface])
    m = re.search(r'inet\s+(\d+\.\d+\.\d+\.\d+)', ip_out)
    if m: ip_str = m.group(1)

sysfs_wakeup = rd(f'/sys/class/net/{iface}/device/power/wakeup') if iface else ''
pci_slot = os.path.basename(os.path.realpath(f'/sys/class/net/{iface}/device')) if iface and os.path.exists(f'/sys/class/net/{iface}/device') else ''
acpi_state = ''
acpi_txt = rd('/proc/acpi/wakeup')
if pci_slot and acpi_txt:
    for ln in acpi_txt.splitlines():
        if pci_slot in ln:
            acpi_state = '*enabled' if '*enabled' in ln else ('*disabled' if '*disabled' in ln else ln.strip())
            break

driver = os.path.basename(os.path.realpath(f'/sys/class/net/{iface}/device/driver')) if iface and os.path.exists(f'/sys/class/net/{iface}/device/driver') else ''
wol_sup, wol_cur, eee_disabled = '', '', None
if iface and has_sudo:
    eth = shutil.which('ethtool') or next((p for p in ('/usr/sbin/ethtool', '/sbin/ethtool') if os.path.exists(p)), None)
    if eth:
        et = sh([eth, iface])
        ms = re.search(r'Supports Wake-on:\s*(\S+)', et)
        mc = re.search(r'Wake-on:\s*(\S+)', et)
        if ms: wol_sup = ms.group(1)
        if mc: wol_cur = mc.group(1)
        ee = sh([eth, '--show-eee', iface])
        if 'EEE status:' in ee:
            eee_disabled = ('EEE status: disabled' in ee or 'not supported' in ee.lower())
    else:
        try:
            class Wol(ctypes.Structure):
                _fields_ = [('cmd', ctypes.c_uint32), ('supported', ctypes.c_uint32), ('wolopts', ctypes.c_uint32), ('sopass', ctypes.c_uint8 * 6)]
            wol = Wol(cmd=5)
            ifr = struct.pack('16sP', iface.encode('ascii'), ctypes.addressof(wol)) + b'\x00' * 16
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            fcntl.ioctl(s.fileno(), 0x8946, ifr[:32])
            s.close()
            flags = [(1<<0,'p'),(1<<1,'u'),(1<<2,'m'),(1<<3,'b'),(1<<4,'a'),(1<<5,'g'),(1<<6,'s'),(1<<7,'f')]
            wol_sup = ''.join(c for b,c in flags if wol.supported & b) or 'd'
            wol_cur = ''.join(c for b,c in flags if wol.wolopts & b) or 'd'
        except Exception:
            pass

nm_wol = sh(['nmcli', '-g', '802-3-ethernet.wake-on-lan', 'connection', 'show', conn_uuid]) if conn_uuid else ''
nm_conf = os.path.exists('/etc/NetworkManager/conf.d/90-ja-wol.conf')
svc_en = sh(['systemctl', 'is-enabled', f'wol-{iface}.service']) if iface else ''
svc_act = sh(['systemctl', 'is-active', f'wol-{iface}.service']) if iface else ''
ssh_en = sh(['systemctl', 'is-enabled', 'ssh'])
if ssh_en not in ('enabled', 'alias', 'static'):
    ssh_en = sh(['systemctl', 'is-enabled', 'sshd'])
ssh_act = sh(['systemctl', 'is-active', 'ssh'])
if ssh_act != 'active':
    ssh_act = sh(['systemctl', 'is-active', 'sshd'])

payload = {
    'os': 'linux',
    'host': host,
    'model': model,
    'bios': bios,
    'hasSudo': has_sudo,
    'biosAttrExposed': os.environ.get('JA_WOL_BIOS_EXPOSED', '0') == '1',
    'biosPasswordSet': os.environ.get('JA_WOL_BIOS_PASS', '0') == '1',
    'biosWolSetting': os.environ.get('JA_WOL_BIOS_WOL', '') or None,
    'biosS5PowerSaving': os.environ.get('JA_WOL_BIOS_S5', '') or None,
    'acpiWakeState': acpi_state,
    'hasPcieNic': bool(iface) and (not usb_only),
    'usbOnlyNic': usb_only,
    'adapterName': iface,
    'adapterDesc': f'{driver} ({pci_slot})'.strip() if iface else '',
    'mac': mac,
    'ip': ip_str,
    'linkUp': rd(f'/sys/class/net/{iface}/carrier') == '1' if iface else False,
    'wolSupported': wol_sup,
    'wolCurrent': wol_cur,
    'eeeDisabled': eee_disabled,
    'sysfsWakeup': sysfs_wakeup,
    'nmWol': nm_wol,
    'nmConfPresent': nm_conf,
    'systemdEnabled': (svc_en == 'enabled'),
    'systemdActive': (svc_act == 'active'),
    'sshReady': (ssh_en in ('enabled', 'alias', 'static') and ssh_act == 'active'),
    'actions': [a for a in actions_raw.split('||') if a.strip()] if actions_raw else [],
}
print('JA_WOL_JSON:' + json.dumps(payload, separators=(',', ':')))
PYJSON
''';
}

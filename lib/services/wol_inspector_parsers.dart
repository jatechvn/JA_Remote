part of 'wol_inspector_service.dart';

const List<WolLayerCheck> _unknownWolLayers = [
  WolLayerCheck(id: 'bios', state: WolLayerState.unknown, summary: '--'),
  WolLayerCheck(id: 'driver', state: WolLayerState.unknown, summary: '--'),
  WolLayerCheck(id: 'persistence', state: WolLayerState.unknown, summary: '--'),
  WolLayerCheck(id: 'power', state: WolLayerState.unknown, summary: '--'),
];

WolAuditReport _parseWolReportOutput({
  required String stdout,
  required String stderr,
  required bool isSuccess,
  String? deviceId,
  required String fallbackName,
  required String fallbackIp,
  required String fallbackOs,
}) {
  Map<String, dynamic>? jsonMap;
  for (final line in const LineSplitter().convert(stdout)) {
    final idx = line.indexOf(WolScripts.outputPrefix);
    if (idx >= 0) {
      final raw = line.substring(idx + WolScripts.outputPrefix.length).trim();
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) jsonMap = decoded;
      } catch (_) {}
    }
  }

  final now = DateTime.now();
  if (jsonMap == null) {
    final combined = '$stderr\n$stdout'.toLowerCase();
    final isAuth =
        combined.contains('access is denied') ||
        combined.contains('accessdenied') ||
        combined.contains('unauthorized') ||
        combined.contains('authentication failed') ||
        combined.contains('permission denied') ||
        combined.contains('sudo:') ||
        combined.contains('1223') ||
        combined.contains('canceled by the user');
    return WolAuditReport(
      deviceId: deviceId,
      targetName: fallbackName,
      ip: fallbackIp,
      os: fallbackOs,
      overallStatus: isAuth
          ? WolReadinessStatus.authRequired
          : WolReadinessStatus.unreachable,
      layers: _unknownWolLayers,
      rawError: stderr.trim().isNotEmpty ? stderr.trim() : stdout.trim(),
      checkedAt: now,
    );
  }

  final host = (jsonMap['host'] as String?)?.trim();
  final ip = (jsonMap['ip'] as String?)?.trim();
  final model = (jsonMap['model'] as String?)?.trim() ?? '';
  final bios = (jsonMap['bios'] as String?)?.trim() ?? '';
  final modelAndBios = [model, bios].where((s) => s.isNotEmpty).join(' | ');
  final detectedMac = (jsonMap['mac'] as String?)?.trim();
  final adapterName = (jsonMap['adapterName'] as String?)?.trim();
  final adapterDesc = (jsonMap['adapterDesc'] as String?)?.trim();
  final adapterDisplay =
      (adapterName != null &&
          adapterName.isNotEmpty &&
          adapterDesc != null &&
          adapterDesc.isNotEmpty)
      ? '$adapterName ($adapterDesc)'
      : (adapterName?.isNotEmpty == true ? adapterName : adapterDesc);

  final actions = (jsonMap['actions'] as List<dynamic>? ?? const [])
      .map((e) => e.toString())
      .toList();

  if (jsonMap['authRequired'] == true) {
    return WolAuditReport(
      deviceId: deviceId,
      targetName: (host != null && host.isNotEmpty) ? host : fallbackName,
      ip: (ip != null && ip.isNotEmpty) ? ip : fallbackIp,
      os: fallbackOs,
      detectedMac: (detectedMac != null && detectedMac.isNotEmpty)
          ? detectedMac
          : null,
      adapterName: adapterDisplay,
      modelAndBios: modelAndBios.isNotEmpty ? modelAndBios : null,
      overallStatus: WolReadinessStatus.authRequired,
      layers: _unknownWolLayers,
      rawError: jsonMap['error']?.toString(),
      checkedAt: now,
    );
  }

  final resolvedName = (host != null && host.isNotEmpty) ? host : fallbackName;
  final resolvedIp = (ip != null && ip.isNotEmpty) ? ip : fallbackIp;
  final isLinux = (jsonMap['os'] as String?)?.toLowerCase() == 'linux';
  return isLinux
      ? _evaluateLinuxWol(
          jsonMap,
          deviceId: deviceId,
          targetName: resolvedName,
          ip: resolvedIp,
          detectedMac: detectedMac,
          adapterDisplay: adapterDisplay,
          modelAndBios: modelAndBios,
          actions: actions,
          now: now,
        )
      : _evaluateWindowsWol(
          jsonMap,
          deviceId: deviceId,
          targetName: resolvedName,
          ip: resolvedIp,
          detectedMac: detectedMac,
          adapterDisplay: adapterDisplay,
          modelAndBios: modelAndBios,
          actions: actions,
          now: now,
        );
}

WolAuditReport _evaluateWindowsWol(
  Map<String, dynamic> j, {
  required String? deviceId,
  required String targetName,
  required String ip,
  required String? detectedMac,
  required String? adapterDisplay,
  required String modelAndBios,
  required List<String> actions,
  required DateTime now,
}) {
  final isAdmin = j['isAdmin'] == true;
  final biosWmi = j['biosWmiSupported'] == true;
  final biosPass = j['biosPasswordSet'] == true;
  final biosWol = j['biosWolSetting']?.toString();
  final biosS5 = j['biosS5PowerSaving']?.toString();
  final biosReboot = j['biosNeedsReboot'] == true;
  final hasPcie = j['hasPcieNic'] == true;
  final usbOnly = j['usbOnlyNic'] == true;

  var manualBios = false;
  late WolLayerCheck l1;
  if (biosWmi) {
    final badWol =
        biosWol != null && biosWol.toLowerCase().startsWith('disable');
    final badS5 = biosS5 != null && biosS5.toLowerCase().startsWith('enable');
    if (badWol || badS5) {
      l1 = WolLayerCheck(
        id: 'bios',
        state: biosPass ? WolLayerState.warn : WolLayerState.fail,
        summary: biosPass
            ? 'BIOS đang khóa mật khẩu Setup (${biosWol ?? "Disable"})'
            : 'BIOS chưa bật WoL (${biosWol ?? "--"}) / S5=${biosS5 ?? "--"}',
        details: [
          'Wake On LAN: ${biosWol ?? "--"}',
          'S5 Power: ${biosS5 ?? "--"}',
        ],
      );
    } else if (biosReboot) {
      l1 = WolLayerCheck(
        id: 'bios',
        state: WolLayerState.warn,
        summary: 'Đã cập nhật BIOS WMI — Cần khởi động lại để có hiệu lực',
        details: [
          'Wake On LAN: ${biosWol ?? "--"}',
          'S5 Power: ${biosS5 ?? "--"}',
        ],
      );
    } else {
      l1 = WolLayerCheck(
        id: 'bios',
        state: WolLayerState.pass,
        summary:
            'HP BIOS WMI: ${biosWol ?? "Enabled"} (S5: ${biosS5 ?? "Off"})',
        details: [
          'Wake On LAN: ${biosWol ?? "--"}',
          'S5 Power: ${biosS5 ?? "--"}',
        ],
      );
    }
  } else {
    manualBios = true;
    l1 = WolLayerCheck(
      id: 'bios',
      state: WolLayerState.warn,
      summary: 'BIOS không mở WMI — Xác nhận thủ công mục WoL / ErP (F10)',
      details: [if (modelAndBios.isNotEmpty) modelAndBios],
    );
  }

  late WolLayerCheck l2;
  if (usbOnly) {
    l2 = WolLayerCheck(
      id: 'driver',
      state: WolLayerState.fail,
      summary: 'Chỉ có USB-LAN (không hỗ trợ đánh thức từ Shutdown S5)',
      details: [?adapterDisplay],
    );
  } else if (!hasPcie) {
    l2 = const WolLayerCheck(
      id: 'driver',
      state: WolLayerState.fail,
      summary: 'Không tìm thấy card mạng PCIe Ethernet',
    );
  } else {
    final wakeMagic = j['wakeOnMagicPacket'] as bool?;
    final s5Wol = j['s5WakeOnLan'] as bool?;
    final eeeOff = j['eeeDisabled'] as bool?;
    final details = <String>[
      if (adapterDisplay != null) 'NIC: $adapterDisplay',
      'MagicPacket: ${wakeMagic ?? "--"}',
      if (s5Wol != null) 'S5WakeOnLan: $s5Wol',
      if (eeeOff != null) 'EEE Disabled: $eeeOff',
    ];
    if (wakeMagic == false || s5Wol == false || eeeOff == false) {
      l2 = WolLayerCheck(
        id: 'driver',
        state: WolLayerState.fail,
        summary: wakeMagic == false
            ? 'Driver chưa bật Wake on Magic Packet'
            : (s5Wol == false
                  ? 'Driver chưa bật Shutdown Wake-On-Lan (S5)'
                  : 'EEE / Green Ethernet đang bật — dễ rớt link S5'),
        details: details,
      );
    } else if (wakeMagic == null && !isAdmin) {
      l2 = WolLayerCheck(
        id: 'driver',
        state: WolLayerState.warn,
        summary: 'Chưa đọc được cờ driver (cần quyền Admin)',
        details: details,
      );
    } else {
      l2 = WolLayerCheck(
        id: 'driver',
        state: WolLayerState.pass,
        summary: 'PCIe Driver: MagicPacket=ON, S5/EEE đạt chuẩn',
        details: details,
      );
    }
  }

  final wakeArmed = j['wakeArmed'] == true;
  final wmiWake = j['wmiWakeEnabled'] as bool?;
  final l3 = (!wakeArmed || wmiWake == false)
      ? WolLayerCheck(
          id: 'persistence',
          state: WolLayerState.fail,
          summary: !wakeArmed
              ? 'powercfg /devicequery wake_armed chưa kích hoạt NIC'
              : 'WMI MSPower_DeviceWakeEnable đang tắt',
          details: [
            'wake_armed: $wakeArmed',
            'WMI WakeEnable: ${wmiWake ?? "--"}',
          ],
        )
      : WolLayerCheck(
          id: 'persistence',
          state: WolLayerState.pass,
          summary: 'powercfg wake_armed = ACTIVE',
          details: [
            'wake_armed: true',
            'WMI WakeEnable: ${wmiWake ?? (isAdmin ? "--" : "N/A (User)")}',
          ],
        );

  final fastOff = j['fastStartupDisabled'] == true;
  final aspmOff = j['aspmDisabled'] as bool?;
  final l4 = (!fastOff || aspmOff == false)
      ? WolLayerCheck(
          id: 'power',
          state: WolLayerState.fail,
          summary: !fastOff
              ? 'Fast Startup (Hiberboot=1) đang bật — chặn WoL ở Shutdown S4'
              : 'PCIe ASPM AC đang bật tiết kiệm điện',
          details: [
            'FastStartupOff: $fastOff',
            'PCIe ASPM Off: ${aspmOff ?? "--"}',
          ],
        )
      : WolLayerCheck(
          id: 'power',
          state: WolLayerState.pass,
          summary: 'Fast Startup = OFF, PCIe ASPM = OFF',
          details: [
            'FastStartupOff: true',
            'PCIe ASPM Off: ${aspmOff ?? "OK"}',
          ],
        );

  final layers = [l1, l2, l3, l4];
  late WolReadinessStatus status;
  if (usbOnly) {
    status = WolReadinessStatus.unsupportedUsbOnly;
  } else if (layers.any((l) => l.state == WolLayerState.fail)) {
    status = WolReadinessStatus.needsFix;
  } else if (manualBios ||
      biosReboot ||
      layers.any((l) => l.state == WolLayerState.warn)) {
    status = WolReadinessStatus.partialBiosManual;
  } else {
    status = WolReadinessStatus.ready;
  }

  return WolAuditReport(
    deviceId: deviceId,
    targetName: targetName,
    ip: ip,
    os: 'Windows',
    detectedMac: (detectedMac != null && detectedMac.isNotEmpty)
        ? detectedMac
        : null,
    adapterName: adapterDisplay,
    modelAndBios: modelAndBios.isNotEmpty ? modelAndBios : null,
    overallStatus: status,
    layers: layers,
    actionsApplied: actions,
    needsBiosManualCheck: manualBios,
    needsReboot: biosReboot,
    checkedAt: now,
  );
}

WolAuditReport _evaluateLinuxWol(
  Map<String, dynamic> j, {
  required String? deviceId,
  required String targetName,
  required String ip,
  required String? detectedMac,
  required String? adapterDisplay,
  required String modelAndBios,
  required List<String> actions,
  required DateTime now,
}) {
  final hasSudo = j['hasSudo'] == true;
  final biosExposed = j['biosAttrExposed'] == true;
  final biosWol = j['biosWolSetting']?.toString();
  final biosS5 = j['biosS5PowerSaving']?.toString();
  final acpiState = j['acpiWakeState']?.toString() ?? '';
  final usbOnly = j['usbOnlyNic'] == true;
  final hasPcie = j['hasPcieNic'] == true;
  final wolCur = j['wolCurrent']?.toString() ?? '';
  final eeeOff = j['eeeDisabled'] as bool?;
  final sysfsWake = j['sysfsWakeup']?.toString() ?? '';
  final nmWol = j['nmWol']?.toString() ?? '';
  final nmConf = j['nmConfPresent'] == true;
  final svcOk = j['systemdEnabled'] == true && j['systemdActive'] == true;
  final sshReady = j['sshReady'] == true;

  var manualBios = false;
  late WolLayerCheck l1;
  if (acpiState.contains('*disabled')) {
    l1 = WolLayerCheck(
      id: 'bios',
      state: WolLayerState.fail,
      summary: 'ACPI wakeup thiết bị PCIe đang *disabled',
      details: ['ACPI: $acpiState'],
    );
  } else if (biosExposed &&
      ((biosWol?.toLowerCase().startsWith('disable') ?? false) ||
          (biosS5?.toLowerCase().startsWith('enable') ?? false))) {
    l1 = WolLayerCheck(
      id: 'bios',
      state: WolLayerState.fail,
      summary: 'HP BIOS firmware tắt WoL hoặc bật S5 Max Power Savings',
      details: ['BIOS WoL: ${biosWol ?? "--"}', 'S5 Power: ${biosS5 ?? "--"}'],
    );
  } else if (biosExposed) {
    l1 = WolLayerCheck(
      id: 'bios',
      state: WolLayerState.pass,
      summary: 'HP BIOS & ACPI Wakeup sẵn sàng ($acpiState)',
    );
  } else {
    manualBios = true;
    l1 = WolLayerCheck(
      id: 'bios',
      state: WolLayerState.warn,
      summary: acpiState.contains('*enabled')
          ? 'ACPI *enabled; BIOS không xuất cờ WoL — xác nhận F10 nếu tắt S5'
          : 'Cần xác nhận WoL trong BIOS (F10)',
      details: [if (acpiState.isNotEmpty) 'ACPI: $acpiState'],
    );
  }

  late WolLayerCheck l2;
  if (usbOnly) {
    l2 = const WolLayerCheck(
      id: 'driver',
      state: WolLayerState.fail,
      summary: 'Chỉ có USB-LAN (không hỗ trợ kích nguồn S5)',
    );
  } else if (!hasPcie) {
    l2 = const WolLayerCheck(
      id: 'driver',
      state: WolLayerState.fail,
      summary: 'Không tìm thấy card mạng PCIe Ethernet',
    );
  } else if (sysfsWake != 'enabled') {
    l2 = WolLayerCheck(
      id: 'driver',
      state: WolLayerState.fail,
      summary: 'sysfs device/power/wakeup đang là "$sysfsWake" (cần enabled)',
      details: ['sysfs wakeup: $sysfsWake', 'ethtool Wake-on: $wolCur'],
    );
  } else if (hasSudo && !wolCur.contains('g')) {
    l2 = WolLayerCheck(
      id: 'driver',
      state: WolLayerState.fail,
      summary:
          'ethtool Wake-on đang là "${wolCur.isEmpty ? "d" : wolCur}" (cần g)',
      details: ['Supports: ${j['wolSupported'] ?? "--"}', 'Wake-on: $wolCur'],
    );
  } else if (hasSudo && eeeOff == false) {
    l2 = const WolLayerCheck(
      id: 'driver',
      state: WolLayerState.fail,
      summary: 'EEE đang bật trên NIC — cần tắt để giữ link khi S5',
    );
  } else if (!hasSudo && wolCur.isEmpty) {
    l2 = const WolLayerCheck(
      id: 'driver',
      state: WolLayerState.warn,
      summary:
          'sysfs wakeup=enabled (cần sudo để xác minh cờ ethtool Wake-on: g)',
      details: ['sysfs wakeup: enabled'],
    );
  } else {
    l2 = WolLayerCheck(
      id: 'driver',
      state: WolLayerState.pass,
      summary:
          'Wake-on: ${wolCur.isEmpty ? "g" : wolCur}, sysfs power/wakeup = enabled',
      details: [
        'Supports: ${j['wolSupported'] ?? "--"}',
        'EEE Off: ${eeeOff ?? "N/A"}',
      ],
    );
  }

  final nmMagic =
      nmWol == 'magic' ||
      nmWol == '64' ||
      nmWol.toLowerCase().contains('magic');
  final l3 = (nmMagic && nmConf && svcOk)
      ? const WolLayerCheck(
          id: 'persistence',
          state: WolLayerState.pass,
          summary: 'Khóa bền vững 3 lớp (NM + conf.d + systemd wol)',
          details: [
            'NM: magic',
            'conf.d: 90-ja-wol.conf',
            'systemd: enabled & active',
          ],
        )
      : WolLayerCheck(
          id: 'persistence',
          state: WolLayerState.fail,
          summary: 'Chưa khóa đủ 3 lớp qua reboot/shutdown',
          details: [
            'NM wake-on-lan: ${nmWol.isEmpty ? "default" : nmWol}',
            'conf.d: $nmConf',
            'systemd wol service: $svcOk',
          ],
        );

  final l4 = sshReady
      ? const WolLayerCheck(
          id: 'power',
          state: WolLayerState.pass,
          summary:
              'ssh.service enabled & active — sẵn sàng điều khiển sau boot',
        )
      : const WolLayerCheck(
          id: 'power',
          state: WolLayerState.warn,
          summary: 'ssh.service chưa bật tự chạy khi khởi động',
        );

  final layers = [l1, l2, l3, l4];
  late WolReadinessStatus status;
  if (usbOnly) {
    status = WolReadinessStatus.unsupportedUsbOnly;
  } else if (layers.any((l) => l.state == WolLayerState.fail)) {
    status = WolReadinessStatus.needsFix;
  } else if (manualBios || layers.any((l) => l.state == WolLayerState.warn)) {
    status = WolReadinessStatus.partialBiosManual;
  } else {
    status = WolReadinessStatus.ready;
  }

  return WolAuditReport(
    deviceId: deviceId,
    targetName: targetName,
    ip: ip,
    os: 'Linux',
    detectedMac: (detectedMac != null && detectedMac.isNotEmpty)
        ? detectedMac
        : null,
    adapterName: adapterDisplay,
    modelAndBios: modelAndBios.isNotEmpty ? modelAndBios : null,
    overallStatus: status,
    layers: layers,
    actionsApplied: actions,
    needsBiosManualCheck: manualBios,
    checkedAt: now,
  );
}

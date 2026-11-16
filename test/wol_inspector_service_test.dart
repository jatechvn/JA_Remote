import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/network_utils.dart';
import 'package:ja_remote/core/process/process_runner.dart';
import 'package:ja_remote/core/utils/app_storage.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/services/power_service.dart';
import 'package:ja_remote/services/remote_command_service.dart';
import 'package:ja_remote/services/wol_inspector_service.dart';
import 'package:ja_remote/services/wol_scripts.dart';

class _FakeRemoteCommandService extends RemoteCommandService {
  final Future<RemoteCommandResult> Function(
    ManagedDevice device,
    String command,
    String? typeOverride,
  )
  handler;

  _FakeRemoteCommandService(this.handler);

  @override
  Future<RemoteCommandResult> execute({
    required ManagedDevice device,
    required String command,
    String? typeOverride,
    String? username,
    String? password,
    int timeoutSeconds = 15,
  }) => handler(device, command, typeOverride);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wol_service_test_');
    AppStorage.setDirectoryForTesting(tempDir);
  });

  tearDown(() async {
    AppStorage.setDirectoryForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Supernet /21 Broadcast & PowerService', () {
    test(
      'NetworkUtils.getBroadcastIp handles /21 supernet and /24 fallback',
      () {
        expect(
          NetworkUtils.getBroadcastIp('172.21.174.80/21'),
          '172.21.175.255',
        );
        expect(
          NetworkUtils.getBroadcastIp('192.168.10.42/24'),
          '192.168.10.255',
        );
        expect(NetworkUtils.getBroadcastIp('172.21.175.29'), '172.21.175.255');
        expect(NetworkUtils.getBroadcastIp('invalid-ip'), '255.255.255.255');
      },
    );

    test(
      'resolveDirectedBroadcast matches /21 physical adapter before /24 fallback',
      () {
        const adapters = [
          NetworkInterfaceDetails(
            name: 'Ethernet 2',
            ip: '172.21.175.48',
            subnet: '172.21.168.0/21',
            isVirtual: false,
            isPrivateLan: true,
            netmask: '255.255.248.0',
            prefixLength: 21,
          ),
          NetworkInterfaceDetails(
            name: 'Tailscale',
            ip: '100.80.1.2',
            subnet: '100.80.1.0/24',
            isVirtual: true,
            isPrivateLan: false,
            prefixLength: 24,
          ),
        ];

        final resolved = NetworkUtils.resolveDirectedBroadcast(
          '172.21.170.161',
          adapters,
        );
        expect(resolved.broadcastIp, '172.21.175.255');
        expect(resolved.localBindIp, '172.21.175.48');

        final fallback = NetworkUtils.resolveDirectedBroadcast(
          '10.10.5.9',
          adapters,
        );
        expect(fallback.broadcastIp, '10.10.5.255');
        expect(fallback.localBindIp, isNull);
      },
    );

    test(
      'PowerService.wakeDevice rejects missing MAC and uses adapter resolver',
      () async {
        final svc = PowerService(
          loadAdapters: () async => const [
            NetworkInterfaceDetails(
              name: 'Ethernet 2',
              ip: '172.21.175.48',
              subnet: '172.21.168.0/21',
              isVirtual: false,
              isPrivateLan: true,
              prefixLength: 21,
            ),
          ],
        );

        final missingMac = await svc.wakeDevice(
          const ManagedDevice(
            id: 'd1',
            name: 'NoMac',
            hostname: 'nomac',
            ip: '172.21.175.29',
          ),
        );
        expect(missingMac, isFalse);

        final ok = await svc.wakeDevice(
          const ManagedDevice(
            id: 'd2',
            name: 'LinuxAI',
            hostname: 'linux-ai',
            ip: '172.21.175.29',
            mac: 'F8-ED-FC-54-FE-AE',
            os: 'Linux',
          ),
        );
        expect(ok, isTrue);
      },
    );

    test(
      'RemoteCommandService.loadLocalSshIdentities skips missing/invalid files safely',
      () async {
        final sshDir = Directory('${tempDir.path}/.ssh');
        await sshDir.create(recursive: true);
        await File(
          '${sshDir.path}/id_ed25519',
        ).writeAsString('not-a-valid-pem');
        final loaded = RemoteCommandService.loadLocalSshIdentities(
          sshDir: sshDir,
        );
        expect(loaded, isEmpty);
      },
    );
  });

  group('WolScripts builders', () {
    test(
      'Windows script controls Restart-NetAdapter flag separately for UAC vs WinRM',
      () {
        final winrmFix = WolScripts.buildWindowsScript(
          applyFix: true,
          allowAdapterRestart: false,
        );
        final localFix = WolScripts.buildWindowsScript(
          applyFix: true,
          allowAdapterRestart: true,
        );
        expect(winrmFix, contains(r'$applyFix = $true'));
        expect(winrmFix, contains(r'$allowRestart = $false'));
        expect(localFix, contains(r'$allowRestart = $true'));
      },
    );

    test(
      'Linux script base64-wraps commands and never exposes plaintext sudo password',
      () {
        final cmd = WolScripts.buildLinuxScript(
          applyFix: true,
          sudoPassword: 'SecretSudoPass!99',
        );
        expect(cmd, contains('JA_SUDO_PW_B64='));
        expect(cmd, isNot(contains('SecretSudoPass!99')));
      },
    );
  });

  group('WolInspectorService 4-layer parser & orchestration', () {
    test('parses Windows needsFix then ready after WMI+NIC fix', () {
      const beforeJson =
          'JA_WOL_JSON:{"os":"windows","host":"CMDL09","model":"HP Pro Tower 280 G9","bios":"AMI F.33","isAdmin":true,"biosWmiSupported":true,"biosPasswordSet":false,"biosWolSetting":"Disable","biosS5PowerSaving":"Enable","biosNeedsReboot":false,"hasPcieNic":true,"usbOnlyNic":false,"adapterName":"Ethernet 2","adapterDesc":"Realtek PCIe GbE","mac":"F8-ED-FC-53-16-F7","ip":"172.21.175.48","wakeOnMagicPacket":false,"s5WakeOnLan":false,"eeeDisabled":false,"wmiWakeEnabled":false,"wakeArmed":false,"fastStartupDisabled":false,"aspmDisabled":false,"actions":[]}';
      final needsFix = WolInspectorService.parseReportOutput(
        stdout: beforeJson,
        stderr: '',
        isSuccess: true,
        deviceId: 'win-1',
        fallbackName: 'CMDL09',
        fallbackIp: '172.21.175.48',
        fallbackOs: 'Windows',
      );
      expect(needsFix.overallStatus, WolReadinessStatus.needsFix);
      expect(needsFix.canAutoFix, isTrue);
      expect(needsFix.detectedMac, 'F8-ED-FC-53-16-F7');
      expect(
        needsFix.layers.every((l) => l.state == WolLayerState.fail),
        isTrue,
      );

      const afterJson =
          'JA_WOL_JSON:{"os":"windows","host":"CMDL09","model":"HP Pro Tower 280 G9","bios":"AMI F.33","isAdmin":true,"biosWmiSupported":true,"biosPasswordSet":false,"biosWolSetting":"Boot to Hard Drive","biosS5PowerSaving":"Disable","biosNeedsReboot":false,"hasPcieNic":true,"usbOnlyNic":false,"adapterName":"Ethernet 2","adapterDesc":"Realtek PCIe GbE","mac":"F8-ED-FC-53-16-F7","ip":"172.21.175.48","wakeOnMagicPacket":true,"s5WakeOnLan":true,"eeeDisabled":true,"wmiWakeEnabled":true,"wakeArmed":true,"fastStartupDisabled":true,"aspmDisabled":true,"actions":["BIOS: Wake On LAN -> Boot to Hard Drive","OS: HiberbootEnabled 1 -> 0"]}';
      final ready = WolInspectorService.parseReportOutput(
        stdout: afterJson,
        stderr: '',
        isSuccess: true,
        deviceId: 'win-1',
        fallbackName: 'CMDL09',
        fallbackIp: '172.21.175.48',
        fallbackOs: 'Windows',
      );
      expect(ready.overallStatus, WolReadinessStatus.ready);
      expect(ready.isReady, isTrue);
      expect(ready.actionsApplied.length, 2);
      expect(ready.layers.every((l) => l.state == WolLayerState.pass), isTrue);
    });

    test(
      'Windows AMI BIOS without WMI reports partialBiosManual when OS layers pass',
      () {
        const amiJson =
            'JA_WOL_JSON:{"os":"windows","host":"CMDL09","model":"HP Pro Tower 280 G9","bios":"AMI F.33","isAdmin":false,"biosWmiSupported":false,"biosPasswordSet":false,"biosNeedsReboot":false,"hasPcieNic":true,"usbOnlyNic":false,"adapterName":"Ethernet 2","adapterDesc":"Realtek PCIe GbE","mac":"F8-ED-FC-53-16-F7","ip":"172.21.175.48","wakeOnMagicPacket":true,"s5WakeOnLan":true,"eeeDisabled":true,"wmiWakeEnabled":null,"wakeArmed":true,"fastStartupDisabled":true,"aspmDisabled":true,"actions":[]}';
        final report = WolInspectorService.parseReportOutput(
          stdout: amiJson,
          stderr: '',
          isSuccess: true,
          fallbackName: 'CMDL09',
          fallbackIp: '127.0.0.1',
          fallbackOs: 'Windows',
        );
        expect(report.overallStatus, WolReadinessStatus.partialBiosManual);
        expect(report.isReady, isTrue);
        expect(report.needsBiosManualCheck, isTrue);
      },
    );

    test('USB-only NIC is flagged unsupportedUsbOnly', () {
      const usbJson =
          'JA_WOL_JSON:{"os":"windows","host":"PC-USB","isAdmin":true,"biosWmiSupported":false,"hasPcieNic":false,"usbOnlyNic":true,"adapterName":"Ethernet 3","adapterDesc":"USB GbE","mac":"AA-BB-CC-DD-EE-01","ip":"172.21.175.99","fastStartupDisabled":true,"aspmDisabled":true,"actions":[]}';
      final report = WolInspectorService.parseReportOutput(
        stdout: usbJson,
        stderr: '',
        isSuccess: true,
        fallbackName: 'PC-USB',
        fallbackIp: '172.21.175.99',
        fallbackOs: 'Windows',
      );
      expect(report.overallStatus, WolReadinessStatus.unsupportedUsbOnly);
      expect(report.canAutoFix, isFalse);
    });

    test('parses Linux needsFix and 3-lock ready report', () {
      const linuxNeedsFix =
          'JA_WOL_JSON:{"os":"linux","host":"jaai-pc","model":"HP 280 G9","bios":"AMI F.33","hasSudo":true,"biosAttrExposed":false,"acpiWakeState":"PXSX S4 *enabled pci:0000:01:00.0","hasPcieNic":true,"usbOnlyNic":false,"adapterName":"enp1s0","adapterDesc":"r8169 (0000:01:00.0)","mac":"F8-ED-FC-54-FE-AE","ip":"172.21.175.29","wolSupported":"pumbg","wolCurrent":"d","eeeDisabled":false,"sysfsWakeup":"disabled","nmWol":"default","nmConfPresent":false,"systemdEnabled":false,"systemdActive":false,"sshReady":true,"actions":[]}';
      final r1 = WolInspectorService.parseReportOutput(
        stdout: linuxNeedsFix,
        stderr: '',
        isSuccess: true,
        fallbackName: 'ja-ai',
        fallbackIp: '172.21.175.29',
        fallbackOs: 'Linux',
      );
      expect(r1.overallStatus, WolReadinessStatus.needsFix);

      const linuxFixed =
          'JA_WOL_JSON:{"os":"linux","host":"jaai-pc","model":"HP 280 G9","bios":"AMI F.33","hasSudo":true,"biosAttrExposed":true,"biosWolSetting":"Enable","biosS5PowerSaving":"Disable","acpiWakeState":"PXSX S4 *enabled pci:0000:01:00.0","hasPcieNic":true,"usbOnlyNic":false,"adapterName":"enp1s0","adapterDesc":"r8169 (0000:01:00.0)","mac":"F8-ED-FC-54-FE-AE","ip":"172.21.175.29","wolSupported":"pumbg","wolCurrent":"g","eeeDisabled":true,"sysfsWakeup":"enabled","nmWol":"magic","nmConfPresent":true,"systemdEnabled":true,"systemdActive":true,"sshReady":true,"actions":["ethtool -s enp1s0 wol g","Enabled wol-enp1s0.service"]}';
      final r2 = WolInspectorService.parseReportOutput(
        stdout: linuxFixed,
        stderr: '',
        isSuccess: true,
        fallbackName: 'ja-ai',
        fallbackIp: '172.21.175.29',
        fallbackOs: 'Linux',
      );
      expect(r2.overallStatus, WolReadinessStatus.ready);
      expect(r2.isReady, isTrue);
      expect(r2.actionsApplied.length, 2);
    });

    test('classifies authRequired and unreachable errors accurately', () {
      final authJson = WolInspectorService.parseReportOutput(
        stdout:
            'JA_WOL_JSON:{"os":"linux","hasSudo":false,"authRequired":true,"error":"sudo required"}',
        stderr: '',
        isSuccess: true,
        fallbackName: 'L1',
        fallbackIp: '172.21.175.29',
        fallbackOs: 'Linux',
      );
      expect(authJson.overallStatus, WolReadinessStatus.authRequired);

      final uacDenied = WolInspectorService.parseReportOutput(
        stdout: '',
        stderr: 'The operation was canceled by the user',
        isSuccess: false,
        fallbackName: 'ThisPC',
        fallbackIp: '127.0.0.1',
        fallbackOs: 'Windows',
      );
      expect(uacDenied.overallStatus, WolReadinessStatus.authRequired);

      final timeout = WolInspectorService.parseReportOutput(
        stdout: '',
        stderr: 'SocketException: Connection timed out',
        isSuccess: false,
        fallbackName: 'OffPC',
        fallbackIp: '172.21.175.90',
        fallbackOs: 'Windows',
      );
      expect(timeout.overallStatus, WolReadinessStatus.unreachable);
    });

    test('checkLocalWindows and runBatch with cancellation work cleanly', () async {
      final remote = _FakeRemoteCommandService((
        device,
        cmd,
        typeOverride,
      ) async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        return RemoteCommandResult(
          device: device,
          isSuccess: true,
          output:
              'JA_WOL_JSON:{"os":"linux","host":"${device.name}","hasSudo":true,"biosAttrExposed":true,"acpiWakeState":"*enabled","hasPcieNic":true,"usbOnlyNic":false,"mac":"F8-ED-FC-54-FE-AE","ip":"${device.ip}","wolCurrent":"g","eeeDisabled":true,"sysfsWakeup":"enabled","nmWol":"magic","nmConfPresent":true,"systemdEnabled":true,"systemdActive":true,"sshReady":true,"actions":[]}',
          error: '',
          durationMs: 25,
        );
      });

      final service = WolInspectorService(
        remoteService: remote,
        localPowerShellRunner: (script, {int timeoutSeconds = 20}) async {
          return const ProcessExecutionResult(
            exitCode: 0,
            stdout:
                'JA_WOL_JSON:{"os":"windows","host":"LOCALPC","isAdmin":true,"biosWmiSupported":true,"biosWolSetting":"Enable","biosS5PowerSaving":"Disable","hasPcieNic":true,"usbOnlyNic":false,"mac":"F8-ED-FC-53-16-F7","ip":"172.21.175.48","wakeOnMagicPacket":true,"s5WakeOnLan":true,"eeeDisabled":true,"wmiWakeEnabled":true,"wakeArmed":true,"fastStartupDisabled":true,"aspmDisabled":true,"actions":[]}',
            stderr: '',
            isSuccess: true,
          );
        },
      );

      final localReport = await service.checkLocalWindows();
      expect(localReport.overallStatus, WolReadinessStatus.ready);
      expect(localReport.detectedMac, 'F8-ED-FC-53-16-F7');

      final devices = List.generate(
        6,
        (i) => ManagedDevice(
          id: 'd$i',
          name: 'Node-$i',
          hostname: 'node-$i',
          ip: '172.21.175.${10 + i}',
          os: 'Linux',
        ),
      );
      var completed = 0;
      final batchFuture = service.runBatch(
        devices: devices,
        applyFix: false,
        concurrency: 2,
        onProgress: (done, total, _) {
          completed = done;
          if (done == 2) service.cancel();
        },
      );
      final results = await batchFuture;
      expect(completed, greaterThanOrEqualTo(2));
      expect(results.length, lessThanOrEqualTo(devices.length));
    });
  });
}

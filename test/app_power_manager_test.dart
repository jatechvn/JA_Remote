import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/utils/app_storage.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/services/app_power_manager.dart';
import 'package:ja_remote/services/device_service.dart';
import 'package:ja_remote/services/ip_drift_scanner_service.dart';
import 'package:ja_remote/widgets/glass_widgets.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ja_remote_power_test_');
    AppStorage.setDirectoryForTesting(tempDir);
    AppPowerManager.instance.resetForTesting(
      focused: true,
      visible: true,
      enableIdleSleep: true,
      idleTimeoutSeconds: 5,
    );
  });

  tearDown(() async {
    AppPowerManager.instance.resetForTesting();
    AppStorage.setDirectoryForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AppPowerManager 4-Tier Policy & Guards', () {
    test('Tier 1 (Active) enables all animation tiers', () {
      final power = AppPowerManager.instance;
      expect(power.isWindowFocused, isTrue);
      expect(power.isWindowVisible, isTrue);
      expect(power.isUserIdle, isFalse);
      expect(power.shouldAnimateBackground, isTrue);
      expect(power.shouldAnimateIndicators, isTrue);
      expect(power.shouldAnimateMarquee, isTrue);
    });

    test('Tier 3 (Unfocused) disables all animation tiers immediately', () {
      final power = AppPowerManager.instance;
      power.setWindowFocused(false);

      expect(power.isWindowFocused, isFalse);
      expect(power.shouldAnimateBackground, isFalse);
      expect(power.shouldAnimateIndicators, isFalse);
      expect(power.shouldAnimateMarquee, isFalse);
      expect(power.backgroundAnimationNotifier.value, isFalse);
      expect(power.indicatorsAnimationNotifier.value, isFalse);
      expect(power.marqueeAnimationNotifier.value, isFalse);
    });

    test(
      'Unfocused Restore Guard: restoring visibility while unfocused keeps animations paused',
      () {
        final power = AppPowerManager.instance;
        power.setWindowFocused(false);
        power.setWindowVisible(false);
        expect(power.isRenderingActive, isFalse);

        // Window becomes visible on another monitor/behind active window without focus
        power.setWindowVisible(true);
        expect(power.isWindowVisible, isTrue);
        expect(power.isWindowFocused, isFalse);
        expect(power.shouldAnimateBackground, isFalse);
        expect(power.shouldAnimateIndicators, isFalse);
        expect(power.shouldAnimateMarquee, isFalse);

        // Once focused, animations resume
        power.setWindowFocused(true);
        expect(power.shouldAnimateBackground, isTrue);
        expect(power.shouldAnimateIndicators, isTrue);
        expect(power.shouldAnimateMarquee, isTrue);
      },
    );

    test('Settings persistence saves and loads power_settings.json', () async {
      final power = AppPowerManager.instance;
      power.setEnableIdleSleep(false, persist: false);
      power.setIdleTimeoutSeconds(30, persist: false);
      await power.saveSettings();

      // Reset to defaults then reload from disk
      power.resetForTesting(enableIdleSleep: true, idleTimeoutSeconds: 12);
      await power.loadSettings();

      expect(power.enableIdleSleep, isFalse);
      expect(power.idleTimeoutSeconds, 30);
    });
  });

  group('Widget Animation Gating & Marquee Session Epoch', () {
    testWidgets(
      'AsymmetricMarqueeText freezes offset on pause and guards against ghost timers',
      (tester) async {
        final power = AppPowerManager.instance;
        power.resetForTesting(
          focused: true,
          visible: true,
          enableIdleSleep: true,
          idleTimeoutSeconds: 5,
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 80,
                child: AsymmetricMarqueeText(
                  text:
                      'JA Remote - TE PC Manager Very Long Overflowing Marquee Text 1234567890',
                  pauseStart: Duration(milliseconds: 200),
                  pauseEnd: Duration(milliseconds: 200),
                  velocity: 50,
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 350));
        // Lose window focus mid-scroll
        power.setWindowFocused(false);
        await tester.pump();

        // Advance time well past pauseStart/pauseEnd to verify no ghost timer throws or scrolls
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);

        // Regain focus and verify clean resumption
        power.setWindowFocused(true);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);

        // Unmount widget so marquee timers are cancelled cleanly before test teardown
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('DeviceService Deferred UI Notification & Selection Helpers', () {
    test(
      'defers UI notification while window is unfocused and flushes on focus',
      () {
        final power = AppPowerManager.instance;
        final service = DeviceService(initialize: false);
        addTearDown(service.dispose);

        service.setDevicesForTesting([
          ManagedDevice(
            id: '1',
            name: 'PC-01',
            ip: '172.21.174.12',
            hostname: 'PC-01',
          ),
          ManagedDevice(
            id: '2',
            name: 'PC-02',
            ip: '172.21.174.13',
            hostname: 'PC-02',
          ),
        ]);

        int notifyCount = 0;
        service.addListener(() => notifyCount++);

        // Unfocus window -> background metric change should defer UI rebuild
        power.setWindowFocused(false);
        service.simulateDeferredMetricChangeForTesting();
        expect(notifyCount, 0);
        expect(service.hasPendingUiUpdate, isTrue);

        // Refocus window -> deferred UI update flushes automatically
        power.setWindowFocused(true);
        expect(notifyCount, 1);
        expect(service.hasPendingUiUpdate, isFalse);
      },
    );

    test('selectByIds selects only valid device IDs', () {
      final service = DeviceService(initialize: false);
      addTearDown(service.dispose);

      service.setDevicesForTesting([
        ManagedDevice(id: 'a', name: 'HostA', ip: '10.0.0.1', hostname: 'A'),
        ManagedDevice(id: 'b', name: 'HostB', ip: '10.0.0.2', hostname: 'B'),
        ManagedDevice(id: 'c', name: 'HostC', ip: '10.0.0.3', hostname: 'C'),
      ]);

      service.selectByIds(['b', 'c', 'non_existent']);
      expect(service.selectedIds, equals({'b', 'c'}));
    });
  });

  group('TerminalLine.fromExternal & IpDriftScannerService', () {
    test(
      'TerminalLine.fromExternal strips duplicate [HH:mm:ss] prefix and classifies semantics',
      () {
        final successLine = TerminalLine.fromExternal(
          '[14:25:09] [✓] IQ5-SOZ-024 (172.21.175.117): Hoàn tất trong 420ms',
        );
        expect(
          successLine.text,
          '[✓] IQ5-SOZ-024 (172.21.175.117): Hoàn tất trong 420ms',
        );
        expect(successLine.type, TerminalLineType.success);

        final errorLine = TerminalLine.fromExternal(
          '[14:25:10] [✗] IQ4-FT3-032: Thất bại - Connection timeout',
        );
        expect(
          errorLine.text,
          '[✗] IQ4-FT3-032: Thất bại - Connection timeout',
        );
        expect(errorLine.type, TerminalLineType.error);
      },
    );

    test(
      'IpDriftScannerService.parsePastedTargets parses TSV/Excel rows and matches registered devices',
      () {
        final existing = [
          ManagedDevice(
            id: 'dev_24',
            name: 'IQ5-SOZ-024',
            ip: '172.21.174.86',
            hostname: 'IQ5-SOZ-024',
            mac: '48:ea:62:4f:b6:4f',
            group: 'IQ5',
          ),
        ];

        const raw = '''
IQ5-SOZ-024\t172.21.174.86\t48-EA-62-4F-B6-4F
JCI Dashboard\t172.21.170.161\t48:ea:62:4f:bc:7d
''';

        final parsed = IpDriftScannerService.parsePastedTargets(raw, existing);
        expect(parsed.length, 2);
        expect(parsed[0].deviceId, 'dev_24');
        expect(parsed[0].name, 'IQ5-SOZ-024');
        expect(parsed[0].expectedIp, '172.21.174.86');
        expect(parsed[0].expectedMac, '48-EA-62-4F-B6-4F');

        expect(parsed[1].deviceId, isNull);
        expect(parsed[1].name, 'JCI Dashboard');
        expect(parsed[1].expectedIp, '172.21.170.161');
        expect(parsed[1].expectedMac, '48-EA-62-4F-BC-7D');
      },
    );
  });
}

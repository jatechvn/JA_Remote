import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/core/network/network_utils.dart';
import 'package:ja_remote/core/utils/app_storage.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/data/repositories/credential_repository.dart';
import 'package:ja_remote/features/devices/devices_view.dart';
import 'package:ja_remote/features/devices/wol_inspector_dialog.dart';
import 'package:ja_remote/services/device_service.dart';
import 'package:ja_remote/services/power_service.dart';
import 'package:ja_remote/services/wol_inspector_service.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';

class _TestDeviceService extends DeviceService {
  List<ManagedDevice> items;
  final Set<String> _selected = {};

  _TestDeviceService(this.items) : super(initialize: false);

  @override
  List<ManagedDevice> get devices => List.unmodifiable(items);

  @override
  List<ManagedDevice> get filteredDevices => List.unmodifiable(items);

  @override
  Set<String> get selectedIds => _selected;

  @override
  List<ManagedDevice> get selectedDevices =>
      items.where((d) => _selected.contains(d.id)).toList();

  @override
  int get totalCount => items.length;

  @override
  int get onlineCount => items.where((d) => d.online).length;

  @override
  Future<void> addDevice(ManagedDevice device) async {
    items = [...items, device];
    notifyListeners();
  }

  @override
  Future<void> updateDevice(ManagedDevice device) async {
    items = items.map((d) => d.id == device.id ? device : d).toList();
    notifyListeners();
  }
}

class _FakeWolInspectorService extends WolInspectorService {
  bool localChecked = false;
  bool localFixed = false;
  final Map<String, bool> fixedIps = {};

  @override
  Future<WolAuditReport> checkLocalWindows() async {
    localChecked = true;
    return WolAuditReport(
      targetName: 'CMDL09-LOCAL',
      ip: '127.0.0.1',
      os: 'Windows',
      detectedMac: 'F8-ED-FC-53-16-F7',
      adapterName: 'Ethernet 2',
      modelAndBios: 'HP Pro Tower 280 G9 | AMI F.33',
      overallStatus: localFixed
          ? WolReadinessStatus.partialBiosManual
          : WolReadinessStatus.needsFix,
      layers: [
        const WolLayerCheck(
          id: 'bios',
          state: WolLayerState.warn,
          summary: 'Verify BIOS F10',
        ),
        WolLayerCheck(
          id: 'driver',
          state: localFixed ? WolLayerState.pass : WolLayerState.fail,
          summary: localFixed ? 'MagicPacket=ON' : 'MagicPacket=OFF',
        ),
        WolLayerCheck(
          id: 'persistence',
          state: localFixed ? WolLayerState.pass : WolLayerState.fail,
          summary: localFixed ? 'wake_armed=ACTIVE' : 'Not armed',
        ),
        WolLayerCheck(
          id: 'power',
          state: localFixed ? WolLayerState.pass : WolLayerState.fail,
          summary: localFixed ? 'FastStartup=OFF' : 'HiberbootEnabled=1',
        ),
      ],
      checkedAt: DateTime(2026, 11, 16),
    );
  }

  @override
  Future<WolAuditReport> fixLocalWindowsWithUac() async {
    localFixed = true;
    return checkLocalWindows();
  }

  @override
  Future<WolAuditReport> checkDevice(
    ManagedDevice device, {
    String? username,
    String? password,
    int timeoutSeconds = 20,
  }) async {
    final isFixed = fixedIps[device.ip] ?? false;
    return WolAuditReport(
      deviceId: device.id == 'adhoc_${device.ip}' ? null : device.id,
      targetName: device.name == device.ip ? 'jaai-host' : device.name,
      ip: device.ip,
      os: device.os,
      detectedMac: device.ip == '172.21.175.29'
          ? 'F8-ED-FC-54-FE-AE'
          : '48-EA-62-4F-B5-E3',
      adapterName: device.os == 'Linux' ? 'enp1s0 (r8169)' : 'Ethernet',
      overallStatus: isFixed
          ? WolReadinessStatus.ready
          : WolReadinessStatus.needsFix,
      layers: [
        WolLayerCheck(
          id: 'bios',
          state: isFixed ? WolLayerState.pass : WolLayerState.warn,
          summary: 'BIOS checked',
        ),
        WolLayerCheck(
          id: 'driver',
          state: isFixed ? WolLayerState.pass : WolLayerState.fail,
          summary: isFixed ? 'Wake-on: g' : 'Wake-on: d',
        ),
        WolLayerCheck(
          id: 'persistence',
          state: isFixed ? WolLayerState.pass : WolLayerState.fail,
          summary: isFixed ? '3-lock OK' : 'Not persisted',
        ),
        const WolLayerCheck(
          id: 'power',
          state: WolLayerState.pass,
          summary: 'SSH/Boot OK',
        ),
      ],
      actionsApplied: isFixed ? const ['Applied 3-lock WoL fix'] : const [],
      checkedAt: DateTime(2026, 11, 16),
    );
  }

  @override
  Future<WolAuditReport> fixDevice(
    ManagedDevice device, {
    String? username,
    String? password,
    int timeoutSeconds = 30,
  }) async {
    fixedIps[device.ip] = true;
    return checkDevice(device, username: username, password: password);
  }
}

class _FakePowerService extends PowerService {
  _FakePowerService()
    : super(
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
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wol_dialog_test_');
    AppStorage.setDirectoryForTesting(tempDir);
    CredentialRepository().setStorageFileForTesting(
      File('${tempDir.path}/credentials.json'),
    );
  });

  tearDown(() async {
    CredentialRepository().setStorageFileForTesting(null);
    AppStorage.setDirectoryForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'DevicesView renders WoL toolbar trigger without RenderFlex overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final devService = _TestDeviceService([
        const ManagedDevice(
          id: 'd1',
          name: 'IQ4-FT1',
          hostname: 'iq4-ft1',
          ip: '172.21.173.237',
          online: true,
        ),
      ]);
      devService._selected.add('d1');
      addTearDown(devService.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DeviceService>.value(value: devService),
            ChangeNotifierProvider(
              create: (_) =>
                  ThemeProvider()..setPerfTierMode(PerfTierMode.lite),
            ),
            ChangeNotifierProvider(
              create: (_) => LanguageProvider(initialLanguage: AppLanguage.vi),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: DevicesView())),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.settings_power_rounded), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'WolInspectorDialog supports Managed, This PC, Ad-hoc tabs, MAC sync and Fix',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final devService = _TestDeviceService([
        const ManagedDevice(
          id: 'linux-1',
          name: 'JA-AI-Linux',
          hostname: 'jaai',
          ip: '172.21.175.29',
          os: 'Linux',
          online: true,
        ),
      ]);
      addTearDown(devService.dispose);

      final fakeInspector = _FakeWolInspectorService();
      final fakePower = _FakePowerService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DeviceService>.value(value: devService),
            ChangeNotifierProvider(
              create: (_) =>
                  ThemeProvider()..setPerfTierMode(PerfTierMode.lite),
            ),
            ChangeNotifierProvider(
              create: (_) => LanguageProvider(initialLanguage: AppLanguage.en),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => showWolInspectorDialog(
                      ctx,
                      inspectorService: fakeInspector,
                      powerService: fakePower,
                    ),
                    child: const Text('Open WoL'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open WoL'));
      await tester.pumpAndSettle();

      // 1. Managed tab Check -> shows NEEDS FIX -> Sync MAC updates DeviceService -> Fix updates to READY
      await tester.tap(find.text('Check WoL'));
      await tester.pumpAndSettle();
      expect(find.text('NEEDS FIX'), findsOneWidget);
      expect(find.text('Sync MAC'), findsOneWidget);

      await tester.tap(find.text('Sync MAC'));
      await tester.pumpAndSettle();
      expect(devService.items.first.mac, 'F8-ED-FC-54-FE-AE');

      await tester.tap(find.text('Fix WoL'));
      await tester.pumpAndSettle();
      expect(find.text('READY'), findsOneWidget);

      // 2. Switch to This PC tab -> auto-runs checkLocalWindows -> click Fix with Admin (UAC)
      await tester.tap(find.text('This PC (Local)'));
      await tester.pumpAndSettle();
      expect(fakeInspector.localChecked, isTrue);
      expect(find.textContaining('CMDL09-LOCAL'), findsOneWidget);

      await tester.tap(find.text('Fix with Admin (UAC)'));
      await tester.pumpAndSettle();
      expect(fakeInspector.localFixed, isTrue);
      expect(find.text('VERIFY BIOS'), findsOneWidget);

      // 3. Switch to Ad-hoc IP tab -> enter IP + Linux -> Check -> Save to Devices
      await tester.tap(find.text('Ad-hoc IP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '172.21.175.88');
      await tester.tap(find.text('Linux'));
      await tester.tap(find.text('Check WoL'));
      await tester.pumpAndSettle();
      expect(find.text('Save to Devices'), findsOneWidget);

      await tester.tap(find.text('Save to Devices'));
      await tester.pumpAndSettle();
      expect(devService.items.any((d) => d.ip == '172.21.175.88'), isTrue);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/layout/dashboard_shell.dart';
import 'package:ja_remote/features/logs/logs_view.dart';
import 'package:ja_remote/features/devices/devices_view.dart';
import 'package:ja_remote/features/file_deploy/file_deploy_view.dart';
import 'package:ja_remote/services/device_service.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/widgets/command_palette.dart';
import 'package:ja_remote/widgets/glass_dialog.dart';

class TestDevices extends ChangeNotifier implements DeviceService {
  int refreshes = 0;
  int selections = 0;
  int deselections = 0;
  @override
  List<ManagedDevice> get filteredDevices => [];
  @override
  List<ManagedDevice> get devices => [];
  @override
  Set<String> get selectedIds => {};
  @override
  String get searchQuery => '';
  @override
  String get selectedGroup => 'All';
  @override
  String get statusFilter => 'All';
  @override
  List<String> get availableGroups => ['All'];
  @override
  bool get isPolling => false;
  @override
  int get totalCount => 0;
  @override
  int get onlineCount => 0;
  @override
  Future<void> refreshAllStatus() async {
    refreshes++;
  }

  @override
  void selectAll() {
    selections++;
  }

  @override
  void deselectAll() {
    deselections++;
  }

  @override
  List<ManagedDevice> get selectedDevices => [];
  @override
  String get sortColumn => 'ip';
  @override
  bool get sortAscending => true;
  @override
  void setSort(String column, {bool? ascending}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = true,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('dashboard shortcuts work at startup and after header focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final devices = TestDevices();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ThemeProvider()..setPerfTierMode(PerfTierMode.lite),
          ),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider<DeviceService>.value(value: devices),
        ],
        child: MaterialApp(
          home: CommandPaletteShortcut(
            items: () => [],
            child: const DashboardShell(),
          ),
        ),
      ),
    );
    await tester.pump();
    await key(tester, LogicalKeyboardKey.digit4);
    expect(find.byType(FileDeployView), findsOneWidget);
    await key(tester, LogicalKeyboardKey.digit5);
    expect(find.byType(LogsView), findsOneWidget);
    await key(tester, LogicalKeyboardKey.digit1);
    expect(find.byType(DevicesView), findsOneWidget);
    // Deliberately focus a header control, outside the active page subtree.
    Focus.of(tester.element(find.text('JA'))).requestFocus();
    await tester.pump();
    await key(tester, LogicalKeyboardKey.f5, control: false);
    expect(devices.refreshes, 1);
    await key(tester, LogicalKeyboardKey.keyF);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await key(tester, LogicalKeyboardKey.keyA);
    await key(tester, LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(devices.selections, 1);
    expect(devices.deselections, 1);
    await key(tester, LogicalKeyboardKey.keyK);
    expect(find.byType(CommandPalette), findsOneWidget);
    await key(tester, LogicalKeyboardKey.f5, control: false);
    expect(devices.refreshes, 1, reason: 'modal must block dashboard actions');
    await key(tester, LogicalKeyboardKey.escape, control: false);
    await key(tester, LogicalKeyboardKey.keyN);
    expect(find.byType(GlassDialog), findsOneWidget);
    await key(tester, LogicalKeyboardKey.f5, control: false);
    expect(devices.refreshes, 1);
    await key(tester, LogicalKeyboardKey.escape, control: false);
    await key(tester, LogicalKeyboardKey.f1, control: false);
    expect(find.byType(AlertDialog), findsOneWidget);
    await key(tester, LogicalKeyboardKey.escape, control: false);
    await key(tester, LogicalKeyboardKey.comma);
    expect(find.byType(GlassDialog), findsOneWidget);
    await key(tester, LogicalKeyboardKey.escape, control: false);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    devices.dispose();
  });
}

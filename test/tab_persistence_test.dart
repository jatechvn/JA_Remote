import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/layout/dashboard_shell.dart';
import 'package:ja_remote/features/command_runner/command_runner_view.dart';
import 'package:ja_remote/features/devices/devices_view.dart';
import 'package:ja_remote/features/discovery/discovery_view.dart';
import 'package:ja_remote/features/file_deploy/file_deploy_view.dart';
import 'package:ja_remote/features/logs/logs_view.dart';
import 'package:ja_remote/widgets/glass_script_editor.dart';
import 'package:ja_remote/widgets/glass_terminal.dart';
import 'package:ja_remote/widgets/glass_search_history_field.dart';
import 'package:ja_remote/services/device_service.dart';
import 'package:ja_remote/services/discovery_service.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/theme/language_provider.dart';

Future<void> _switchTab(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'DiscoveryView preserves filter, search query, sort and view mode across tab switches',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final deviceService = DeviceService(initialize: false);
      final discoveryService = DiscoveryService(initialize: false);
      addTearDown(deviceService.dispose);
      addTearDown(discoveryService.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) =>
                  ThemeProvider()..setPerfTierMode(PerfTierMode.lite),
            ),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<DeviceService>.value(value: deviceService),
            ChangeNotifierProvider<DiscoveryService>.value(
              value: discoveryService,
            ),
          ],
          child: const MaterialApp(home: DashboardShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Initial tab is Devices (index 0)
      expect(find.byType(DevicesView), findsOneWidget);
      expect(find.byType(DiscoveryView), findsNothing);

      // 2. Switch to Tab 1 (LAN Scanner / Discovery)
      await _switchTab(tester, LogicalKeyboardKey.digit2);
      expect(find.byType(DiscoveryView), findsOneWidget);

      // An unsubmitted subnet draft must also survive tab navigation.
      final subnetField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.controller?.text == discoveryService.currentSubnet,
      );
      await tester.enterText(subnetField, '172.21.168.0/21');

      // 3. Set search query, filter mode, sort, and view mode
      discoveryService.setSearchQuery('172.21.174');
      discoveryService.setFilterMode('fast');
      discoveryService.setSort('ping', ascending: false);
      discoveryService.setViewMode('grid');
      discoveryService.toggleSelectIp('172.21.174.41');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify search field contains the query
      final searchFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '172.21.174',
      );
      expect(searchFinder, findsOneWidget);
      expect(discoveryService.filterMode, equals('fast'));
      expect(discoveryService.sortColumn, equals('ping'));
      expect(discoveryService.sortAscending, isFalse);
      expect(discoveryService.viewMode, equals('grid'));
      expect(discoveryService.selectedIps, contains('172.21.174.41'));

      // 4. Switch away to Tab 0 (Devices)
      await _switchTab(tester, LogicalKeyboardKey.digit1);

      expect(find.byType(DevicesView), findsOneWidget);
      expect(find.byType(DiscoveryView), findsNothing);

      // Also set sort on Devices tab
      deviceService.setSort('name', ascending: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Switch back to Tab 1 (LAN Scanner / Discovery)
      await _switchTab(tester, LogicalKeyboardKey.digit2);

      expect(find.byType(DiscoveryView), findsOneWidget);

      // 6. Verify ALL filters, query, sort, and view modes were retained 100%!
      final retainedSearchFinder = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '172.21.174',
      );
      expect(retainedSearchFinder, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == '172.21.168.0/21',
        ),
        findsOneWidget,
      );
      expect(discoveryService.filterMode, equals('fast'));
      expect(discoveryService.sortColumn, equals('ping'));
      expect(discoveryService.sortAscending, isFalse);
      expect(discoveryService.viewMode, equals('grid'));
      expect(discoveryService.selectedIps, contains('172.21.174.41'));

      // 7. Switch back to Devices and verify Devices sort was retained
      await _switchTab(tester, LogicalKeyboardKey.digit1);

      expect(deviceService.sortColumn, equals('name'));
      expect(deviceService.sortAscending, isFalse);

      // 8. Switch to Tab 3 (File Deploy)
      await _switchTab(tester, LogicalKeyboardKey.digit4);
      expect(find.byType(FileDeployView), findsOneWidget);

      // 9. Switch to Tab 4 (Audit Logs)
      await _switchTab(tester, LogicalKeyboardKey.digit5);
      expect(find.byType(LogsView), findsOneWidget);
    },
  );

  testWidgets(
    'CommandRunnerView and FileDeployView preserve typed inputs, command drafts, and destination across tab switches',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final deviceService = DeviceService(initialize: false);
      final discoveryService = DiscoveryService(initialize: false);
      addTearDown(deviceService.dispose);
      addTearDown(discoveryService.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) =>
                  ThemeProvider()..setPerfTierMode(PerfTierMode.lite),
            ),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<DeviceService>.value(value: deviceService),
            ChangeNotifierProvider<DiscoveryService>.value(
              value: discoveryService,
            ),
          ],
          child: const MaterialApp(home: DashboardShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Switch to Tab 2 (Command Runner)
      await _switchTab(tester, LogicalKeyboardKey.digit3);
      expect(find.byType(CommandRunnerView), findsOneWidget);

      // 2. Locate the command editor TextField and type a custom draft
      final scriptField = find.descendant(
        of: find.byType(GlassScriptEditor),
        matching: find.byType(TextField),
      );
      expect(scriptField, findsOneWidget);
      const customScript = 'Get-Process | Where-Object CPU -gt 10';
      await tester.enterText(scriptField, customScript);
      await tester.pump();

      // 3. Switch to Tab 3 (File Deploy)
      await _switchTab(tester, LogicalKeyboardKey.digit4);
      expect(find.byType(FileDeployView), findsOneWidget);

      // 4. Locate the destination path TextField and enter custom path
      final destField = find.byWidgetPredicate(
        (w) =>
            w is TextField && (w.controller?.text.contains('Deploy') ?? false),
      );
      expect(destField, findsOneWidget);
      const customDest = r'D:\Custom\Target\Folder';
      await tester.enterText(destField, customDest);
      await tester.pump();

      // 5. Switch back to Tab 0 (Devices) and Tab 1 (LAN Discovery)
      await _switchTab(tester, LogicalKeyboardKey.digit1);
      expect(find.byType(DevicesView), findsOneWidget);

      await _switchTab(tester, LogicalKeyboardKey.digit2);
      expect(find.byType(DiscoveryView), findsOneWidget);

      // 6. Switch back to Tab 2 (Command Runner) - Verify typed script is preserved!
      await _switchTab(tester, LogicalKeyboardKey.digit3);
      expect(find.byType(CommandRunnerView), findsOneWidget);

      final retainedScriptField = find.descendant(
        of: find.byType(GlassScriptEditor),
        matching: find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == customScript,
        ),
      );
      expect(retainedScriptField, findsOneWidget);

      // 7. Switch back to Tab 3 (File Deploy) - Verify destination path is preserved!
      await _switchTab(tester, LogicalKeyboardKey.digit4);
      expect(find.byType(FileDeployView), findsOneWidget);

      final retainedDestField = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == customDest,
      );
      expect(retainedDestField, findsOneWidget);
    },
  );

  testWidgets(
    'Auto-focus places cursor at primary inputs on tab switch without intrusive overlay',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final deviceService = DeviceService(initialize: false);
      final discoveryService = DiscoveryService(initialize: false);
      addTearDown(deviceService.dispose);
      addTearDown(discoveryService.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) =>
                  ThemeProvider()..setPerfTierMode(PerfTierMode.lite),
            ),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ChangeNotifierProvider<DeviceService>.value(value: deviceService),
            ChangeNotifierProvider<DiscoveryService>.value(
              value: discoveryService,
            ),
          ],
          child: const MaterialApp(home: DashboardShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Initial tab is Devices (Tab 0) -> Search field must have focus
      final devSearch = find.descendant(
        of: find.byType(DevicesView),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(devSearch).focusNode?.hasFocus, isTrue);

      // 2. Switch to LAN Scanner (Tab 1) -> Search field must have focus
      await _switchTab(tester, LogicalKeyboardKey.digit2);
      final discSearch = find.descendant(
        of: find.byType(DiscoveryView),
        matching: find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.prefixIcon is Icon &&
              (w.decoration?.prefixIcon as Icon).icon == Icons.search_rounded,
        ),
      );
      expect(tester.widget<TextField>(discSearch).focusNode?.hasFocus, isTrue);

      // 3. Switch to Command Runner (Tab 2) -> Terminal Enter Remote Command prompt must have focus
      await _switchTab(tester, LogicalKeyboardKey.digit3);
      final cmdPrompt = find.descendant(
        of: find.descendant(
          of: find.byType(CommandRunnerView),
          matching: find.byType(GlassTerminalPanel),
        ),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(cmdPrompt).focusNode?.hasFocus, isTrue);

      // 4. Switch to File Deploy (Tab 3) -> Terminal Enter Command prompt must have focus
      await _switchTab(tester, LogicalKeyboardKey.digit4);
      final deployPrompt = find.descendant(
        of: find.byType(GlassTerminalPanel),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(deployPrompt).focusNode?.hasFocus,
        isTrue,
      );

      // 5. Switch to Audit Logs (Tab 4) -> Search field must have focus & use GlassSearchHistoryField
      await _switchTab(tester, LogicalKeyboardKey.digit5);
      expect(
        find.descendant(
          of: find.byType(LogsView),
          matching: find.byType(GlassSearchHistoryField),
        ),
        findsOneWidget,
      );
      final logsSearch = find.descendant(
        of: find.byType(LogsView),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(logsSearch).focusNode?.hasFocus, isTrue);

      // 6. Switch back to Devices (Tab 0) -> Devices search field must regain focus
      await _switchTab(tester, LogicalKeyboardKey.digit1);
      expect(tester.widget<TextField>(devSearch).focusNode?.hasFocus, isTrue);
    },
  );
}

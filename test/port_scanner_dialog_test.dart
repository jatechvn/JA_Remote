import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/features/devices/port_scanner_dialog.dart';

Widget _createTestWrapper(Widget child, [LanguageProvider? langProvider]) {
  final lang = langProvider ?? LanguageProvider();
  lang.setLanguage(AppLanguage.vi);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider.value(value: lang),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets(
    'PortScannerDialogContent renders correctly in single port mode',
    (tester) async {
      await tester.pumpWidget(
        _createTestWrapper(
          const PortScannerDialogContent(
            initialHost: '192.168.1.50',
            initialPort: 8080,
          ),
        ),
      );
      await tester.pump();

      // Verify host field
      expect(find.text('192.168.1.50'), findsOneWidget);
      // Verify port field
      expect(find.text('8080'), findsOneWidget);

      // Verify Quick port chip exists
      expect(find.text('22 (SSH)'), findsOneWidget);

      // Tap quick chip 22
      await tester.tap(find.text('22 (SSH)'));
      await tester.pump();

      // Now port input should have updated to 22
      expect(find.text('22'), findsOneWidget);
    },
  );

  testWidgets('Switching mode tabs updates configuration controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      _createTestWrapper(
        const PortScannerDialogContent(initialHost: '10.0.0.1'),
      ),
    );
    await tester.pump();

    // Default mode without initialPort is common
    expect(find.textContaining('Quét nhanh 30 cổng chuẩn'), findsOneWidget);

    // Switch to Range mode
    await tester.tap(find.text('Dải Cổng (Range)'));
    await tester.pump();

    // Range controls should appear
    expect(find.text('1 - 1024 (Well-Known)'), findsOneWidget);
    expect(find.text('8000 - 9000 (Web & APIs)'), findsOneWidget);

    // Tap a preset chip
    await tester.tap(find.text('8000 - 9000 (Web & APIs)'));
    await tester.pump();

    expect(find.text('8000'), findsOneWidget);
    expect(find.text('9000'), findsOneWidget);

    // Switch to Single mode
    await tester.tap(find.text('1 Cổng (Single)'));
    await tester.pump();

    expect(find.text('Số cổng (Port)'), findsOneWidget);
  });

  testWidgets('Filter open only checkbox toggles properly', (tester) async {
    await tester.pumpWidget(
      _createTestWrapper(
        const PortScannerDialogContent(initialHost: '127.0.0.1'),
      ),
    );
    await tester.pump();

    final filterFinder = find.text('Chỉ hiện cổng đang mở');
    expect(filterFinder, findsOneWidget);

    // Initial state: unchecked icon
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);

    // Tap filter
    await tester.tap(filterFinder);
    await tester.pump();

    // Now checked icon
    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
  });

  testWidgets('showPortScannerDialog displays glass dialog modal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _createTestWrapper(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPortScannerDialog(
              context,
              initialHost: '192.168.1.1',
              initialPort: 3389,
            ),
            child: const Text('Open Scanner'),
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap open
    await tester.tap(find.text('Open Scanner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(PortScannerDialogContent), findsOneWidget);
    expect(find.text('192.168.1.1'), findsOneWidget);
  });
}

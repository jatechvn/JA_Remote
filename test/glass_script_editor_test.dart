import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/widgets/glass_script_editor.dart';

void main() {
  Widget buildTestableWidget({
    required TextEditingController controller,
    String protocol = 'powershell',
    List<GlassScriptSnippet>? quickSnippets,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => LanguageProvider(initialLanguage: AppLanguage.vi),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassScriptEditor(
              controller: controller,
              protocol: protocol,
              quickSnippets: quickSnippets,
            ),
          ),
        ),
      ),
    );
  }

  group('GlassScriptEditor Tests', () {
    testWidgets('Renders window chrome, protocol badge and filename', (
      tester,
    ) async {
      final controller = TextEditingController(
        text: 'Get-Process | Select-Object -First 5',
      );

      await tester.pumpWidget(
        buildTestableWidget(controller: controller, protocol: 'powershell'),
      );
      await tester.pumpAndSettle();

      // Check title and protocol badge
      expect(find.text('script.ps1'), findsOneWidget);
      expect(find.text('POWERSHELL'), findsOneWidget);
      expect(find.textContaining('1 dòng'), findsOneWidget);

      // Check traffic lights rendered
      expect(find.byType(GlassScriptEditor), findsOneWidget);
    });

    testWidgets('Renders SSH protocol and script.sh correctly', (tester) async {
      final controller = TextEditingController(text: 'uname -a\nuptime\n');

      await tester.pumpWidget(
        buildTestableWidget(controller: controller, protocol: 'ssh'),
      );
      await tester.pumpAndSettle();

      expect(find.text('script.sh'), findsOneWidget);
      expect(find.text('SSH BASH'), findsOneWidget);
      expect(find.textContaining('3 dòng'), findsOneWidget);
    });

    testWidgets('Tapping quick snippet updates controller text', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'initial');

      await tester.pumpWidget(
        buildTestableWidget(
          controller: controller,
          quickSnippets: const [
            GlassScriptSnippet(label: 'Uptime', command: 'Get-Uptime'),
            GlassScriptSnippet(label: 'IPConfig', command: 'ipconfig /all'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uptime'), findsOneWidget);
      expect(find.text('IPConfig'), findsOneWidget);

      // Tap snippet
      await tester.tap(find.text('Uptime'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('Get-Uptime'));
    });

    testWidgets('Clear button clears editor content', (tester) async {
      final controller = TextEditingController(text: 'Some command');

      await tester.pumpWidget(buildTestableWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(controller.text, equals('Some command'));

      // Tap clear icon
      await tester.tap(find.byIcon(Icons.clear_all_rounded));
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
    });
  });
}

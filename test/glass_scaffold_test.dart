import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/widgets/glass_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GlassScaffold renders body, header and MeshBackground properly',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
          child: MaterialApp(
            home: GlassScaffold(
              header: const Text('Custom Header Title'),
              body: Center(
                child: Builder(
                  builder: (context) {
                    return BentoCard(
                      colors: context.watch<ThemeProvider>().colors,
                      child: const Text('Custom Glass Card'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Custom Header Title'), findsOneWidget);
      expect(find.text('Custom Glass Card'), findsOneWidget);
      expect(find.byType(MeshBackground), findsOneWidget);
      expect(find.byType(GlassScaffold), findsOneWidget);
    },
  );

  testWidgets('GlassScaffold functions gracefully without ThemeProvider', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassScaffold(
          body: Center(child: Text('Fallback Without Provider')),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Fallback Without Provider'), findsOneWidget);
    expect(find.byType(MeshBackground), findsOneWidget);
  });

  testWidgets(
    'BentoCard, GlassCard, and GlassContainer reactively update blur and opacity from ThemeProvider',
    (tester) async {
      final theme = ThemeProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: theme,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  BentoCard(
                    colors: theme.colors,
                    child: const Text('Dynamic Bento Card'),
                  ),
                  GlassCard(
                    colors: theme.colors,
                    child: const Text('Dynamic Glass Card'),
                  ),
                  GlassContainer(
                    colors: theme.colors,
                    child: const Text('Dynamic Glass Container'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(BackdropFilter), findsNWidgets(3));

      // Change blur to 0 (Lite mode behavior)
      theme.setLiveGlassmorphism(cardBlur: 0.0, cardOpacity: 0.8);
      await tester.pump();

      // When blur is 0, BackdropFilter is omitted for GPU performance
      expect(find.byType(BackdropFilter), findsNothing);

      // Change blur to 30.0
      theme.setLiveGlassmorphism(cardBlur: 30.0, cardOpacity: 0.5);
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNWidgets(3));
    },
  );

  testWidgets(
    'GlassHorizontalScrollView renders horizontally, supports mouse-wheel and chevrons',
    (tester) async {
      final controller = ScrollController();
      final theme = ThemeProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 50,
              child: GlassHorizontalScrollView(
                controller: controller,
                colors: theme.colors,
                child: Row(
                  children: List.generate(
                    15,
                    (i) => SizedBox(width: 80, child: Text('Chip $i')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GlassHorizontalScrollView), findsOneWidget);
      expect(find.text('Chip 0'), findsOneWidget);
      expect(controller.position.maxScrollExtent, greaterThan(100.0));

      // Right chevron is present because content overflows
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Simulate mouse wheel scroll over the widget
      final scrollLocation = tester.getCenter(
        find.byType(GlassHorizontalScrollView),
      );
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(scrollLocation);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 200)));
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0.0));
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    },
  );

  test(
    'ThemeProvider saves and loads glassmorphism parameters from JSON storage',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('ja_theme_test_');
      final settingsFile = File(
        '${tempDir.path}${Platform.pathSeparator}app_settings.json',
      );

      try {
        final theme1 = ThemeProvider();
        theme1.setStorageFileForTesting(settingsFile);

        theme1.setLiveGlassmorphism(
          cardBlur: 35.0,
          cardOpacity: 0.95,
          dialogBlur: 15.0,
          dialogOpacity: 0.70,
          dropdownBlur: 25.0,
          dropdownOpacity: 0.88,
        );
        await theme1.saveSettings();

        expect(await settingsFile.exists(), isTrue);

        final theme2 = ThemeProvider();
        theme2.setStorageFileForTesting(settingsFile);
        await theme2.loadSavedSettings();

        expect(theme2.cardBlur, 35.0);
        expect(theme2.cardOpacity, 0.95);
        expect(theme2.dialogBlur, 15.0);
        expect(theme2.dialogOpacity, 0.70);
        expect(theme2.dropdownBlur, 25.0);
        expect(theme2.dropdownOpacity, 0.88);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/widgets/command_palette.dart';

void main() {
  testWidgets(
    'palette opens with Ctrl K, navigates and executes selected result',
    (tester) async {
      var selected = '';
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: CommandPaletteShortcut(
              items: () => [
                for (final label in ['Alpha', 'Beta'])
                  CommandPaletteItem(
                    label: label,
                    icon: Icons.check,
                    onSelect: () => selected = label,
                  ),
              ],
              child: const Scaffold(body: Text('Home')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(CommandPalette), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester.widgetList<ListTile>(find.byType(ListTile)).last.selected,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'Beta');
      expect(find.byType(CommandPalette), findsNothing);
    },
  );

  testWidgets(
    'palette handles empty search and resets selection after filtering',
    (tester) async {
      var selected = '';
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showCommandPalette(
                    context,
                    items: [
                      for (final label in ['Alpha', 'Beta'])
                        CommandPaletteItem(
                          label: label,
                          icon: Icons.check,
                          onSelect: () => selected = label,
                        ),
                    ],
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(selected, isEmpty);
      await tester.enterText(find.byType(TextField), ' Alpha ');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, 'Alpha');
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(CommandPalette), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/widgets/glass_terminal.dart';

void main() {
  testWidgets('external prompt focus retains Tab completion and history', (
    tester,
  ) async {
    final focus = FocusNode();
    final theme = ThemeProvider();
    final language = LanguageProvider(initialLanguage: AppLanguage.en);
    addTearDown(focus.dispose);
    addTearDown(theme.dispose);
    addTearDown(language.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: language),
        ],
        child: MaterialApp(
          home: Scaffold(body: GlassTerminalPanel(promptFocusNode: focus)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await tester.enterText(input, 'he');
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, 'help ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.enterText(input, 'draft');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, 'help');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, 'draft');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

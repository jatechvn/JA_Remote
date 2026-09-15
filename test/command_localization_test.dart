import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/data/models/command_template.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/widgets/glass_dropdown.dart';

void main() {
  test('built-in templates translate without mutating saved data', () {
    final templates = CommandTemplate.getDefaultTemplates();
    final english = LanguageProvider(initialLanguage: AppLanguage.en);
    final chinese = LanguageProvider(initialLanguage: AppLanguage.cn);
    addTearDown(english.dispose);
    addTearDown(chinese.dispose);
    for (final template in templates) {
      final restored = CommandTemplate.fromJson(template.toJson());
      expect(english.templateName(restored), isNot(template.name));
      expect(
        chinese.templateDescription(restored),
        isNot(template.description),
      );
      expect(restored.command, template.command);
      expect(restored.name, template.name);
      expect(
        english.templateName(template.copyWith(isCustom: true)),
        template.name,
      );
      expect(
        english.templateName(template.copyWith(name: 'My own name')),
        'My own name',
      );
    }
    expect(english.t('cmd_workers', {'count': '2'}), '2 parallel workers');
  });

  for (final locale in AppLanguage.values) {
    testWidgets('dropdown search and empty state use ${locale.code}', (
      tester,
    ) async {
      final language = LanguageProvider(initialLanguage: locale);
      final theme = ThemeProvider();
      addTearDown(language.dispose);
      addTearDown(theme.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: language),
            ChangeNotifierProvider.value(value: theme),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  child: GlassDropdown<int>(
                    items: const [
                      GlassDropdownItem(value: 1, label: 'Alpha'),
                      GlassDropdownItem(value: 2, label: 'Beta'),
                      GlassDropdownItem(value: 3, label: 'Gamma'),
                      GlassDropdownItem(value: 4, label: 'Delta'),
                      GlassDropdownItem(value: 5, label: 'Epsilon'),
                      GlassDropdownItem(value: 6, label: 'Zeta'),
                    ],
                    value: 1,
                    onChanged: (_) {},
                    colors: theme.colors,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(
        find.text(language.t('dropdown_search', {'count': '6'})),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'no-result');
      await tester.pumpAndSettle();
      expect(find.text(language.t('dropdown_empty')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}

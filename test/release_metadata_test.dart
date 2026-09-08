import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/modules/constants.dart';
import 'package:ja_remote/theme/language_provider.dart';

void main() {
  test('release version matches manifest and user-facing documents', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('version: $appVersion+'),
    );
    for (final path in [
      'ABOUT.txt',
      'README.md',
      'USERGUIDE.md',
      'CHANGELOG.md',
      'RELEASE_NOTES.md',
    ]) {
      expect(File(path).readAsStringSync(), contains(appVersion), reason: path);
    }
  });
  test(
    'every supported language documents the shipped shortcuts and version',
    () {
      final language = LanguageProvider();
      addTearDown(language.dispose);
      for (final locale in AppLanguage.values) {
        language.setLanguage(locale);
        final guide = language.t('guide_shortcuts_desc');
        for (final key in [
          'Ctrl+1',
          'Ctrl+K',
          'Ctrl+,',
          'Ctrl+F',
          'Ctrl+N',
          'F5',
          'Ctrl+Shift+A',
          'Ctrl+Shift+D',
          'Ctrl+Enter',
          'F1',
        ]) {
          expect(guide, contains(key), reason: locale.code);
        }
        expect(
          language.t('guide_start_title', {'version': appVersion}),
          contains(appVersion),
        );
      }
    },
  );
}

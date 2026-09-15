import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/theme/language_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider OS Detection Tests', () {
    test('detects Vietnamese locales accurately', () {
      expect(LanguageProvider.detectSystemLanguage('vi'), AppLanguage.vi);
      expect(LanguageProvider.detectSystemLanguage('vi_VN'), AppLanguage.vi);
      expect(LanguageProvider.detectSystemLanguage('vi-VN'), AppLanguage.vi);
      expect(LanguageProvider.detectSystemLanguage('VI_vn'), AppLanguage.vi);
    });

    test('detects Chinese locales accurately', () {
      expect(LanguageProvider.detectSystemLanguage('zh'), AppLanguage.cn);
      expect(LanguageProvider.detectSystemLanguage('zh_CN'), AppLanguage.cn);
      expect(LanguageProvider.detectSystemLanguage('zh-Hans'), AppLanguage.cn);
      expect(LanguageProvider.detectSystemLanguage('zh-TW'), AppLanguage.cn);
      expect(LanguageProvider.detectSystemLanguage('ZH_cn'), AppLanguage.cn);
    });

    test('falls back to English for other locales or empty strings', () {
      expect(LanguageProvider.detectSystemLanguage('en'), AppLanguage.en);
      expect(LanguageProvider.detectSystemLanguage('en_US'), AppLanguage.en);
      expect(LanguageProvider.detectSystemLanguage('en_GB'), AppLanguage.en);
      expect(LanguageProvider.detectSystemLanguage('ja_JP'), AppLanguage.en);
      expect(LanguageProvider.detectSystemLanguage('fr_FR'), AppLanguage.en);
      expect(LanguageProvider.detectSystemLanguage('de_DE'), AppLanguage.en);
      expect(LanguageProvider.detectSystemLanguage(''), AppLanguage.en);
      expect(LanguageProvider.detectSystemLanguage(null), isA<AppLanguage>());
    });
  });

  group('LanguageProvider Persistence Tests', () {
    late File tempFile;

    setUp(() async {
      tempFile = File(
        '${Directory.systemTemp.path}/test_app_settings_${DateTime.now().microsecondsSinceEpoch}.json',
      );
    });

    tearDown(() async {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    });

    test('Loads saved language from file if present', () async {
      await tempFile.writeAsString(jsonEncode({'language': 'CN'}));

      final provider = await LanguageProvider.create(storageFile: tempFile);
      expect(provider.currentLanguage, AppLanguage.cn);
    });

    test(
      'Defaults to initialLanguage or system detection if file is absent',
      () async {
        final provider = await LanguageProvider.create(
          initialLanguage: AppLanguage.vi,
          storageFile: tempFile,
        );
        expect(provider.currentLanguage, AppLanguage.vi);
      },
    );

    test('setLanguage updates state and persists choice', () async {
      final provider = await LanguageProvider.create(
        initialLanguage: AppLanguage.en,
        storageFile: tempFile,
      );
      expect(provider.currentLanguage, AppLanguage.en);

      provider.setLanguage(AppLanguage.vi);
      expect(provider.currentLanguage, AppLanguage.vi);

      // Wait a brief tick for async file writing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(await tempFile.exists(), isTrue);
      final content = jsonDecode(await tempFile.readAsString());
      expect(content['language'], 'VI');

      // Verify a new instance loads the persisted language
      final newProvider = await LanguageProvider.create(storageFile: tempFile);
      expect(newProvider.currentLanguage, AppLanguage.vi);
    });

    test('cycleLanguage updates state and persists cycled choice', () async {
      final provider = await LanguageProvider.create(
        initialLanguage: AppLanguage.vi,
        storageFile: tempFile,
      );

      // VI -> EN
      provider.cycleLanguage();
      expect(provider.currentLanguage, AppLanguage.en);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      var content = jsonDecode(await tempFile.readAsString());
      expect(content['language'], 'EN');

      // EN -> CN
      provider.cycleLanguage();
      expect(provider.currentLanguage, AppLanguage.cn);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      content = jsonDecode(await tempFile.readAsString());
      expect(content['language'], 'CN');
    });

    test('Preserves other settings keys in app_settings.json', () async {
      await tempFile.writeAsString(jsonEncode({'theme': 'dark', 'volume': 80}));

      final provider = await LanguageProvider.create(
        initialLanguage: AppLanguage.en,
        storageFile: tempFile,
      );

      provider.setLanguage(AppLanguage.cn);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final content = jsonDecode(await tempFile.readAsString());
      expect(content['language'], 'CN');
      expect(content['theme'], 'dark');
      expect(content['volume'], 80);
    });

    test('lang_changed_msg does not contain duplicate globe emoji', () async {
      final provider = await LanguageProvider.create(
        initialLanguage: AppLanguage.en,
        storageFile: tempFile,
      );

      for (final lang in AppLanguage.values) {
        provider.setLanguage(lang);
        final msg = provider.t('lang_changed_msg');
        expect(
          msg.contains('🌐'),
          isFalse,
          reason:
              'lang_changed_msg should not have 🌐 emoji since toast icon is Icons.language_rounded',
        );
        expect(msg.isNotEmpty, isTrue);
      }
    });
  });
}

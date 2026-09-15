import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/data/models/command_template.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/data/models/saved_credential.dart';
import 'package:ja_remote/data/repositories/command_template_repository.dart';
import 'package:ja_remote/services/config_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommandTemplate Model Tests', () {
    test('copyWith updates fields correctly', () {
      const original = CommandTemplate(
        id: 'tmpl_1',
        name: 'Original',
        platform: 'windows',
        type: 'powershell',
        command: 'Get-Process',
        description: 'Desc',
        isCustom: false,
      );

      final updated = original.copyWith(
        name: 'Updated Name',
        isCustom: true,
        command: 'Get-Service',
      );

      expect(updated.id, 'tmpl_1');
      expect(updated.name, 'Updated Name');
      expect(updated.command, 'Get-Service');
      expect(updated.isCustom, isTrue);
      expect(updated.platform, 'windows');
      expect(updated.description, 'Desc');
    });

    test('toJson and fromJson work seamlessly including isCustom', () {
      const tmpl = CommandTemplate(
        id: 'custom_123',
        name: 'Reboot Host',
        platform: 'linux',
        type: 'ssh',
        command: 'sudo reboot',
        description: 'Restarts machine',
        isCustom: true,
      );

      final json = tmpl.toJson();
      final restored = CommandTemplate.fromJson(json);

      expect(restored.id, 'custom_123');
      expect(restored.name, 'Reboot Host');
      expect(restored.platform, 'linux');
      expect(restored.type, 'ssh');
      expect(restored.command, 'sudo reboot');
      expect(restored.description, 'Restarts machine');
      expect(restored.isCustom, isTrue);
    });
  });

  group('CommandTemplateRepository Tests', () {
    late Directory tempDir;
    late File testStorage;
    late CommandTemplateRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cmd_repo_test_');
      testStorage = File('${tempDir.path}/command_templates.json');
      repo = CommandTemplateRepository();
      repo.setStorageFileForTesting(testStorage);
    });

    tearDown(() async {
      repo.setStorageFileForTesting(null);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'loadTemplates initializes with default templates if storage empty',
      () async {
        final templates = await repo.loadTemplates();
        expect(templates.isNotEmpty, isTrue);
        expect(templates.any((t) => t.id == 'win_uptime'), isTrue);
        expect(repo.cachedTemplates.length, equals(templates.length));
        expect(await testStorage.exists(), isTrue);
      },
    );

    test(
      'corrupt or empty template storage is never overwritten by loading',
      () async {
        for (final content in ['{broken json', '']) {
          await testStorage.writeAsString(content);
          final templates = await repo.loadTemplates();
          expect(templates, isNotEmpty);
          expect(await testStorage.readAsString(), content);
        }
      },
    );

    test(
      'loaded templates cannot mutate the repository cache by reference',
      () async {
        final templates = await repo.loadTemplates();
        final count = repo.cachedTemplates.length;
        expect(() => templates.clear(), throwsUnsupportedError);
        expect(repo.cachedTemplates.length, count);
      },
    );

    test('saveTemplate adds new custom template and persists it', () async {
      await repo.loadTemplates();
      const newTmpl = CommandTemplate(
        id: 'test_custom_ping',
        name: 'Ping Gateway',
        platform: 'windows',
        type: 'powershell',
        command: 'Test-Connection 192.168.1.1',
        isCustom: true,
      );

      await repo.saveTemplate(newTmpl);
      expect(
        repo.cachedTemplates.any((t) => t.id == 'test_custom_ping'),
        isTrue,
      );

      // Reload from storage
      final reloaded = await repo.loadTemplates();
      expect(reloaded.any((t) => t.id == 'test_custom_ping'), isTrue);
    });

    test(
      'saveTemplate updates existing template without duplicating',
      () async {
        const updatedTmpl = CommandTemplate(
          id: 'test_custom_ping',
          name: 'Ping Gateway Updated',
          platform: 'windows',
          type: 'powershell',
          command: 'Test-Connection 8.8.8.8',
          isCustom: true,
        );

        await repo.saveTemplate(updatedTmpl);
        final list = repo.cachedTemplates
            .where((t) => t.id == 'test_custom_ping')
            .toList();
        expect(list.length, equals(1));
        expect(list.first.name, equals('Ping Gateway Updated'));
        expect(list.first.command, equals('Test-Connection 8.8.8.8'));
      },
    );

    test('deleteTemplate removes template from repository and cache', () async {
      await repo.deleteTemplate('test_custom_ping');
      expect(
        repo.cachedTemplates.any((t) => t.id == 'test_custom_ping'),
        isFalse,
      );
    });

    test('resetToDefaults restores initial templates', () async {
      final defaults = await repo.resetToDefaults();
      expect(defaults.isNotEmpty, isTrue);
      expect(defaults.any((t) => t.id == 'win_uptime'), isTrue);
      expect(defaults.any((t) => t.id == 'linux_uptime'), isTrue);
    });
  });

  group('ConfigBackupService with CommandTemplates Tests', () {
    test(
      'previewConfigFile parses commandTemplates from bundle JSON',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ja_remote_test_',
        );
        final testFile = File('${tempDir.path}/test_config.json');

        final bundle = {
          'app': 'JA_Remote',
          'version': '1.0.0+1',
          'devices': [
            ManagedDevice(
              id: 'd1',
              name: 'Device A',
              hostname: 'devA',
              ip: '192.168.1.10',
            ).toJson(),
          ],
          'credentials': [
            SavedCredential(
              id: 'c1',
              username: 'admin',
              password: 'secret',
            ).toJson(),
          ],
          'commandTemplates': [
            const CommandTemplate(
              id: 'test_tmpl_1',
              name: 'Test Template 1',
              platform: 'windows',
              type: 'powershell',
              command: 'hostname',
              isCustom: true,
            ).toJson(),
          ],
        };

        await testFile.writeAsString(jsonEncode(bundle));

        final service = ConfigBackupService();
        final preview = await service.previewConfigFile(testFile.path);

        expect(preview.isValid, isTrue);
        expect(preview.deviceCount, equals(1));
        expect(preview.credentialCount, equals(1));
        expect(preview.templateCount, equals(1));
        expect(preview.commandTemplates.first.name, equals('Test Template 1'));

        await tempDir.delete(recursive: true);
      },
    );

    test('previewConfigFile parses raw array of commandTemplates', () async {
      final tempDir = await Directory.systemTemp.createTemp('ja_remote_raw_');
      final testFile = File('${tempDir.path}/templates_only.json');

      final templates = [
        const CommandTemplate(
          id: 'tmpl_raw_1',
          name: 'Raw Template 1',
          platform: 'linux',
          type: 'ssh',
          command: 'ls -la',
        ).toJson(),
        const CommandTemplate(
          id: 'tmpl_raw_2',
          name: 'Raw Template 2',
          platform: 'windows',
          type: 'powershell',
          command: 'dir',
        ).toJson(),
      ];

      await testFile.writeAsString(jsonEncode(templates));

      final service = ConfigBackupService();
      final preview = await service.previewConfigFile(testFile.path);

      expect(preview.isValid, isTrue);
      expect(preview.templateCount, equals(2));
      expect(preview.commandTemplates[0].id, equals('tmpl_raw_1'));
      expect(preview.commandTemplates[1].id, equals('tmpl_raw_2'));

      await tempDir.delete(recursive: true);
    });

    test(
      'applyImport in merge mode preserves existing templates and adds new',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ja_remote_import_',
        );
        final testStorage = File('${tempDir.path}/command_templates.json');
        final repo = CommandTemplateRepository();
        repo.setStorageFileForTesting(testStorage);
        await repo.loadTemplates();
        final initialCount = repo.cachedTemplates.length;

        final preview = ConfigImportPreview(
          isValid: true,
          commandTemplates: const [
            CommandTemplate(
              id: 'import_merged_1',
              name: 'Imported Merged Template',
              platform: 'windows',
              type: 'powershell',
              command: 'echo 123',
              isCustom: true,
            ),
          ],
        );

        final service = ConfigBackupService();
        await service.applyImport(preview, overwrite: false);

        expect(
          repo.cachedTemplates.any((t) => t.id == 'import_merged_1'),
          isTrue,
        );
        expect(repo.cachedTemplates.length, equals(initialCount + 1));

        repo.setStorageFileForTesting(null);
        await tempDir.delete(recursive: true);
      },
    );
  });
}

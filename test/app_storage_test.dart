import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/utils/app_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRootDir;

  setUp(() async {
    tempRootDir = await Directory.systemTemp.createTemp('test_app_storage_');
    AppStorage.setDirectoryForTesting(tempRootDir);
  });

  tearDown(() async {
    AppStorage.setDirectoryForTesting(null);
    try {
      if (await tempRootDir.exists()) {
        await tempRootDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test(
    'migration preserves legacy data when destination already exists',
    () async {
      final legacy = File(
        p.join(tempRootDir.path, 'JA_Remote', 'devices.json'),
      );
      await legacy.parent.create(recursive: true);
      await legacy.writeAsString('legacy devices');
      final current = File(p.join(tempRootDir.path, 'devices.json'));
      await current.writeAsString('current devices');
      await AppStorage.migrateLegacyFolderIfNeeded();
      expect(await current.readAsString(), 'current devices');
      expect(await legacy.exists(), isTrue);
      expect(await legacy.readAsString(), 'legacy devices');
    },
  );

  test(
    'AppStorage returns file directly in root data directory without nested JA_Remote',
    () async {
      final file = await AppStorage.getFile('devices.json');
      expect(file.parent.path, equals(tempRootDir.path));
      expect(p.basename(file.path), equals('devices.json'));
      expect(file.path.contains('JA_Remote'), isFalse);
    },
  );

  test(
    'AppStorage automatically migrates legacy nested JA_Remote files and cleans folder',
    () async {
      final legacyDir = Directory(p.join(tempRootDir.path, 'JA_Remote'));
      await legacyDir.create(recursive: true);

      final legacyDevices = File(p.join(legacyDir.path, 'devices.json'));
      await legacyDevices.writeAsString('[{"id": "dev_1"}]');

      final legacySettings = File(p.join(legacyDir.path, 'app_settings.json'));
      await legacySettings.writeAsString('{"language": "VI"}');

      // Run migration
      final count = await AppStorage.migrateLegacyFolderIfNeeded();
      expect(count, equals(2));

      // Target files exist in root directory
      final targetDevices = File(p.join(tempRootDir.path, 'devices.json'));
      expect(await targetDevices.exists(), isTrue);
      expect(await targetDevices.readAsString(), equals('[{"id": "dev_1"}]'));

      final targetSettings = File(
        p.join(tempRootDir.path, 'app_settings.json'),
      );
      expect(await targetSettings.exists(), isTrue);

      // Legacy folder should have been cleaned up and deleted
      expect(await legacyDir.exists(), isFalse);
    },
  );
}

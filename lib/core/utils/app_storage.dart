import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Centralized application storage directory manager.
/// Resolves paths directly in the application support directory without redundant folder nesting.
/// Automatically migrates existing files from legacy nested 'JA_Remote' subfolders if present.
class AppStorage {
  AppStorage._();

  static Directory? _testDirectory;

  /// Sets a custom storage directory for unit testing.
  static void setDirectoryForTesting(Directory? dir) {
    _testDirectory = dir;
  }

  /// Returns the root data directory for the application.
  static Future<Directory> getDataDirectory() async {
    if (_testDirectory != null) return _testDirectory!;
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Returns the file for the given [fileName] in the application data directory.
  /// If the file does not exist in the primary directory, but exists in the legacy
  /// nested 'JA_Remote' subdirectory, it will be automatically migrated.
  static Future<File> getFile(String fileName) async {
    final dir = await getDataDirectory();
    final file = File(p.join(dir.path, fileName));

    // Backward-compatible migration from legacy nested folder
    if (!await file.exists()) {
      final legacyFile = File(p.join(dir.path, 'JA_Remote', fileName));
      try {
        if (await legacyFile.exists()) {
          await legacyFile.copy(file.path);
        }
      } catch (_) {}
    }

    return file;
  }

  /// Automatically detects and migrates legacy nested 'JA_Remote' subfolder files
  /// to the root application support directory, then cleans up the redundant subfolder.
  static Future<int> migrateLegacyFolderIfNeeded() async {
    try {
      final dir = await getDataDirectory();
      final legacyDir = Directory(p.join(dir.path, 'JA_Remote'));
      if (!await legacyDir.exists()) return 0;

      int migratedCount = 0;
      await for (final entity in legacyDir.list()) {
        if (entity is File) {
          final targetFile = File(p.join(dir.path, p.basename(entity.path)));
          if (!await targetFile.exists()) {
            await entity.copy(targetFile.path);
            migratedCount++;
            await entity.delete();
          }
        }
      }

      // If legacy directory is empty, remove it completely
      if (await legacyDir.list().isEmpty) {
        await legacyDir.delete();
      }
      return migratedCount;
    } catch (_) {
      return 0;
    }
  }
}

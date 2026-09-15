import 'dart:convert';
import 'dart:io';
import '../modules/constants.dart';
import '../data/models/managed_device.dart';
import '../data/models/saved_credential.dart';
import '../data/models/command_template.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/credential_repository.dart';
import '../data/repositories/command_template_repository.dart';

/// Preview result before applying an imported config.
class ConfigImportPreview {
  final bool isValid;
  final String? error;
  final List<ManagedDevice> devices;
  final List<SavedCredential> credentials;
  final List<CommandTemplate> commandTemplates;

  const ConfigImportPreview({
    required this.isValid,
    this.error,
    this.devices = const [],
    this.credentials = const [],
    this.commandTemplates = const [],
  });

  /// Template import must never mutate devices or credentials in a full backup.
  ConfigImportPreview get templatesOnly => ConfigImportPreview(
    isValid: isValid,
    error: error,
    commandTemplates: commandTemplates,
  );

  int get deviceCount => devices.length;
  int get credentialCount => credentials.length;
  int get templateCount => commandTemplates.length;
}

/// Service handling JSON export, import, and migration of devices, credentials, and command templates.
class ConfigBackupService {
  final DeviceRepository _deviceRepo = DeviceRepository();
  final CredentialRepository _credRepo = CredentialRepository();
  final CommandTemplateRepository _templateRepo = CommandTemplateRepository();

  /// Exports full configuration (devices + credentials + command templates) to a JSON file.
  Future<int> exportConfig(String filePath) async {
    final devices = await _deviceRepo.loadDevices();
    final credentials = await _credRepo.loadCredentials();
    final templates = await _templateRepo.loadTemplates();

    final bundle = {
      'app': 'JA_Remote',
      'version': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'deviceCount': devices.length,
      'credentialCount': credentials.length,
      'templateCount': templates.length,
      'devices': devices.map((d) => d.toJson()).toList(),
      'credentials': credentials.map((c) => c.toJson()).toList(),
      'commandTemplates': templates.map((t) => t.toJson()).toList(),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final file = File(filePath);
    await file.writeAsString(encoder.convert(bundle), flush: true);
    return devices.length;
  }

  /// Exports selected devices along with credentials and templates to a JSON file.
  Future<int> exportSelectedDevices(
    String filePath,
    List<ManagedDevice> devices,
  ) async {
    final credentials = await _credRepo.loadCredentials();
    final templates = await _templateRepo.loadTemplates();

    final bundle = {
      'app': 'JA_Remote',
      'version': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'deviceCount': devices.length,
      'credentialCount': credentials.length,
      'templateCount': templates.length,
      'devices': devices.map((d) => d.toJson()).toList(),
      'credentials': credentials.map((c) => c.toJson()).toList(),
      'commandTemplates': templates.map((t) => t.toJson()).toList(),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final file = File(filePath);
    await file.writeAsString(encoder.convert(bundle), flush: true);
    return devices.length;
  }

  /// Exports only command templates to a JSON file.
  Future<int> exportCommandTemplates(String filePath) async {
    final templates = await _templateRepo.loadTemplates();
    final bundle = {
      'app': 'JA_Remote',
      'version': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'templateCount': templates.length,
      'commandTemplates': templates.map((t) => t.toJson()).toList(),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final file = File(filePath);
    await file.writeAsString(encoder.convert(bundle), flush: true);
    return templates.length;
  }

  /// Parses and validates a JSON configuration file for import preview.
  Future<ConfigImportPreview> previewConfigFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const ConfigImportPreview(
          isValid: false,
          error: 'File không tồn tại.',
        );
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return const ConfigImportPreview(isValid: false, error: 'File rỗng.');
      }

      final dynamic decoded = jsonDecode(content);
      final List<ManagedDevice> devices = [];
      final List<SavedCredential> credentials = [];
      final List<CommandTemplate> commandTemplates = [];

      // Format 1: Full JA_Remote bundle { "devices": [...], "credentials": [...], "commandTemplates": [...] }
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('devices') && decoded['devices'] is List) {
          for (final item in decoded['devices'] as List) {
            if (item is Map<String, dynamic>) {
              devices.add(ManagedDevice.fromJson(item));
            }
          }
        }
        if (decoded.containsKey('credentials') &&
            decoded['credentials'] is List) {
          for (final item in decoded['credentials'] as List) {
            if (item is Map<String, dynamic>) {
              credentials.add(SavedCredential.fromJson(item));
            }
          }
        }
        if (decoded.containsKey('commandTemplates') &&
            decoded['commandTemplates'] is List) {
          for (final item in decoded['commandTemplates'] as List) {
            if (item is Map<String, dynamic>) {
              commandTemplates.add(CommandTemplate.fromJson(item));
            }
          }
        } else if (decoded.containsKey('templates') &&
            decoded['templates'] is List) {
          for (final item in decoded['templates'] as List) {
            if (item is Map<String, dynamic>) {
              commandTemplates.add(CommandTemplate.fromJson(item));
            }
          }
        }
      }
      // Format 2: Raw array of devices or templates
      else if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            if (item.containsKey('command')) {
              commandTemplates.add(CommandTemplate.fromJson(item));
            } else {
              devices.add(ManagedDevice.fromJson(item));
            }
          }
        }
      } else {
        return const ConfigImportPreview(
          isValid: false,
          error: 'Cấu trúc file JSON không hợp lệ.',
        );
      }

      if (devices.isEmpty && credentials.isEmpty && commandTemplates.isEmpty) {
        return const ConfigImportPreview(
          isValid: false,
          error:
              'Không tìm thấy dữ liệu thiết bị, tài khoản hoặc lệnh mẫu trong file.',
        );
      }

      return ConfigImportPreview(
        isValid: true,
        devices: devices,
        credentials: credentials,
        commandTemplates: commandTemplates,
      );
    } catch (e) {
      return ConfigImportPreview(
        isValid: false,
        error: 'Lỗi đọc file JSON: $e',
      );
    }
  }

  /// Applies the parsed configuration with either Merge or Overwrite mode.
  Future<void> applyImport(
    ConfigImportPreview preview, {
    required bool overwrite,
  }) async {
    if (!preview.isValid) return;

    if (overwrite) {
      // Overwrite completely
      if (preview.devices.isNotEmpty) {
        await _deviceRepo.saveAll(preview.devices);
      }
      if (preview.credentials.isNotEmpty) {
        await _credRepo.saveAll(preview.credentials);
      }
      if (preview.commandTemplates.isNotEmpty) {
        await _templateRepo.saveAll(preview.commandTemplates);
      }
    } else {
      // Merge mode: upsert devices, append credentials, merge templates
      for (final dev in preview.devices) {
        await _deviceRepo.upsert(dev);
      }
      for (final cred in preview.credentials) {
        await _credRepo.recordCredential(
          cred.username,
          cred.password,
          label: cred.label,
        );
      }
      if (preview.commandTemplates.isNotEmpty) {
        final existing = await _templateRepo.loadTemplates();
        final Map<String, CommandTemplate> map = {
          for (final t in existing) t.id: t,
        };
        for (final t in preview.commandTemplates) {
          map[t.id] = t;
        }
        await _templateRepo.saveAll(map.values.toList());
      }
    }
  }
}

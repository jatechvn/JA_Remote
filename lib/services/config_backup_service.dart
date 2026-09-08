import 'dart:convert';
import 'dart:io';
import '../modules/constants.dart';
import '../data/models/managed_device.dart';
import '../data/models/saved_credential.dart';
import '../data/repositories/device_repository.dart';
import '../data/repositories/credential_repository.dart';

/// Preview result before applying an imported config.
class ConfigImportPreview {
  final bool isValid;
  final String? error;
  final List<ManagedDevice> devices;
  final List<SavedCredential> credentials;

  const ConfigImportPreview({
    required this.isValid,
    this.error,
    this.devices = const [],
    this.credentials = const [],
  });

  int get deviceCount => devices.length;
  int get credentialCount => credentials.length;
}

/// Service handling JSON export, import, and migration of devices and credentials.
class ConfigBackupService {
  final DeviceRepository _deviceRepo = DeviceRepository();
  final CredentialRepository _credRepo = CredentialRepository();

  /// Exports full configuration (devices + credentials) to a JSON file.
  Future<int> exportConfig(String filePath) async {
    final devices = await _deviceRepo.loadDevices();
    final credentials = await _credRepo.loadCredentials();

    final bundle = {
      'app': 'JA_Remote',
      'version': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'deviceCount': devices.length,
      'devices': devices.map((d) => d.toJson()).toList(),
      'credentials': credentials.map((c) => c.toJson()).toList(),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final file = File(filePath);
    await file.writeAsString(encoder.convert(bundle), flush: true);
    return devices.length;
  }

  /// Exports selected devices to a JSON file.
  Future<int> exportSelectedDevices(
    String filePath,
    List<ManagedDevice> devices,
  ) async {
    final credentials = await _credRepo.loadCredentials();

    final bundle = {
      'app': 'JA_Remote',
      'version': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'deviceCount': devices.length,
      'devices': devices.map((d) => d.toJson()).toList(),
      'credentials': credentials.map((c) => c.toJson()).toList(),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final file = File(filePath);
    await file.writeAsString(encoder.convert(bundle), flush: true);
    return devices.length;
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

      // Format 1: Full JA_Remote bundle { "devices": [...], "credentials": [...] }
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
      }
      // Format 2: Raw array of devices [ { "name": "...", "ip": "..." } ]
      else if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            devices.add(ManagedDevice.fromJson(item));
          }
        }
      } else {
        return const ConfigImportPreview(
          isValid: false,
          error: 'Cấu trúc file JSON không hợp lệ.',
        );
      }

      if (devices.isEmpty && credentials.isEmpty) {
        return const ConfigImportPreview(
          isValid: false,
          error: 'Không tìm thấy dữ liệu thiết bị hoặc tài khoản trong file.',
        );
      }

      return ConfigImportPreview(
        isValid: true,
        devices: devices,
        credentials: credentials,
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
      await _deviceRepo.saveAll(preview.devices);
      if (preview.credentials.isNotEmpty) {
        await _credRepo.saveAll(preview.credentials);
      }
    } else {
      // Merge mode: upsert devices and append credentials
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
    }
  }
}

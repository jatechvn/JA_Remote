import 'dart:convert';
import 'dart:io';
import '../../core/security/dpapi_helper.dart';
import '../../core/utils/app_storage.dart';
import '../models/managed_device.dart';

/// Repository for managing device persistence with atomic JSON file storage.
class DeviceRepository {
  List<ManagedDevice> _cachedDevices = [];
  bool _isInitialized = false;
  File? _customStorageFile;

  List<ManagedDevice> get cachedDevices => List.unmodifiable(_cachedDevices);

  /// Allows unit tests to redirect JSON storage to a temporary file.
  void setStorageFileForTesting(File? file) {
    _customStorageFile = file;
    _isInitialized = false;
    _cachedDevices.clear();
  }

  Future<File> _getStorageFile() async {
    if (_customStorageFile != null) return _customStorageFile!;
    return AppStorage.getFile('devices.json');
  }

  /// Initializes repository and loads devices from local storage or loads defaults.
  Future<List<ManagedDevice>> loadDevices() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          _cachedDevices = decoded.map((e) {
            final dev = ManagedDevice.fromJson(e as Map<String, dynamic>);
            if (dev.password != null && dev.password!.isNotEmpty) {
              return dev.copyWith(password: DpapiHelper.decrypt(dev.password!));
            }
            return dev;
          }).toList();
          _isInitialized = true;
          return _cachedDevices;
        }
      }
    } catch (_) {}

    // First time defaults for factory testing
    _cachedDevices = _getDefaultDevices();
    await saveAll(_cachedDevices);
    _isInitialized = true;
    return _cachedDevices;
  }

  /// Saves entire device list to disk.
  Future<void> saveAll(List<ManagedDevice> devices) async {
    _cachedDevices = List.from(devices);
    try {
      final file = await _getStorageFile();
      final toSave = _cachedDevices.map((d) {
        if (d.password != null && d.password!.isNotEmpty) {
          return d
              .copyWith(password: DpapiHelper.encrypt(d.password!))
              .toJson();
        }
        return d.toJson();
      }).toList();

      final jsonStr = jsonEncode(toSave);
      // Atomic write using temporary file
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonStr, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {}
  }

  /// Adds or updates a device.
  Future<void> upsert(ManagedDevice device) async {
    if (!_isInitialized) await loadDevices();
    final index = _cachedDevices.indexWhere(
      (d) => d.id == device.id || d.ip == device.ip,
    );
    if (index >= 0) {
      _cachedDevices[index] = device;
    } else {
      _cachedDevices.add(device);
    }
    await saveAll(_cachedDevices);
  }

  /// Removes a device by ID.
  Future<void> delete(String id) async {
    if (!_isInitialized) await loadDevices();
    _cachedDevices.removeWhere((d) => d.id == id);
    await saveAll(_cachedDevices);
  }

  /// Removes multiple devices by IDs.
  Future<void> deleteMultiple(List<String> ids) async {
    if (!_isInitialized) await loadDevices();
    final idSet = ids.toSet();
    _cachedDevices.removeWhere((d) => idSet.contains(d.id));
    await saveAll(_cachedDevices);
  }

  /// Updates the group for multiple devices by IDs.
  Future<void> updateGroupForMultiple(List<String> ids, String newGroup) async {
    if (!_isInitialized) await loadDevices();
    final idSet = ids.toSet();
    for (int i = 0; i < _cachedDevices.length; i++) {
      if (idSet.contains(_cachedDevices[i].id)) {
        _cachedDevices[i] = _cachedDevices[i].copyWith(group: newGroup);
      }
    }
    await saveAll(_cachedDevices);
  }

  static List<ManagedDevice> _getDefaultDevices() {
    return [
      ManagedDevice(
        id: 'te-pc01',
        name: 'L6-TE01',
        hostname: 'L6-TE01.factory.local',
        ip: '172.19.116.157',
        mac: 'A4:B1:C1:11:22:33',
        os: 'Windows',
        online: false,
        group: 'L6',
        note: 'Main TE Functional Testbed Station #1',
      ),
      ManagedDevice(
        id: 'te-pc02',
        name: 'L6-TE02',
        hostname: 'L6-TE02.factory.local',
        ip: '172.19.116.158',
        mac: 'A4:B1:C1:44:55:66',
        os: 'Windows',
        online: false,
        group: 'L6',
        note: 'Backup Station L6',
      ),
      ManagedDevice(
        id: 'cmdl-pc01',
        name: 'L10-CMDL01',
        hostname: 'L10-CMDL01.factory.local',
        ip: '172.19.116.188',
        mac: 'BC:24:11:88:99:AA',
        os: 'Windows',
        online: false,
        group: 'L10',
        note: 'CMDL Calibration Bench',
      ),
      ManagedDevice(
        id: 'srv-local',
        name: 'Localhost',
        hostname: '127.0.0.1',
        ip: '127.0.0.1',
        os: 'Windows',
        online: true,
        pingMs: 1,
        group: 'Local',
        note: 'Current Machine Loopback',
      ),
    ];
  }
}

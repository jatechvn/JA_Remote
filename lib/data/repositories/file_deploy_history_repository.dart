import 'dart:convert';
import 'dart:io';
import '../../core/utils/app_storage.dart';

/// Represents a previously used deployment source item.
class DeploySourceItem {
  final String path;
  final bool isDirectory;
  final DateTime lastUsed;

  const DeploySourceItem({
    required this.path,
    required this.isDirectory,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
    'path': path,
    'is_directory': isDirectory,
    'last_used': lastUsed.toIso8601String(),
  };

  factory DeploySourceItem.fromJson(Map<String, dynamic> json) =>
      DeploySourceItem(
        path: json['path'] as String? ?? '',
        isDirectory: json['is_directory'] as bool? ?? false,
        lastUsed:
            DateTime.tryParse(json['last_used'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Repository managing persistent deployment source and destination history.
/// Saves last selected paths across app restarts and provides suggestion history.
class FileDeployHistoryRepository {
  static final FileDeployHistoryRepository _instance =
      FileDeployHistoryRepository._internal();
  factory FileDeployHistoryRepository() => _instance;
  FileDeployHistoryRepository._internal();

  File? _customStorageFile;
  bool _isLoaded = false;

  String? _lastSourcePath;
  bool _lastSourceIsDir = false;
  String _lastDestPath = r'C:\Temp\Deploy';

  final List<DeploySourceItem> _sourceHistory = [];
  final List<String> _destHistory = [];

  static const int maxHistory = 10;

  static bool _sameDestination(String a, String b) {
    final windowsPath = RegExp(r'^[a-zA-Z]:[\\/]|^\\\\');
    return windowsPath.hasMatch(a) && windowsPath.hasMatch(b)
        ? a.toLowerCase() == b.toLowerCase()
        : a == b;
  }

  /// Allows unit tests to redirect JSON storage to a temporary file.
  void setStorageFileForTesting(File? file) {
    _customStorageFile = file;
    _isLoaded = false;
    _lastSourcePath = null;
    _lastSourceIsDir = false;
    _lastDestPath = r'C:\Temp\Deploy';
    _sourceHistory.clear();
    _destHistory.clear();
  }

  Future<File> _getStorageFile() async {
    if (_customStorageFile != null) return _customStorageFile!;
    return AppStorage.getFile('file_deploy_history.json');
  }

  Future<void> _load() async {
    if (_isLoaded) return;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final data = jsonDecode(raw);
          if (data is Map<String, dynamic>) {
            _lastSourcePath = data['last_source_path'] as String?;
            _lastSourceIsDir = data['last_source_is_dir'] as bool? ?? false;
            final savedDest = data['last_dest_path'] as String?;
            if (savedDest != null) {
              _lastDestPath = savedDest.trim();
            }

            if (data['source_history'] is List) {
              _sourceHistory.clear();
              for (final item in data['source_history'] as List) {
                if (item is Map<String, dynamic>) {
                  final entry = DeploySourceItem.fromJson(item);
                  if (entry.path.trim().isNotEmpty) {
                    _sourceHistory.add(entry);
                  }
                } else if (item is String && item.trim().isNotEmpty) {
                  _sourceHistory.add(
                    DeploySourceItem(
                      path: item,
                      isDirectory: Directory(item).existsSync(),
                      lastUsed: DateTime.now(),
                    ),
                  );
                }
              }
            }

            if (data['dest_history'] is List) {
              _destHistory.clear();
              for (final item in data['dest_history'] as List) {
                final str = item.toString().trim();
                if (str.isNotEmpty &&
                    !_destHistory.any((d) => _sameDestination(d, str))) {
                  _destHistory.add(str);
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    _isLoaded = true;
  }

  Future<void> _save() async {
    try {
      final file = await _getStorageFile();
      final data = {
        'last_source_path': _lastSourcePath,
        'last_source_is_dir': _lastSourceIsDir,
        'last_dest_path': _lastDestPath,
        'source_history': _sourceHistory.map((e) => e.toJson()).toList(),
        'dest_history': _destHistory,
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  Future<String?> getLastSourcePath() async {
    await _load();
    return _lastSourcePath;
  }

  Future<bool> getLastSourceIsDir() async {
    await _load();
    return _lastSourceIsDir;
  }

  Future<String> getLastDestPath() async {
    await _load();
    return _lastDestPath;
  }

  Future<void> saveLastState({
    String? sourcePath,
    bool? isDirectory,
    String? destPath,
  }) async {
    await _load();
    if (sourcePath != null) _lastSourcePath = sourcePath;
    if (isDirectory != null) _lastSourceIsDir = isDirectory;
    if (destPath != null) {
      _lastDestPath = destPath.trim();
    }
    await _save();
  }

  Future<List<DeploySourceItem>> getSourceHistory() async {
    await _load();
    return List.unmodifiable(_sourceHistory);
  }

  Future<void> addSourceHistory(String path, bool isDirectory) async {
    final clean = path.trim();
    if (clean.isEmpty) return;
    await _load();

    _lastSourcePath = clean;
    _lastSourceIsDir = isDirectory;

    _sourceHistory.removeWhere(
      (item) => item.path.toLowerCase() == clean.toLowerCase(),
    );
    _sourceHistory.insert(
      0,
      DeploySourceItem(
        path: clean,
        isDirectory: isDirectory,
        lastUsed: DateTime.now(),
      ),
    );
    if (_sourceHistory.length > maxHistory) {
      _sourceHistory.removeRange(maxHistory, _sourceHistory.length);
    }
    await _save();
  }

  Future<void> removeSourceHistory(String path) async {
    await _load();
    _sourceHistory.removeWhere(
      (item) => item.path.toLowerCase() == path.trim().toLowerCase(),
    );
    if (_lastSourcePath != null &&
        _lastSourcePath!.toLowerCase() == path.trim().toLowerCase()) {
      _lastSourcePath = _sourceHistory.isNotEmpty
          ? _sourceHistory.first.path
          : null;
      _lastSourceIsDir = _sourceHistory.isNotEmpty
          ? _sourceHistory.first.isDirectory
          : false;
    }
    await _save();
  }

  Future<void> clearSourceHistory() async {
    await _load();
    _sourceHistory.clear();
    await _save();
  }

  Future<List<String>> getDestHistory() async {
    await _load();
    return List.unmodifiable(_destHistory);
  }

  Future<void> addDestHistory(String path) async {
    final clean = path.trim();
    if (clean.isEmpty) return;
    await _load();

    _lastDestPath = clean;

    _destHistory.removeWhere((p) => _sameDestination(p, clean));
    _destHistory.insert(0, clean);
    if (_destHistory.length > maxHistory) {
      _destHistory.removeRange(maxHistory, _destHistory.length);
    }
    await _save();
  }

  Future<void> removeDestHistory(String path) async {
    await _load();
    _destHistory.removeWhere((p) => _sameDestination(p, path.trim()));
    await _save();
  }

  Future<void> clearDestHistory() async {
    await _load();
    _destHistory.clear();
    await _save();
  }
}

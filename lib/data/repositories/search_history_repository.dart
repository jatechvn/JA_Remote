import 'dart:convert';
import 'dart:io';
import '../../core/utils/app_storage.dart';

/// Repository managing persistent search history queries per category (e.g. 'devices', 'scanner').
class SearchHistoryRepository {
  static final SearchHistoryRepository _instance =
      SearchHistoryRepository._internal();
  factory SearchHistoryRepository() => _instance;
  SearchHistoryRepository._internal();

  File? _customStorageFile;
  final Map<String, List<String>> _cache = {};
  bool _isLoaded = false;
  static const int maxHistoryPerCategory = 10;

  /// Allows unit tests to redirect JSON storage to a temporary file.
  void setStorageFileForTesting(File? file) {
    _customStorageFile = file;
    _isLoaded = false;
    _cache.clear();
  }

  Future<File> _getStorageFile() async {
    if (_customStorageFile != null) return _customStorageFile!;
    return AppStorage.getFile('search_history.json');
  }

  Future<void> _load() async {
    if (_isLoaded) return;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            _cache.clear();
            for (final entry in decoded.entries) {
              if (entry.value is List) {
                _cache[entry.key] = (entry.value as List)
                    .map((e) => e.toString())
                    .where((s) => s.trim().isNotEmpty)
                    .toList();
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
      await file.writeAsString(jsonEncode(_cache));
    } catch (_) {}
  }

  /// Returns recent search queries for a category (most recent first).
  Future<List<String>> getHistory(String category) async {
    await _load();
    return List.unmodifiable(_cache[category] ?? []);
  }

  /// Adds or moves a query to the top of recent history.
  Future<void> addQuery(String category, String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    await _load();
    final list = _cache.putIfAbsent(category, () => []);
    list.remove(clean);
    list.insert(0, clean);
    if (list.length > maxHistoryPerCategory) {
      list.removeRange(maxHistoryPerCategory, list.length);
    }
    await _save();
  }

  /// Removes a single query entry from category history.
  Future<void> removeQuery(String category, String query) async {
    await _load();
    final list = _cache[category];
    if (list != null) {
      list.remove(query.trim());
      await _save();
    }
  }

  /// Clears all history for a category.
  Future<void> clearHistory(String category) async {
    await _load();
    _cache[category]?.clear();
    await _save();
  }
}

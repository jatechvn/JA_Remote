import 'dart:convert';
import 'dart:io';
import '../../core/utils/app_storage.dart';
import '../models/command_template.dart';

/// Repository managing persistent command templates stored in JSON.
class CommandTemplateRepository {
  static final CommandTemplateRepository _instance =
      CommandTemplateRepository._internal();
  factory CommandTemplateRepository() => _instance;
  CommandTemplateRepository._internal();

  File? _customStorageFile;
  List<CommandTemplate> _cachedTemplates = [];
  bool _isInitialized = false;

  List<CommandTemplate> get cachedTemplates =>
      List.unmodifiable(_cachedTemplates);

  /// Allows unit tests to redirect JSON storage to a temporary file.
  void setStorageFileForTesting(File? file) {
    _customStorageFile = file;
    _isInitialized = false;
    _cachedTemplates.clear();
  }

  Future<File> _getStorageFile() async {
    if (_customStorageFile != null) return _customStorageFile!;
    return AppStorage.getFile('command_templates.json');
  }

  /// Initializes repository and loads command templates from local JSON storage or defaults.
  Future<List<CommandTemplate>> loadTemplates() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          _cachedTemplates = decoded
              .map((e) => CommandTemplate.fromJson(e as Map<String, dynamic>))
              .toList();
          _isInitialized = true;
          return cachedTemplates;
        }
        throw const FormatException('Empty template file');
      }
    } catch (_) {
      // Preserve unreadable/corrupt storage. Defaults are a session fallback,
      // not permission to overwrite the only copy of the user's templates.
      _cachedTemplates = List.of(CommandTemplate.getDefaultTemplates());
      _isInitialized = true;
      return cachedTemplates;
    }

    // First time defaults
    _cachedTemplates = List.of(CommandTemplate.getDefaultTemplates());
    await saveAll(_cachedTemplates);
    _isInitialized = true;
    return cachedTemplates;
  }

  /// Saves a single template (adds if new ID, updates if existing ID).
  Future<void> saveTemplate(CommandTemplate template) async {
    if (!_isInitialized) await loadTemplates();

    final index = _cachedTemplates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      _cachedTemplates[index] = template;
    } else {
      _cachedTemplates.add(template);
    }
    await saveAll(_cachedTemplates);
  }

  /// Removes a command template by ID.
  Future<void> deleteTemplate(String id) async {
    if (!_isInitialized) await loadTemplates();

    _cachedTemplates.removeWhere((t) => t.id == id);
    await saveAll(_cachedTemplates);
  }

  /// Saves the entire list of command templates to disk atomically.
  Future<void> saveAll(List<CommandTemplate> templates) async {
    _cachedTemplates = List.from(templates);
    try {
      final file = await _getStorageFile();
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonStr = encoder.convert(
        _cachedTemplates.map((e) => e.toJson()).toList(),
      );
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonStr, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {}
  }

  /// Resets templates back to built-in default templates.
  Future<List<CommandTemplate>> resetToDefaults() async {
    final defaults = CommandTemplate.getDefaultTemplates();
    await saveAll(defaults);
    return cachedTemplates;
  }
}

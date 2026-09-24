import 'dart:convert';
import 'dart:io';
import '../../core/security/dpapi_helper.dart';
import '../../core/utils/app_storage.dart';
import '../models/saved_credential.dart';

/// Repository managing persistent history of recently used and saved credentials.
class CredentialRepository {
  static final CredentialRepository _instance =
      CredentialRepository._internal();
  factory CredentialRepository() => _instance;
  CredentialRepository._internal();

  List<SavedCredential> _cachedCredentials = [];
  bool _isInitialized = false;
  File? _customStorageFile;

  List<SavedCredential> get credentials =>
      List.unmodifiable(_cachedCredentials);

  /// Allows unit tests to redirect JSON storage to a temporary file.
  void setStorageFileForTesting(File? file) {
    _customStorageFile = file;
    _isInitialized = false;
    _cachedCredentials.clear();
  }

  Future<File> _getStorageFile() async {
    if (_customStorageFile != null) return _customStorageFile!;
    return AppStorage.getFile('credentials.json');
  }

  /// Loads credentials from persistent storage.
  /// Automatically decrypts DPAPI-encrypted passwords.
  Future<List<SavedCredential>> loadCredentials() async {
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          _cachedCredentials = decoded.map((e) {
            final cred = SavedCredential.fromJson(e as Map<String, dynamic>);
            // Decrypt DPAPI password if encrypted, or return plain as-is
            return cred.copyWith(password: DpapiHelper.decrypt(cred.password));
          }).toList();
          _cachedCredentials.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
          _isInitialized = true;
          return _cachedCredentials;
        }
      }
    } catch (_) {}

    _cachedCredentials = [];
    _isInitialized = true;
    return _cachedCredentials;
  }

  /// Saves the current list to disk atomically with DPAPI-encrypted passwords.
  Future<void> saveAll(List<SavedCredential> list) async {
    _cachedCredentials = List.from(list);
    try {
      final file = await _getStorageFile();
      final toSave = _cachedCredentials.map((e) {
        final encryptedPass = DpapiHelper.encrypt(e.password);
        return e.copyWith(password: encryptedPass).toJson();
      }).toList();

      final jsonStr = jsonEncode(toSave);
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonStr, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {}
  }

  /// Records a recently used credential into MRU history (max 10 items).
  Future<void> recordCredential(
    String username,
    String password, {
    String? label,
  }) async {
    final user = username.trim();
    final pass = password;
    if (user.isEmpty && pass.isEmpty) return;

    if (!_isInitialized) await loadCredentials();

    // Remove existing match if present
    _cachedCredentials.removeWhere(
      (c) =>
          c.username.toLowerCase() == user.toLowerCase() && c.password == pass,
    );

    // Insert at front as most recent
    final newCred = SavedCredential(
      id: 'cred_${DateTime.now().millisecondsSinceEpoch}',
      username: user.isEmpty ? 'Administrator' : user,
      password: pass,
      label: label,
      lastUsed: DateTime.now(),
    );
    _cachedCredentials.insert(0, newCred);

    // Cap at 10 items
    if (_cachedCredentials.length > 10) {
      _cachedCredentials = _cachedCredentials.sublist(0, 10);
    }

    await saveAll(_cachedCredentials);
  }

  /// Deletes a credential by ID.
  Future<void> delete(String id) async {
    if (!_isInitialized) await loadCredentials();
    _cachedCredentials.removeWhere((c) => c.id == id);
    await saveAll(_cachedCredentials);
  }

  /// Clears all saved credentials.
  Future<void> clearAll() async {
    _cachedCredentials.clear();
    await saveAll([]);
  }
}

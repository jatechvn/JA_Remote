import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/security/dpapi_helper.dart';
import '../modules/constants.dart';

/// Flutter-compatible version parser and comparator for OTA package updates.
/// Build numbers (`+4`) take precedence so a newer Windows build can update.
class SemanticVersion implements Comparable<SemanticVersion> {
  final int major;
  final int minor;
  final int patch;
  final int? build;
  final String raw;
  final String? prerelease;

  const SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build,
    required this.raw,
    this.prerelease,
  });

  /// Parses version strings such as: '1.2.1', 'v1.2.1', '1.2.1+4', '1.3.0-beta'
  static SemanticVersion? tryParse(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final clean = input.trim().toLowerCase().replaceAll(RegExp(r'^[vV]'), '');
    if (!RegExp(
      r'^\d+\.\d+(?:\.\d+)?(?:-[0-9a-z.-]+)?(?:\+\d+)?$',
    ).hasMatch(clean)) {
      return null;
    }
    final pre = RegExp(r'-([^+]+)').firstMatch(clean)?.group(1);

    int? buildNum;
    String versionCore = clean;
    if (clean.contains('+')) {
      final parts = clean.split('+');
      versionCore = parts[0];
      buildNum = int.tryParse(parts[1]);
    }

    if (versionCore.contains('-')) {
      versionCore = versionCore.split('-')[0];
    }

    final segments = versionCore.split('.');
    if (segments.isEmpty) return null;

    final major = int.tryParse(segments[0]);
    if (major == null) return null;
    final minor = segments.length > 1 ? int.tryParse(segments[1]) : 0;
    if (minor == null) return null;
    final patch = segments.length > 2 ? int.tryParse(segments[2]) : 0;
    if (patch == null) return null;

    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      build: buildNum,
      raw: input.trim(),
      prerelease: pre,
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (prerelease != other.prerelease) {
      if (prerelease == null) return 1;
      if (other.prerelease == null) return -1;
      final a = prerelease!.split('.');
      final b = other.prerelease!.split('.');
      for (var i = 0; i < a.length && i < b.length; i++) {
        final x = int.tryParse(a[i]);
        final y = int.tryParse(b[i]);
        final comparison = x != null && y != null
            ? x.compareTo(y)
            : x != null
            ? -1
            : y != null
            ? 1
            : a[i].compareTo(b[i]);
        if (comparison != 0) return comparison;
      }
      if (a.length != b.length) return a.length.compareTo(b.length);
    }
    final b1 = build ?? 0;
    final b2 = other.build ?? 0;
    return b1.compareTo(b2);
  }

  bool operator >(SemanticVersion other) => compareTo(other) > 0;
  bool operator <(SemanticVersion other) => compareTo(other) < 0;
  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;
  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SemanticVersion && compareTo(other) == 0;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build ?? 0, prerelease);

  @override
  String toString() {
    final base =
        '$major.$minor.$patch${prerelease == null ? '' : '-$prerelease'}';
    return build != null && build! > 0 ? '$base+$build' : base;
  }

  String get displayVersion => 'v$this';
}

/// Metadata describing an available update package located on the network server.
class UpdatePackageInfo {
  final SemanticVersion version;
  final String fileName;
  final String fullPath;
  final int fileSize;
  final String? releaseNotes;
  final DateTime? releaseDate;
  final String? sha256;

  const UpdatePackageInfo({
    required this.version,
    required this.fileName,
    required this.fullPath,
    required this.fileSize,
    this.releaseNotes,
    this.releaseDate,
    this.sha256,
  });

  String get formattedSize {
    if (fileSize <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = fileSize.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 2)} ${suffixes[i]}';
  }
}

/// Result returned from checking for available updates.
class UpdateCheckResult {
  final bool hasUpdate;
  final UpdatePackageInfo? packageInfo;
  final String currentVersion;
  final String? errorMessage;
  final bool isConnectionSuccess;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.packageInfo,
    required this.currentVersion,
    this.errorMessage,
    this.isConnectionSuccess = true,
  });
}

/// Configuration model stored in external `update_config.json`.
class OtaUpdateConfig {
  final String serverPath;
  final String username;
  final String password;
  final String checkInterval; // 'daily', 'weekly', 'monthly', 'off'
  final DateTime? lastCheckTime;
  final String? cachedUpdateVersion;

  const OtaUpdateConfig({
    required this.serverPath,
    required this.username,
    required this.password,
    this.checkInterval = 'daily',
    this.lastCheckTime,
    this.cachedUpdateVersion,
  });

  factory OtaUpdateConfig.defaults() => const OtaUpdateConfig(
    serverPath: r'\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_Remote',
    username: '',
    password: '',
    checkInterval: 'daily',
  );

  factory OtaUpdateConfig.fromJson(Map<String, dynamic> json) {
    return OtaUpdateConfig(
      serverPath:
          json['serverPath'] as String? ??
          r'\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_Remote',
      username: json['username'] as String? ?? '',
      // Old clear-text files remain readable and are encrypted on next save.
      password: DpapiHelper.decrypt(json['password'] as String? ?? ''),
      checkInterval: json['checkInterval'] as String? ?? 'daily',
      lastCheckTime: json['lastCheckTime'] != null
          ? DateTime.tryParse(json['lastCheckTime'] as String)
          : null,
      cachedUpdateVersion: json['cachedUpdateVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'serverPath': serverPath,
    'username': username,
    'password': DpapiHelper.encrypt(password),
    'checkInterval': checkInterval,
    if (lastCheckTime != null)
      'lastCheckTime': lastCheckTime!.toIso8601String(),
    if (cachedUpdateVersion != null) 'cachedUpdateVersion': cachedUpdateVersion,
  };

  OtaUpdateConfig copyWith({
    String? serverPath,
    String? username,
    String? password,
    String? checkInterval,
    DateTime? lastCheckTime,
    String? cachedUpdateVersion,
  }) {
    return OtaUpdateConfig(
      serverPath: serverPath ?? this.serverPath,
      username: username ?? this.username,
      password: password ?? this.password,
      checkInterval: checkInterval ?? this.checkInterval,
      lastCheckTime: lastCheckTime ?? this.lastCheckTime,
      cachedUpdateVersion: cachedUpdateVersion ?? this.cachedUpdateVersion,
    );
  }
}

/// Centralized LAN OTA Update Service for JA Remote.
class OtaUpdateService extends ChangeNotifier {
  static bool isValidPackageName(String name) =>
      RegExp(
        r'^JA_Remote_[a-zA-Z0-9_.+-]+\.zip$',
        caseSensitive: false,
      ).hasMatch(name) &&
      !name.contains('..');

  static bool isValidSha256(String? value) =>
      value != null && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value);

  static const int _maxArchiveEntries = 5000;
  static const int _maxArchiveUncompressedBytes = 1024 * 1024 * 1024;

  static String _psLiteral(String value) => "'${value.replaceAll("'", "''")}'";

  static Future<ProcessResult> _runPowerShell(String script) {
    final encoded = base64Encode(
      script.codeUnits.expand((c) => [c & 255, c >> 8]).toList(),
    );
    return Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      encoded,
    ]);
  }

  bool _applying = false;
  bool _isChecking = false;
  UpdateCheckResult? _lastCheckResult;
  OtaUpdateConfig _config = OtaUpdateConfig.defaults();

  static final OtaUpdateService _instance = OtaUpdateService._internal();
  factory OtaUpdateService() => _instance;

  OtaUpdateService._internal() {
    _loadInitialConfig();
  }

  bool get isChecking => _isChecking;
  bool get isApplying => _applying;
  UpdateCheckResult? get lastCheckResult => _lastCheckResult;
  OtaUpdateConfig get config => _config;

  File? _customConfigFileForTesting;
  Directory? _customServerDirForTesting;

  @visibleForTesting
  void setCustomConfigFileForTesting(File? file) {
    _customConfigFileForTesting = file;
  }

  @visibleForTesting
  void setCustomServerDirForTesting(Directory? dir) {
    _customServerDirForTesting = dir;
  }

  Future<void> _loadInitialConfig() async {
    final loaded = await loadExternalConfigFile();
    if (loaded != null) {
      _config = loaded;
      notifyListeners();
    }
  }

  /// Resolves the path to `update_config.json`:
  /// 1. Next to the executing binary (.exe) for portable LAN deployment.
  /// 2. In %APPDATA%\JA_Remote\update_config.json.
  File getConfigFile() {
    if (_customConfigFileForTesting != null) {
      return _customConfigFileForTesting!;
    }

    try {
      final exeDir = File(Platform.resolvedExecutable).parent;
      final exeConfig = File(
        '${exeDir.path}${Platform.pathSeparator}update_config.json',
      );
      if (exeConfig.existsSync()) {
        return exeConfig;
      }
    } catch (_) {}

    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      final dir = Directory('$appData\\JA_Remote');
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (_) {}
      }
      return File('${dir.path}\\update_config.json');
    }
    return File('update_config.json');
  }

  /// Loads configuration from `update_config.json` if present.
  Future<OtaUpdateConfig?> loadExternalConfigFile() async {
    try {
      final file = getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          _config = OtaUpdateConfig.fromJson(json);
          return _config;
        }
      }
    } catch (e) {
      debugPrint('[OtaUpdateService] Load config error: $e');
    }
    return null;
  }

  /// Saves configuration to `update_config.json`.
  Future<bool> saveExternalConfigFile(OtaUpdateConfig newConfig) async {
    try {
      final file = getConfigFile();
      final encoder = const JsonEncoder.withIndent('  ');
      await file.writeAsString(
        encoder.convert(newConfig.toJson()),
        flush: true,
      );
      _config = newConfig;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[OtaUpdateService] Save config error: $e');
      return false;
    }
  }

  /// Determines whether it's time to check for updates based on the configured interval.
  bool shouldCheckForUpdates({
    required String interval,
    DateTime? lastCheckTime,
    DateTime? now,
  }) {
    if (interval == 'off') return false;
    if (lastCheckTime == null) return true;

    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(lastCheckTime);

    switch (interval) {
      case 'daily':
        return elapsed.inHours >= 24;
      case 'weekly':
        return elapsed.inDays >= 7;
      case 'monthly':
        return elapsed.inDays >= 30;
      default:
        return elapsed.inHours >= 24;
    }
  }

  /// Extracts the root SMB share from a UNC path (e.g. `\\10.81.141.226\temp`).
  static String? extractSmbShareRoot(String uncPath) {
    final normalized = uncPath.replaceAll('/', '\\');
    if (!normalized.startsWith(r'\\')) return null;

    final parts = normalized.substring(2).split('\\');
    if (parts.length < 2) return null;
    return '\\\\${parts[0]}\\${parts[1]}';
  }

  /// Connects to a network SMB/UNC share using Windows `net use` if required.
  Future<bool> connectSmbShare({
    String? path,
    String? username,
    String? password,
  }) async {
    if (_customServerDirForTesting != null) {
      return await _customServerDirForTesting!.exists();
    }

    final targetPath = path ?? _config.serverPath;
    final user = username ?? _config.username;
    final pass = password ?? _config.password;

    final normalized = targetPath.replaceAll('/', '\\');
    if (!normalized.startsWith(r'\\')) {
      return await Directory(targetPath).exists();
    }

    // 1. Check if already accessible
    try {
      if (await Directory(targetPath).exists()) {
        return true;
      }
    } catch (_) {}

    // 2. Mount root share with net use
    final shareRoot = extractSmbShareRoot(targetPath);
    if (shareRoot != null && Platform.isWindows) {
      try {
        final args = ['use', shareRoot];
        if (user.isNotEmpty || pass.isNotEmpty) {
          args.add(pass);
          if (user.isNotEmpty) args.add('/user:$user');
        }
        final result = await Process.run('net', args);
        if (result.exitCode == 0) {
          return await Directory(targetPath).exists();
        }
        final out = '${result.stdout} ${result.stderr}';
        if (out.contains('1219')) {
          // Error 1219: multiple connections to a server or shared resource by the same user
          return await Directory(targetPath).exists();
        }
      } catch (e) {
        debugPrint('[OtaUpdateService] net use error: $e');
      }
    }

    return await Directory(targetPath).exists();
  }

  /// Checks the server share for available update packages.
  Future<UpdateCheckResult> checkForUpdates({
    String? overrideServerPath,
    String? overrideCurrentVersion,
  }) async {
    _isChecking = true;
    notifyListeners();

    try {
      final serverPath = overrideServerPath ?? _config.serverPath;
      final currentVerStr = overrideCurrentVersion ?? appVersion;
      final currentSemVer =
          SemanticVersion.tryParse(currentVerStr) ??
          const SemanticVersion(major: 1, minor: 0, patch: 0, raw: '1.0.0');

      // 1. Connect to SMB Share
      final connected = await connectSmbShare(path: serverPath);
      if (!connected) {
        final res = UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVerStr,
          isConnectionSuccess: false,
          errorMessage:
              'Không thể kết nối hoặc truy cập thư mục máy chủ: $serverPath',
        );
        _lastCheckResult = res;
        return res;
      }

      // Update last check time
      final updatedConfig = _config.copyWith(lastCheckTime: DateTime.now());
      await saveExternalConfigFile(updatedConfig);

      final Directory dir = _customServerDirForTesting ?? Directory(serverPath);
      if (!await dir.exists()) {
        final res = UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVerStr,
          isConnectionSuccess: false,
          errorMessage: 'Thư mục máy chủ không tồn tại: $serverPath',
        );
        _lastCheckResult = res;
        return res;
      }

      // 2. Prioritize reading version.json if present
      final versionJsonFile = File(
        '${dir.path}${Platform.pathSeparator}version.json',
      );
      if (await versionJsonFile.exists()) {
        try {
          final content = await versionJsonFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final verStr = json['version'] as String?;
          final fileName =
              json['fileName'] as String? ?? json['file'] as String?;
          final notes =
              json['releaseNotes'] as String? ?? json['changelog'] as String?;
          final dateStr = json['releaseDate'] as String?;
          final sha256 = json['sha256'] as String?;

          final serverSemVer = SemanticVersion.tryParse(verStr);
          if (serverSemVer != null &&
              fileName != null &&
              isValidPackageName(fileName) &&
              isValidSha256(sha256)) {
            final zipFile = File(
              '${dir.path}${Platform.pathSeparator}$fileName',
            );
            if (await zipFile.exists()) {
              final hasUpdate = serverSemVer > currentSemVer;
              final pkg = UpdatePackageInfo(
                version: serverSemVer,
                fileName: fileName,
                fullPath: zipFile.path,
                fileSize: await zipFile.length(),
                releaseNotes: notes,
                releaseDate: dateStr != null
                    ? DateTime.tryParse(dateStr)
                    : null,
                sha256: sha256!.toLowerCase(),
              );
              if (hasUpdate) {
                await saveExternalConfigFile(
                  _config.copyWith(
                    cachedUpdateVersion: serverSemVer.toString(),
                  ),
                );
              }
              final res = UpdateCheckResult(
                hasUpdate: hasUpdate,
                packageInfo: pkg,
                currentVersion: currentVerStr,
              );
              _lastCheckResult = res;
              return res;
            }
          }
          final res = UpdateCheckResult(
            hasUpdate: false,
            currentVersion: currentVerStr,
            isConnectionSuccess: false,
            errorMessage:
                'Update metadata must include a valid version, package name, and SHA-256 checksum.',
          );
          _lastCheckResult = res;
          return res;
        } catch (e) {
          final res = UpdateCheckResult(
            hasUpdate: false,
            currentVersion: currentVerStr,
            isConnectionSuccess: false,
            errorMessage: 'Update metadata is invalid: $e',
          );
          _lastCheckResult = res;
          return res;
        }
      }

      // 3. Fallback: Scan .zip packages matching JA_Remote_v*.zip
      final List<FileSystemEntity> entries = await dir
          .list(followLinks: false)
          .toList();
      final List<UpdatePackageInfo> candidates = [];

      final verRegex = RegExp(
        r'^JA_Remote_[vV](\d+\.\d+(?:\.\d+)?(?:-[a-zA-Z0-9.-]+)?(?:\+\d+)?)(?:_[a-zA-Z0-9_]+)?\.zip$',
        caseSensitive: false,
      );

      for (final entity in entries) {
        if (entity is File && entity.path.toLowerCase().endsWith('.zip')) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final match = isValidPackageName(fileName)
              ? verRegex.firstMatch(fileName)
              : null;
          if (match != null) {
            final verStr = match.group(1);
            final semVer = SemanticVersion.tryParse(verStr);
            if (semVer != null) {
              int size = 0;
              try {
                size = await entity.length();
              } catch (_) {}
              candidates.add(
                UpdatePackageInfo(
                  version: semVer,
                  fileName: fileName,
                  fullPath: entity.path,
                  fileSize: size,
                ),
              );
            }
          }
        }
      }

      if (candidates.isEmpty) {
        final res = UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVerStr,
          errorMessage: 'Không tìm thấy gói cập nhật .zip nào trên máy chủ',
        );
        _lastCheckResult = res;
        return res;
      }

      candidates.sort((a, b) => b.version.compareTo(a.version));
      final latestPkg = candidates.first;
      final hasUpdate = latestPkg.version > currentSemVer;

      if (!hasUpdate) {
        final res = UpdateCheckResult(
          hasUpdate: false,
          packageInfo: latestPkg,
          currentVersion: currentVerStr,
        );
        _lastCheckResult = res;
        return res;
      }

      // Có phiên bản mới hơn trên máy chủ -> tìm hoặc tính mã SHA-256
      String? checksum;
      final shaSumsFile = File(
        '${dir.path}${Platform.pathSeparator}SHA256SUMS.txt',
      );
      if (await shaSumsFile.exists()) {
        try {
          final lines = await shaSumsFile.readAsLines();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.toLowerCase().contains(
              latestPkg.fileName.toLowerCase(),
            )) {
              final match = RegExp(r'([A-Fa-f0-9]{64})').firstMatch(trimmed);
              if (match != null) {
                checksum = match.group(1)!.toLowerCase();
                break;
              }
            }
          }
        } catch (_) {}
      }

      if (checksum == null) {
        final singleShaFile = File('${latestPkg.fullPath}.sha256');
        if (await singleShaFile.exists()) {
          try {
            final content = await singleShaFile.readAsString();
            final match = RegExp(r'([A-Fa-f0-9]{64})').firstMatch(content);
            if (match != null) {
              checksum = match.group(1)!.toLowerCase();
            }
          } catch (_) {}
        }
      }

      if (checksum == null) {
        try {
          checksum = await _sha256Of(File(latestPkg.fullPath));
        } catch (_) {}
      }

      if (checksum == null || !isValidSha256(checksum)) {
        final res = UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVerStr,
          isConnectionSuccess: false,
          errorMessage:
              'Unsigned update packages are blocked. Add version.json or SHA256SUMS.txt with a SHA-256 checksum.',
        );
        _lastCheckResult = res;
        return res;
      }

      final verifiedPkg = UpdatePackageInfo(
        version: latestPkg.version,
        fileName: latestPkg.fileName,
        fullPath: latestPkg.fullPath,
        fileSize: latestPkg.fileSize,
        sha256: checksum,
      );

      await saveExternalConfigFile(
        _config.copyWith(cachedUpdateVersion: verifiedPkg.version.toString()),
      );

      final res = UpdateCheckResult(
        hasUpdate: true,
        packageInfo: verifiedPkg,
        currentVersion: currentVerStr,
      );
      _lastCheckResult = res;
      return res;
    } catch (e) {
      final res = UpdateCheckResult(
        hasUpdate: false,
        currentVersion: overrideCurrentVersion ?? appVersion,
        isConnectionSuccess: false,
        errorMessage: 'Lỗi khi quét tệp trên máy chủ: $e',
      );
      _lastCheckResult = res;
      return res;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Downloads, verifies, extracts, and hands over application update via `apply_update.bat`.
  Future<void> performUpdate(
    UpdatePackageInfo packageInfo, {
    void Function(double progress, String status)? onProgress,
  }) async {
    if (!Platform.isWindows) throw UnsupportedError('OTA requires Windows');
    if (_applying) throw StateError('An update is already running');
    if (!isValidSha256(packageInfo.sha256)) {
      throw StateError('Update package is missing a valid SHA-256 checksum');
    }
    _applying = true;
    notifyListeners();

    try {
      await _performUpdate(packageInfo, onProgress: onProgress);
    } finally {
      _applying = false;
      notifyListeners();
    }
  }

  Future<Directory> _performUpdate(
    UpdatePackageInfo packageInfo, {
    void Function(double progress, String status)? onProgress,
    bool prepareOnly = false,
  }) async {
    onProgress?.call(0.05, 'ota_progress_preparing');

    final tempBase = await Directory.systemTemp.createTemp('JA_Remote_Update_');
    final localZipFile = File('${tempBase.path}/update.zip');
    final sourceZip = File(packageInfo.fullPath);
    final totalBytes = await sourceZip.length();
    if (totalBytes == 0 ||
        (packageInfo.fileSize > 0 && totalBytes != packageInfo.fileSize)) {
      throw StateError('Update package size changed; check for updates again');
    }

    // 1. Download zip with real-time stream
    final writer = localZipFile.openWrite();
    var copied = 0;
    try {
      await for (final chunk in sourceZip.openRead()) {
        writer.add(chunk);
        copied += chunk.length;
        onProgress?.call(
          (0.1 + copied / totalBytes * 0.5).clamp(0.1, 0.6),
          'ota_downloading',
        );
      }
      await writer.flush();
    } finally {
      await writer.close();
    }
    if (copied != totalBytes) throw StateError('Incomplete update package');

    onProgress?.call(0.63, 'ota_progress_verifying');
    final actualHash = await _sha256Of(localZipFile);
    if (actualHash != packageInfo.sha256!.toLowerCase()) {
      throw StateError('Update package checksum verification failed');
    }

    // 2. Safe Extraction with anti Zip-Slip verification
    onProgress?.call(0.65, 'ota_progress_extracting');
    final extractDir = Directory('${tempBase.path}\\extracted');
    extractDir.createSync(recursive: true);

    final validation = await _runPowerShell("""
\$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
\$zip = [IO.Compression.ZipFile]::OpenRead(${_psLiteral(localZipFile.path)})
try {
  \$entryCount = 0
  [Int64]\$totalLength = 0
  foreach (\$entry in \$zip.Entries) {
    \$entryCount++
    if (\$entryCount -gt $_maxArchiveEntries -or \$entry.Length -gt $_maxArchiveUncompressedBytes) { throw 'Archive exceeds safety limits' }
    \$totalLength += \$entry.Length
    if (\$totalLength -gt $_maxArchiveUncompressedBytes) { throw 'Archive exceeds safety limits' }
    \$parts = \$entry.FullName.Replace('\\', '/').Split('/')
    if (\$entry.FullName -match '^[\\/]' -or \$entry.FullName.Contains(':') -or \$parts -contains '..' -or ((\$entry.ExternalAttributes -shr 16) -band 61440) -eq 40960) { throw 'Unsafe archive entry' }
  }
  [IO.Compression.ZipFileExtensions]::ExtractToDirectory(\$zip, ${_psLiteral(extractDir.path)})
} finally { \$zip.Dispose() }
""");
    if (validation.exitCode != 0) {
      throw StateError('Invalid or unsafe update archive');
    }

    // 3. Locate payload directory (handle nested parent folder)
    onProgress?.call(0.85, 'ota_progress_handoff');
    Directory payloadDir = extractDir;

    final subDirs = extractDir.listSync().whereType<Directory>().toList();
    if (subDirs.length == 1) {
      final testExe = File('${subDirs.first.path}\\ja_remote.exe');
      if (testExe.existsSync()) {
        payloadDir = subDirs.first;
      }
    }

    await _validatePayloadDirectory(payloadDir);

    if (prepareOnly) return payloadDir;

    // 4. Identify running app path
    final currentExe = File(Platform.resolvedExecutable);
    final targetAppDir = currentExe.parent;
    final currentPid = pid;

    // 5. Generate apply_update.bat
    final batFile = File('${tempBase.path}\\apply_update.bat');
    final batContent = generateApplyUpdateScript(
      oldPid: currentPid,
      sourceDir: payloadDir.path,
      targetDir: targetAppDir.path,
      exeName: currentExe.path.split(Platform.pathSeparator).last,
    );
    batFile.writeAsStringSync(batContent);

    onProgress?.call(1.0, 'ota_ready_restart');
    await Future.delayed(const Duration(milliseconds: 600));

    // 6. Launch apply_update.bat detached and exit current process
    if (Platform.isWindows) {
      final launch = await _runPowerShell(
        "Start-Process -FilePath 'cmd.exe' -ArgumentList ${_psLiteral('/c ""${batFile.path}""')} -WindowStyle Hidden",
      );
      if (launch.exitCode != 0) {
        throw StateError('Cannot start update installer');
      }
      exit(0);
    }
    return payloadDir;
  }

  @visibleForTesting
  Future<Directory> validatePackageForTesting(UpdatePackageInfo package) =>
      _performUpdate(package, prepareOnly: true);

  @visibleForTesting
  Future<void> validatePayloadForTesting(Directory payloadDir) =>
      _validatePayloadDirectory(payloadDir);

  static Future<void> _validatePayloadDirectory(Directory payloadDir) async {
    for (final name in ['ja_remote.exe', 'flutter_windows.dll']) {
      if (!await File(
        '${payloadDir.path}${Platform.pathSeparator}$name',
      ).exists()) {
        throw StateError('Incomplete Flutter update package: $name');
      }
    }
    if (!await Directory(
      '${payloadDir.path}${Platform.pathSeparator}data',
    ).exists()) {
      throw StateError('Incomplete Flutter update package: data');
    }
  }

  static Future<String> _sha256Of(File file) async {
    final result = await Process.run('certutil', [
      '-hashfile',
      file.path,
      'SHA256',
    ]);
    final output = '${result.stdout}\n${result.stderr}';
    final hash = RegExp(
      r'(?<![A-Fa-f0-9])([A-Fa-f0-9]{64})(?![A-Fa-f0-9])',
    ).firstMatch(output)?.group(1);
    if (result.exitCode != 0 || hash == null) {
      throw StateError('Cannot verify update package checksum');
    }
    return hash.toLowerCase();
  }

  /// Generates the robust Windows updater batch script.
  static String generateApplyUpdateScript({
    required int oldPid,
    required String sourceDir,
    required String targetDir,
    required String exeName,
  }) {
    for (final value in [sourceDir, targetDir, exeName]) {
      if (value.contains(RegExp(r'["%\r\n]'))) {
        throw ArgumentError('Unsupported updater path');
      }
    }
    if (oldPid <= 0 || exeName.contains(RegExp(r'[\\/]'))) {
      throw ArgumentError('Invalid updater target');
    }
    return '''@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title JA Remote - Dang Cap Nhat Phien Ban Moi...

set "OLD_PID=$oldPid"
set "SRC_DIR=$sourceDir"
set "DST_DIR=$targetDir"
set "EXE_NAME=$exeName"
set "BACKUP_DIR=%~dp0backup"
if not exist "%SRC_DIR%\\%EXE_NAME%" exit /b 10
if not exist "%DST_DIR%\\%EXE_NAME%" exit /b 11
set /a WAIT_COUNT=0

echo ========================================================
echo   JA REMOTE - DANG TIEN HANH CAP NHAT
echo ========================================================
echo.
echo [1/3] Dang cho tien trinh cu (PID %OLD_PID%) dong han...

:wait_loop
set /a WAIT_COUNT+=1
if %WAIT_COUNT% GEQ 60 exit /b 12
timeout /t 1 /nobreak >nul
tasklist /fi "PID eq %OLD_PID%" 2>nul | findstr /i "%OLD_PID%" >nul
if not errorlevel 1 goto wait_loop

:: Cho them 1s de Windows giai phong toan bo file handle
timeout /t 1 /nobreak >nul

echo [2/3] Dang ghi de tep ung dung moi...
robocopy "%DST_DIR%" "%BACKUP_DIR%" /E /NP /R:2 /W:1 /XD logs /XF update_config.json config.json credentials.json devices.json >"%~dp0backup.log"
if errorlevel 8 exit /b 13
robocopy "%SRC_DIR%" "%DST_DIR%" /E /IS /IT /NP /R:5 /W:2 /XD logs /XF update_config.json config.json credentials.json devices.json >"%~dp0apply.log"
if errorlevel 8 goto rollback

echo [3/3] Khoi chay ung dung moi...
start "" "%DST_DIR%\\%EXE_NAME%"

timeout /t 2 /nobreak >nul
exit /b 0

:rollback
robocopy "%BACKUP_DIR%" "%DST_DIR%" /E /IS /IT /NP /R:2 /W:1 >"%~dp0rollback.log"
if errorlevel 8 exit /b 14
start "" "%DST_DIR%\\%EXE_NAME%"
exit /b 15
''';
  }
}

import 'dart:async';
import 'dart:convert';
import '../core/process/file_unlock_script.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import '../core/process/process_runner.dart';
import '../core/utils/command_variable_resolver.dart';
import '../data/models/managed_device.dart';
import '../data/repositories/log_repository.dart';

/// Status of deployment for an individual device.
enum DeployStatus {
  idle,
  pending,
  connecting,
  transferring,
  completed,
  failed,
  cancelled,
}

/// Realtime progress and metrics for a device in the deployment queue.
class DeviceDeployProgress {
  final ManagedDevice device;
  final DeployStatus status;
  final int bytesTransferred;
  final int totalBytes;
  final double speedBytesPerSec;
  final String? error;
  final int durationMs;
  final String currentFileName;

  const DeviceDeployProgress({
    required this.device,
    this.status = DeployStatus.idle,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.speedBytesPerSec = 0.0,
    this.error,
    this.durationMs = 0,
    this.currentFileName = '',
  });

  double get percent =>
      totalBytes > 0 ? (bytesTransferred / totalBytes).clamp(0.0, 1.0) : 0.0;

  String get formattedPercent => '${(percent * 100).toStringAsFixed(1)}%';

  String get formattedSpeed {
    if (speedBytesPerSec < 1024) {
      return '${speedBytesPerSec.toStringAsFixed(0)} B/s';
    } else if (speedBytesPerSec < 1024 * 1024) {
      return '${(speedBytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String get formattedProgress {
    return '${formatBytes(bytesTransferred)} / ${formatBytes(totalBytes)}';
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  DeviceDeployProgress copyWith({
    DeployStatus? status,
    int? bytesTransferred,
    int? totalBytes,
    double? speedBytesPerSec,
    String? error,
    int? durationMs,
    String? currentFileName,
  }) {
    return DeviceDeployProgress(
      device: device,
      status: status ?? this.status,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      error: error ?? this.error,
      durationMs: durationMs ?? this.durationMs,
      currentFileName: currentFileName ?? this.currentFileName,
    );
  }
}

/// Configuration options for a batch file deployment job.
class FileDeployJobConfig {
  final String sourcePath;
  final bool isDirectory;
  final String destDir;
  final bool overwrite;
  final bool autoKillIfInUse;
  final bool createDirIfMissing;
  final int maxConcurrency;
  final String? username;
  final String? password;
  final int timeoutSeconds;
  final String? preDeployScript;
  final String? postDeployScript;
  final bool abortOnPreFail;

  const FileDeployJobConfig({
    required this.sourcePath,
    this.isDirectory = false,
    required this.destDir,
    this.overwrite = true,
    this.autoKillIfInUse = true,
    this.createDirIfMissing = true,
    this.maxConcurrency = 4,
    this.username,
    this.password,
    this.timeoutSeconds = 120,
    this.preDeployScript,
    this.postDeployScript,
    this.abortOnPreFail = true,
  });
}

/// Service managing concurrent file deployment to multiple devices with live progress tracking.
class FileDeployService extends ChangeNotifier {
  final Future<File> Function(File, String) _copyFile;
  final LogRepository _logRepo = LogRepository();

  final Future<SSHClient> Function(
    ManagedDevice device,
    String username,
    String password,
    Duration timeout,
  )
  _connectSsh;

  final Future<ProcessExecutionResult> Function(
    String script, {
    String? computerName,
    String? username,
    String? password,
    int timeoutSeconds,
  })
  _runPowerShell;

  FileDeployService({
    Future<File> Function(File, String)? copyFile,
    Future<SSHClient> Function(
      ManagedDevice device,
      String username,
      String password,
      Duration timeout,
    )?
    connectSsh,
    Future<ProcessExecutionResult> Function(
      String script, {
      String? computerName,
      String? username,
      String? password,
      int timeoutSeconds,
    })?
    runPowerShell,
  }) : _copyFile =
           copyFile ?? ((source, destination) => source.copy(destination)),
       _connectSsh = connectSsh ?? _defaultOpenSsh,
       _runPowerShell = runPowerShell ?? ProcessRunner.runPowerShell;

  static Future<SSHClient> _defaultOpenSsh(
    ManagedDevice device,
    String username,
    String password,
    Duration timeout,
  ) async {
    final socket = await SSHSocket.connect(
      device.ip,
      device.sshPort,
      timeout: timeout,
    );
    return SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
    );
  }

  bool _isRunning = false;
  bool _disposed = false;
  bool _abortRequested = false;
  FileDeployJobConfig? _currentConfig;
  final Map<String, DeviceDeployProgress> _progressMap = {};
  int _totalSourceBytes = 0;
  final List<File> _sourceFilesList = [];

  final StreamController<String> _eventController =
      StreamController<String>.broadcast();

  bool get isRunning => _isRunning;
  FileDeployJobConfig? get currentConfig => _currentConfig;
  List<DeviceDeployProgress> get progressList => _progressMap.values.toList();
  Map<String, DeviceDeployProgress> get progressMap =>
      Map.unmodifiable(_progressMap);
  Stream<String> get eventStream => _eventController.stream;

  int get totalDevices => _progressMap.length;
  int get completedCount => _progressMap.values
      .where((p) => p.status == DeployStatus.completed)
      .length;
  int get failedCount =>
      _progressMap.values.where((p) => p.status == DeployStatus.failed).length;
  int get transferringCount => _progressMap.values
      .where((p) => p.status == DeployStatus.transferring)
      .length;
  int get pendingCount =>
      _progressMap.values.where((p) => p.status == DeployStatus.pending).length;

  int get totalBytesTransferred =>
      _progressMap.values.fold(0, (sum, p) => sum + p.bytesTransferred);

  double get overallPercent {
    if (_progressMap.isEmpty || _totalSourceBytes == 0) return 0.0;
    final totalExpected = _totalSourceBytes * _progressMap.length;
    if (totalExpected <= 0) return 0.0;
    return (totalBytesTransferred / totalExpected).clamp(0.0, 1.0);
  }

  double get totalSpeedBytesPerSec => _progressMap.values
      .where((p) => p.status == DeployStatus.transferring)
      .fold(0.0, (sum, p) => sum + p.speedBytesPerSec);

  void _log(String message) {
    if (_disposed) return;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _eventController.add('[$timeStr] $message');
  }

  /// Calculates total size and scans files for the source path.
  Future<void> _scanSource(FileDeployJobConfig config) async {
    _sourceFilesList.clear();
    _totalSourceBytes = 0;

    final sourcePath = config.sourcePath.trim();
    if (sourcePath.isEmpty) {
      throw ArgumentError('Source path cannot be empty');
    }

    if (config.isDirectory) {
      final dir = Directory(sourcePath);
      if (!await dir.exists()) {
        throw FileSystemException('Thư mục nguồn không tồn tại', sourcePath);
      }
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          _sourceFilesList.add(entity);
          _totalSourceBytes += await entity.length();
        }
      }
    } else {
      final file = File(sourcePath);
      if (!await file.exists()) {
        throw FileSystemException('File nguồn không tồn tại', sourcePath);
      }
      _sourceFilesList.add(file);
      _totalSourceBytes = await file.length();
    }
  }

  /// Starts deploying the file/folder to target devices with concurrency worker pool.
  Future<void> startDeploy({
    required List<ManagedDevice> targets,
    required FileDeployJobConfig config,
  }) async {
    if (_disposed) throw StateError('FileDeployService is disposed');
    if (_isRunning) {
      throw StateError('A deployment job is already running');
    }
    if (targets.isEmpty) {
      throw ArgumentError('No target devices selected');
    }

    final jobTargets = List<ManagedDevice>.of(targets);
    _isRunning = true;
    _abortRequested = false;
    _currentConfig = config;
    _progressMap.clear();

    try {
      _log('Preparing source: ${p.basename(config.sourcePath)}...');
      await _scanSource(config);
      _log(
        'Source ready: ${_sourceFilesList.length} file(s), total size: ${DeviceDeployProgress.formatBytes(_totalSourceBytes)}',
      );

      for (final target in jobTargets) {
        _progressMap[target.id] = DeviceDeployProgress(
          device: target,
          status: DeployStatus.pending,
          totalBytes: _totalSourceBytes,
        );
      }
      notifyListeners();

      await _executePool(jobTargets, config);
    } catch (e, stack) {
      _log('Deploy initialization error: $e');
      debugPrint('Deploy Error: $e\n$stack');
    } finally {
      _isRunning = false;
      notifyListeners();
      _log('Deployment session finished.');
    }
  }

  /// Retries deployment only on devices that failed or were cancelled.
  Future<void> retryFailed({required FileDeployJobConfig config}) async {
    if (_isRunning) return;
    final failedTargets = _progressMap.values
        .where(
          (p) =>
              p.status == DeployStatus.failed ||
              p.status == DeployStatus.cancelled,
        )
        .map((p) => p.device)
        .toList();

    if (failedTargets.isEmpty) return;

    _isRunning = true;
    _abortRequested = false;
    _currentConfig = config;

    for (final target in failedTargets) {
      _progressMap[target.id] = DeviceDeployProgress(
        device: target,
        status: DeployStatus.pending,
        totalBytes: _totalSourceBytes,
      );
    }
    notifyListeners();

    try {
      _log('Retrying ${failedTargets.length} failed target(s)...');
      await _executePool(failedTargets, config);
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Retries a single specific device.
  Future<void> retrySingle(
    String deviceId, {
    required FileDeployJobConfig config,
  }) async {
    if (_isRunning) return;
    final prog = _progressMap[deviceId];
    if (prog == null) return;

    _isRunning = true;
    _abortRequested = false;
    _currentConfig = config;

    _progressMap[deviceId] = DeviceDeployProgress(
      device: prog.device,
      status: DeployStatus.pending,
      totalBytes: _totalSourceBytes,
    );
    notifyListeners();

    try {
      _log('Retrying [${prog.device.name} - ${prog.device.ip}]...');
      await _executePool([prog.device], config);
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// Requests aborting the current running deployment.
  void abort() {
    if (!_isRunning) return;
    _abortRequested = true;
    _log('Abort requested by user...');
    for (final entry in _progressMap.entries) {
      if (entry.value.status == DeployStatus.pending ||
          entry.value.status == DeployStatus.connecting ||
          entry.value.status == DeployStatus.transferring) {
        _progressMap[entry.key] = entry.value.copyWith(
          status: DeployStatus.cancelled,
          error: 'Cancelled by user',
        );
      }
    }
    notifyListeners();
  }

  /// Worker pool queue execution with concurrency limit.
  Future<void> _executePool(
    List<ManagedDevice> targets,
    FileDeployJobConfig config,
  ) async {
    final queue = List<ManagedDevice>.from(targets);
    final concurrency = math.max(
      1,
      math.min(config.maxConcurrency, targets.length),
    );
    final activeFutures = <Future<void>>[];

    while (queue.isNotEmpty || activeFutures.isNotEmpty) {
      if (_abortRequested) {
        // Do not allow another job to reuse shared state until active copies end.
        await Future.wait(activeFutures);
        break;
      }

      while (queue.isNotEmpty && activeFutures.length < concurrency) {
        final target = queue.removeAt(0);
        final future = _deployToDevice(target, config);
        activeFutures.add(future);

        // Remove from activeFutures when completed
        future.whenComplete(() {
          activeFutures.remove(future);
        });
      }

      if (activeFutures.isNotEmpty) {
        await Future.any(activeFutures);
      }
    }
  }

  /// Dispatches deployment to a single target based on its OS.
  Future<void> _deployToDevice(
    ManagedDevice device,
    FileDeployJobConfig config,
  ) async {
    if (_abortRequested) {
      _updateDeviceProgress(
        device.id,
        status: DeployStatus.cancelled,
        error: 'Cancelled before start',
      );
      return;
    }

    final sw = Stopwatch()..start();
    _updateDeviceProgress(device.id, status: DeployStatus.connecting);
    _log('[${device.ip}] Connecting to ${device.name} (${device.os})...');

    try {
      final isLinux = device.os.toLowerCase() == 'linux';
      final effectiveUser = config.username ?? device.username;
      final effectivePass = config.password ?? device.password;

      // 1. Pre-deploy Hook Execution
      if (config.preDeployScript != null &&
          config.preDeployScript!.trim().isNotEmpty) {
        _log('⚡ [${device.ip}] Executing Pre-deploy hook...');
        final preScript = CommandVariableResolver.resolve(
          config.preDeployScript!,
          device,
          username: effectiveUser,
        );
        try {
          if (isLinux) {
            final client = await _connectSsh(
              device,
              effectiveUser ?? 'root',
              effectivePass ?? '',
              Duration(seconds: 30),
            );
            try {
              final session = await client.execute(preScript);
              await session.done;
              if (session.exitCode != 0 && config.abortOnPreFail) {
                throw Exception(
                  'Pre-deploy hook exited with code ${session.exitCode}',
                );
              }
            } finally {
              client.close();
            }
          } else {
            final isLocal =
                device.ip == '127.0.0.1' ||
                device.ip.toLowerCase() == 'localhost';
            final res = await _runPowerShell(
              preScript,
              computerName: isLocal ? null : device.ip,
              username: effectiveUser,
              password: effectivePass,
              timeoutSeconds: 30,
            );
            if (!res.isSuccess && config.abortOnPreFail) {
              throw Exception('Pre-deploy hook failed: ${res.stderr}');
            }
          }
        } catch (e) {
          if (config.abortOnPreFail) {
            rethrow;
          } else {
            _log('⚠️ [${device.ip}] Pre-deploy hook warning (ignored): $e');
          }
        }
      }

      if (_abortRequested) return;

      // 2. File Transfer
      if (isLinux) {
        await _deployLinuxSftp(device, config, sw);
      } else {
        await _deployWindows(device, config, sw);
      }

      if (_abortRequested) return;

      // 3. Post-deploy Hook Execution
      if (config.postDeployScript != null &&
          config.postDeployScript!.trim().isNotEmpty) {
        _log('⚡ [${device.ip}] Executing Post-deploy hook...');
        final postScript = CommandVariableResolver.resolve(
          config.postDeployScript!,
          device,
          username: effectiveUser,
        );
        try {
          if (isLinux) {
            final client = await _connectSsh(
              device,
              effectiveUser ?? 'root',
              effectivePass ?? '',
              Duration(seconds: 30),
            );
            try {
              final session = await client.execute(postScript);
              await session.done;
            } finally {
              client.close();
            }
          } else {
            final isLocal =
                device.ip == '127.0.0.1' ||
                device.ip.toLowerCase() == 'localhost';
            await _runPowerShell(
              postScript,
              computerName: isLocal ? null : device.ip,
              username: effectiveUser,
              password: effectivePass,
              timeoutSeconds: 30,
            );
          }
        } catch (e) {
          _log('⚠️ [${device.ip}] Post-deploy hook warning: $e');
        }
      }

      if (_abortRequested) return;
      sw.stop();
      _updateDeviceProgress(
        device.id,
        status: DeployStatus.completed,
        bytesTransferred: _totalSourceBytes,
        speedBytesPerSec: 0.0,
        durationMs: sw.elapsedMilliseconds,
      );
      _log('✅ [${device.ip}] Deploy success (${sw.elapsedMilliseconds}ms)');

      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'FILE_DEPLOY',
        status: 'SUCCESS',
        message:
            'Transferred ${p.basename(config.sourcePath)} (${DeviceDeployProgress.formatBytes(_totalSourceBytes)}) in ${sw.elapsedMilliseconds}ms',
      );
    } catch (e) {
      if (_abortRequested) return;
      sw.stop();
      final errStr = e.toString().replaceAll('Exception: ', '');
      _updateDeviceProgress(
        device.id,
        status: DeployStatus.failed,
        error: errStr,
        speedBytesPerSec: 0.0,
        durationMs: sw.elapsedMilliseconds,
      );
      _log('❌ [${device.ip}] Failed: $errStr');

      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'FILE_DEPLOY',
        status: 'FAILED',
        message: 'File deploy error: $errStr',
      );
    } finally {
      notifyListeners();
    }
  }

  /// Deploys files to a Linux target via SSH / SFTP.
  Future<void> _deployLinuxSftp(
    ManagedDevice device,
    FileDeployJobConfig config,
    Stopwatch sw,
  ) async {
    final username = config.username ?? device.username ?? 'root';
    final password = config.password ?? '';
    final timeout = Duration(seconds: config.timeoutSeconds);

    final client = await _connectSsh(device, username, password, timeout);
    SftpClient? sftp;
    try {
      sftp = await client.sftp();

      // Normalize remote destination directory
      String remoteDestDir = config.destDir.trim().replaceAll('\\', '/');
      if (!remoteDestDir.endsWith('/')) remoteDestDir += '/';

      if (config.createDirIfMissing) {
        await _ensureRemoteDirSftp(sftp, remoteDestDir);
      }

      int cumulativeBytes = 0;
      var lastReportTime = DateTime.now();
      var lastReportBytes = 0;

      final sourceRoot = config.isDirectory
          ? config.sourcePath
          : p.dirname(config.sourcePath);

      for (final localFile in _sourceFilesList) {
        if (_abortRequested) {
          throw Exception('Bị hủy bởi người dùng');
        }

        final relPath = p.relative(localFile.path, from: sourceRoot);
        final remoteFilePath = p.posix.join(
          remoteDestDir,
          relPath.replaceAll('\\', '/'),
        );
        final remoteParentDir = p.posix.dirname(remoteFilePath);

        if (config.createDirIfMissing) {
          await _ensureRemoteDirSftp(sftp, remoteParentDir);
        }

        _updateDeviceProgress(
          device.id,
          status: DeployStatus.transferring,
          currentFileName: p.basename(localFile.path),
        );

        final mode =
            SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            (config.overwrite
                ? SftpFileOpenMode.truncate
                : SftpFileOpenMode.exclusive);
        SftpFile sftpFile;
        try {
          sftpFile = await sftp.open(remoteFilePath, mode: mode);
        } on SftpStatusError {
          if (!config.overwrite || !config.autoKillIfInUse) rethrow;
          final quoted = "'${remoteFilePath.replaceAll("'", "'\\''")}'";
          final session = await client.execute('fuser -k -TERM -- $quoted');
          final output = await Future.wait([
            utf8.decoder.bind(session.stdout).join(),
            utf8.decoder.bind(session.stderr).join(),
          ]).timeout(timeout);
          await session.done.timeout(timeout);
          if (session.exitCode != 0) {
            throw StateError(
              'Cannot unlock $remoteFilePath: ${output.join(' ')}',
            );
          }
          _log(
            '[${device.ip}] AUTO_KILL FILE=$remoteFilePath ${output.join(' ').trim()}',
          );
          await Future<void>.delayed(const Duration(milliseconds: 250));
          sftpFile = await sftp.open(remoteFilePath, mode: mode);
        }

        try {
          final fileStream = localFile.openRead().map(
            (chunk) => Uint8List.fromList(chunk),
          );
          final writer = sftpFile.write(
            fileStream,
            onProgress: (fileBytesWritten) {
              final totalDone = cumulativeBytes + fileBytesWritten;
              final now = DateTime.now();
              final elapsedSec =
                  now.difference(lastReportTime).inMilliseconds / 1000.0;

              double speed = 0.0;
              if (elapsedSec >= 0.3) {
                final diffBytes = totalDone - lastReportBytes;
                speed = diffBytes / elapsedSec;
                lastReportTime = now;
                lastReportBytes = totalDone;
              }

              _updateDeviceProgress(
                device.id,
                status: DeployStatus.transferring,
                bytesTransferred: totalDone,
                speedBytesPerSec: speed > 0 ? speed : null,
                currentFileName: p.basename(localFile.path),
              );
            },
          );
          await writer.done;
          cumulativeBytes += await localFile.length();
        } finally {
          await sftpFile.close();
        }
      }
    } finally {
      await sftp?.close();
      client.close();
    }
  }

  /// Ensures that all path components exist remotely via SFTP.
  Future<void> _ensureRemoteDirSftp(SftpClient sftp, String remotePath) async {
    final parts = remotePath.split('/').where((p) => p.isNotEmpty).toList();
    var current = remotePath.startsWith('/') ? '' : '.';
    for (final part in parts) {
      current += '/$part';
      try {
        await sftp.mkdir(current);
      } catch (_) {
        // Directory may already exist, ignore SftpStatusError
      }
    }
  }

  /// Deploys files to a Windows target via WinRM PSSession Copy-Item or local copy.
  Future<void> _deployWindows(
    ManagedDevice device,
    FileDeployJobConfig config,
    Stopwatch sw,
  ) async {
    final isLocal =
        device.ip == '127.0.0.1' || device.ip.toLowerCase() == 'localhost';

    if (isLocal) {
      // Local deployment
      await _copyLocalFiles(config, device.id);
      return;
    }

    _updateDeviceProgress(
      device.id,
      status: DeployStatus.transferring,
      currentFileName: p.basename(config.sourcePath),
    );

    final sourceRoot = config.isDirectory
        ? config.sourcePath
        : p.dirname(config.sourcePath);
    final items = <Map<String, String>>[];
    for (final file in _sourceFilesList) {
      final rel = p.relative(file.path, from: sourceRoot);
      if (p.split(rel).contains('..') ||
          rel.contains(':') ||
          p.isAbsolute(rel)) {
        throw ArgumentError('Invalid relative path in deploy source: $rel');
      }
      final sourceHandle = await file.open();
      await sourceHandle.close();
      items.add({'source': file.absolute.path, 'relative': rel});
    }
    String encoded(String value) => base64Encode(utf8.encode(value));
    final values = {
      'items': items,
      'dest': config.destDir,
      'host': device.ip,
      'user': config.username ?? device.username ?? '',
      'password': config.password ?? '',
      'overwrite': config.overwrite,
      'create': config.createDirIfMissing,
      'kill': config.overwrite && config.autoKillIfInUse,
    };
    final payload = encoded(jsonEncode(values));
    final unlock = encoded(fileUnlockScript);
    final script =
        "\$payload = '$payload'\n\$unlock = '$unlock'\n"
        r'''
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$cfg = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
$unlockText = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($unlock))

function Is-SharingViolation($err) {
  if (!$err) { return $false }
  $ex = $err.Exception
  while ($ex) {
    if ($ex -is [System.IO.IOException]) {
      $hr = $ex.HResult
      if ($hr -eq -2147024864 -or $hr -eq -2147024863) { return $true }
      if ($ex.NativeErrorCode -eq 32 -or $ex.NativeErrorCode -eq 33) { return $true }
    }
    $ex = $ex.InnerException
  }
  return $false
}

$session = $null
$cred = $null
if ($cfg.user) {
  $secure = ConvertTo-SecureString $cfg.password -AsPlainText -Force
  $cred = New-Object Management.Automation.PSCredential($cfg.user, $secure)
}
try {
  $argsSession = @{ ComputerName = $cfg.host; ErrorAction = 'Stop' }
  if ($cred) { $argsSession.Credential = $cred }
  $session = New-PSSession @argsSession
} catch {
  Write-Output "WinRM unavailable; using SMB. Auto-kill needs WinRM on the target."
}
$driveName = 'JADeploy' + [Guid]::NewGuid().ToString('N')
$mapped = $false
try {
  if (!$session) {
    if ($cfg.dest -notmatch '^([A-Za-z]):\\(.*)$') { throw 'SMB requires an absolute Windows drive path' }
    $root = '\\' + $cfg.host + '\' + $matches[1] + '$'
    $sub = $matches[2]
    $mapping = @{ Name=$driveName; PSProvider='FileSystem'; Root=$root; ErrorAction='Stop' }
    if ($cred) { $mapping.Credential = $cred }
    New-PSDrive @mapping | Out-Null
    $mapped = $true
    $smbDest = Join-Path ($driveName + ':\') $sub
  }

  # Validate all target paths on their owning machine before killing any holder.
  $validateManifest = {
    param($base, $items, $overwrite, $create)
    if ($base -notmatch '^(?:[A-Za-z]:\\|\\\\[^\\]+\\[^\\]+)') { throw 'Destination must be absolute' }
    $rootPath = [IO.Path]::GetFullPath($base).TrimEnd('\') + '\'
    $seen = @{}
    foreach ($item in $items) {
      $relative = [string]$item.relative
      if ([IO.Path]::IsPathRooted($relative) -or $relative.Contains(':') -or ($relative -split '[\\/]' -contains '..')) { throw 'Invalid relative destination' }
      $path = [IO.Path]::GetFullPath((Join-Path $base $relative))
      if (!$path.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)) { throw 'Destination escapes selected directory' }
      if ($seen.ContainsKey($path)) { throw "Duplicate destination: $path" }
      $seen[$path] = $true
      $ancestor = $path
      while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
          $entry = Get-Item -LiteralPath $ancestor -Force -ErrorAction Stop
          if (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Destination traverses a reparse point: $ancestor" }
        }
        $parent = [IO.Path]::GetDirectoryName($ancestor)
        if ($parent -eq $ancestor) { break }
        $ancestor = $parent
      }
      if (Test-Path -LiteralPath $path) {
        if (!$overwrite) { throw "Destination already exists: $path" }
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Destination is not a file: $path" }
      }
      if (!$create -and !(Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($path)) -PathType Container)) { throw "Destination directory missing: $path" }
    }
  }
  if ($session) {
    Invoke-Command -Session $session -ScriptBlock $validateManifest -ArgumentList $cfg.dest, $cfg.items, $cfg.overwrite, $cfg.create
  } else {
    & $validateManifest (Join-Path $root $sub) $cfg.items $cfg.overwrite $cfg.create
  }

  # Preflight manifest unlock for WinRM when auto-kill is enabled
  if ($session -and $cfg.kill) {
    $manifestDestFiles = @($cfg.items | ForEach-Object { Join-Path $cfg.dest $_.relative })
    Invoke-Command -Session $session -ScriptBlock {
      param($files, $text)
      . ([ScriptBlock]::Create($text))
      Unlock-DeployManifest $files
    } -ArgumentList $manifestDestFiles, $unlockText
  }

  $prepare = {
    param($dest, $backup, $overwrite, $create, $kill, $text)
    $parent = Split-Path -LiteralPath $dest
    if (!(Test-Path -LiteralPath $parent -PathType Container)) {
      if (!$create) { throw "Destination directory missing: $parent" }
      [IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    if (Test-Path -LiteralPath $dest) {
      if (!$overwrite) { throw "Destination already exists: $dest" }
      if (!(Test-Path -LiteralPath $dest -PathType Leaf)) { throw 'Destination is not a file' }
      try {
        [IO.File]::Move($dest, $backup)
      } catch {
        if (!$kill) { throw }
        . ([ScriptBlock]::Create($text))
        Unlock-DeployFile $dest
        [IO.File]::Move($dest, $backup)
      }
    }
  }

  $restore = {
    param($dest, $backup)
    $rollbackError = $null
    if (Test-Path -LiteralPath $backup -PathType Leaf) {
      try {
        if (Test-Path -LiteralPath $dest -PathType Leaf) { [IO.File]::Delete($dest) }
        [IO.File]::Move($backup, $dest)
      } catch {
        $rollbackError = "Rollback failed; original retained at ${backup}: $_"
      }
    } else {
      try {
        if (Test-Path -LiteralPath $dest -PathType Leaf) { [IO.File]::Delete($dest) }
      } catch {
        $rollbackError = "Partial cleanup failed at ${dest}: $_"
      }
    }
    if ($rollbackError) { throw $rollbackError }
  }

  foreach ($item in $cfg.items) {
    if ($session) {
      $dest = Join-Path $cfg.dest $item.relative
      $backup = $dest + '.jad_old_' + [Guid]::NewGuid().ToString('N')
      Invoke-Command -Session $session -ScriptBlock $prepare -ArgumentList $dest, $backup, $cfg.overwrite, $cfg.create, $cfg.kill, $unlockText

      $copied = $false
      $copyError = $null
      for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
          Copy-Item -LiteralPath $item.source -Destination $dest -ToSession $session -Force -ErrorAction Stop
          $copied = $true
          break
        } catch {
          $copyError = $_
          if ($attempt -lt 3 -and (Is-SharingViolation $copyError)) {
            Start-Sleep -Milliseconds (300 * $attempt)
          } else {
            break
          }
        }
      }

      if (!$copied) {
        $rbErr = $null
        try {
          Invoke-Command -Session $session -ScriptBlock $restore -ArgumentList $dest, $backup
        } catch {
          $rbErr = $_
        }
        if ($rbErr) {
          throw "Copy failed: $copyError; $rbErr"
        } else {
          throw $copyError
        }
      }

      Invoke-Command -Session $session -ScriptBlock {
        param($backup)
        if (Test-Path -LiteralPath $backup -PathType Leaf) {
          try {
            Remove-Item -LiteralPath $backup -Force -ErrorAction Stop
          } catch {
            Write-Output "WARNING: Backup retained at ${backup} (in use or locked)"
          }
        }
      } -ArgumentList $backup

    } else {
      $dest = Join-Path (Join-Path $root $sub) $item.relative
      $backup = $dest + '.jad_old_' + [Guid]::NewGuid().ToString('N')
      & $prepare $dest $backup $cfg.overwrite $cfg.create $false $unlockText

      $copied = $false
      $copyError = $null
      for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
          Copy-Item -LiteralPath $item.source -Destination $dest -Force -ErrorAction Stop
          $copied = $true
          break
        } catch {
          $copyError = $_
          if ($attempt -lt 3 -and (Is-SharingViolation $copyError)) {
            Start-Sleep -Milliseconds (300 * $attempt)
          } else {
            break
          }
        }
      }

      if (!$copied) {
        $rbErr = $null
        try {
          & $restore $dest $backup
        } catch {
          $rbErr = $_
        }
        if ($rbErr) {
          throw "Copy failed: $copyError; $rbErr"
        } else {
          throw $copyError
        }
      }

      if (Test-Path -LiteralPath $backup -PathType Leaf) {
        try {
          Remove-Item -LiteralPath $backup -Force -ErrorAction Stop
        } catch {
          Write-Output "WARNING: Backup retained at ${backup} (in use or locked)"
        }
      }
    }
  }
  Write-Output 'DEPLOY_SUCCESS'
} finally {
  if ($session) { Remove-PSSession -Session $session -ErrorAction SilentlyContinue }
  if ($mapped) { Remove-PSDrive -Name $driveName -ErrorAction SilentlyContinue }
}
''';
    final res = await _runPowerShell(
      script,
      timeoutSeconds: config.timeoutSeconds,
    );
    for (final line in const LineSplitter().convert(res.stdout)) {
      if (line.startsWith('AUTO_KILL ') ||
          line.startsWith('WARNING: ') ||
          line.startsWith('WinRM unavailable')) {
        _log('[${device.ip}] $line');
      }
    }
    if (!res.isSuccess || !res.stdout.contains('DEPLOY_SUCCESS')) {
      throw Exception(
        res.stderr.trim().isNotEmpty
            ? res.stderr.trim()
            : 'Remote copy failed: ${res.stdout}',
      );
    }
  }

  /// Copies files directly if the target is local machine.
  Future<void> _copyLocalFiles(
    FileDeployJobConfig config,
    String deviceId,
  ) async {
    final destDir = Directory(config.destDir);
    if (!await destDir.exists()) {
      if (!config.createDirIfMissing) {
        throw FileSystemException(
          'Destination directory missing',
          destDir.path,
        );
      }
    }

    int bytesDone = 0;
    final sourceRoot = config.isDirectory
        ? config.sourcePath
        : p.dirname(config.sourcePath);

    // Validate the entire manifest before any process may be terminated.
    final destinations = <String>{};
    for (final file in _sourceFilesList) {
      final rel = p.relative(file.path, from: sourceRoot);
      if (p.split(rel).contains('..') ||
          rel.contains(':') ||
          p.isAbsolute(rel)) {
        throw ArgumentError('Invalid relative path in deploy source: $rel');
      }
      final destination = p.normalize(p.absolute(p.join(destDir.path, rel)));
      if (p.equals(p.normalize(file.absolute.path), destination)) {
        throw ArgumentError('Source and destination must be different');
      }
      if (!destinations.add(
        Platform.isWindows ? destination.toLowerCase() : destination,
      )) {
        throw ArgumentError('Duplicate destination: $destination');
      }
      var ancestor = destination;
      while (true) {
        if (await FileSystemEntity.type(ancestor, followLinks: false) ==
            FileSystemEntityType.link) {
          throw FileSystemException('Destination traverses a link', ancestor);
        }
        final parent = p.dirname(ancestor);
        if (parent == ancestor) break;
        ancestor = parent;
      }
      final type = await FileSystemEntity.type(destination, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw FileSystemException('Destination is not a file', destination);
      }
      if (!config.overwrite && type == FileSystemEntityType.file) {
        throw FileSystemException('Destination already exists', destination);
      }
      if (!config.createDirIfMissing &&
          !await Directory(p.dirname(destination)).exists()) {
        throw FileSystemException(
          'Destination directory missing',
          p.dirname(destination),
        );
      }
      final handle = await file.open();
      await handle.close();
    }
    if (_abortRequested) throw Exception('Deployment cancelled');
    if (!await destDir.exists()) await destDir.create(recursive: true);

    // Preflight manifest unlock for local Windows
    if (config.overwrite && config.autoKillIfInUse && Platform.isWindows) {
      final existingDestFiles = <String>[];
      for (final file in _sourceFilesList) {
        final rel = p.relative(file.path, from: sourceRoot);
        final destFile = File(p.join(destDir.path, rel));
        if (await destFile.exists()) {
          existingDestFiles.add(destFile.path);
        }
      }
      if (existingDestFiles.isNotEmpty) {
        await _killLocalLockedProcessesForManifest(existingDestFiles, deviceId);
      }
    }

    for (final file in _sourceFilesList) {
      if (_abortRequested) throw Exception('Bị hủy bởi người dùng');
      final rel = p.relative(file.path, from: sourceRoot);
      if (p.split(rel).contains('..') ||
          rel.contains(':') ||
          p.isAbsolute(rel)) {
        throw ArgumentError('Invalid relative path in deploy source: $rel');
      }
      final destFile = File(p.join(destDir.path, rel));
      if (!await destFile.parent.exists()) {
        if (!config.createDirIfMissing) {
          throw FileSystemException(
            'Destination directory missing',
            destFile.parent.path,
          );
        }
        await destFile.parent.create(recursive: true);
      }
      if (p.equals(
        p.normalize(file.absolute.path),
        p.normalize(destFile.absolute.path),
      )) {
        throw ArgumentError('Source and destination must be different');
      }
      if (!config.overwrite && await destFile.exists()) {
        throw FileSystemException('Destination already exists', destFile.path);
      }
      final backup = File(
        '${destFile.path}.jad_old_${DateTime.now().microsecondsSinceEpoch}',
      );
      var backedUp = false;
      if (await destFile.exists()) {
        try {
          await destFile.rename(backup.path);
        } on FileSystemException {
          if (!config.overwrite ||
              !config.autoKillIfInUse ||
              !Platform.isWindows) {
            rethrow;
          }
          await _killLocalLockedProcesses(destFile.path, deviceId);
          await destFile.rename(backup.path);
        }
        backedUp = true;
      }

      var copied = false;
      Object? lastCopyError;
      for (var attempt = 1; attempt <= 3; attempt++) {
        if (_abortRequested) {
          lastCopyError = StateError('Deployment cancelled');
          break;
        }
        try {
          await _copyFile(file, destFile.path);
          copied = true;
          break;
        } catch (error) {
          lastCopyError = error;
          final isSharingViolation =
              error is FileSystemException &&
              (error.osError?.errorCode == 32 ||
                  error.osError?.errorCode == 33);
          if (attempt < 3 && isSharingViolation) {
            await Future.delayed(Duration(milliseconds: 300 * attempt));
          } else {
            break;
          }
        }
      }

      if (!copied) {
        if (backedUp) {
          try {
            if (await destFile.exists()) await destFile.delete();
            await backup.rename(destFile.path);
          } catch (rollbackError) {
            throw FileSystemException(
              'Copy failed: $lastCopyError; rollback failed: $rollbackError; original retained',
              backup.path,
            );
          }
        } else {
          try {
            if (await destFile.exists()) await destFile.delete();
          } catch (cleanupError) {
            throw FileSystemException(
              'Copy failed: $lastCopyError; partial cleanup failed: $cleanupError',
              destFile.path,
            );
          }
        }
        if (lastCopyError is Exception) throw lastCopyError;
        throw Exception('Copy failed: $lastCopyError');
      }

      if (backedUp) {
        try {
          await backup.delete();
        } catch (e) {
          _log('[$deviceId] WARNING: Backup retained at ${backup.path}: $e');
        }
      }
      bytesDone += await file.length();
      _updateDeviceProgress(
        deviceId,
        status: DeployStatus.transferring,
        bytesTransferred: bytesDone,
        currentFileName: p.basename(file.path),
      );
    }
  }

  Future<void> _killLocalLockedProcessesForManifest(
    List<String> targetFiles,
    String deviceId,
  ) async {
    final psList = targetFiles
        .map((f) => "'${f.replaceAll("'", "''")}'")
        .join(', ');
    final result = await _runPowerShell(
      "\$ErrorActionPreference = 'Stop'\n$fileUnlockScript\nUnlock-DeployManifest @($psList)",
      timeoutSeconds: 30,
    );
    for (final line in const LineSplitter().convert(result.stdout)) {
      if (line.startsWith('AUTO_KILL ')) _log('[$deviceId] $line');
    }
    if (!result.isSuccess) {
      throw Exception('Unlock manifest failed: ${result.stderr}');
    }
  }

  Future<void> _killLocalLockedProcesses(
    String targetFile,
    String deviceId,
  ) async {
    final safeFile = targetFile.replaceAll("'", "''");
    final result = await _runPowerShell(
      "\$ErrorActionPreference = 'Stop'\n$fileUnlockScript\nUnlock-DeployFile '$safeFile'",
      timeoutSeconds: 15,
    );
    for (final line in const LineSplitter().convert(result.stdout)) {
      if (line.startsWith('AUTO_KILL ')) _log('[$deviceId] $line');
    }
    if (!result.isSuccess) throw Exception('Unlock failed: ${result.stderr}');
  }

  void _updateDeviceProgress(
    String deviceId, {
    DeployStatus? status,
    int? bytesTransferred,
    double? speedBytesPerSec,
    String? error,
    int? durationMs,
    String? currentFileName,
  }) {
    if (_disposed || _abortRequested) return;
    final current = _progressMap[deviceId];
    if (current == null) return;
    _progressMap[deviceId] = current.copyWith(
      status: status,
      bytesTransferred: bytesTransferred,
      speedBytesPerSec: speedBytesPerSec,
      error: error,
      durationMs: durationMs,
      currentFileName: currentFileName,
    );
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _abortRequested = true;
    _disposed = true;
    _eventController.close();
    super.dispose();
  }
}

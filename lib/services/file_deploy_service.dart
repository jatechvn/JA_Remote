import 'dart:async';
import 'dart:convert';
import '../core/process/file_unlock_script.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:path/path.dart' as p;
import '../core/process/process_runner.dart';
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
      if (isLinux) {
        await _deployLinuxSftp(device, config, sw);
      } else {
        await _deployWindows(device, config, sw);
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
    final items = _sourceFilesList
        .map(
          (file) => {
            'source': file.absolute.path,
            'relative': p.relative(file.path, from: sourceRoot),
          },
        )
        .toList();
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
  foreach ($item in $cfg.items) {
    $dest = Join-Path $cfg.dest $item.relative
    $backup = $dest + '.jad_old_' + [Guid]::NewGuid().ToString('N')
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
        try { [IO.File]::Move($dest, $backup) } catch {
          if (!$kill) { throw }
          . ([ScriptBlock]::Create($text))
          Unlock-DeployFile $dest
          [IO.File]::Move($dest, $backup)
        }
      }
    }
    $restore = {
      param($dest, $backup)
      if (Test-Path -LiteralPath $backup -PathType Leaf) {
        try {
          if (Test-Path -LiteralPath $dest -PathType Leaf) { [IO.File]::Delete($dest) }
          [IO.File]::Move($backup, $dest)
        } catch { throw "Rollback failed; original retained at ${backup}: $_" }
      }
    }
    if ($session) {
      Invoke-Command -Session $session -ScriptBlock $prepare -ArgumentList $dest, $backup, $cfg.overwrite, $cfg.create, $cfg.kill, $unlockText
      try {
        Copy-Item -LiteralPath $item.source -Destination $dest -ToSession $session -Force -ErrorAction Stop
      } catch {
        $copyError = $_
        Invoke-Command -Session $session -ScriptBlock $restore -ArgumentList $dest, $backup
        throw $copyError
      }
      Invoke-Command -Session $session -ScriptBlock {
        param($backup)
        if (Test-Path -LiteralPath $backup -PathType Leaf) { Remove-Item -LiteralPath $backup -ErrorAction SilentlyContinue }
      } -ArgumentList $backup
    } else {
      # Use an actual UNC path for .NET file operations (PSDrive names are PowerShell-only).
      $dest = Join-Path (Join-Path $root $sub) $item.relative
      $backup = $dest + '.jad_old_' + [Guid]::NewGuid().ToString('N')
      & $prepare $dest $backup $cfg.overwrite $cfg.create $false $unlockText
      try {
        Copy-Item -LiteralPath $item.source -Destination $dest -Force -ErrorAction Stop
      } catch {
        $copyError = $_
        & $restore $dest $backup
        throw $copyError
      }
      if (Test-Path -LiteralPath $backup -PathType Leaf) { Remove-Item -LiteralPath $backup -ErrorAction SilentlyContinue }
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
      await destDir.create(recursive: true);
    }

    int bytesDone = 0;
    final sourceRoot = config.isDirectory
        ? config.sourcePath
        : p.dirname(config.sourcePath);

    for (final file in _sourceFilesList) {
      if (_abortRequested) throw Exception('Bị hủy bởi người dùng');
      final rel = p.relative(file.path, from: sourceRoot);
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
      try {
        await _copyFile(file, destFile.path);
      } catch (error) {
        if (backedUp) {
          try {
            if (await destFile.exists()) await destFile.delete();
            await backup.rename(destFile.path);
          } catch (rollbackError) {
            throw FileSystemException(
              'Copy failed: $error; rollback failed: $rollbackError; original retained',
              backup.path,
            );
          }
        }
        rethrow;
      }
      if (backedUp) {
        try {
          await backup.delete();
        } catch (_) {}
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

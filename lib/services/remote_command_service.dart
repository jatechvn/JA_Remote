import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:dartssh2/dartssh2.dart';
import '../core/process/process_runner.dart';
import '../data/models/managed_device.dart';
import '../data/repositories/log_repository.dart';

/// Result of a remote command execution.
class RemoteCommandResult {
  final ManagedDevice device;
  final bool isSuccess;
  final String output;
  final String error;
  final int durationMs;

  const RemoteCommandResult({
    required this.device,
    required this.isSuccess,
    required this.output,
    required this.error,
    required this.durationMs,
  });
}

/// Service managing execution of PowerShell and SSH commands across network PCs.
class RemoteCommandService {
  final LogRepository _logRepo = LogRepository();
  final Future<SSHClient> Function(ManagedDevice, String, String, Duration)
  _connectSsh;

  RemoteCommandService({
    Future<SSHClient> Function(ManagedDevice, String, String, Duration)?
    connectSsh,
  }) : _connectSsh = connectSsh ?? _openSsh;

  static Future<SSHClient> _openSsh(
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

  /// Executes a command on a single device (auto selects PowerShell or SSH based on device.os or override).
  Future<RemoteCommandResult> execute({
    required ManagedDevice device,
    required String command,
    String? typeOverride, // 'powershell' or 'ssh'
    String? username,
    String? password,
    int timeoutSeconds = 15,
  }) async {
    if (timeoutSeconds < 1) {
      throw ArgumentError.value(
        timeoutSeconds,
        'timeoutSeconds',
        'Must be positive',
      );
    }
    final sw = Stopwatch()..start();
    final type =
        typeOverride ??
        (device.os.toLowerCase() == 'linux' ? 'ssh' : 'powershell');

    if (type == 'ssh') {
      return _executeSsh(
        device: device,
        command: command,
        username: username ?? device.username ?? 'root',
        password: password ?? '',
        timeoutSeconds: timeoutSeconds,
        sw: sw,
      );
    } else {
      return _executePowerShell(
        device: device,
        command: command,
        username: username ?? device.username,
        password: password,
        timeoutSeconds: timeoutSeconds,
        sw: sw,
      );
    }
  }

  Future<RemoteCommandResult> _executePowerShell({
    required ManagedDevice device,
    required String command,
    String? username,
    String? password,
    required int timeoutSeconds,
    required Stopwatch sw,
  }) async {
    // If device is localhost/127.0.0.1, run locally without -ComputerName
    final isLocal =
        device.ip == '127.0.0.1' || device.ip.toLowerCase() == 'localhost';
    final targetComputer = isLocal ? null : device.ip;

    final res = await ProcessRunner.runPowerShell(
      command,
      computerName: targetComputer,
      username: username,
      password: password,
      timeoutSeconds: timeoutSeconds,
    );

    sw.stop();
    final ok = res.isSuccess;

    // Smart Error Diagnostic for Windows network / WinRM
    String formattedError = res.stderr;
    if (!ok && formattedError.isNotEmpty) {
      if (formattedError.contains('Access is denied') ||
          formattedError.contains('AccessDenied') ||
          formattedError.contains('PSRemotingTransportException')) {
        formattedError +=
            '\n\n💡 [HƯỚNG DẪN KHẮC PHỤC LỖI WINRM ACCESS DENIED]:'
            '\n  1. Cần nhập Tài khoản (Username) & Mật khẩu (Password) của máy đích bên cột trái.'
            '\n  2. Nếu máy đích thuộc Workgroup (chưa vào Domain), cần cấp quyền quản trị từ xa bằng cách mở PowerShell (Run as Administrator) trên máy đích (${device.ip}) và chạy lệnh:'
            '\n     Enable-PSRemoting -Force'
            '\n     Set-ItemProperty -Path "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System" -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord'
            '\n     Restart-Service WinRM';
      } else if (formattedError.contains('TrustedHosts')) {
        formattedError +=
            '\n\n💡 [HƯỚNG DẪN KHẮC PHỤC LỖI TRUSTEDHOSTS]:'
            '\n  Máy điều khiển chưa bật danh sách máy tin cậy để kết nối IP. Mở PowerShell Administrator trên máy này và chạy:'
            '\n     Set-Item WSMan:\\localhost\\Client\\TrustedHosts -Value * -Force';
      }
    }

    _logRepo.addLog(
      deviceName: device.name,
      deviceIp: device.ip,
      action: 'POWERSHELL',
      status: ok ? 'SUCCESS' : 'FAILED',
      message: ok
          ? 'Thực thi thành công (${sw.elapsedMilliseconds}ms)'
          : formattedError,
    );

    return RemoteCommandResult(
      device: device,
      isSuccess: ok,
      output: res.stdout,
      error: formattedError,
      durationMs: sw.elapsedMilliseconds,
    );
  }

  Future<RemoteCommandResult> _executeSsh({
    required ManagedDevice device,
    required String command,
    required String username,
    required String password,
    required int timeoutSeconds,
    required Stopwatch sw,
  }) async {
    SSHClient? client;
    var finished = false;
    final timeout = Duration(seconds: timeoutSeconds);
    try {
      final result = await (() async {
        final connected = await _connectSsh(
          device,
          username,
          password,
          timeout,
        );
        if (finished) {
          connected.close();
          throw TimeoutException(
            'SSH connection completed after deadline',
            timeout,
          );
        }
        client = connected;
        final session = await connected.execute(command);
        // Drain both channels concurrently, and wait for exit metadata.
        final output = await Future.wait<String>([
          utf8.decodeStream(session.stdout),
          utf8.decodeStream(session.stderr),
          session.done.then((_) => ''),
        ]);
        return (
          output: output[0],
          error: output[1],
          code: session.exitCode,
          signaled: session.exitSignal != null,
        );
      })().timeout(timeout);
      sw.stop();
      final ok = result.code == 0 && !result.signaled;
      final stderr = !ok && result.error.isEmpty
          ? 'SSH command failed (exit code: ${result.code ?? 'unavailable'}).'
          : result.error;
      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'SSH',
        status: ok ? 'SUCCESS' : 'FAILED',
        message: ok ? 'Thực thi lệnh SSH thành công' : stderr,
      );

      return RemoteCommandResult(
        device: device,
        isSuccess: ok,
        output: result.output,
        error: stderr,
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      _logRepo.addLog(
        deviceName: device.name,
        deviceIp: device.ip,
        action: 'SSH',
        status: 'FAILED',
        message: 'Lỗi kết nối SSH: $e',
      );
      return RemoteCommandResult(
        device: device,
        isSuccess: false,
        output: '',
        error: 'SSH Error: $e',
        durationMs: sw.elapsedMilliseconds,
      );
    } finally {
      finished = true;
      client?.close();
      sw.stop();
    }
  }

  /// Batch executes a command across multiple devices with controlled concurrency.
  /// Automatically runs high-concurrency multi-workers when >= 10 devices.
  Future<List<RemoteCommandResult>> executeBatch({
    required List<ManagedDevice> devices,
    required String command,
    String? typeOverride,
    String? username,
    String? password,
    int? maxConcurrent,
    Function(int completed, int total, RemoteCommandResult result)? onProgress,
  }) async {
    if (maxConcurrent != null && maxConcurrent < 1) {
      throw ArgumentError.value(
        maxConcurrent,
        'maxConcurrent',
        'Must be positive',
      );
    }
    final targets = List<ManagedDevice>.of(devices);
    final total = targets.length;
    if (total == 0) return [];
    final concurrency = math.min(
      maxConcurrent ?? (total >= 10 ? 30 : total),
      total,
    );
    final results = <RemoteCommandResult>[];
    var next = 0;
    Object? progressError;
    StackTrace? progressStack;

    Future<void> worker() async {
      while (next < total) {
        final device = targets[next++];
        final watch = Stopwatch()..start();
        RemoteCommandResult result;
        try {
          result = await execute(
            device: device,
            command: command,
            typeOverride: typeOverride,
            username: username,
            password: password,
          );
        } catch (error) {
          result = RemoteCommandResult(
            device: device,
            isSuccess: false,
            output: '',
            error: 'Command execution failed: $error',
            durationMs: watch.elapsedMilliseconds,
          );
        }
        results.add(result);
        try {
          onProgress?.call(results.length, total, result);
        } catch (error, stack) {
          progressError ??= error;
          progressStack ??= stack;
        }
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
    if (progressError != null) {
      Error.throwWithStackTrace(progressError!, progressStack!);
    }
    return results;
  }
}

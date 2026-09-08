import 'dart:async';
import 'dart:convert';
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

  /// Executes a command on a single device (auto selects PowerShell or SSH based on device.os or override).
  Future<RemoteCommandResult> execute({
    required ManagedDevice device,
    required String command,
    String? typeOverride, // 'powershell' or 'ssh'
    String? username,
    String? password,
    int timeoutSeconds = 15,
  }) async {
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
    try {
      final socket = await SSHSocket.connect(
        device.ip,
        device.sshPort,
        timeout: Duration(seconds: timeoutSeconds),
      );

      final client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
      );

      final session = await client.execute(command);
      final stdout = await utf8.decodeStream(session.stdout);
      final stderr = await utf8.decodeStream(session.stderr);

      client.close();
      await client.done;
      sw.stop();

      final ok = stderr.isEmpty;
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
        output: stdout,
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
    }
  }

  /// Batch executes a command across multiple devices with controlled concurrency.
  Future<List<RemoteCommandResult>> executeBatch({
    required List<ManagedDevice> devices,
    required String command,
    String? typeOverride,
    String? username,
    String? password,
    int maxConcurrent = 5,
    Function(int completed, int total, RemoteCommandResult result)? onProgress,
  }) async {
    final List<RemoteCommandResult> results = [];
    final queue = List<ManagedDevice>.from(devices);
    final total = devices.length;
    int completed = 0;

    final completer = Completer<List<RemoteCommandResult>>();
    int active = 0;

    void processNext() {
      if (queue.isEmpty && active == 0) {
        if (!completer.isCompleted) completer.complete(results);
        return;
      }

      while (active < maxConcurrent && queue.isNotEmpty) {
        final dev = queue.removeAt(0);
        active++;

        execute(
              device: dev,
              command: command,
              typeOverride: typeOverride,
              username: username,
              password: password,
            )
            .then((res) {
              results.add(res);
              completed++;
              onProgress?.call(completed, total, res);
            })
            .whenComplete(() {
              active--;
              processNext();
            });
      }
    }

    processNext();
    return completer.future;
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Execution output from system processes.
class ProcessExecutionResult {
  final int exitCode;
  final String stdout;
  final String stderr;
  final bool isSuccess;

  const ProcessExecutionResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.isSuccess,
  });

  @override
  String toString() =>
      'ProcessResult(exitCode: $exitCode, success: $isSuccess, out: $stdout, err: $stderr)';
}

/// Helper for executing system processes and Windows management tools.
class ProcessRunner {
  /// Converts a UTF-8 script string to Windows UTF-16LE Base64 for PowerShell -EncodedCommand.
  /// This eliminates any shell escaping, quoting, newline, or pipe corruption issues.
  static String toEncodedCommand(String script) {
    final units = script.codeUnits;
    final bytes = Uint8List(units.length * 2);
    for (int i = 0; i < units.length; i++) {
      bytes[i * 2] = units[i] & 0xFF;
      bytes[i * 2 + 1] = (units[i] >> 8) & 0xFF;
    }
    return base64.encode(bytes);
  }

  /// Decodes PowerShell CLIXML output stream into human-readable plain text.
  /// Removes XML wrappers, progress objects, and decodes hex entity escapes (_x000D__x000A_).
  static String decodeClixml(String raw) {
    if (!raw.contains('#< CLIXML') && !raw.contains('<Objs')) {
      return raw;
    }

    final buffer = StringBuffer();
    final sTagRegex = RegExp(r'<S(?:\s+[^>]*)?>(.*?)<\/S>', dotAll: true);
    for (final m in sTagRegex.allMatches(raw)) {
      var text = m.group(1) ?? '';
      text = text
          .replaceAll('_x000D__x000A_', '\n')
          .replaceAll('_x000A_', '\n')
          .replaceAll('_x000D_', '\r')
          .replaceAll('_x0009_', '\t')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'");

      final trimmed = text.trim();
      if (trimmed.startsWith('+ CategoryInfo') ||
          trimmed.startsWith('+ FullyQualifiedErrorId') ||
          trimmed.startsWith('+ PSComputerName')) {
        continue;
      }
      buffer.write(text);
    }

    final decoded = buffer.toString().trim();
    return decoded.isNotEmpty ? decoded : raw;
  }

  /// Executes a PowerShell script block or command locally or remotely via Invoke-Command.
  static Future<ProcessExecutionResult> runPowerShell(
    String script, {
    String? computerName,
    String? username,
    String? password,
    int timeoutSeconds = 15,
  }) async {
    try {
      String finalScript;
      if (computerName != null && computerName.isNotEmpty) {
        if (username != null && username.isNotEmpty && password != null) {
          final safeUser = username.replaceAll("'", "''");
          final safePass = password.replaceAll("'", "''");
          finalScript =
              '''
\$ProgressPreference = 'SilentlyContinue'
\$secPass = ConvertTo-SecureString '$safePass' -AsPlainText -Force
\$cred = New-Object System.Management.Automation.PSCredential('$safeUser', \$secPass)
Invoke-Command -ComputerName $computerName -Credential \$cred -ScriptBlock {
  \$ProgressPreference = 'SilentlyContinue'
  $script
}
''';
        } else {
          finalScript =
              '''
\$ProgressPreference = 'SilentlyContinue'
Invoke-Command -ComputerName $computerName -ScriptBlock {
  \$ProgressPreference = 'SilentlyContinue'
  $script
}
''';
        }
      } else {
        finalScript =
            '''
\$ProgressPreference = 'SilentlyContinue'
$script
''';
      }

      final encoded = toEncodedCommand(finalScript);

      final result =
          await Process.run('powershell.exe', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-EncodedCommand',
            encoded,
          ]).timeout(
            Duration(seconds: timeoutSeconds),
            onTimeout: () => ProcessResult(
              -1,
              -1,
              '',
              'Execution timed out after $timeoutSeconds seconds.',
            ),
          );

      final out = result.stdout.toString().trim();
      final rawErr = result.stderr.toString().trim();
      final err = decodeClixml(rawErr);

      // Smart Success Evaluation:
      // In PowerShell, native commands (e.g. adb, git, curl) write status banners to stderr.
      // This produces a NativeCommandError in CLIXML even when the command succeeded (exit code 0).
      bool isSuccess = result.exitCode == 0;
      if (isSuccess && err.isNotEmpty) {
        final lowerErr = err.toLowerCase();
        final hasFatalError =
            lowerErr.contains('access is denied') ||
            lowerErr.contains('unauthorized') ||
            lowerErr.contains('psremotingtransportexception') ||
            lowerErr.contains('commandnotfoundexception') ||
            lowerErr.contains('cannot find path') ||
            lowerErr.contains('itemnotfoundexception') ||
            lowerErr.contains('cannot bind parameter') ||
            lowerErr.contains('the network path was not found') ||
            lowerErr.contains('term is not recognized');

        if (hasFatalError) {
          isSuccess = false;
        }
      }

      // If execution succeeded but output was sent to stderr (like adb start-server),
      // forward that output into stdout so it's presented to the user as normal output:
      String finalOut = out;
      String finalErr = err;
      if (isSuccess && out.isEmpty && err.isNotEmpty) {
        finalOut = err;
        finalErr = '';
      } else if (isSuccess && out.isNotEmpty && err.isNotEmpty) {
        finalOut = '$out\n$err';
        finalErr = '';
      }

      return ProcessExecutionResult(
        exitCode: result.exitCode,
        stdout: finalOut,
        stderr: finalErr,
        isSuccess: isSuccess,
      );
    } catch (e) {
      return ProcessExecutionResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Process execution error: $e',
        isSuccess: false,
      );
    }
  }

  /// Launches Windows Remote Desktop (mstsc.exe) targeting the specified IP.
  static Future<bool> launchRdp(String ip) async {
    if (!Platform.isWindows) return false;
    try {
      await Process.start('mstsc.exe', [
        '/v:$ip',
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens Windows Explorer pointing to the host's administrative share (e.g. \\172.19.116.157\c$).
  static Future<bool> launchExplorerShare(
    String ip, [
    String share = 'c\$',
  ]) async {
    if (!Platform.isWindows) return false;
    try {
      final uncPath = '\\\\$ip\\$share';
      await Process.start('explorer.exe', [
        uncPath,
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Opens Windows Computer Management snap-in for remote computer.
  static Future<bool> launchComputerManagement(String ip) async {
    if (!Platform.isWindows) return false;
    try {
      await Process.start('mmc.exe', [
        'compmgmt.msc',
        '/computer=$ip',
      ], mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restarts a remote Windows PC.
  static Future<ProcessExecutionResult> restartWindowsPc(String ip) async {
    return runPowerShell(
      'Restart-Computer -ComputerName $ip -Force',
      timeoutSeconds: 10,
    );
  }

  /// Shuts down a remote Windows PC.
  static Future<ProcessExecutionResult> shutdownWindowsPc(String ip) async {
    return runPowerShell(
      'Stop-Computer -ComputerName $ip -Force',
      timeoutSeconds: 10,
    );
  }
}

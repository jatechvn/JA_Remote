import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import '../core/process/process_runner.dart';
import '../data/models/managed_device.dart';
import '../data/repositories/log_repository.dart';
import 'remote_command_service.dart';
import 'wol_scripts.dart';

part 'wol_inspector_parsers.dart';

/// Overall Wake-on-LAN readiness status for an audited host.
enum WolReadinessStatus {
  ready,
  partialBiosManual,
  needsFix,
  unsupportedUsbOnly,
  authRequired,
  unreachable,
}

/// Evaluation state for a single layer in the 4-layer WoL audit.
enum WolLayerState { pass, warn, fail, unknown }

/// Result for one of the 4 WoL audit layers (`bios`, `driver`, `persistence`, `power`).
class WolLayerCheck {
  final String id;
  final WolLayerState state;
  final String summary;
  final List<String> details;

  const WolLayerCheck({
    required this.id,
    required this.state,
    required this.summary,
    this.details = const [],
  });
}

/// Full 4-layer Wake-on-LAN diagnostic & remediation report for a host.
class WolAuditReport {
  final String? deviceId;
  final String targetName;
  final String ip;
  final String os;
  final String? detectedMac;
  final String? adapterName;
  final String? modelAndBios;
  final WolReadinessStatus overallStatus;
  final List<WolLayerCheck> layers;
  final List<String> actionsApplied;
  final bool needsBiosManualCheck;
  final bool needsReboot;
  final String? rawError;
  final DateTime checkedAt;

  const WolAuditReport({
    this.deviceId,
    required this.targetName,
    required this.ip,
    required this.os,
    this.detectedMac,
    this.adapterName,
    this.modelAndBios,
    required this.overallStatus,
    required this.layers,
    this.actionsApplied = const [],
    this.needsBiosManualCheck = false,
    this.needsReboot = false,
    this.rawError,
    required this.checkedAt,
  });

  bool get isReady =>
      overallStatus == WolReadinessStatus.ready ||
      overallStatus == WolReadinessStatus.partialBiosManual;

  bool get canAutoFix =>
      overallStatus == WolReadinessStatus.needsFix ||
      overallStatus == WolReadinessStatus.authRequired;

  String toTsvRow() {
    final lSummary = layers.map((l) => '${l.id}:${l.state.name}').join(' | ');
    return '$targetName\t$ip\t$os\t${detectedMac ?? ""}\t${overallStatus.name.toUpperCase()}\t${adapterName ?? ""}\t$lSummary';
  }
}

typedef LocalPsRunner =
    Future<ProcessExecutionResult> Function(
      String script, {
      int timeoutSeconds,
    });

/// Audits and remediates 4-layer Wake-on-LAN readiness across local Windows,
/// remote WinRM Windows, and remote SSH Linux workstations.
class WolInspectorService {
  final RemoteCommandService _remoteService;
  final LocalPsRunner _localRunner;
  final LocalPsRunner _localElevatedRunner;
  final LogRepository _logRepo = LogRepository();
  bool _cancelled = false;

  WolInspectorService({
    RemoteCommandService? remoteService,
    LocalPsRunner? localPowerShellRunner,
    LocalPsRunner? localElevatedRunner,
  }) : _remoteService = remoteService ?? RemoteCommandService(),
       _localRunner = localPowerShellRunner ?? _defaultLocalRunner,
       _localElevatedRunner =
           localElevatedRunner ?? _defaultLocalElevatedRunner;

  void cancel() => _cancelled = true;

  /// Parses `JA_WOL_JSON:` output produced by Windows or Linux audit scripts.
  static WolAuditReport parseReportOutput({
    required String stdout,
    required String stderr,
    required bool isSuccess,
    String? deviceId,
    required String fallbackName,
    required String fallbackIp,
    required String fallbackOs,
  }) => _parseWolReportOutput(
    stdout: stdout,
    stderr: stderr,
    isSuccess: isSuccess,
    deviceId: deviceId,
    fallbackName: fallbackName,
    fallbackIp: fallbackIp,
    fallbackOs: fallbackOs,
  );

  static Future<ProcessExecutionResult> _defaultLocalRunner(
    String script, {
    int timeoutSeconds = 20,
  }) => ProcessRunner.runPowerShell(script, timeoutSeconds: timeoutSeconds);

  static Future<ProcessExecutionResult> _defaultLocalElevatedRunner(
    String script, {
    int timeoutSeconds = 60,
  }) async {
    if (!Platform.isWindows) {
      return const ProcessExecutionResult(
        exitCode: -1,
        stdout: '',
        stderr: 'UAC elevation is only supported on Windows.',
        isSuccess: false,
      );
    }
    final tag = DateTime.now().microsecondsSinceEpoch;
    final tmpDir = Directory.systemTemp.path;
    final ps1File = File(p.join(tmpDir, 'ja_wol_uac_$tag.ps1'));
    final outFile = File(p.join(tmpDir, 'ja_wol_uac_$tag.out'));
    final escOut = outFile.path.replaceAll("'", "''");
    final escPs1 = ps1File.path.replaceAll("'", "''");

    final wrapped =
        '''
\$ErrorActionPreference = 'Continue'
\$ProgressPreference = 'SilentlyContinue'
\$lines = & {
$script
} 2>&1 | ForEach-Object { "\$_" }
[System.IO.File]::WriteAllLines('$escOut', @(\$lines), [System.Text.UTF8Encoding]::new(\$false))
''';

    try {
      await ps1File.writeAsBytes([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(wrapped),
      ], flush: true);

      final launcher =
          "\$p = Start-Process -FilePath 'powershell.exe' "
          "-ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File','$escPs1') "
          r'-Verb RunAs -Wait -PassThru -ErrorAction Stop; exit $p.ExitCode';
      final launchRes = await ProcessRunner.runPowerShell(
        launcher,
        timeoutSeconds: timeoutSeconds,
      );
      final outText = await outFile.exists()
          ? (await outFile.readAsString()).trim()
          : launchRes.stdout;
      return ProcessExecutionResult(
        exitCode: launchRes.exitCode,
        stdout: outText,
        stderr: launchRes.stderr,
        isSuccess: launchRes.isSuccess && outText.isNotEmpty,
      );
    } finally {
      for (final f in [ps1File, outFile]) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  /// Checks WoL readiness on the local Windows workstation without elevation.
  Future<WolAuditReport> checkLocalWindows() async {
    final script = WolScripts.buildWindowsScript(
      applyFix: false,
      allowAdapterRestart: false,
    );
    final res = await _localRunner(script, timeoutSeconds: 20);
    return parseReportOutput(
      stdout: res.stdout,
      stderr: res.stderr,
      isSuccess: res.isSuccess,
      fallbackName: Platform.localHostname,
      fallbackIp: '127.0.0.1',
      fallbackOs: 'Windows',
    );
  }

  /// Applies full 4-layer WoL optimization on the local Windows workstation via UAC.
  Future<WolAuditReport> fixLocalWindowsWithUac() async {
    final script = WolScripts.buildWindowsScript(
      applyFix: true,
      allowAdapterRestart: true,
    );
    final res = await _localElevatedRunner(script, timeoutSeconds: 60);
    final report = parseReportOutput(
      stdout: res.stdout,
      stderr: res.stderr,
      isSuccess: res.isSuccess,
      fallbackName: Platform.localHostname,
      fallbackIp: '127.0.0.1',
      fallbackOs: 'Windows',
    );
    _logRepo.addLog(
      deviceName: report.targetName,
      deviceIp: report.ip,
      action: 'WOL_FIX',
      status: report.isReady ? 'SUCCESS' : 'FAILED',
      message: 'Local WoL fix: ${report.overallStatus.name}',
    );
    return report;
  }

  /// Audits 4-layer WoL readiness on a remote or managed [device].
  Future<WolAuditReport> checkDevice(
    ManagedDevice device, {
    String? username,
    String? password,
    int timeoutSeconds = 20,
  }) => _runRemote(
    device,
    applyFix: false,
    username: username,
    password: password,
    timeoutSeconds: timeoutSeconds,
  );

  /// Applies safe 4-layer WoL remediation on a remote or managed [device].
  Future<WolAuditReport> fixDevice(
    ManagedDevice device, {
    String? username,
    String? password,
    int timeoutSeconds = 30,
  }) async {
    final report = await _runRemote(
      device,
      applyFix: true,
      username: username,
      password: password,
      timeoutSeconds: timeoutSeconds,
    );
    _logRepo.addLog(
      deviceName: device.name,
      deviceIp: device.ip,
      action: 'WOL_FIX',
      status: report.isReady ? 'SUCCESS' : 'FAILED',
      message: report.actionsApplied.isNotEmpty
          ? report.actionsApplied.join('; ')
          : (report.rawError ?? report.overallStatus.name),
    );
    return report;
  }

  /// Runs Check or Fix across multiple [devices] with bounded worker concurrency.
  Future<List<WolAuditReport>> runBatch({
    required List<ManagedDevice> devices,
    required bool applyFix,
    String? username,
    String? password,
    int concurrency = 5,
    void Function(int completed, int total, WolAuditReport latest)? onProgress,
  }) async {
    _cancelled = false;
    final targets = List<ManagedDevice>.of(devices);
    if (targets.isEmpty) return [];

    final workers = math.max(1, math.min(concurrency, targets.length));
    final results = List<WolAuditReport?>.filled(targets.length, null);
    var nextIdx = 0;
    var doneCount = 0;

    Future<void> worker() async {
      while (!_cancelled && nextIdx < targets.length) {
        final idx = nextIdx++;
        final dev = targets[idx];
        final report = applyFix
            ? await fixDevice(dev, username: username, password: password)
            : await checkDevice(dev, username: username, password: password);
        results[idx] = report;
        doneCount++;
        onProgress?.call(doneCount, targets.length, report);
      }
    }

    await Future.wait(List.generate(workers, (_) => worker()));
    return results.whereType<WolAuditReport>().toList();
  }

  Future<WolAuditReport> _runRemote(
    ManagedDevice device, {
    required bool applyFix,
    String? username,
    String? password,
    required int timeoutSeconds,
  }) async {
    final isLinux = device.os.toLowerCase() == 'linux';
    final effectiveUser = (username != null && username.isNotEmpty)
        ? username
        : device.username;
    final effectivePass = (password != null && password.isNotEmpty)
        ? password
        : device.password;

    final command = isLinux
        ? WolScripts.buildLinuxScript(
            applyFix: applyFix,
            sudoPassword: effectivePass,
          )
        : WolScripts.buildWindowsScript(
            applyFix: applyFix,
            allowAdapterRestart: false,
          );

    final res = await _remoteService.execute(
      device: device,
      command: command,
      typeOverride: isLinux ? 'ssh' : 'powershell',
      username: effectiveUser,
      password: effectivePass,
      timeoutSeconds: timeoutSeconds,
    );

    return parseReportOutput(
      stdout: res.output,
      stderr: res.error,
      isSuccess: res.isSuccess,
      deviceId: device.id,
      fallbackName: device.name,
      fallbackIp: device.ip,
      fallbackOs: device.os,
    );
  }
}

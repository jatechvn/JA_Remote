import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/network/network_utils.dart';
import '../../data/models/managed_device.dart';
import '../../data/models/saved_credential.dart';
import '../../data/repositories/credential_repository.dart';
import '../../services/device_service.dart';
import '../../services/power_service.dart';
import '../../services/wol_inspector_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/language_provider.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/glass_widgets.dart';

part 'wol_inspector_cards.dart';
part 'wol_inspector_controls.dart';

/// Opens the 4-layer Wake-on-LAN Auditor & Auto-Fix dialog.
Future<void> showWolInspectorDialog(
  BuildContext context, {
  List<ManagedDevice>? initialDevices,
  int initialTab = 0,
  WolInspectorService? inspectorService,
  PowerService? powerService,
}) {
  final colors = context.read<ThemeProvider>().colors;
  final language = context.read<LanguageProvider>();

  return showGlassDialog(
    context: context,
    colors: colors,
    title: language.t('wol_inspector_title'),
    icon: Icons.settings_power_rounded,
    width: 920,
    content: _WolInspectorDialogBody(
      initialDevices: initialDevices,
      initialTab: initialTab,
      inspectorService: inspectorService,
      powerService: powerService,
    ),
  );
}

class _WolInspectorDialogBody extends StatefulWidget {
  final List<ManagedDevice>? initialDevices;
  final int initialTab;
  final WolInspectorService? inspectorService;
  final PowerService? powerService;

  const _WolInspectorDialogBody({
    this.initialDevices,
    this.initialTab = 0,
    this.inspectorService,
    this.powerService,
  });

  @override
  State<_WolInspectorDialogBody> createState() =>
      _WolInspectorDialogBodyState();
}

class _WolInspectorDialogBodyState extends State<_WolInspectorDialogBody> {
  late final WolInspectorService _service;
  late final PowerService _powerService;
  final CredentialRepository _credRepo = CredentialRepository();

  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _adhocIpController = TextEditingController();
  final TextEditingController _adhocPortController = TextEditingController(
    text: '22',
  );

  int _activeTab = 0; // 0: Managed, 1: This PC, 2: Ad-hoc
  String _adhocOs = 'Windows';
  bool _obscurePass = true;
  bool _isRunning = false;
  bool _localAutoChecked = false;
  String _filterMode = 'all';
  String _progressText = '';
  double _progress = 0.0;

  List<SavedCredential> _savedCreds = [];
  List<WolAuditReport> _reports = [];
  final Set<String> _expandedKeys = {};
  final Set<String> _busyCardKeys = {};

  @override
  void initState() {
    super.initState();
    _service = widget.inspectorService ?? WolInspectorService();
    _powerService = widget.powerService ?? PowerService();
    _activeTab = widget.initialTab.clamp(0, 2);
    if (widget.initialDevices != null && widget.initialDevices!.length == 1) {
      final d = widget.initialDevices!.first;
      if (d.username != null && d.username!.isNotEmpty) {
        _userController.text = d.username!;
      }
      if (d.password != null && d.password!.isNotEmpty) {
        _passController.text = d.password!;
      }
    }
    _loadSavedCredentials();
    if (_activeTab == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_localAutoChecked) _runLocalCheck();
      });
    }
  }

  @override
  void dispose() {
    _service.cancel();
    _userController.dispose();
    _passController.dispose();
    _adhocIpController.dispose();
    _adhocPortController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final list = await _credRepo.loadCredentials();
    if (mounted) {
      setState(() => _savedCreds = list);
    }
  }

  void _mutate(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  String _reportKey(WolAuditReport r) => '${r.ip}|${r.targetName}';

  void _selectTab(int idx) {
    if (_isRunning) return;
    setState(() => _activeTab = idx);
    if (idx == 1 && !_localAutoChecked) {
      _runLocalCheck();
    }
  }

  List<ManagedDevice> _resolveManagedTargets(DeviceService deviceService) {
    if (widget.initialDevices != null && widget.initialDevices!.isNotEmpty) {
      return widget.initialDevices!;
    }
    if (deviceService.selectedDevices.isNotEmpty) {
      return deviceService.selectedDevices;
    }
    return deviceService.devices;
  }

  Future<void> _runManagedBatch({
    required DeviceService deviceService,
    required AppColors colors,
    required LanguageProvider language,
    required bool applyFix,
  }) async {
    var targets = _resolveManagedTargets(deviceService);
    if (applyFix && _reports.isNotEmpty) {
      final fixIps = _reports
          .where((r) => r.canAutoFix)
          .map((r) => r.ip)
          .toSet();
      if (fixIps.isNotEmpty) {
        targets = targets.where((d) => fixIps.contains(d.ip)).toList();
      }
    }
    if (targets.isEmpty) {
      showAppToast(
        context,
        colors: colors,
        message: language.t('wol_empty_targets'),
        icon: Icons.warning_amber_rounded,
        accentColor: colors.accentAmber,
      );
      return;
    }

    setState(() {
      _isRunning = true;
      _progress = 0.05;
      _progressText = applyFix
          ? '${language.t('wol_btn_fix')} (${targets.length})...'
          : '${language.t('wol_btn_check')} (${targets.length})...';
    });

    final user = _userController.text.trim();
    final pass = _passController.text;
    final list = await _service.runBatch(
      devices: targets,
      applyFix: applyFix,
      username: user.isNotEmpty ? user : null,
      password: pass.isNotEmpty ? pass : null,
      onProgress: (done, total, latest) {
        if (!mounted) return;
        setState(() {
          _progress = total > 0 ? done / total : 1.0;
          _progressText =
              '$done / $total — ${latest.targetName} (${latest.ip})';
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _mergeReports(list);
      if (_reports.length == 1) {
        _expandedKeys.add(_reportKey(_reports.first));
      }
    });
  }

  void _mergeReports(List<WolAuditReport> incoming) {
    if (_reports.isEmpty) {
      _reports = List<WolAuditReport>.of(incoming);
      return;
    }
    final map = <String, WolAuditReport>{
      for (final r in _reports) _reportKey(r): r,
    };
    for (final r in incoming) {
      map[_reportKey(r)] = r;
    }
    _reports = map.values.toList();
  }

  Future<void> _runLocalCheck() async {
    _localAutoChecked = true;
    setState(() {
      _isRunning = true;
      _progress = 0.2;
      _progressText = 'This PC (localhost)...';
    });
    final report = await _service.checkLocalWindows();
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _progress = 1.0;
      _reports = [report];
      _expandedKeys.add(_reportKey(report));
    });
  }

  Future<void> _runLocalFix(AppColors colors) async {
    setState(() {
      _isRunning = true;
      _progress = 0.3;
      _progressText = 'Waiting for Windows Admin UAC...';
    });
    final report = await _service.fixLocalWindowsWithUac();
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _progress = 1.0;
      _reports = [report];
      _expandedKeys.add(_reportKey(report));
    });
    showAppToast(
      context,
      colors: colors,
      message: report.isReady
          ? 'Đã tối ưu WoL cho máy hiện tại!'
          : (report.rawError ?? 'Không thể hoàn tất tối ưu UAC'),
      icon: report.isReady ? Icons.check_circle_rounded : Icons.warning_rounded,
      accentColor: report.isReady ? colors.accentEmerald : colors.accentRose,
    );
  }

  Future<void> _runAdhoc({
    required AppColors colors,
    required bool applyFix,
  }) async {
    final ip = _adhocIpController.text.trim();
    if (!NetworkUtils.isValidIp(ip)) {
      showAppToast(
        context,
        colors: colors,
        message: 'Vui lòng nhập địa chỉ IPv4 hợp lệ!',
        icon: Icons.warning_amber_rounded,
        accentColor: colors.accentAmber,
      );
      return;
    }
    final port = int.tryParse(_adhocPortController.text.trim()) ?? 22;
    final dev = ManagedDevice(
      id: 'adhoc_$ip',
      name: ip,
      hostname: ip,
      ip: ip,
      os: _adhocOs,
      sshPort: port.clamp(1, 65535),
      username: _userController.text.trim().isNotEmpty
          ? _userController.text.trim()
          : null,
      password: _passController.text.isNotEmpty ? _passController.text : null,
    );
    setState(() {
      _isRunning = true;
      _progress = 0.35;
      _progressText = '$ip ($_adhocOs)...';
    });
    final report = applyFix
        ? await _service.fixDevice(dev)
        : await _service.checkDevice(dev);
    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _progress = 1.0;
      _reports = [report];
      _expandedKeys.add(_reportKey(report));
    });
  }

  Future<void> _fixSingleCard(
    WolAuditReport report,
    DeviceService deviceService,
    AppColors colors,
  ) async {
    final key = _reportKey(report);
    if (_activeTab == 1 || report.ip == '127.0.0.1') {
      await _runLocalFix(colors);
      return;
    }
    setState(() => _busyCardKeys.add(key));
    ManagedDevice? existing;
    if (report.deviceId != null) {
      for (final d in deviceService.devices) {
        if (d.id == report.deviceId) {
          existing = d;
          break;
        }
      }
    }
    final dev =
        existing ??
        ManagedDevice(
          id: report.deviceId ?? 'adhoc_${report.ip}',
          name: report.targetName,
          hostname: report.targetName,
          ip: report.ip,
          os: report.os,
          sshPort: int.tryParse(_adhocPortController.text.trim()) ?? 22,
        );
    final updated = await _service.fixDevice(
      dev,
      username: _userController.text.trim().isNotEmpty
          ? _userController.text.trim()
          : null,
      password: _passController.text.isNotEmpty ? _passController.text : null,
    );
    if (!mounted) return;
    setState(() {
      _busyCardKeys.remove(key);
      final idx = _reports.indexWhere((r) => _reportKey(r) == key);
      if (idx >= 0) {
        _reports[idx] = updated;
      } else {
        _reports.add(updated);
      }
      _expandedKeys.add(_reportKey(updated));
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    final language = context.watch<LanguageProvider>();
    final deviceService = context.watch<DeviceService>();

    final readyCount = _reports.where((r) => r.isReady).length;
    final fixCount = _reports
        .where((r) => r.overallStatus == WolReadinessStatus.needsFix)
        .length;
    final errCount = _reports
        .where(
          (r) =>
              r.overallStatus == WolReadinessStatus.authRequired ||
              r.overallStatus == WolReadinessStatus.unreachable,
        )
        .length;

    final filtered = _reports.where((r) {
      switch (_filterMode) {
        case 'fix':
          return r.overallStatus == WolReadinessStatus.needsFix;
        case 'ready':
          return r.isReady;
        case 'error':
          return r.overallStatus == WolReadinessStatus.authRequired ||
              r.overallStatus == WolReadinessStatus.unreachable;
        default:
          return true;
      }
    }).toList();

    final managedTargets = _resolveManagedTargets(deviceService);

    return SizedBox(
      width: 880,
      height: 590,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Mode Tabs & Controls
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _WolTabChip(
                      label:
                          '${language.t('wol_tab_managed')} (${managedTargets.length})',
                      icon: Icons.devices_rounded,
                      selected: _activeTab == 0,
                      colors: colors,
                      onTap: _isRunning ? null : () => _selectTab(0),
                    ),
                    _WolTabChip(
                      label: language.t('wol_tab_local'),
                      icon: Icons.computer_rounded,
                      selected: _activeTab == 1,
                      colors: colors,
                      onTap: _isRunning ? null : () => _selectTab(1),
                    ),
                    _WolTabChip(
                      label: language.t('wol_tab_adhoc'),
                      icon: Icons.lan_rounded,
                      selected: _activeTab == 2,
                      colors: colors,
                      onTap: _isRunning ? null : () => _selectTab(2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_activeTab == 0)
                  buildManagedControls(deviceService, colors, language)
                else if (_activeTab == 1)
                  buildLocalControls(colors, language)
                else
                  buildAdhocControls(deviceService, colors, language),
              ],
            ),
          ),

          if (_isRunning || _reports.isNotEmpty) ...[
            const SizedBox(height: 10),
            buildProgressOrFilterBar(
              colors: colors,
              language: language,
              readyCount: readyCount,
              fixCount: fixCount,
              errCount: errCount,
            ),
          ],
          const SizedBox(height: 10),

          // Results List
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.cardBg.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.cardBorder),
              ),
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _isRunning
                            ? _progressText
                            : language.t('wol_idle_hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.textMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = filtered[i];
                        final key = _reportKey(r);
                        ManagedDevice? matched;
                        for (final d in deviceService.devices) {
                          if (d.id == r.deviceId || d.ip == r.ip) {
                            matched = d;
                            break;
                          }
                        }
                        final canSyncMac =
                            r.detectedMac != null &&
                            r.detectedMac!.isNotEmpty &&
                            (matched == null ||
                                (matched.mac ?? '').toUpperCase() !=
                                    r.detectedMac!.toUpperCase());
                        return _WolReportCard(
                          report: r,
                          colors: colors,
                          language: language,
                          isExpanded: _expandedKeys.contains(key),
                          isBusy: _busyCardKeys.contains(key),
                          canSyncMac: canSyncMac,
                          onToggleExpand: () => setState(() {
                            if (!_expandedKeys.add(key)) {
                              _expandedKeys.remove(key);
                            }
                          }),
                          onFix: () => _fixSingleCard(r, deviceService, colors),
                          onSyncMac: () => _syncWolMacToDevice(
                            context: context,
                            report: r,
                            deviceService: deviceService,
                            colors: colors,
                            username: _userController.text.trim(),
                            password: _passController.text,
                          ),
                          onTestWake: () => _testWolWake(
                            context: context,
                            powerService: _powerService,
                            report: r,
                            deviceService: deviceService,
                            colors: colors,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

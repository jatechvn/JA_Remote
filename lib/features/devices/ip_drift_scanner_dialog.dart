import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/managed_device.dart';
import '../../services/device_service.dart';
import '../../services/ip_drift_scanner_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/language_provider.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/glass_dialog.dart';
import '../../widgets/glass_widgets.dart';

Future<void> showIpDriftScannerDialog(BuildContext context) {
  final colors = context.read<ThemeProvider>().colors;
  final language = context.read<LanguageProvider>();

  return showGlassDialog(
    context: context,
    colors: colors,
    title: language.t('drift_scanner_title'),
    icon: Icons.radar_rounded,
    width: 900,
    content: const _IpDriftScannerDialogBody(),
  );
}

class _IpDriftScannerDialogBody extends StatefulWidget {
  const _IpDriftScannerDialogBody();

  @override
  State<_IpDriftScannerDialogBody> createState() =>
      _IpDriftScannerDialogBodyState();
}

class _IpDriftScannerDialogBodyState extends State<_IpDriftScannerDialogBody> {
  final IpDriftScannerService _scanner = IpDriftScannerService();
  final TextEditingController _pasteController = TextEditingController();

  bool _usePastedInput = false;
  bool _sweepSubnets = true;
  bool _isScanning = false;
  String _phaseText = '';
  double _progress = 0.0;
  String _filterMode = 'all'; // 'all', 'issues', 'ok', 'offline'

  List<IpDriftAuditEntry> _results = [];
  final Set<String> _updatedTargetKeys = {};

  @override
  void dispose() {
    _scanner.cancel();
    _pasteController.dispose();
    super.dispose();
  }

  String _targetKey(IpDriftTarget t) => '${t.name}|${t.expectedIp}';

  Future<void> _startScan(
    DeviceService deviceService,
    AppColors colors,
    LanguageProvider language,
  ) async {
    List<IpDriftTarget> targets;
    if (_usePastedInput) {
      targets = IpDriftScannerService.parsePastedTargets(
        _pasteController.text,
        deviceService.devices,
      );
      if (targets.isEmpty) {
        showAppToast(
          context,
          colors: colors,
          message: language.t('drift_scanner_empty_paste'),
          icon: Icons.warning_amber_rounded,
          accentColor: colors.accentAmber,
        );
        return;
      }
    } else {
      final sourceDevices = deviceService.selectedDevices.isNotEmpty
          ? deviceService.selectedDevices
          : deviceService.devices;
      targets = sourceDevices.map(IpDriftTarget.fromDevice).toList();
      if (targets.isEmpty) {
        showAppToast(
          context,
          colors: colors,
          message: language.t('drift_scanner_empty_devices'),
          icon: Icons.warning_amber_rounded,
          accentColor: colors.accentAmber,
        );
        return;
      }
    }

    setState(() {
      _isScanning = true;
      _progress = 0.05;
      _phaseText = language.t('drift_scanner_starting');
      _results = [];
      _updatedTargetKeys.clear();
    });

    final entries = await _scanner.runAudit(
      targets: targets,
      sweepSubnetsForMissing: _sweepSubnets,
      onProgress: (phase, prog) {
        if (!mounted) return;
        setState(() {
          _phaseText = phase;
          _progress = prog;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _results = entries;
      if (entries.any((e) => e.isIssue)) {
        _filterMode = 'issues';
      } else {
        _filterMode = 'all';
      }
    });
  }

  Future<void> _applySingleUpdate(
    IpDriftAuditEntry entry,
    DeviceService deviceService,
    AppColors colors,
  ) async {
    final newIp = entry.discoveredNewIp;
    if (newIp == null || newIp.isEmpty) return;

    if (entry.target.deviceId != null) {
      await deviceService.applyDiscoveredIpUpdate(
        entry.target.deviceId!,
        newIp,
        newMac: entry.discoveredNewMac ?? entry.target.expectedMac,
        discoveredHostname: entry.discoveredNewHost,
      );
    } else {
      await deviceService.addDevice(
        ManagedDevice(
          id: 'dev_${DateTime.now().microsecondsSinceEpoch}',
          name: entry.target.name,
          ip: newIp,
          mac: entry.discoveredNewMac ?? entry.target.expectedMac,
          hostname: entry.discoveredNewHost ?? entry.target.name,
          group: entry.target.group,
          online: true,
          lastSeen: DateTime.now(),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _updatedTargetKeys.add(_targetKey(entry.target));
    });
    showAppToast(
      context,
      colors: colors,
      message:
          'Đã cập nhật IP mới cho ${entry.target.name}: ${entry.target.expectedIp} → $newIp',
      icon: Icons.check_circle_rounded,
      accentColor: colors.accentEmerald,
    );
  }

  Future<void> _applyAllJumpedUpdates(
    DeviceService deviceService,
    AppColors colors,
  ) async {
    final jumped = _results
        .where(
          (e) =>
              e.hasJumpedIp &&
              !_updatedTargetKeys.contains(_targetKey(e.target)),
        )
        .toList();
    if (jumped.isEmpty) return;

    for (final entry in jumped) {
      final newIp = entry.discoveredNewIp!;
      if (entry.target.deviceId != null) {
        await deviceService.applyDiscoveredIpUpdate(
          entry.target.deviceId!,
          newIp,
          newMac: entry.discoveredNewMac ?? entry.target.expectedMac,
          discoveredHostname: entry.discoveredNewHost,
        );
      } else {
        await deviceService.addDevice(
          ManagedDevice(
            id: 'dev_${DateTime.now().microsecondsSinceEpoch}_${entry.target.name}',
            name: entry.target.name,
            ip: newIp,
            mac: entry.discoveredNewMac ?? entry.target.expectedMac,
            hostname: entry.discoveredNewHost ?? entry.target.name,
            group: entry.target.group,
            online: true,
            lastSeen: DateTime.now(),
          ),
        );
      }
      _updatedTargetKeys.add(_targetKey(entry.target));
    }

    if (!mounted) return;
    setState(() {});
    showAppToast(
      context,
      colors: colors,
      message: 'Đã cập nhật IP mới cho ${jumped.length} máy bị nhảy IP!',
      icon: Icons.check_circle_rounded,
      accentColor: colors.accentEmerald,
    );
  }

  void _copyAuditReport(AppColors colors) {
    if (_results.isEmpty) return;
    final sb = StringBuffer();
    sb.writeln('HOSTNAME\tOLD_IP\tEXPECTED_MAC\tSTATUS\tNEW_IP\tDETAIL');
    for (final r in _results) {
      sb.writeln(
        '${r.target.name}\t${r.target.expectedIp}\t${r.target.expectedMac ?? ""}\t${r.status.name.toUpperCase()}\t${r.discoveredNewIp ?? r.target.expectedIp}\t${r.detailMessage}',
      );
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    showAppToast(
      context,
      colors: colors,
      message:
          'Đã sao chép báo cáo đối soát IP (${_results.length} máy) vào Clipboard!',
      icon: Icons.copy_rounded,
      accentColor: colors.accentCyan,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().colors;
    final language = context.watch<LanguageProvider>();
    final deviceService = context.watch<DeviceService>();

    final jumpedCount = _results.where((e) => e.hasJumpedIp).length;
    final conflictCount = _results
        .where(
          (e) =>
              e.status == IpDriftStatus.ipConflict ||
              e.status == IpDriftStatus.hostnameMismatch,
        )
        .length;
    final okCount = _results
        .where((e) => e.status == IpDriftStatus.onlineOk)
        .length;
    final offlineCount = _results
        .where((e) => e.status == IpDriftStatus.offline)
        .length;

    final filtered = _results.where((e) {
      switch (_filterMode) {
        case 'issues':
          return e.isIssue;
        case 'ok':
          return e.status == IpDriftStatus.onlineOk;
        case 'offline':
          return e.status == IpDriftStatus.offline;
        default:
          return true;
      }
    }).toList();

    final pendingJumpedCount = _results
        .where(
          (e) =>
              e.hasJumpedIp &&
              !_updatedTargetKeys.contains(_targetKey(e.target)),
        )
        .length;

    return SizedBox(
      width: 860,
      height: 580,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Mode & Controls Card
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
                Row(
                  children: [
                    _buildSourceToggleChip(
                      label: deviceService.selectedDevices.isNotEmpty
                          ? 'Máy đang chọn (${deviceService.selectedDevices.length})'
                          : 'Danh sách máy đã lưu (${deviceService.totalCount})',
                      icon: Icons.devices_rounded,
                      selected: !_usePastedInput,
                      colors: colors,
                      onTap: _isScanning
                          ? null
                          : () => setState(() => _usePastedInput = false),
                    ),
                    const SizedBox(width: 8),
                    _buildSourceToggleChip(
                      label: language.t('drift_scanner_mode_paste'),
                      icon: Icons.content_paste_rounded,
                      selected: _usePastedInput,
                      colors: colors,
                      onTap: _isScanning
                          ? null
                          : () => setState(() => _usePastedInput = true),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _sweepSubnets,
                            activeColor: colors.accentCyan,
                            onChanged: _isScanning
                                ? null
                                : (v) =>
                                      setState(() => _sweepSubnets = v ?? true),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message:
                              'Quét toàn dải Subnet (/24 hoặc /21) + RDP Cert (3389) + NetBIOS (137) để bắt chính xác IP mới của máy bị nhảy DHCP',
                          child: Text(
                            language.t('drift_scanner_deep_sweep'),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (_isScanning)
                      GlassButton(
                        label: language.t('scanner_btn_stop'),
                        icon: Icons.stop_circle_outlined,
                        colors: colors,
                        accentColor: colors.accentRose,
                        onTap: () {
                          _scanner.cancel();
                          setState(() => _isScanning = false);
                        },
                      )
                    else
                      GlassButton(
                        label: language.t('drift_scanner_btn_start'),
                        icon: Icons.radar_rounded,
                        colors: colors,
                        accentColor: colors.accentCyan,
                        onTap: () =>
                            _startScan(deviceService, colors, language),
                      ),
                  ],
                ),
                if (_usePastedInput) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pasteController,
                    enabled: !_isScanning,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Dán danh sách từ Excel / bảng (Mỗi dòng: Hostname   IP   MAC)\nVD: IQ5-SOZ-024   172.21.174.86   48-EA-62-4F-B6-4F',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                      ),
                      filled: true,
                      fillColor: colors.subCardBg,
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.cardBorder),
                      ),
                    ),
                  ),
                ],
                if (_isScanning) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.accentCyan,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _phaseText,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.accentCyan,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${(_progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: colors.accentCyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 5,
                      backgroundColor: colors.cardBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colors.accentCyan,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Summary & Filter Row
          if (_results.isNotEmpty) ...[
            Row(
              children: [
                _buildFilterTab(
                  keyMode: 'all',
                  label: 'Tất cả (${_results.length})',
                  color: colors.accentCyan,
                  colors: colors,
                ),
                const SizedBox(width: 6),
                _buildFilterTab(
                  keyMode: 'issues',
                  label: 'Nhảy IP / Xung đột (${jumpedCount + conflictCount})',
                  color: (jumpedCount + conflictCount) > 0
                      ? colors.accentAmber
                      : colors.textMuted,
                  colors: colors,
                ),
                const SizedBox(width: 6),
                _buildFilterTab(
                  keyMode: 'ok',
                  label: 'Đúng IP & MAC ($okCount)',
                  color: colors.accentEmerald,
                  colors: colors,
                ),
                const SizedBox(width: 6),
                _buildFilterTab(
                  keyMode: 'offline',
                  label: 'Offline ($offlineCount)',
                  color: colors.textMuted,
                  colors: colors,
                ),
                const Spacer(),
                if (pendingJumpedCount > 0) ...[
                  GlassButton(
                    label: 'Cập nhật tất cả IP nhảy ($pendingJumpedCount)',
                    icon: Icons.published_with_changes_rounded,
                    colors: colors,
                    accentColor: colors.accentEmerald,
                    onTap: () => _applyAllJumpedUpdates(deviceService, colors),
                  ),
                  const SizedBox(width: 8),
                ],
                GlassButton(
                  label: 'Sao chép báo cáo',
                  icon: Icons.copy_all_rounded,
                  colors: colors,
                  accentColor: colors.accentPurple,
                  onTap: () => _copyAuditReport(colors),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Results Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.cardBorder),
              ),
              child: _results.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.find_replace_rounded,
                            size: 46,
                            color: colors.textMuted.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _isScanning
                                ? _phaseText
                                : language.t('drift_scanner_idle_hint'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 6,
                        color: colors.cardBorder.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (ctx, i) {
                        final item = filtered[i];
                        final isUpdated = _updatedTargetKeys.contains(
                          _targetKey(item.target),
                        );
                        return _buildResultRow(
                          item,
                          isUpdated,
                          deviceService,
                          colors,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceToggleChip({
    required String label,
    required IconData icon,
    required bool selected,
    required AppColors colors,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.accentCyan.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? colors.accentCyan.withValues(alpha: 0.5)
                : colors.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? colors.accentCyan : colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? colors.accentCyan : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab({
    required String keyMode,
    required String label,
    required Color color,
    required AppColors colors,
  }) {
    final selected = _filterMode == keyMode;
    return InkWell(
      onTap: () => setState(() => _filterMode = keyMode),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : colors.cardBg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.55) : colors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? color : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(
    IpDriftAuditEntry item,
    bool isUpdated,
    DeviceService deviceService,
    AppColors colors,
  ) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    switch (item.status) {
      case IpDriftStatus.jumpedByMac:
      case IpDriftStatus.jumpedByName:
        badgeColor = colors.accentAmber;
        badgeIcon = Icons.swap_horiz_rounded;
        badgeText = 'NHẢY IP';
        break;
      case IpDriftStatus.ipConflict:
        badgeColor = colors.accentRose;
        badgeIcon = Icons.warning_rounded;
        badgeText = 'XUNG ĐỘT MAC/IP';
        break;
      case IpDriftStatus.hostnameMismatch:
        badgeColor = colors.accentPurple;
        badgeIcon = Icons.badge_outlined;
        badgeText = 'LỆCH TÊN MÁY';
        break;
      case IpDriftStatus.onlineOk:
        badgeColor = colors.accentEmerald;
        badgeIcon = Icons.check_circle_rounded;
        badgeText = 'CHUẨN (OK)';
        break;
      case IpDriftStatus.offline:
        badgeColor = colors.textMuted;
        badgeIcon = Icons.portable_wifi_off_rounded;
        badgeText = 'OFFLINE';
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Status Badge
          Container(
            width: 118,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 13, color: badgeColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    badgeText,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Device Name & Expected IP/MAC
          SizedBox(
            width: 215,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.target.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.target.expectedIp} • ${item.target.expectedMac ?? "Chưa lưu MAC"}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Detail Description
          Expanded(
            child: Text(
              item.detailMessage,
              style: TextStyle(
                fontSize: 11.5,
                color: item.isIssue ? colors.textPrimary : colors.textSecondary,
                fontWeight: item.isIssue ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),

          // Action Button for Jumped IP
          if (item.hasJumpedIp) ...[
            const SizedBox(width: 8),
            if (isUpdated)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accentEmerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Đã cập nhật ✓',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colors.accentEmerald,
                  ),
                ),
              )
            else
              GlassButton(
                label: 'Đổi → ${item.discoveredNewIp}',
                icon: Icons.sync_alt_rounded,
                colors: colors,
                accentColor: colors.accentEmerald,
                onTap: () => _applySingleUpdate(item, deviceService, colors),
              ),
          ],
        ],
      ),
    );
  }
}

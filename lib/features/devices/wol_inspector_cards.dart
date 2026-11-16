part of 'wol_inspector_dialog.dart';

class _WolTabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final AppColors colors;
  final VoidCallback? onTap;

  const _WolTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                ? colors.accentCyan.withValues(alpha: 0.55)
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
}

class _WolOsChip extends StatelessWidget {
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _WolOsChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.accentPurple.withValues(alpha: 0.16)
              : colors.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? colors.accentPurple : colors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? colors.accentPurple : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _WolFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final AppColors colors;
  final VoidCallback onTap;

  const _WolFilterPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
}

class _WolReportCard extends StatelessWidget {
  final WolAuditReport report;
  final AppColors colors;
  final LanguageProvider language;
  final bool isExpanded;
  final bool isBusy;
  final bool canSyncMac;
  final VoidCallback onToggleExpand;
  final VoidCallback onFix;
  final VoidCallback onSyncMac;
  final VoidCallback onTestWake;

  const _WolReportCard({
    required this.report,
    required this.colors,
    required this.language,
    required this.isExpanded,
    required this.isBusy,
    required this.canSyncMac,
    required this.onToggleExpand,
    required this.onFix,
    required this.onSyncMac,
    required this.onTestWake,
  });

  (Color, IconData, String) _statusBadge() {
    switch (report.overallStatus) {
      case WolReadinessStatus.ready:
        return (colors.accentEmerald, Icons.check_circle_rounded, 'READY');
      case WolReadinessStatus.partialBiosManual:
        return (colors.accentCyan, Icons.verified_user_rounded, 'VERIFY BIOS');
      case WolReadinessStatus.needsFix:
        return (colors.accentAmber, Icons.build_circle_rounded, 'NEEDS FIX');
      case WolReadinessStatus.unsupportedUsbOnly:
        return (colors.accentRose, Icons.usb_off_rounded, 'USB-LAN ONLY');
      case WolReadinessStatus.authRequired:
        return (colors.accentPurple, Icons.lock_outline_rounded, 'AUTH');
      case WolReadinessStatus.unreachable:
        return (colors.textMuted, Icons.portable_wifi_off_rounded, 'OFFLINE');
    }
  }

  Color _layerColor(WolLayerState s) {
    switch (s) {
      case WolLayerState.pass:
        return colors.accentEmerald;
      case WolLayerState.warn:
        return colors.accentAmber;
      case WolLayerState.fail:
        return colors.accentRose;
      case WolLayerState.unknown:
        return colors.textMuted;
    }
  }

  String _layerTitle(String id) {
    switch (id) {
      case 'bios':
        return language.t('wol_layer_bios');
      case 'driver':
        return language.t('wol_layer_driver');
      case 'persistence':
        return language.t('wol_layer_persistence');
      case 'power':
        return language.t('wol_layer_power');
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (badgeColor, badgeIcon, badgeLabel) = _statusBadge();
    final hasMac =
        report.detectedMac != null && report.detectedMac!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: report.overallStatus == WolReadinessStatus.needsFix
              ? colors.accentAmber.withValues(alpha: 0.45)
              : colors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 112,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        badgeLabel,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.targetName}  (${report.ip})  [${report.os}]',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      [
                        if (hasMac) 'MAC: ${report.detectedMac}',
                        if (report.adapterName?.isNotEmpty == true)
                          report.adapterName!,
                        if (report.modelAndBios?.isNotEmpty == true)
                          report.modelAndBios!,
                      ].join('  •  '),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                if (report.canAutoFix)
                  GlassButton(
                    label: 'Fix WoL',
                    icon: Icons.build_rounded,
                    colors: colors,
                    accentColor: colors.accentEmerald,
                    onTap: onFix,
                  ),
                if (canSyncMac) ...[
                  const SizedBox(width: 6),
                  GlassButton(
                    label: language.t('wol_btn_sync_mac'),
                    icon: Icons.fingerprint_rounded,
                    colors: colors,
                    accentColor: colors.accentCyan,
                    onTap: onSyncMac,
                  ),
                ],
                if (hasMac) ...[
                  const SizedBox(width: 6),
                  GlassButton(
                    label: language.t('wol_btn_test_wake'),
                    icon: Icons.bolt_rounded,
                    colors: colors,
                    accentColor: colors.accentAmber,
                    onTap: onTestWake,
                  ),
                ],
              ],
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: colors.textSecondary,
                ),
                onPressed: onToggleExpand,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: report.layers.map((l) {
              final lc = _layerColor(l.state);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: lc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: lc.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${_layerTitle(l.id)}: ${l.state.name.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: lc,
                  ),
                ),
              );
            }).toList(),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: colors.cardBorder),
            const SizedBox(height: 8),
            ...report.layers.map((l) {
              final lc = _layerColor(l.state);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: lc),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_layerTitle(l.id)}: ${l.summary}'
                        '${l.details.isNotEmpty ? " (${l.details.join(", ")})" : ""}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (report.actionsApplied.isNotEmpty)
              Text(
                '✓ ${report.actionsApplied.join(" • ")}',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.accentEmerald,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (report.needsReboot)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '⚠ Cần khởi động lại máy đích để thay đổi BIOS có hiệu lực.',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.accentAmber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (report.rawError?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  report.rawError!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: colors.accentRose,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

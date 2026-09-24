import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../modules/constants.dart';
import '../services/ota_update_service.dart';
import '../theme/language_provider.dart';
import '../theme/theme_provider.dart';
import 'glass_dialog.dart';

/// Shows the OTA update notification dialog.
Future<void> showGlassUpdateDialog({
  required BuildContext context,
  required UpdatePackageInfo packageInfo,
}) {
  final theme = context.read<ThemeProvider>();
  final isDark = theme.isDark;

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'GlassUpdateDialog',
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.40),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) =>
        GlassUpdateDialog(packageInfo: packageInfo),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.94,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

/// Frosted Glass update prompt and download progress dialog.
class GlassUpdateDialog extends StatefulWidget {
  final UpdatePackageInfo packageInfo;

  const GlassUpdateDialog({super.key, required this.packageInfo});

  @override
  State<GlassUpdateDialog> createState() => _GlassUpdateDialogState();
}

class _GlassUpdateDialogState extends State<GlassUpdateDialog> {
  bool _isUpdating = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startUpdate() async {
    final lang = context.read<LanguageProvider>();
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _progress = 0.05;
      _statusText = lang.t('ota_progress_preparing');
    });

    try {
      await OtaUpdateService().performUpdate(
        widget.packageInfo,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _progress = prog;
              _statusText = lang.t(status);
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final lang = context.watch<LanguageProvider>();
    final isDark = theme.isDark;

    final pkg = widget.packageInfo;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!_isUpdating &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GlassDialog(
        title: lang.t('ota_update_title'),
        icon: Icons.system_update_alt_rounded,
        isDark: isDark,
        width: 540,
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        actions: [
          if (!_isUpdating)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                lang.t('ota_btn_later'),
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isUpdating ? null : _startUpdate,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accentCyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: _isUpdating
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 17),
            label: Text(
              _isUpdating
                  ? lang.t('ota_downloading')
                  : lang.t('ota_btn_update_now'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Version Comparison Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.subCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.subCardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accentCyan, colors.accentColor],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'v$appVersion',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: colors.accentCyan,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              pkg.version.displayVersion,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colors.accentEmerald,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${lang.t('ota_package_size')}: ${pkg.formattedSize}  ·  ${pkg.fileName}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Release Notes / Changelog
            if (pkg.releaseNotes != null &&
                pkg.releaseNotes!.trim().isNotEmpty) ...[
              Text(
                lang.t('ota_release_notes'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.subCardBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.subCardBorder),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    pkg.releaseNotes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // 3. Progress bar when updating
            if (_isUpdating) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: colors.subCardBg,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accentCyan),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.accentCyan,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: colors.accentCyan,
                    ),
                  ),
                ],
              ),
            ],

            // 4. Error message if update failed
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.accentRose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.accentRose.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: colors.accentRose,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.accentRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

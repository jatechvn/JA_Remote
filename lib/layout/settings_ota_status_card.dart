part of 'dashboard_shell.dart';

class _OtaVersionStatusCard extends StatelessWidget {
  const _OtaVersionStatusCard({
    required this.colors,
    required this.language,
    required this.lastCheckStr,
    required this.isCheckingUpdates,
    required this.manualCheckResult,
    required this.onCheckNow,
  });

  final AppColors colors;
  final LanguageProvider language;
  final String lastCheckStr;
  final bool isCheckingUpdates;
  final UpdateCheckResult? manualCheckResult;
  final VoidCallback onCheckNow;

  @override
  Widget build(BuildContext context) {
    final lang = language;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentCyan, colors.accentColor],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lang.t('ota_current_version')}: v${app_constants.appVersion}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${lang.t('ota_last_check')}: $lastCheckStr',
                      style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: isCheckingUpdates ? null : onCheckNow,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accentCyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                icon: isCheckingUpdates
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  isCheckingUpdates
                      ? lang.t('ota_checking')
                      : lang.t('ota_check_now'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // Result banner if checked
          if (manualCheckResult != null) ...[
            const SizedBox(height: 12),
            if (manualCheckResult!.hasUpdate) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accentEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.accentEmerald.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: colors.accentEmerald,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.t('ota_update_available', {
                          'version':
                              manualCheckResult
                                  ?.packageInfo
                                  ?.version
                                  .displayVersion ??
                              '',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.accentEmerald,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (manualCheckResult?.packageInfo != null) {
                          showGlassUpdateDialog(
                            context: context,
                            packageInfo: manualCheckResult!.packageInfo!,
                          );
                        }
                      },
                      child: Text(
                        lang.t('ota_btn_update_now'),
                        style: TextStyle(
                          color: colors.accentEmerald,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (manualCheckResult!.isConnectionSuccess) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accentCyan.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.accentCyan.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: colors.accentCyan,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.t('ota_up_to_date'),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.accentRose.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.accentRose.withValues(alpha: 0.30),
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
                        manualCheckResult!.errorMessage ??
                            lang.t('ota_connection_failed'),
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
        ],
      ),
    );
  }
}

part of 'dashboard_shell.dart';

class _SettingsAboutTab extends StatelessWidget {
  const _SettingsAboutTab({
    required this.colors,
    required this.theme,
    required this.language,
    required this.appVersion,
    required this.isDebug,
  });

  final AppColors colors;
  final ThemeProvider theme;
  final LanguageProvider language;
  final String appVersion;
  final bool isDebug;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colors.accentColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accentColor, colors.accentCyan],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primaryGlow.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'JA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            language.t('about_app_name'),
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          PillBadge(
                            label: isDebug ? 'DEBUG' : 'RELEASE',
                            color: isDebug
                                ? colors.accentAmber
                                : colors.accentEmerald,
                            bg:
                                (isDebug
                                        ? colors.accentAmber
                                        : colors.accentEmerald)
                                    .withValues(alpha: 0.12),
                            border:
                                (isDebug
                                        ? colors.accentAmber
                                        : colors.accentEmerald)
                                    .withValues(alpha: 0.3),
                            fontSize: 9.5,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'v$appVersion • Release 2026-09-15',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            language.t('about_app_desc'),
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          // System Runtime Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.subCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language.t('about_sys_title'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _buildInfoRow(
                  'Hệ điều hành / OS',
                  Platform.operatingSystemVersion,
                  colors,
                ),
                _buildInfoRow('Số nhân CPU', '${theme.cpuCores} Cores', colors),
                _buildInfoRow(
                  'Điểm phần cứng',
                  '${theme.hardwareScore}/100',
                  colors,
                ),
                _buildInfoRow(
                  'Cấu hình đồ họa',
                  '${theme.effectiveTier.label} (${theme.effectiveTier.desc})',
                  colors,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Developer & License Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.subCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language.t('about_dev_title'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                _buildInfoRow(
                  'Tác giả / Author',
                  'Johnny / JA-Tech System',
                  colors,
                ),
                _buildInfoRow(
                  'Bản quyền / License',
                  'MIT License (Open Source)',
                  colors,
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => _openProjectLink(
                        context,
                        'https://jatechvn.github.io/',
                      ),
                      child: const Text('jatechvn.github.io'),
                    ),
                    TextButton(
                      onPressed: () => _openProjectLink(
                        context,
                        'https://github.com/jatechvn/JA_Remote',
                      ),
                      child: const Text('GitHub / JA_Remote'),
                    ),
                  ],
                ),
                _buildInfoRow(
                  'Bộ quy chuẩn',
                  'flutter-app-blueprint v1.0',
                  colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openProjectLink(BuildContext context, String url) async {
    try {
      await Process.start('explorer.exe', [url]);
    } catch (_) {
      if (!context.mounted) return;
      showAppToast(
        context,
        colors: colors,
        message: url,
        icon: Icons.link_rounded,
      );
    }
  }

  Widget _buildInfoRow(String label, String value, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'JetBrains Mono',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

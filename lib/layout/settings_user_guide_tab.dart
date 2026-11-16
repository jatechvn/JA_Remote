part of 'dashboard_shell.dart';

class _SettingsUserGuideTab extends StatelessWidget {
  const _SettingsUserGuideTab({required this.colors, required this.language});

  final AppColors colors;
  final LanguageProvider language;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGuideCard(
            icon: Icons.devices_rounded,
            accent: colors.accentCyan,
            title: language.t('guide_start_title', {
              'version': app_constants.appVersion,
            }),
            desc: language.t('guide_start_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.terminal_rounded,
            accent: colors.accentCyan,
            title: language.t('guide_remote_title', {
              'version': app_constants.appVersion,
            }),
            desc: language.t('guide_remote_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.drive_folder_upload_rounded,
            accent: colors.accentPurple,
            title: language.t('guide_deploy_title'),
            desc: language.t('guide_deploy_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.help_outline_rounded,
            accent: colors.accentCyan,
            title: language.t('guide_data_title', {
              'version': app_constants.appVersion,
            }),
            desc: language.t('guide_data_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.keyboard_rounded,
            accent: colors.accentCyan,
            title: language.t('guide_shortcuts_title'),
            desc: language.t('guide_shortcuts_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.touch_app_rounded,
            accent: colors.accentAmber,
            title: language.t('guide_topbar_title'),
            desc: language.t('guide_topbar_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.speed_rounded,
            accent: colors.accentEmerald,
            title: language.t('guide_tier_title'),
            desc: language.t('guide_tier_desc'),
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.swap_vert_rounded,
            accent: colors.accentPurple,
            title: language.t('guide_scroll_title'),
            desc: language.t('guide_scroll_desc'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

part of 'dashboard_shell.dart';

class TopBarExpandingButton extends StatefulWidget {
  final Widget icon;
  final String? collapsedLabel;
  final String expandedLabel;
  final Color? textColor;
  final VoidCallback onTap;
  final String tooltip;
  final AppColors colors;
  final bool isCompact;

  const TopBarExpandingButton({
    super.key,
    required this.icon,
    this.collapsedLabel,
    required this.expandedLabel,
    this.textColor,
    required this.onTap,
    required this.tooltip,
    required this.colors,
    this.isCompact = false,
  });

  @override
  State<TopBarExpandingButton> createState() => _TopBarExpandingButtonState();
}

class _TopBarExpandingButtonState extends State<TopBarExpandingButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final showLabel =
        _isHovered || (!widget.isCompact && widget.collapsedLabel != null);
    final currentLabel = _isHovered
        ? widget.expandedLabel
        : (widget.collapsedLabel ?? '');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(100),
              splashFactory: NoSplash.splashFactory,
              hoverColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: showLabel ? 11 : 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isHovered
                      ? colors.cardHoverBg.withValues(alpha: 0.35)
                      : colors.subCardBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: _isHovered
                        ? (widget.textColor ?? colors.accentCyan).withValues(
                            alpha: 0.65,
                          )
                        : colors.subCardBorder,
                    width: _isHovered ? 1.2 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? (widget.textColor ?? colors.primaryGlow).withValues(
                              alpha: 0.25,
                            )
                          : Colors.black.withValues(alpha: 0.04),
                      blurRadius: _isHovered ? 10 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.icon,
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      clipBehavior: Clip.none,
                      child: showLabel && currentLabel.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 6),
                                Text(
                                  currentLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    color:
                                        widget.textColor ?? colors.textPrimary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias
typedef TopBarPillButton = TopBarExpandingButton;

class _SettingsTabSelector extends StatelessWidget {
  const _SettingsTabSelector({
    required this.activeTab,
    required this.colors,
    required this.language,
    required this.onTabSelected,
  });

  final int activeTab;
  final AppColors colors;
  final LanguageProvider language;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Row(
        children: [
          _buildItem(0, Icons.tune_rounded, language.t('tab_settings_ui')),
          _buildItem(1, Icons.memory_rounded, language.t('tab_settings_oui')),
          _buildItem(2, Icons.menu_book_rounded, language.t('tab_user_guide')),
          _buildItem(3, Icons.info_outline_rounded, language.t('tab_about')),
        ],
      ),
    );
  }

  Widget _buildItem(int index, IconData icon, String label) {
    final isSelected = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      colors.accentColor,
                      colors.accentCyan.withValues(alpha: 0.85),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : colors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : colors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGlassTuningTab extends StatelessWidget {
  const _SettingsGlassTuningTab({
    required this.colors,
    required this.theme,
    required this.language,
    required this.localCardBlur,
    required this.localCardOpacity,
    required this.localDialogBlur,
    required this.localDialogOpacity,
    required this.localDropdownBlur,
    required this.localDropdownOpacity,
    required this.onCardBlurChanged,
    required this.onCardOpacityChanged,
    required this.onDialogBlurChanged,
    required this.onDialogOpacityChanged,
    required this.onDropdownBlurChanged,
    required this.onDropdownOpacityChanged,
    required this.onResetDefaults,
  });

  final AppColors colors;
  final ThemeProvider theme;
  final LanguageProvider language;
  final double localCardBlur;
  final double localCardOpacity;
  final double localDialogBlur;
  final double localDialogOpacity;
  final double localDropdownBlur;
  final double localDropdownOpacity;
  final ValueChanged<double> onCardBlurChanged;
  final ValueChanged<double> onCardOpacityChanged;
  final ValueChanged<double> onDialogBlurChanged;
  final ValueChanged<double> onDialogOpacityChanged;
  final ValueChanged<double> onDropdownBlurChanged;
  final ValueChanged<double> onDropdownOpacityChanged;
  final VoidCallback onResetDefaults;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: BentoCard(
        colors: colors,
        blurSigma: localCardBlur,
        bgOpacity: localCardOpacity,
        padding: const EdgeInsets.all(16),
        borderRadius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.blur_on_rounded,
                        size: 18,
                        color: colors.accentPurple,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          language.t('settings_card_header'),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: onResetDefaults,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: Text(
                      language.t('settings_default'),
                      style: TextStyle(
                        color: colors.accentCyan,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SettingsGlassSlider(
              label: language.t('settings_card_blur'),
              value: localCardBlur,
              min: 0,
              max: 40,
              colors: colors,
              onChanged: onCardBlurChanged,
            ),
            _SettingsGlassSlider(
              label: language.t('settings_card_opacity'),
              value: localCardOpacity,
              min: 0.05,
              max: 1.0,
              isPercent: true,
              colors: colors,
              onChanged: onCardOpacityChanged,
            ),
            const SizedBox(height: 6),
            Divider(color: colors.subCardBorder, height: 1),
            const SizedBox(height: 6),
            _SettingsGlassSlider(
              label: language.t('settings_dialog_blur'),
              value: localDialogBlur,
              min: 0,
              max: 40,
              colors: colors,
              onChanged: onDialogBlurChanged,
            ),
            _SettingsGlassSlider(
              label: language.t('settings_dialog_opacity'),
              value: localDialogOpacity,
              min: 0.1,
              max: 1.0,
              isPercent: true,
              colors: colors,
              onChanged: onDialogOpacityChanged,
            ),
            const SizedBox(height: 6),
            Divider(color: colors.subCardBorder, height: 1),
            const SizedBox(height: 6),
            _SettingsGlassSlider(
              label: language.t('settings_dropdown_blur'),
              value: localDropdownBlur,
              min: 0,
              max: 40,
              colors: colors,
              onChanged: onDropdownBlurChanged,
            ),
            _SettingsGlassSlider(
              label: language.t('settings_dropdown_opacity'),
              value: localDropdownOpacity,
              min: 0.1,
              max: 1.0,
              isPercent: true,
              colors: colors,
              onChanged: onDropdownOpacityChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGlassSlider extends StatelessWidget {
  const _SettingsGlassSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.isPercent = false,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final bool isPercent;
  final AppColors colors;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final display = isPercent
        ? '${(value * 100).round()}%'
        : '${value.toStringAsFixed(0)}px';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                display,
                style: TextStyle(
                  color: colors.accentCyan,
                  fontSize: 11,
                  fontFamily: 'JetBrains Mono',
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              activeTrackColor: colors.accentColor,
              inactiveTrackColor: colors.subCardBorder,
              thumbColor: colors.accentCyan,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: isPercent ? 19 : 40,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

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

class _SettingsMacOuiTab extends StatefulWidget {
  final AppColors colors;
  final LanguageProvider language;

  const _SettingsMacOuiTab({required this.colors, required this.language});

  @override
  State<_SettingsMacOuiTab> createState() => _SettingsMacOuiTabState();
}

class _SettingsMacOuiTabState extends State<_SettingsMacOuiTab> {
  final _prefixController = TextEditingController();
  final _vendorController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _prefixController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final prefix = _prefixController.text.trim();
    final vendor = _vendorController.text.trim();

    final cleanedOui = MacOuiResolver.cleanOUI(prefix);
    if (cleanedOui == null) {
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_invalid_prefix'),
        icon: Icons.warning_rounded,
        accentColor: widget.colors.accentAmber,
      );
      return;
    }

    if (vendor.isEmpty) {
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_vendor_required'),
        icon: Icons.warning_rounded,
        accentColor: widget.colors.accentAmber,
      );
      return;
    }

    setState(() => _isLoading = true);
    await MacOuiResolver.setCustomMapping(cleanedOui, vendor);
    _prefixController.clear();
    _vendorController.clear();
    if (mounted) {
      setState(() => _isLoading = false);
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_toast_saved', {
          'oui': cleanedOui,
          'vendor': vendor,
        }),
        icon: Icons.check_circle_rounded,
        accentColor: widget.colors.accentEmerald,
      );
    }
  }

  Future<void> _handleDelete(String oui) async {
    setState(() => _isLoading = true);
    await MacOuiResolver.removeCustomMapping(oui);
    if (mounted) {
      setState(() => _isLoading = false);
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_toast_deleted', {'oui': oui}),
        icon: Icons.delete_outline_rounded,
        accentColor: widget.colors.accentRose,
      );
    }
  }

  Future<void> _handleReload() async {
    setState(() => _isLoading = true);
    final count = await MacOuiResolver.loadCustomMappings();
    if (mounted) {
      setState(() => _isLoading = false);
      showAppToast(
        context,
        colors: widget.colors,
        message: widget.language.t('oui_toast_reloaded', {
          'count': count.toString(),
        }),
        icon: Icons.refresh_rounded,
        accentColor: widget.colors.accentCyan,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final lang = widget.language;
    final customEntries = MacOuiResolver.customMap.entries.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header & Actions Bento Card
          BentoCard(
            colors: colors,
            padding: const EdgeInsets.all(14),
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: colors.accentCyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.memory_rounded,
                        color: colors.accentCyan,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        lang.t('oui_header_title'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lang.t('oui_header_desc'),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionButton(
                      icon: Icons.description_outlined,
                      label: lang.t('oui_btn_open_file'),
                      color: colors.accentCyan,
                      onTap: () => MacOuiResolver.openConfigFile(),
                    ),
                    _buildActionButton(
                      icon: Icons.folder_open_rounded,
                      label: lang.t('oui_btn_open_folder'),
                      color: colors.accentEmerald,
                      onTap: () => MacOuiResolver.openConfigFolder(),
                    ),
                    _buildActionButton(
                      icon: Icons.refresh_rounded,
                      label: lang.t('oui_btn_reload'),
                      color: colors.accentAmber,
                      onTap: _handleReload,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Add New OUI Mapping Card
          BentoCard(
            colors: colors,
            padding: const EdgeInsets.all(14),
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.t('oui_input_prefix_label'),
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _prefixController,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.w600,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: lang.t('oui_input_prefix_hint'),
                          hintStyle: TextStyle(
                            color: colors.textMuted.withValues(alpha: 0.6),
                            fontSize: 11.5,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          filled: true,
                          fillColor: colors.subCardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.subCardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.subCardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.accentCyan),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _vendorController,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: lang.t('oui_input_vendor_hint'),
                          hintStyle: TextStyle(
                            color: colors.textMuted.withValues(alpha: 0.6),
                            fontSize: 11.5,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          filled: true,
                          fillColor: colors.subCardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.subCardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.subCardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.accentCyan),
                          ),
                        ),
                        onSubmitted: (_) => _handleSave(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlowingActionButton(
                      height: 36,
                      colors: colors,
                      icon: Icons.add_rounded,
                      label: lang.t('oui_btn_save'),
                      onPressed: _isLoading ? null : _handleSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3. Custom Entries List Card
          BentoCard(
            colors: colors,
            padding: const EdgeInsets.all(14),
            borderRadius: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.t('oui_custom_list_title', {
                        'count': customEntries.length.toString(),
                      }),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      lang.t('oui_status_summary', {
                        'custom': customEntries.length.toString(),
                        'builtin': MacOuiResolver.totalBuiltInCount.toString(),
                      }),
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (customEntries.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.subCardBg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.subCardBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        lang.t('oui_empty_custom', {
                          'count': MacOuiResolver.totalBuiltInCount.toString(),
                        }),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: customEntries.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = customEntries[index];
                      final formattedOui =
                          '${item.key.substring(0, 2)}:${item.key.substring(2, 4)}:${item.key.substring(4, 6)}';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.subCardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.subCardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accentCyan.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: colors.accentCyan.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                formattedOui,
                                style: TextStyle(
                                  color: colors.accentCyan,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'JetBrains Mono',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 12,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.value,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                                color: colors.accentRose,
                              ),
                              tooltip: 'Delete',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () => _handleDelete(item.key),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colors = widget.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

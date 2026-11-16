part of 'dashboard_shell.dart';

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
    required this.localEnableIdleSleep,
    required this.localIdleTimeoutSeconds,
    required this.onCardBlurChanged,
    required this.onCardOpacityChanged,
    required this.onDialogBlurChanged,
    required this.onDialogOpacityChanged,
    required this.onDropdownBlurChanged,
    required this.onDropdownOpacityChanged,
    required this.onEnableIdleSleepChanged,
    required this.onIdleTimeoutChanged,
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
  final bool localEnableIdleSleep;
  final int localIdleTimeoutSeconds;
  final ValueChanged<double> onCardBlurChanged;
  final ValueChanged<double> onCardOpacityChanged;
  final ValueChanged<double> onDialogBlurChanged;
  final ValueChanged<double> onDialogOpacityChanged;
  final ValueChanged<double> onDropdownBlurChanged;
  final ValueChanged<double> onDropdownOpacityChanged;
  final ValueChanged<bool> onEnableIdleSleepChanged;
  final ValueChanged<int> onIdleTimeoutChanged;
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
            const SizedBox(height: 10),
            Divider(color: colors.subCardBorder, height: 1),
            const SizedBox(height: 10),
            // Power Optimizer & Idle Sleep Section
            Row(
              children: [
                Icon(
                  Icons.energy_savings_leaf_rounded,
                  size: 17,
                  color: colors.accentEmerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.t('settings_idle_sleep_title'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        language.t('settings_idle_sleep_desc'),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: localEnableIdleSleep,
                  activeThumbColor: colors.accentEmerald,
                  onChanged: onEnableIdleSleepChanged,
                ),
              ],
            ),
            if (localEnableIdleSleep) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    language.t('settings_idle_timeout_label'),
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  for (final sec in const [12, 30, 60]) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        onTap: () => onIdleTimeoutChanged(sec),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: localIdleTimeoutSeconds == sec
                                ? colors.accentEmerald.withValues(alpha: 0.18)
                                : colors.subCardBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: localIdleTimeoutSeconds == sec
                                  ? colors.accentEmerald.withValues(alpha: 0.6)
                                  : colors.subCardBorder,
                            ),
                          ),
                          child: Text(
                            '${sec}s',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'JetBrains Mono',
                              fontWeight: localIdleTimeoutSeconds == sec
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: localIdleTimeoutSeconds == sec
                                  ? colors.accentEmerald
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
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

part of 'dashboard_shell.dart';

void _showDashboardSettingsDialog({
  required BuildContext context,
  required ThemeProvider theme,
  required LanguageProvider language,
  required String appVersion,
  required bool isDebug,
  required bool Function() isMounted,
}) {
  final colors = theme.colors;
  final origCardBlur = theme.cardBlur;
  final origCardOpacity = theme.cardOpacity;
  final origDialogBlur = theme.dialogBlur;
  final origDialogOpacity = theme.dialogOpacity;
  final origDropdownBlur = theme.dropdownBlur;
  final origDropdownOpacity = theme.dropdownOpacity;
  final origEnableIdleSleep = AppPowerManager.instance.enableIdleSleep;
  final origIdleTimeout = AppPowerManager.instance.idleTimeoutSeconds;

  double localCardBlur = origCardBlur;
  double localCardOpacity = origCardOpacity;
  double localDialogBlur = origDialogBlur;
  double localDialogOpacity = origDialogOpacity;
  double localDropdownBlur = origDropdownBlur;
  double localDropdownOpacity = origDropdownOpacity;
  bool localEnableIdleSleep = origEnableIdleSleep;
  int localIdleTimeoutSeconds = origIdleTimeout;

  int activeTab = 0;

  showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return GlassDialog(
            title: language.t('settings_dialog_title'),
            icon: Icons.tune_rounded,
            isDark: theme.isDark,
            width: 700,
            height: 590,
            contentPadding: EdgeInsets.zero,
            blurSigma: localDialogBlur,
            bgOpacity: localDialogOpacity,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx, false);
                },
                child: Text(
                  language.t('action_cancel'),
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              GlowingActionButton(
                height: 36,
                colors: colors,
                icon: Icons.save_rounded,
                label: language.t('action_save'),
                onPressed: () {
                  theme.saveSettings();
                  unawaited(AppPowerManager.instance.saveSettings());
                  Navigator.pop(ctx, true);
                },
              ),
            ],
            child: Column(
              children: [
                _SettingsTabSelector(
                  activeTab: activeTab,
                  colors: colors,
                  language: language,
                  onTabSelected: (index) {
                    setDialogState(() => activeTab = index);
                  },
                ),
                Divider(color: colors.subCardBorder, height: 1),
                Expanded(
                  child: activeTab == 0
                      ? _SettingsGlassTuningTab(
                          colors: colors,
                          theme: theme,
                          language: language,
                          localCardBlur: localCardBlur,
                          localCardOpacity: localCardOpacity,
                          localDialogBlur: localDialogBlur,
                          localDialogOpacity: localDialogOpacity,
                          localDropdownBlur: localDropdownBlur,
                          localDropdownOpacity: localDropdownOpacity,
                          localEnableIdleSleep: localEnableIdleSleep,
                          localIdleTimeoutSeconds: localIdleTimeoutSeconds,
                          onCardBlurChanged: (v) {
                            setDialogState(() => localCardBlur = v);
                            theme.setLiveGlassmorphism(cardBlur: v);
                          },
                          onCardOpacityChanged: (v) {
                            setDialogState(() => localCardOpacity = v);
                            theme.setLiveGlassmorphism(cardOpacity: v);
                          },
                          onDialogBlurChanged: (v) {
                            setDialogState(() => localDialogBlur = v);
                            theme.setLiveGlassmorphism(dialogBlur: v);
                          },
                          onDialogOpacityChanged: (v) {
                            setDialogState(() => localDialogOpacity = v);
                            theme.setLiveGlassmorphism(dialogOpacity: v);
                          },
                          onDropdownBlurChanged: (v) {
                            setDialogState(() => localDropdownBlur = v);
                            theme.setLiveGlassmorphism(dropdownBlur: v);
                          },
                          onDropdownOpacityChanged: (v) {
                            setDialogState(() => localDropdownOpacity = v);
                            theme.setLiveGlassmorphism(dropdownOpacity: v);
                          },
                          onEnableIdleSleepChanged: (v) {
                            setDialogState(() => localEnableIdleSleep = v);
                            AppPowerManager.instance.setEnableIdleSleep(
                              v,
                              persist: false,
                            );
                          },
                          onIdleTimeoutChanged: (sec) {
                            setDialogState(() => localIdleTimeoutSeconds = sec);
                            AppPowerManager.instance.setIdleTimeoutSeconds(
                              sec,
                              persist: false,
                            );
                          },
                          onResetDefaults: () {
                            setDialogState(() {
                              localCardBlur = 20.0;
                              localCardOpacity = 0.25;
                              localDialogBlur = 20.0;
                              localDialogOpacity = 0.85;
                              localDropdownBlur = 20.0;
                              localDropdownOpacity = 0.95;
                              localEnableIdleSleep = true;
                              localIdleTimeoutSeconds = 12;
                            });
                            theme.setLiveGlassmorphism(
                              cardBlur: 20.0,
                              cardOpacity: 0.25,
                              dialogBlur: 20.0,
                              dialogOpacity: 0.85,
                              dropdownBlur: 20.0,
                              dropdownOpacity: 0.95,
                            );
                            AppPowerManager.instance.setEnableIdleSleep(
                              true,
                              persist: false,
                            );
                            AppPowerManager.instance.setIdleTimeoutSeconds(
                              12,
                              persist: false,
                            );
                          },
                        )
                      : (activeTab == 1
                            ? _SettingsOtaUpdateTab(
                                colors: colors,
                                language: language,
                              )
                            : (activeTab == 2
                                  ? _SettingsMacOuiTab(
                                      colors: colors,
                                      language: language,
                                    )
                                  : (activeTab == 3
                                        ? _SettingsUserGuideTab(
                                            colors: colors,
                                            language: language,
                                          )
                                        : _SettingsAboutTab(
                                            colors: colors,
                                            theme: theme,
                                            language: language,
                                            appVersion: appVersion,
                                            isDebug: isDebug,
                                          )))),
                ),
              ],
            ),
          );
        },
      );
    },
  ).then((saved) {
    if (!isMounted() || saved == true) return;
    theme.setLiveGlassmorphism(
      cardBlur: origCardBlur,
      cardOpacity: origCardOpacity,
      dialogBlur: origDialogBlur,
      dialogOpacity: origDialogOpacity,
      dropdownBlur: origDropdownBlur,
      dropdownOpacity: origDropdownOpacity,
    );
    AppPowerManager.instance.setEnableIdleSleep(
      origEnableIdleSleep,
      persist: false,
    );
    AppPowerManager.instance.setIdleTimeoutSeconds(
      origIdleTimeout,
      persist: false,
    );
  });
}

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
          _buildItem(
            1,
            Icons.system_update_alt_rounded,
            language.t('settings_tab_ota'),
          ),
          _buildItem(2, Icons.memory_rounded, language.t('tab_settings_oui')),
          _buildItem(3, Icons.menu_book_rounded, language.t('tab_user_guide')),
          _buildItem(4, Icons.info_outline_rounded, language.t('tab_about')),
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

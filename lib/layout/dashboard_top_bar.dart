part of 'dashboard_shell.dart';

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.appTitle,
    required this.appVersion,
    required this.isDebug,
    required this.buildTimestamp,
    required this.currentIndex,
    required this.tabIcons,
    required this.onSelectTab,
    required this.onOpenSettings,
  });

  final String appTitle;
  final String appVersion;
  final bool isDebug;
  final String? buildTimestamp;
  final int currentIndex;
  final List<IconData> tabIcons;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    final colors = theme.colors;
    final timestamp = buildTimestamp ?? _getFallbackBuildTimestamp();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _DashboardShellState._mobileBreakpoint;
    final isCompact = screenWidth < 1220;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.headerBg,
        border: Border(
          bottom: BorderSide(color: colors.headerBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Brand Logo + Title + Version Tag
          InkWell(
            onTap: () => onSelectTab(0),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accentColor, colors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primaryGlow.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'JA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          appTitle,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (isDebug) ...[
                          const SizedBox(width: 6),
                          PillBadge(
                            label: 'DEBUG',
                            color: colors.accentAmber,
                            bg: colors.accentAmber.withValues(alpha: 0.15),
                            border: colors.accentAmber.withValues(alpha: 0.4),
                            icon: Icons.bug_report_rounded,
                            fontSize: 9.5,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(
                      width: 130,
                      child: AsymmetricMarqueeText(
                        text: isDebug
                            ? 'v$appVersion ($timestamp)'
                            : 'v$appVersion',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(width: isMobile ? 8 : 20),

          // Sliding Pill Tab Bar (Centered) — hidden on narrow/mobile-width
          // windows in favor of the floating MobileDockNav at the bottom.
          Expanded(
            child: isMobile
                ? const SizedBox.shrink()
                : Center(
                    child: SlidingPillTabBar(
                      colors: colors,
                      currentIndex: currentIndex,
                      tabs: language.tabLabels,
                      icons: tabIcons,
                      onTabSelected: onSelectTab,
                    ),
                  ),
          ),

          SizedBox(width: isMobile ? 8 : 12),

          // Dynamic Island Status Capsule (Compact to reserve space for tabs)
          Builder(
            builder: (ctx) {
              final deviceService = ctx.watch<DeviceService>();
              final power = AppPowerManager.instance;
              final isEcoSleep = power.enableIdleSleep && power.isUserIdle;
              final isPolling = deviceService.isPolling;
              final online = deviceService.onlineCount;
              final total = deviceService.totalCount;

              final String capsuleStatusText;
              final Color capsuleColor;
              if (isEcoSleep) {
                capsuleStatusText = language.t('status_eco_sleep');
                capsuleColor = colors.accentCyan;
              } else if (!isPolling) {
                capsuleStatusText = isCompact
                    ? language.t('status_paused')
                    : '${language.t('status_paused')} • $online/$total';
                capsuleColor = colors.accentAmber;
              } else {
                capsuleStatusText = isCompact
                    ? language.t('status_live')
                    : '${language.t('status_live')} • $online/$total';
                capsuleColor = colors.accentEmerald;
              }

              return Tooltip(
                message: isEcoSleep
                    ? language.t('status_eco_sleep_tooltip')
                    : (isPolling
                          ? '${language.t('status_live')} ($online/$total Online)'
                          : language.t('dev_tooltip_autoping_off')),
                child: DynamicIslandCapsule(
                  colors: colors,
                  isRunning: isPolling && !isEcoSleep,
                  customColor: capsuleColor,
                  statusText: capsuleStatusText,
                  subText: (!isMobile && screenWidth > 1560 && isPolling)
                      ? language.t('status_devices')
                      : null,
                  onTap: () => onSelectTab(0),
                ),
              );
            },
          ),

          const SizedBox(width: 8),

          // 1. Quick Performance Tier Switcher (⚡ Auto / Ultra / Balanced / Lite)
          TopBarExpandingButton(
            icon: Icon(
              theme.effectiveTier.icon,
              color: theme.effectiveTier.color,
              size: 14,
            ),
            collapsedLabel: isCompact ? null : theme.perfLabel,
            expandedLabel: theme.perfLabel,
            textColor: theme.effectiveTier.color,
            isCompact: isCompact,
            tooltip: language.t('perf_tooltip'),
            colors: colors,
            onTap: () {
              theme.cyclePerfTier();
              final langCode = language.currentLanguage.code;
              String msg;
              if (langCode == 'EN') {
                msg =
                    'Graphic Tier: ${theme.perfLabel} (Optimized for ${theme.cpuCores} CPU Cores)';
              } else if (langCode == 'CN') {
                msg = '硬件档位: ${theme.perfLabel} (针对 ${theme.cpuCores} 核处理器优化)';
              } else {
                msg =
                    'Cấu hình máy: ${theme.perfLabel} (Tự động nhận diện CPU ${theme.cpuCores} Cores)';
              }
              showAppToast(
                context,
                message: msg,
                colors: colors,
                icon: Icons.bolt_rounded,
              );
            },
          ),

          const SizedBox(width: 6),

          // 2. Quick Language Switcher (🌐 VI / EN / CN)
          TopBarExpandingButton(
            icon: Icon(
              Icons.language_rounded,
              color: colors.accentCyan,
              size: 14,
            ),
            collapsedLabel: isCompact ? null : language.currentLanguage.code,
            expandedLabel: language.currentLanguage.label,
            textColor: colors.accentCyan,
            isCompact: isCompact,
            tooltip: language.t('lang_tooltip'),
            colors: colors,
            onTap: () {
              language.cycleLanguage();
              showAppToast(
                context,
                message: language.t('lang_changed_msg'),
                colors: colors,
                icon: Icons.language_rounded,
              );
            },
          ),

          const SizedBox(width: 6),

          // 3. 1-Click Theme Toggle Button with Hover Zoom & Full Text
          TopBarExpandingButton(
            icon: Icon(
              theme.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: theme.isDark ? colors.accentAmber : colors.accentPurple,
              size: 14,
            ),
            collapsedLabel: null,
            expandedLabel: language.t(
              theme.isDark ? 'theme_light' : 'theme_dark',
            ),
            textColor: theme.isDark ? colors.accentAmber : colors.accentPurple,
            isCompact: isCompact,
            tooltip: language.t('theme_tooltip'),
            colors: colors,
            onTap: () => theme.toggleTheme(),
          ),

          const SizedBox(width: 6),

          // 4. OTA Update Badge (appears when an update is available)
          ListenableBuilder(
            listenable: OtaUpdateService(),
            builder: (context, _) {
              final ota = OtaUpdateService();
              final hasUpdate = ota.lastCheckResult?.hasUpdate == true;
              if (!hasUpdate) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TopBarExpandingButton(
                    icon: Icon(
                      Icons.system_update_alt_rounded,
                      color: colors.accentEmerald,
                      size: 14,
                    ),
                    collapsedLabel: null,
                    expandedLabel:
                        ota
                            .lastCheckResult
                            ?.packageInfo
                            ?.version
                            .displayVersion ??
                        'Update',
                    textColor: colors.accentEmerald,
                    isCompact: isCompact,
                    tooltip: language.t('ota_update_available', {
                      'version':
                          ota
                              .lastCheckResult
                              ?.packageInfo
                              ?.version
                              .displayVersion ??
                          '',
                    }),
                    colors: colors,
                    onTap: () {
                      if (ota.lastCheckResult?.packageInfo != null) {
                        showGlassUpdateDialog(
                          context: context,
                          packageInfo: ota.lastCheckResult!.packageInfo!,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              );
            },
          ),

          // 5. Glassmorphism Settings Button with Hover Zoom & Full Text
          TopBarExpandingButton(
            icon: Icon(
              Icons.settings_rounded,
              color: colors.textSecondary,
              size: 14,
            ),
            collapsedLabel: null,
            expandedLabel: language.t('settings_btn_label'),
            textColor: colors.accentCyan,
            isCompact: isCompact,
            tooltip: '${language.t('settings_tooltip')} (Ctrl+, • F1)',
            colors: colors,
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

String _getFallbackBuildTimestamp() {
  try {
    final exe = File(Platform.resolvedExecutable);
    final so = File(
      '${exe.parent.path}${Platform.pathSeparator}data${Platform.pathSeparator}app.so',
    );
    final f = so.existsSync() ? so : (exe.existsSync() ? exe : null);
    if (f != null) {
      final dt = f.lastModifiedSync();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    }
  } catch (_) {}
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
}

/// A modern Apple Liquid Glass Pill Button for the Topbar with smooth hover zoom & label expansion
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

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../core/network/mac_oui_resolver.dart';
import '../features/command_runner/command_runner_view.dart';
import '../features/devices/devices_view.dart';
import '../features/discovery/discovery_view.dart';
import '../features/file_deploy/file_deploy_view.dart';
import '../features/logs/logs_view.dart';
import '../modules/constants.dart' as app_constants;
import '../services/app_power_manager.dart';
import '../services/device_service.dart';
import '../services/ota_update_service.dart';
import '../theme/app_colors.dart';
import '../theme/language_provider.dart';
import '../theme/theme_provider.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_update_dialog.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/mobile_dock_nav.dart';
import '../widgets/route_shortcuts.dart';

part 'dashboard_top_bar.dart';
part 'dashboard_shell_settings.dart';
part 'settings_glass_tuning_tab.dart';
part 'settings_user_guide_tab.dart';
part 'settings_about_tab.dart';
part 'settings_mac_oui_tab.dart';
part 'settings_ota_update_tab.dart';
part 'settings_ota_status_card.dart';

class DashboardShell extends StatefulWidget {
  final String appTitle;
  final String appVersion;
  final bool isDebug;
  final String? buildTimestamp;

  const DashboardShell({
    super.key,
    this.appTitle = app_constants.appTitle,
    this.appVersion = app_constants.appVersion,
    this.isDebug = false,
    this.buildTimestamp,
  });

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> with WindowListener {
  int _currentIndex = 0;
  final Set<int> _activatedTabs = {0};
  Timer? _otaTimer;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    AppPowerManager.instance.addListener(_onPowerStateChanged);
    _lifecycleListener = AppLifecycleListener(
      onShow: () {
        AppPowerManager.instance.setWindowVisible(true);
        unawaited(AppPowerManager.instance.syncNativeWindowState());
      },
      onHide: () => AppPowerManager.instance.setWindowVisible(false),
      onResume: () {
        AppPowerManager.instance.setWindowVisible(true);
        AppPowerManager.instance.setWindowFocused(true);
        unawaited(AppPowerManager.instance.syncNativeWindowState());
      },
      onInactive: () => AppPowerManager.instance.setWindowFocused(false),
      onPause: () => AppPowerManager.instance.setWindowVisible(false),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(AppPowerManager.instance.syncNativeWindowState());
      _checkOtaOnStartup();
    });
  }

  void _onPowerStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void onWindowFocus() {
    AppPowerManager.instance.setWindowVisible(true);
    AppPowerManager.instance.setWindowFocused(true);
    unawaited(AppPowerManager.instance.syncNativeWindowState());
  }

  @override
  void onWindowBlur() {
    AppPowerManager.instance.setWindowFocused(false);
    unawaited(AppPowerManager.instance.syncNativeWindowState());
  }

  @override
  void onWindowMinimize() {
    AppPowerManager.instance.setWindowVisible(false);
    AppPowerManager.instance.setWindowFocused(false);
  }

  @override
  void onWindowRestore() {
    AppPowerManager.instance.setWindowVisible(true);
    unawaited(AppPowerManager.instance.syncNativeWindowState());
  }

  @override
  void onWindowMaximize() {
    AppPowerManager.instance.setWindowVisible(true);
    unawaited(AppPowerManager.instance.syncNativeWindowState());
  }

  @override
  void onWindowUnmaximize() {
    AppPowerManager.instance.setWindowVisible(true);
    unawaited(AppPowerManager.instance.syncNativeWindowState());
  }

  void _checkOtaOnStartup() {
    _otaTimer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final ota = OtaUpdateService();
      if (ota.shouldCheckForUpdates(
        interval: ota.config.checkInterval,
        lastCheckTime: ota.config.lastCheckTime,
      )) {
        final result = await ota.checkForUpdates();
        if (result.hasUpdate && result.packageInfo != null && mounted) {
          showGlassUpdateDialog(
            context: context,
            packageInfo: result.packageInfo!,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    AppPowerManager.instance.removeListener(_onPowerStateChanged);
    _lifecycleListener.dispose();
    _otaTimer?.cancel();
    _otaTimer = null;
    super.dispose();
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _tabIcons.length) return;
    setState(() {
      _currentIndex = index;
      _activatedTabs.add(index);
    });
  }

  void _openSettings(
    BuildContext context,
    ThemeProvider theme,
    LanguageProvider language,
  ) {
    _showDashboardSettingsDialog(
      context: context,
      theme: theme,
      language: language,
      appVersion: widget.appVersion,
      isDebug: widget.isDebug,
      isMounted: () => mounted,
    );
  }

  // Below this width the top SlidingPillTabBar hides and MobileDockNav
  // takes over, matching tablet/mobile responsive breakpoints.
  static const double _mobileBreakpoint = 880;

  static const _tabIcons = [
    Icons.devices_rounded,
    Icons.radar_rounded,
    Icons.terminal_rounded,
    Icons.drive_folder_upload_rounded,
    Icons.history_edu_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    _activatedTabs.add(_currentIndex);
    final theme = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    final colors = theme.colors;
    final isMobile = MediaQuery.of(context).size.width < _mobileBreakpoint;

    return RouteShortcuts(
      bindings: {
        for (final entry in [
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.digit3,
          LogicalKeyboardKey.digit4,
          LogicalKeyboardKey.digit5,
        ].asMap().entries)
          SingleActivator(entry.value, control: true): () =>
              _selectTab(entry.key),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            _openSettings(context, theme, language),
        const SingleActivator(LogicalKeyboardKey.f1): () => showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(language.t('guide_shortcuts_title')),
            content: SingleChildScrollView(
              child: Text(language.t('guide_shortcuts_desc')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      },
      child: Focus(
        autofocus: true,
        child: GlassScaffold(
          colors: colors,
          header: _DashboardTopBar(
            appTitle: widget.appTitle,
            appVersion: widget.appVersion,
            isDebug: widget.isDebug,
            buildTimestamp: widget.buildTimestamp,
            currentIndex: _currentIndex,
            tabIcons: _tabIcons,
            onSelectTab: _selectTab,
            onOpenSettings: () => _openSettings(context, theme, language),
          ),
          body: Stack(
            children: [
              Positioned.fill(
                left: 18,
                right: 18,
                top: 0,
                bottom: isMobile ? 84 : 16,
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    DevicesView(
                      key: const ValueKey('Devices'),
                      onNavigateTab: _selectTab,
                      isActive: _currentIndex == 0,
                    ),
                    _activatedTabs.contains(1)
                        ? DiscoveryView(
                            key: const ValueKey('Discovery'),
                            isActive: _currentIndex == 1,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('Discovery_Placeholder'),
                          ),
                    _activatedTabs.contains(2)
                        ? CommandRunnerView(
                            key: const ValueKey('CommandRunner'),
                            isActive: _currentIndex == 2,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('CommandRunner_Placeholder'),
                          ),
                    _activatedTabs.contains(3)
                        ? FileDeployView(
                            key: const ValueKey('FileDeploy'),
                            isActive: _currentIndex == 3,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('FileDeploy_Placeholder'),
                          ),
                    _activatedTabs.contains(4)
                        ? LogsView(
                            key: const ValueKey('Logs'),
                            isActive: _currentIndex == 4,
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('Logs_Placeholder'),
                          ),
                  ],
                ),
              ),
              if (isMobile)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MobileDockNav(
                    colors: colors,
                    currentIndex: _currentIndex,
                    tabs: language.tabLabels,
                    icons: _tabIcons,
                    onTabSelected: _selectTab,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

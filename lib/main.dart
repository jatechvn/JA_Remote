import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'theme/theme_provider.dart';
import 'theme/language_provider.dart';
import 'layout/dashboard_shell.dart';
import 'widgets/command_palette.dart';
import 'widgets/app_toast.dart';
import 'modules/build_info.dart';
import 'modules/logger_config.dart';
import 'modules/window_helper.dart';
import 'services/app_power_manager.dart';
import 'services/device_service.dart';
import 'services/discovery_service.dart';
import 'core/network/mac_oui_resolver.dart';
import 'core/utils/app_storage.dart';
import 'features/devices/ip_drift_scanner_dialog.dart';
import 'features/devices/port_scanner_dialog.dart';
import 'features/devices/wol_inspector_dialog.dart';

void main(List<String> args) async {
  PowerAwareWidgetsFlutterBinding.ensureInitialized();

  if (args.contains('-debug') ||
      args.contains('--debug') ||
      args.contains('-d')) {
    BuildInfo.isCliDebug = true;
  }
  setupLogger();

  await initGlassWindow(
    title: 'JA Remote - TE PC Manager',
    size: const Size(1280, 840),
    minSize: const Size(800, 560),
  );

  await AppStorage.migrateLegacyFolderIfNeeded();
  await AppPowerManager.instance.loadSettings();
  final themeProvider = await ThemeProvider.create();
  final languageProvider = await LanguageProvider.create();
  await MacOuiResolver.initialize();

  runApp(
    JaRemoteApp(
      themeProvider: themeProvider,
      languageProvider: languageProvider,
    ),
  );
}

class JaRemoteApp extends StatelessWidget {
  final ThemeProvider? themeProvider;
  final LanguageProvider? languageProvider;
  const JaRemoteApp({super.key, this.themeProvider, this.languageProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider ?? ThemeProvider()),
        ChangeNotifierProvider.value(
          value: languageProvider ?? LanguageProvider(),
        ),
        ChangeNotifierProvider(create: (_) => DeviceService()),
        ChangeNotifierProvider(create: (_) => DiscoveryService()),
      ],
      child: const _AppContent(),
    );
  }
}

class _AppContent extends StatelessWidget {
  const _AppContent();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;

    return MaterialApp(
      title: 'JA Remote - TE PC Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: theme.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppPowerManager.instance.indicatorsAnimationNotifier,
          builder: (context, shouldAnimateIndicators, gatedChild) {
            return TickerMode(
              enabled: shouldAnimateIndicators,
              child: gatedChild!,
            );
          },
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) =>
                AppPowerManager.instance.recordUserInteraction(),
            onPointerMove: (_) =>
                AppPowerManager.instance.recordUserInteraction(),
            onPointerSignal: (_) =>
                AppPowerManager.instance.recordUserInteraction(),
            onPointerPanZoomUpdate: (_) =>
                AppPowerManager.instance.recordUserInteraction(),
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (_, _) {
                AppPowerManager.instance.recordUserInteraction();
                return KeyEventResult.ignored;
              },
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: Builder(
        builder: (ctx) {
          final deviceService = ctx.read<DeviceService>();
          final discovery = ctx.read<DiscoveryService>();
          final language = ctx.read<LanguageProvider>();

          return CommandPaletteShortcut(
            items: () => [
              CommandPaletteItem(
                label: language.t('drift_scanner_title'),
                subtitle:
                    'Quét phát hiện máy bị nhảy IP DHCP, xung đột MAC hoặc đổi tên máy',
                icon: Icons.find_replace_rounded,
                keywords: const [
                  'ip',
                  'drift',
                  'nhay ip',
                  'mac',
                  'conflict',
                  'xung dot',
                ],
                onSelect: () => showIpDriftScannerDialog(ctx),
              ),
              CommandPaletteItem(
                label: 'Chuyển Theme Sáng / Tối',
                subtitle: 'Đổi chế độ giao diện 1-Click',
                icon: Icons.brightness_4_rounded,
                onSelect: () => theme.toggleTheme(),
              ),
              CommandPaletteItem(
                label: 'Quét lại Ping tất cả máy',
                subtitle: 'Gửi gói tin ICMP kiểm tra trạng thái máy',
                icon: Icons.refresh_rounded,
                onSelect: () {
                  deviceService.refreshAllStatus();
                  showAppToast(
                    ctx,
                    colors: colors,
                    message: 'Đang kiểm tra kết nối thiết bị...',
                    icon: Icons.sync_rounded,
                  );
                },
              ),
              CommandPaletteItem(
                label: 'Bật / Tắt Auto-Ping tự động (10s)',
                subtitle: deviceService.isPolling
                    ? 'Đang bật — Nhấn để tạm dừng quét định kỳ'
                    : 'Đang tắt — Nhấn để bật lại quét định kỳ',
                icon: deviceService.isPolling
                    ? Icons.pause_circle_outline_rounded
                    : Icons.autorenew_rounded,
                keywords: const ['autoping', 'polling', 'ping', 'tam dung'],
                onSelect: () {
                  deviceService.togglePolling();
                  showAppToast(
                    ctx,
                    colors: colors,
                    message: deviceService.isPolling
                        ? 'Đã bật Auto-Ping định kỳ (10s)!'
                        : 'Đã tạm dừng Auto-Ping định kỳ!',
                    icon: deviceService.isPolling
                        ? Icons.autorenew_rounded
                        : Icons.pause_circle_outline_rounded,
                  );
                },
              ),
              CommandPaletteItem(
                label: 'Chọn nhanh tất cả máy đang Online',
                subtitle:
                    'Chỉ chọn các máy đang phản hồi Ping trong danh sách hiện tại',
                icon: Icons.fact_check_rounded,
                keywords: const ['select', 'online', 'chon may online'],
                onSelect: () {
                  deviceService.selectOnlyOnline();
                  showAppToast(
                    ctx,
                    colors: colors,
                    message:
                        'Đã chọn ${deviceService.selectedIds.length} máy đang Online!',
                    icon: Icons.check_circle_rounded,
                    accentColor: colors.accentEmerald,
                  );
                },
              ),
              CommandPaletteItem(
                label: 'Bật / Tắt chế độ ngủ rảnh tay (Idle Sleep Mode)',
                subtitle: AppPowerManager.instance.enableIdleSleep
                    ? 'Đang bật (${AppPowerManager.instance.idleTimeoutSeconds}s) — Giảm 0% GPU nền khi rảnh'
                    : 'Đang tắt — Nhấn để bật tiết kiệm GPU khi rảnh',
                icon: Icons.energy_savings_leaf_rounded,
                keywords: const ['idle', 'sleep', 'eco', 'gpu', 'power'],
                onSelect: () {
                  final next = !AppPowerManager.instance.enableIdleSleep;
                  AppPowerManager.instance.setEnableIdleSleep(next);
                  showAppToast(
                    ctx,
                    colors: colors,
                    message: next
                        ? 'Đã bật chế độ ngủ rảnh tay (Idle Sleep Mode)!'
                        : 'Đã tắt chế độ ngủ rảnh tay!',
                    icon: Icons.energy_savings_leaf_rounded,
                    accentColor: colors.accentEmerald,
                  );
                },
              ),
              CommandPaletteItem(
                label: 'Quét mạng LAN (Subnet Discovery)',
                subtitle: 'Dò tìm máy tính đang bật trong dải IP',
                icon: Icons.radar_rounded,
                onSelect: () {
                  discovery.startScan();
                  showAppToast(
                    ctx,
                    colors: colors,
                    message: 'Đã kích hoạt quét dải mạng LAN!',
                    icon: Icons.radar_rounded,
                    accentColor: colors.accentCyan,
                  );
                },
              ),
              CommandPaletteItem(
                label: 'Bật máy các máy đã chọn (WOL)',
                subtitle: 'Gửi Magic Packet đánh thức thiết bị qua mạng',
                icon: Icons.bolt_rounded,
                onSelect: () {
                  deviceService.batchWakeSelected();
                  showAppToast(
                    ctx,
                    colors: colors,
                    message: 'Đã gửi gói Wake-on-LAN!',
                    icon: Icons.bolt_rounded,
                    accentColor: colors.accentEmerald,
                  );
                },
              ),
              CommandPaletteItem(
                label: 'Kiểm tra & Tối ưu Wake-on-LAN (Check / Fix WoL)',
                subtitle:
                    'Kiểm tra 4 tầng BIOS, Driver, Persistence, Fast Startup và sửa tự động',
                icon: Icons.settings_power_rounded,
                keywords: const [
                  'wol',
                  'wake',
                  'magic packet',
                  'bios',
                  'check wol',
                  'fix wol',
                ],
                onSelect: () => showWolInspectorDialog(ctx),
              ),
              CommandPaletteItem(
                label: 'Khôi phục Glass Tuning',
                subtitle: 'Đặt lại Blur và Opacity về chuẩn mặc định',
                icon: Icons.restore_rounded,
                onSelect: () {
                  theme.resetToDefaults();
                  showAppToast(
                    ctx,
                    colors: colors,
                    message: 'Đã khôi phục Glass Tuning!',
                    icon: Icons.check_circle_rounded,
                    accentColor: colors.accentCyan,
                  );
                },
              ),
              CommandPaletteItem(
                label: language.t('port_scanner_title'),
                subtitle: language.t('port_scanner_desc'),
                icon: Icons.radar_rounded,
                keywords: const ['port', 'scanner', 'tcp', 'test', 'quet cong'],
                onSelect: () => showPortScannerDialog(ctx),
              ),
            ],
            child: DashboardShell(
              appTitle: 'JA Remote - TE PC Manager',
              appVersion: BuildInfo.version,
              isDebug: BuildInfo.isDebug,
              buildTimestamp: BuildInfo.debugTimestamp,
            ),
          );
        },
      ),
    );
  }
}

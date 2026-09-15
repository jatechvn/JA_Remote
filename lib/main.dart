import 'dart:io';
import 'package:flutter/foundation.dart';
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
import 'services/device_service.dart';
import 'services/discovery_service.dart';
import 'core/network/mac_oui_resolver.dart';
import 'core/utils/app_storage.dart';
import 'features/devices/port_scanner_dialog.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

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

    final showTitle = kIsWeb || !Platform.isWindows || theme.isWin11;

    return MaterialApp(
      title: showTitle ? 'JA Remote - TE PC Manager' : '',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: theme.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Builder(
        builder: (ctx) {
          final deviceService = ctx.read<DeviceService>();
          final discovery = ctx.read<DiscoveryService>();
          final language = ctx.read<LanguageProvider>();

          return CommandPaletteShortcut(
            items: () => [
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

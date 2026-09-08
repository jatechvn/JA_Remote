import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// One-line helper to initialize a transparent, hardware-accelerated desktop window
/// with Windows 10 Aero (0ms drag latency) and Windows 11 Mica / Acrylic backdrop.
///
/// Call this inside [main()] before [runApp()]:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await initGlassWindow(title: 'My Custom App');
///   runApp(const MyApp());
/// }
/// ```
Future<void> initGlassWindow({
  String title = 'JA Application',
  Size size = const Size(1200, 820),
  Size minSize = const Size(760, 520),
  bool center = true,
}) async {
  if (kIsWeb ||
      (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS)) {
    return;
  }

  try {
    await windowManager.ensureInitialized();

    // Detect Windows 11 (Build >= 22000)
    bool isWin11 = false;
    if (Platform.isWindows) {
      try {
        final versionStr = Platform.operatingSystemVersion;
        final match = RegExp(r'Build\s+(\d+)').firstMatch(versionStr);
        if (match != null) {
          final buildNumber = int.tryParse(match.group(1) ?? '') ?? 0;
          isWin11 = buildNumber >= 22000;
        }
      } catch (_) {}
    }

    // Hide title on Windows 10 to eliminate GDI text bounding box artifact.
    // Windows 11 supports native title bar composition with Acrylic.
    final effectiveTitle = (Platform.isWindows && !isWin11) ? '' : title;

    // Deliberately no titleBarStyle / backgroundColor here — window_manager is
    // only used for size/position/focus/close-prevention. Composition (blur,
    // acrylic, dark-mode title bar) is owned entirely by the native
    // theme_win10.cpp / theme_win11.cpp runner code. See flutter-windows-themer
    // skill: window_manager's SetBackgroundColor sets its own competing
    // SetWindowCompositionAttribute accent policy, causing murky double-blur ("bị đục").
    final windowOptions = WindowOptions(
      size: size,
      minimumSize: minSize,
      center: center,
      skipTaskbar: false,
      title: effectiveTitle,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();

      if (Platform.isWindows) {
        if (!isWin11) {
          await windowManager.setTitle('');
        }
      }
    });
  } catch (e) {
    debugPrint('Window manager error: $e');
  }
}

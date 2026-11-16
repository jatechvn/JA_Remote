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

    // Always set the application title so the window title bar, Taskbar,
    // and Alt+Tab show the proper app name instead of the executable name.
    final effectiveTitle = title;

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
      await windowManager.setTitle(effectiveTitle);
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    debugPrint('Window manager error: $e');
  }
}

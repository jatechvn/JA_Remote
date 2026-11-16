# windows/runner/ Directory Guide

Native C++ Win32 runner hosting the Flutter engine, DWM glass composition, window chrome metadata, and PE executable resources.

## Modules & Responsibilities

- `main.cpp` & `utils.cpp` / `utils.h`: Win32 entrypoint (`wWinMain`), attaches console/stdout for CLI flags (`-debug` / `--debug`), initializes COM, and launches `FlutterWindow` with title `'JA Remote - TE PC Manager'`.
- `win32_window.cpp` & `win32_window.h`: Owns HWND creation (`CreateWindow` always passes `title.c_str()` so Taskbar/Alt+Tab show app title on both Win10 and Win11), DPI scaling, resize forwarding, and `WM_ACTIVATE` handling (`if (child_content_ != nullptr && LOWORD(wparam) != WA_INACTIVE) SetFocus(child_content_)` to avoid stealing focus when deactivating).
- `flutter_window.cpp` & `flutter_window.h`: Hosts `flutter::FlutterViewController`, registers plugins, exposes the `ja_remote/theme` MethodChannel (`setTheme`), and defers `Show()` until first frame callback.
- `theme_common.h`, `theme_win10.cpp` / `.h`, `theme_win11.cpp` / `.h`: Single composition owner for Windows 10 Aero (`ACCENT_ENABLE_BLURBEHIND`, 1px top margin) and Windows 11 Acrylic (`ACCENT_ENABLE_ACRYLICBLURBEHIND`, full `-1` margins, `DWMWA_SYSTEMBACKDROP_TYPE`, `DWMWA_USE_IMMERSIVE_DARK_MODE`). Kept independent from `window_manager` background styles to prevent double-blur opacity bugs.
- `Runner.rc`, `resource.h`, `runner.exe.manifest`, `resources/app_icon.ico`: Windows PE VersionInfo (`FileDescription`: `"JA Remote - TE PC Manager"`, `ProductName` / `InternalName`: `"JA Remote"`), 7-layer multi-resolution `.ico`, and UAC/DPI manifest.

## Verification

- Metadata regression: `flutter test test/release_metadata_test.dart`
- Native compilation check (when C++ files change and release build is explicitly requested): `flutter build windows --release`

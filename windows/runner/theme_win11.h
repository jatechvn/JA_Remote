#ifndef RUNNER_THEME_WIN11_H_
#define RUNNER_THEME_WIN11_H_

#include <windows.h>

// True when running on Windows 11 (build >= 22000) or later. Reads the
// registry directly instead of VersionHelpers.h, which has no dedicated
// Win11 check and depends on the app manifest's declared-compatible OS list.
bool IsWindows11OrGreater();

// Applies Windows 11 theming to `hwnd`: dark-mode title bar, native Acrylic
// system backdrop, and client-area blur-behind.
//
// `is_startup` only affects the dark-mode call's semantics at the native
// window-create site — the glass-extension/backdrop/accent-policy calls
// below run unconditionally on every invocation regardless of this flag.
// See flutter-windows-themer skill §2.1 for why: a plugin's native code
// (e.g. window_manager's SetTitleBarStyle) can silently reset the glass
// extension to {0,0,0,0} after startup, so every subsequent theme sync
// must re-assert it or blur silently stops working with no code change
// in between to explain it.
void ApplyThemeWin11(HWND hwnd, bool is_dark, bool is_startup);

#endif  // RUNNER_THEME_WIN11_H_

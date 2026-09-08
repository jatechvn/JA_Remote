#ifndef RUNNER_THEME_WIN10_H_
#define RUNNER_THEME_WIN10_H_

#include <windows.h>

// Applies Windows 10 theming to `hwnd`: dark-mode title bar plus classic
// Aero blur-behind on the client area (Windows 10 has no native Acrylic —
// see flutter-windows-themer skill §2.2 for why Aero, not Acrylic, is used
// here, and why the frame-extension margins are {0,0,1,0} not {-1,-1,-1,-1}).
void ApplyThemeWin10(HWND hwnd, bool is_dark);

#endif  // RUNNER_THEME_WIN10_H_

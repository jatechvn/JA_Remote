#ifndef RUNNER_THEME_COMMON_H_
#define RUNNER_THEME_COMMON_H_

#include <windows.h>

// Undocumented SetWindowCompositionAttribute API (user32.dll) — shared by
// the Windows 10 (Aero blur-behind) and Windows 11 (Acrylic client-area
// blur) theming implementations. See theme_win10.cpp / theme_win11.cpp.

enum ACCENT_STATE {
  ACCENT_DISABLED = 0,
  ACCENT_ENABLE_GRADIENT = 1,
  ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
  ACCENT_ENABLE_BLURBEHIND = 3,
  ACCENT_ENABLE_ACRYLICBLURBEHIND = 4,
  ACCENT_INVALID_STATE = 5
};

struct ACCENT_POLICY {
  ACCENT_STATE AccentState;
  DWORD AccentFlags;
  DWORD GradientColor;
  DWORD AnimationId;
};

enum WINDOWCOMPOSITIONATTRIB {
  WCA_ACCENT_POLICY = 19,
};

struct WINDOWCOMPOSITIONATTRIBDATA {
  WINDOWCOMPOSITIONATTRIB Attrib;
  PVOID pvData;
  SIZE_T cbData;
};

typedef BOOL(WINAPI* pSetWindowCompositionAttribute)(HWND,
                                                       WINDOWCOMPOSITIONATTRIBDATA*);

#endif  // RUNNER_THEME_COMMON_H_

#include "theme_win10.h"

#include <dwmapi.h>

#include "theme_common.h"

void ApplyThemeWin10(HWND hwnd, bool is_dark) {
  BOOL enable_dark_mode = is_dark ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, 19, &enable_dark_mode, sizeof(enable_dark_mode));
  DwmSetWindowAttribute(hwnd, 20, &enable_dark_mode, sizeof(enable_dark_mode));

  HMODULE hUser = GetModuleHandleA("user32.dll");
  if (hUser) {
    pSetWindowCompositionAttribute setWindowCompAttr =
        (pSetWindowCompositionAttribute)GetProcAddress(
            hUser, "SetWindowCompositionAttribute");
    if (setWindowCompAttr) {
      int alpha = 0x66;  // ~40% opacity
      if (alpha == 0) alpha = 1;  // Zero-alpha guard — composition renders
                                  // solid black if alpha is exactly 0.

      int r = is_dark ? 0x1B : 0xF3;
      int g = is_dark ? 0x15 : 0xF4;
      int b = is_dark ? 0x14 : 0xF6;
      int tint_color = (alpha << 24) | (b << 16) | (g << 8) | r;  // ABGR

      ACCENT_POLICY policy = {ACCENT_ENABLE_BLURBEHIND, 2,
                               static_cast<DWORD>(tint_color), 0};
      WINDOWCOMPOSITIONATTRIBDATA data = {WCA_ACCENT_POLICY, &policy,
                                           sizeof(policy)};
      setWindowCompAttr(hwnd, &data);
    }
  }

  // Extend only the top by 1px to authorize transparent backdrop
  // composition without DWM drawing duplicate borders inside the client
  // area (full {-1,-1,-1,-1} extension is a Win11-only trick — see
  // theme_win11.cpp).
  MARGINS margins = {0, 0, 1, 0};
  DwmExtendFrameIntoClientArea(hwnd, &margins);

  // Only trigger frame resize repaint if the window is currently visible
  if (IsWindowVisible(hwnd)) {
    RECT rect;
    GetWindowRect(hwnd, &rect);
    SetWindowPos(hwnd, nullptr, 0, 0, (rect.right - rect.left) - 1,
                 (rect.bottom - rect.top),
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    SetWindowPos(hwnd, nullptr, 0, 0, (rect.right - rect.left),
                 (rect.bottom - rect.top),
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);

    SendMessage(hwnd, WM_NCACTIVATE, FALSE, 0);
    SendMessage(hwnd, WM_NCACTIVATE, TRUE, 0);
  }
}

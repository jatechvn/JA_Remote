#include "theme_win11.h"

#include <dwmapi.h>
#include <cstdlib>

#include "theme_common.h"

bool IsWindows11OrGreater() {
  wchar_t buffer[32] = {0};
  DWORD buffer_size = sizeof(buffer);
  LSTATUS status =
      RegGetValueW(HKEY_LOCAL_MACHINE,
                   L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion",
                   L"CurrentBuildNumber", RRF_RT_REG_SZ, nullptr, buffer,
                   &buffer_size);
  if (status != ERROR_SUCCESS) return false;
  return _wtoi(buffer) >= 22000;
}

void ApplyThemeWin11(HWND hwnd, bool is_dark, bool is_startup) {
  BOOL enable_dark_mode = is_dark ? TRUE : FALSE;
  DwmSetWindowAttribute(hwnd, 20, &enable_dark_mode,
                         sizeof(enable_dark_mode));  // DWMWA_USE_IMMERSIVE_DARK_MODE

  // UNCONDITIONAL — every call, not gated by is_startup. See theme_win11.h:
  // a third-party native plugin resetting this to {0,0,0,0} after our
  // is_startup=true call already ran is what makes blur silently stop
  // working, so re-asserting here on every subsequent theme sync is what
  // actually keeps it alive.
  MARGINS margins = {-1, -1, -1, -1};
  DwmExtendFrameIntoClientArea(hwnd, &margins);

  int r = is_dark ? 0x0B : 0xF8, g = is_dark ? 0x0F : 0xFA,
      b = is_dark ? 0x19 : 0xFC;

  // Client-area blur (ACCENT_STATE / ACCENT_POLICY / WINDOWCOMPOSITIONATTRIBDATA
  // struct defs shared with theme_win10.cpp via theme_common.h).
  HMODULE hUser = GetModuleHandleA("user32.dll");
  if (hUser) {
    pSetWindowCompositionAttribute setWindowCompAttr =
        (pSetWindowCompositionAttribute)GetProcAddress(
            hUser, "SetWindowCompositionAttribute");
    if (setWindowCompAttr) {
      int alpha = 0x4D;  // ~30% — Win11's material already carries its own
                          // noise/blur, so a lighter tint reads correctly.
      if (alpha == 0) alpha = 1;  // Zero-alpha guard
      int tint_color = (alpha << 24) | (b << 16) | (g << 8) | r;  // ABGR
      ACCENT_POLICY policy = {ACCENT_ENABLE_ACRYLICBLURBEHIND, 2,
                               static_cast<DWORD>(tint_color), 0};
      WINDOWCOMPOSITIONATTRIBDATA data = {WCA_ACCENT_POLICY, &policy,
                                           sizeof(policy)};
      setWindowCompAttr(hwnd, &data);
    }
  }

  // Title-bar blur — also unconditional, every call, after the
  // accent-policy call above. With the glass extension no longer being
  // wiped out from under it, this combo blurs BOTH the title bar and the
  // client area correctly at the same time.
  int backdrop_type = 3;  // DWMSBT_TRANSIENTWINDOW (Acrylic)
  DwmSetWindowAttribute(hwnd, 38, &backdrop_type,
                         sizeof(backdrop_type));  // DWMWA_SYSTEMBACKDROP_TYPE
  BOOL use_host_backdrop_brush = TRUE;
  DwmSetWindowAttribute(
      hwnd, 17, &use_host_backdrop_brush,
      sizeof(use_host_backdrop_brush));  // DWMWA_USE_HOSTBACKDROPBRUSH
}

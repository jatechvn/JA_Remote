# lib/layout/ Directory Guide

Top-level application shell, header bar, native window lifecycle wiring, and Settings modal.

## Library Structure (`part` of `lib/layout/dashboard_shell.dart`)

External callers only import `package:ja_remote/layout/dashboard_shell.dart`. All UI subcomponents share library scope via `part`:

- `lib/layout/dashboard_shell.dart`: `DashboardShell` stateful host managing active tab (`IndexedStack` with lazy activation via `_activatedTabs`), `RouteShortcuts` (`Ctrl+1..5`, `Ctrl+,`, `F1`), `WindowListener` + `AppLifecycleListener` forwarding to `AppPowerManager`, and startup OTA timer.
- `lib/layout/dashboard_top_bar.dart`: `_DashboardTopBar` (brand badge, `AsymmetricMarqueeText` version/timestamp, `SlidingPillTabBar`, `DynamicIslandCapsule` status with `LIVE • online/total` vs `ECO • SLEEP`, quick tier/language/theme/OTA controls, `TopBarExpandingButton`).
- `lib/layout/dashboard_shell_settings.dart`: `_showDashboardSettingsDialog` launcher and `_SettingsTabSelector`. Enforces **live-preview with Cancel rollback** for both `ThemeProvider` glass sliders and `AppPowerManager` Idle Sleep settings (`enableIdleSleep`, `idleTimeoutSeconds`).
- `lib/layout/settings_glass_tuning_tab.dart`: `_SettingsGlassTuningTab` + `_SettingsGlassSlider` (blur/opacity tuning + Idle Sleep toggle & `12s`/`30s`/`60s` timeout selector).
- `lib/layout/settings_ota_update_tab.dart`: `_SettingsOtaUpdateTab` (SMB/UNC path, DPAPI-backed credentials, interval selector, connection test).
- `lib/layout/settings_ota_status_card.dart`: `_OtaVersionStatusCard` (current version, last check timestamp, manual check button & update/error banners).
- `lib/layout/settings_mac_oui_tab.dart`: `_SettingsMacOuiTab` (`mac_oui.json` custom vendor rule CRUD + explorer shortcuts).
- `lib/layout/settings_user_guide_tab.dart`: `_SettingsUserGuideTab` (localized operational cards).
- `lib/layout/settings_about_tab.dart`: `_SettingsAboutTab` (app metadata, detected CPU/tier runtime profile, project links).

## Verification

- `flutter test test/dashboard_shortcuts_test.dart test/tab_persistence_test.dart test/app_power_manager_test.dart`

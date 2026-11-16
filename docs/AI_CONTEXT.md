# AI Context — JA Remote Architecture & Navigation Map

Navigation guide for **JA Remote - TE PC Manager** (Flutter Windows x64 Desktop + C++ Win32 DWM Runner). Keep code changes localized to the owning subsystem and always preserve state-management (`Provider` + `ChangeNotifier`) and visual Liquid Glass styling.

## 1. Specifications & Documentation Pointers

- **Workspace rules & safety**: `AGENTS.md` (read first; explains build/cleanup constraints and Vietnamese response convention).
- **Operational specification**: `USERGUIDE.md` (shortcuts, device management, Command Runner, File Deployer, Port Scanner, LAN OTA Update).
- **Subsystem specs**: `docs/OTA_UPDATE.md` (OTA manifest & SHA-256 checksum flow), `docs/FILE_DEPLOY_AUTOKILL_PLAN.md` (Restart Manager unlock & rollback contract), `docs/benchmarks/REPORT.md` (supernet `/21` scan metrics).
- **Project overview & setup**: `README.md`, `CHANGELOG.md`, `ABOUT.txt`.
- **Current status & verification log**: `docs/AI_HANDOFF.md`.

## 2. Module & Directory Map

### Application Bootstrap & Top-Level Layout
- `lib/main.dart`: Entrypoint (`PowerAwareWidgetsFlutterBinding`, `AppPowerManager`, `initGlassWindow`, `AppStorage.migrateLegacyFolderIfNeeded`), `MultiProvider`, global `TickerMode` + input interaction detector, `CommandPaletteShortcut`.
- `lib/modules`: App identity & constants (`lib/modules/constants.dart`), build/CLI debug flags (`lib/modules/build_info.dart`), debug/release logger setup (`lib/modules/logger_config.dart`), and Win10/11 window initialization (`lib/modules/window_helper.dart`).
- `lib/layout`: Top-level `DashboardShell`, `WindowListener` / `AppLifecycleListener` hookup (`lib/layout/dashboard_shell.dart`), header bar & pill buttons (`lib/layout/dashboard_top_bar.dart`), settings dialog & 5 settings tabs (`lib/layout/dashboard_shell_settings.dart`, `lib/layout/settings_glass_tuning_tab.dart`, `lib/layout/settings_ota_update_tab.dart`, `lib/layout/settings_ota_status_card.dart`, `lib/layout/settings_mac_oui_tab.dart`, `lib/layout/settings_user_guide_tab.dart`, `lib/layout/settings_about_tab.dart`). See `lib/layout/INDEX.md`.

### Feature Screens & Dialogs (`lib/features/`)
- `lib/features/devices`: Managed TE workstations table, sort/filter/search, floating batch dock (`lib/features/devices/devices_view.dart`), plus add/detail dialogs, TCP Port Scanner dialog, Smart IP Drift & MAC Conflict Auditor dialog, and 4-layer Wake-on-LAN Auditor & Auto-Fix dialog (`lib/features/devices/wol_inspector_dialog.dart`, `lib/features/devices/wol_inspector_controls.dart`, `lib/features/devices/wol_inspector_cards.dart`). See `lib/features/devices/INDEX.md`.
- `lib/features/discovery`: LAN `/24` & `/21` subnet scanner UI, adapter switcher, table/grid/list views (`lib/features/discovery/discovery_view.dart`).
- `lib/features/command_runner`: Multi-device PowerShell/WinRM & SSH batch script runner with preset/custom templates, credentials, and live terminal output (`lib/features/command_runner/command_runner_view.dart`).
- `lib/features/file_deploy`: Multi-device file/folder deployment UI for Windows WinRM/SMB & Linux SFTP with pre/post hooks, failed-host selection/retry, and deploy log (`lib/features/file_deploy/file_deploy_view.dart`).
- `lib/features/logs`: Session audit logs viewer and search/status filtering (`lib/features/logs/logs_view.dart`).

### Stateful & Domain Services (`lib/services/`)
- `lib/services`: Coordinators and execution engines — `lib/services/app_power_manager.dart` (4-tier animation/frame gate + Idle Sleep), `lib/services/device_service.dart` (device state, 10s polling, coalesced/deferred UI notifications), `lib/services/discovery_service.dart`, `lib/services/ip_drift_scanner_service.dart`, `lib/services/wol_inspector_service.dart` (`lib/services/wol_inspector_parsers.dart`, `lib/services/wol_scripts.dart`, `lib/services/wol_linux_scripts.dart` — 4-layer WoL audit & WinRM/UAC/SSH offline remediation), `lib/services/remote_command_service.dart`, `lib/services/file_deploy_service.dart`, `lib/services/ota_update_service.dart`, `lib/services/config_backup_service.dart`, `lib/services/power_service.dart`, `lib/services/tool_launcher_service.dart`. See `lib/services/INDEX.md`.

### Core Infrastructure (`lib/core/`) & Data (`lib/data/`)
- `lib/core/network`: ICMP/TCP fallback ping, CIDR `/21` supernet slicing & mask discovery, streaming `nbtstat` hostname lookup, ARP cache, Wake-on-LAN, offline MAC OUI lookup, and TCP port scanner. See `lib/core/network/INDEX.md`.
- `lib/core/process`: `lib/core/process/process_runner.dart` (concurrent stdout/stderr draining, WinRM/PowerShell temp `.ps1` execution) and `lib/core/process/file_unlock_script.dart` (Windows Restart Manager helper).
- `lib/core/security`: `lib/core/security/dpapi_helper.dart` (`crypt32.dll` FFI Windows DPAPI encryption for saved credentials & OTA SMB passwords).
- `lib/core/utils`: `lib/core/utils/app_storage.dart` (flat application support storage + legacy subfolder migration), `lib/core/utils/everything_search_matcher.dart`, `lib/core/utils/command_variable_resolver.dart`, `lib/core/utils/file_dialog_helper.dart`.
- `lib/data/models`: `ManagedDevice`, `SavedCredential`, `CommandTemplate`, `ActionLog`.
- `lib/data/repositories`: Persistent JSON/DPAPI stores for devices, credentials, command templates, file-deploy history, search history, and in-session audit logs.

### Shared Theme & Liquid Glass UI (`lib/theme/`, `lib/widgets/`)
- `lib/theme`: `lib/theme/theme_provider.dart` (hardware tiering Auto/Ultra/Balanced/Lite + live glass blur/opacity settings in `app_settings.json`), `lib/theme/app_colors.dart`, `lib/theme/language_provider.dart` (complete `VI`/`EN`/`CN` dictionary), `lib/theme/styles_win10.dart`, `lib/theme/styles_win11.dart`.
- `lib/widgets`: Shared glassmorphic surfaces, animations gated by `AppPowerManager`, `GlassTerminalPanel`, `GlassScriptEditor`, `GlassDropdown`, `CommandPaletteShortcut`, `RouteShortcuts`, `GlassUpdateDialog`, tooltips/toasts. See `lib/widgets/INDEX.md`.

### Native Windows Runner, Packaging & Tests
- `windows/runner`: Native C++ Win32 host (`windows/runner/win32_window.cpp`), method channel (`windows/runner/flutter_window.cpp`), DWM Aero/Acrylic composition (`windows/runner/theme_win10.cpp`, `windows/runner/theme_win11.cpp`), and PE version metadata (`windows/runner/Runner.rc`). See `windows/runner/INDEX.md`.
- `windows/flutter`: Flutter engine CMake integration and `windows/flutter/generated_plugin_registrant.h`.
- Root scripts & packaging: `uninstall.ps1` (Zero-Admin uninstaller logic), `install.bat`, `uninstall.bat`, `build.bat`, `debug.bat`.
- Automated tests & diagnostics: `test` (unit, widget, native lock/installer regressions) and `tool` (`tool/resolve_hostname.dart`, `tool/scan_benchmark_test.dart`, `tool/verify_scan_difference.dart`). See `test/INDEX.md`.

## 3. Critical Architectural Invariants

1. **Flat Application Storage (`lib/core/utils/app_storage.dart`)**: Persistent files (`devices.json`, `credentials.json`, `power_settings.json`, `app_settings.json`, `ota_config.json`, `mac_oui.json`, history files) live directly under the Windows application support directory (no nested `JA_Remote/` subfolder); unit tests isolate storage via `AppStorage.setDirectoryForTesting`.
2. **4-Tier Power Gate (`lib/services/app_power_manager.dart`)**: Never bypass `AppPowerManager` for looping ambient animations or background timers. `_resetIdleTimer()` suppresses real 12s timers under `FLUTTER_TEST` unless `allowIdleTimerInTests: true` is passed explicitly in test setup, preventing `timersPending` invariant failures.
3. **Single Composition Owner (`windows/runner`)**: Win10 Aero (`windows/runner/theme_win10.cpp`) and Win11 Mica/Acrylic (`windows/runner/theme_win11.cpp`) own DWM blur attributes; `lib/modules/window_helper.dart` intentionally avoids `window_manager.setBackgroundColor` / `titleBarStyle` overrides that cause double-blur artifacts, while always keeping window titles non-empty for Taskbar clarity.
4. **Preflight Manifest Unlock (`lib/services/file_deploy_service.dart`, `lib/core/process/file_unlock_script.dart`)**: Validate all targets before touching locks; use Windows Restart Manager (`rstrtmgr.dll`) strictly on exact destination files, validate PID + StartTime, never kill protected system/app processes, and restore per-file backups on failure.

## 4. Verification Commands

- Narrow widget/service check: `flutter test test/<suite>_test.dart`
- Formatting & static analysis: `dart format .` then `flutter analyze`
- Full automated suite: `flutter test`
- Packaging safety: **Do NOT execute `build.bat`** unless release packaging is explicitly requested (`build.bat` kills running `ja_remote.exe` and wipes `dist/`).

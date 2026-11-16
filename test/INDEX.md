# test/ Directory Guide

Automated unit, widget, and Windows integration regressions (`flutter test`).

## Test Isolation Rules

1. Never read or mutate user `%APPDATA%` / live `JA_Remote` runtime folders: call `AppStorage.setDirectoryForTesting(tempDir)` and `MacOuiResolver.setStorageFileForTesting(...)` in `setUp` / `tearDown`.
2. Avoid real LAN/remote calls by default: construct `DeviceService(initialize: false)`, inject mock ping/SSH/process callbacks in service constructors, and keep live benchmarks in `tool/` (`tool/scan_benchmark_test.dart`).
3. Keep `AppPowerManager.instance.resetForTesting(...)` in widget test teardown/setup — under `FLUTTER_TEST`, real 12s idle sleep timers are suppressed automatically unless `allowIdleTimerInTests: true` is set explicitly.

## Subsystem-to-Test Mapping

- **Power Optimizer & App Shortcuts**: `app_power_manager_test.dart`, `dashboard_shortcuts_test.dart`, `route_shortcuts_test.dart`, `command_palette_test.dart`, `tab_persistence_test.dart`
- **Networking, Discovery & OUI**: `unit_test.dart`, `network_fallback_regression_test.dart`, `host_resolver_test.dart`, `discovery_lifecycle_test.dart`, `discovery_notification_test.dart`, `scan_scheduler_test.dart`, `mac_oui_resolver_test.dart`, `port_scan_service_test.dart`, `port_scanner_dialog_test.dart`, `wol_inspector_service_test.dart`, `wol_inspector_dialog_test.dart`, `device_sort_view_test.dart`
- **Command Runner, SSH, Variables & Localization**: `ssh_execution_test.dart`, `command_template_test.dart`, `command_localization_test.dart`, `language_provider_test.dart`, `process_timeout_test.dart`, `process_runner_large_script_test.dart`, `clixml_test.dart`, `core/command_variable_resolver_test.dart`
- **File Deploy & Preflight Unlock**: `file_deploy_service_test.dart`, `file_deploy_review_test.dart`, `file_deploy_unlock_test.dart`, `file_deploy_collapse_test.dart`, `file_deploy_history_repository_test.dart`, `file_deploy_ui_history_test.dart`, `post_update_regression_test.dart`
- **Widgets & Search Fields**: `glass_scaffold_test.dart`, `glass_terminal_test.dart`, `terminal_external_focus_test.dart`, `glass_script_editor_test.dart`, `glass_search_history_field_test.dart`, `dropdown_marquee_test.dart`, `search_history_test.dart`
- **Storage, Security, OTA & Windows Packaging**: `app_storage_test.dart`, `core/dpapi_helper_test.dart`, `repositories/credential_repository_test.dart`, `ota_update_service_test.dart`, `release_metadata_test.dart`, `installer_scripts_test.dart`, `installer_smoke.ps1`, `logger_test.dart`

## Run Commands

- Targeted: `flutter test test/<file>_test.dart`
- Full suite: `flutter test`

# lib/services/ Directory Guide

Business logic, stateful coordinators (`ChangeNotifier`), and execution pipelines.

## Ownership & Lifecycle

- **App-wide `Provider` singletons** (registered in `lib/main.dart`):
  - `DeviceService` (`device_service.dart`): Loads `ManagedDevice` list, runs 10s ping polling (`_isRefreshing` guard), coalesces UI notifications (`_notifyUiOrDefer`), defers UI rebuilds while `!AppPowerManager.instance.shouldAnimateIndicators`, only persists `devices.json` on `online` changes, and provides `selectByIds` / `applyDiscoveredIpUpdate`. Has `DeviceService(initialize: false)` for unit tests.
  - `DiscoveryService` (`discovery_service.dart`): Subnet discovery with `_scanRevision` / `_adapterRevision` generation tokens (stale callbacks after Stop/dispose/new scan are ignored) and 50ms notification coalescing.
- **Process singleton**:
  - `AppPowerManager.instance` (`app_power_manager.dart`) + `PowerAwareWidgetsFlutterBinding`: Coordinates 4 power tiers (Active / Idle Sleep / Unfocused / Hidden-Minimized), `power_settings.json` persistence, 600ms interaction throttle, and `window_manager` native state reconciliation (`_syncGeneration`).
- **Domain & Feature Services** (instantiated on demand or view-scoped):
  - `IpDriftScannerService` (`ip_drift_scanner_service.dart`): Combines ICMP sweep, OS `arp -a` cache, TCP 3389 RDP X.509 certificate CN extraction, and UDP 137 NetBIOS NBSTAT queries to detect DHCP IP jumps, MAC conflicts, and renamed hosts.
  - `WolInspectorService` (`wol_inspector_service.dart`, `wol_inspector_parsers.dart`, `wol_scripts.dart`, `wol_linux_scripts.dart`): 4-layer Wake-on-LAN readiness auditor & auto-fixer across local Windows (UAC), remote WinRM Windows (no-restart), and remote Linux SSH (with offline Python3 `SIOCETHTOOL` ioctl fallback + 3-lock persistence).
  - `FileDeployService` (`file_deploy_service.dart`): Concurrent Windows (WinRM/SMB) and Linux (SFTP) file/folder deployment with preflight manifest validation, Restart Manager lock release, bounded sharing-violation retries, and per-file backup rollback.
  - `RemoteCommandService` (`remote_command_service.dart`): Batch PowerShell/WinRM (`ProcessRunner`) & SSH (`dartssh2`) execution with injectable SSH connector for offline tests.
  - `OtaUpdateService` (`ota_update_service.dart`): SMB/UNC `version.json` update check, `certutil` SHA-256 verification, ZIP size/entry guardrails, DPAPI SMB credentials, and `apply_update.bat` handoff.
  - `ConfigBackupService` (`config_backup_service.dart`), `PowerService` (`power_service.dart`), `ToolLauncherService` (`tool_launcher_service.dart`).

## Verification

- `flutter test test/app_power_manager_test.dart test/discovery_lifecycle_test.dart test/file_deploy_service_test.dart test/file_deploy_review_test.dart test/ssh_execution_test.dart test/ota_update_service_test.dart`

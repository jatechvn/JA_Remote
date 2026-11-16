# lib/features/devices/ Directory Guide

Managed device inventory workspace and diagnostic dialogs.

## Modules

- `devices_view.dart`: Main tab view (`DevicesView`) providing Everything-style search with history (`GlassSearchHistoryField`), group & online/offline filters, numeric IP & nullable ping sorting, toolbar actions (Auto-Ping toggle, Refresh, IP Drift Audit, Export/Import JSON, Add), virtualized row list (`_DeviceRow`), and floating batch actions dock (`WOL`, `Restart`, `Shutdown`, `Run Command`, `Deploy File`, `Change Group`, `Export Selected`, `Delete`). Keep `_DeviceRow` and table header Action column width synchronized (`144px`) and avoid widening top toolbar controls beyond compact layout bounds (`RenderFlex` overflow tests run in `tab_persistence_test.dart` & `device_sort_view_test.dart`).
- `add_device_dialog.dart`: `showAddDeviceDialog` — create new `ManagedDevice` with inline TCP/ping connectivity test and optional per-device credentials.
- `device_detail_dialog.dart`: `showDeviceDetailDialog` — edit device metadata/credentials and trigger quick actions (`WOL`, `RDP`, `C$`, `Computer Management`, `Restart`, `Shutdown`, `Port Scanner`).
- `port_scanner_dialog.dart`: `showPortScannerDialog` / `PortScannerDialogContent` — Single port, Top common ports, or validated Range (`1..65535`) TCP scan with one-click protocol launchers (`RDP`, `SSH`, `WinRM`, `Web`, `SMB`).
- `ip_drift_scanner_dialog.dart`: `showIpDriftScannerDialog` — audits either managed/selected devices or pasted Excel/TSV `Hostname  IP  MAC` tables via `IpDriftScannerService`, offering filter tabs (`Issues`, `OK`, `Offline`), TSV report copy, and 1-click IP update in `DeviceService`.
- `wol_inspector_dialog.dart`, `wol_inspector_controls.dart`, & `wol_inspector_cards.dart`: `showWolInspectorDialog` — 3-mode 4-layer Wake-on-LAN Auditor & Auto-Fixer (`Managed Hosts`, `This PC + UAC`, `Ad-hoc IP`) with expandable 4-layer status cards, 1-click remediation, MAC sync, TSV export, and Magic Packet test.

## Verification

- `flutter test test/device_sort_view_test.dart test/port_scanner_dialog_test.dart test/wol_inspector_dialog_test.dart test/tab_persistence_test.dart test/dashboard_shortcuts_test.dart`

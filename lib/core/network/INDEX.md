# lib/core/network/ Directory Guide

Low-level networking, hostname resolution, ARP/MAC identification, and port scanning primitives.

## Modules

- `ping_engine.dart`: Windows/Unix native `ping` wrapper with automatic 7-port TCP handshake fallback (`6475, 5985, 445, 135, 3389, 22, 80`) returning the fastest reachable latency while draining all attempts; `PingEngine.pingBatch` schedules sweeps efficiently via index pointers.
- `network_utils.dart`: Adapter classification (`isVirtualAdapter` filtering Tailscale/WSL/Hyper-V/loopback/APIPA), CIDR math (`calculateCidrSubnet`, `/21` supernet slicing into constituent `/24` slices via `getSubnetSlices`), locale-safe `ipconfig` / `netsh` mask parsers, numeric IP comparator, and broadcast calculation.
- `host_resolver.dart`: Reverse DNS (750ms deadline) followed on Windows by streaming `nbtstat -A <ip>` (`resolveNetBios`), resolving immediately on the first `<00>`/`<20> UNIQUE` line and killing the child process cleanly within a 4s deadline.
- `arp_resolver.dart`: Parses OS `arp -a` output (`getArpTable`, normalized `AA:BB:CC:DD:EE:FF`, rejecting broadcast `FF:FF:FF:FF:FF:FF`) and supports targeted single-IP refresh.
- `mac_oui_resolver.dart`: Offline built-in OUI database (`_ouiMap`, >1,600 entries) merged with user-editable `mac_oui.json` overrides via `cleanOUI` / `loadCustomMappings`.
- `port_scan_service.dart`: Native `Socket.connect` scanner with `CancellationToken`, stream subscription cancellation safety, well-known port dictionary, and common preset list.
- `wake_on_lan.dart`: UDP broadcast Magic Packet sender (`FF:FF:FF:FF:FF:FF` + 16x MAC repetitions) on port 9.

## Verification

- `flutter test test/unit_test.dart test/network_fallback_regression_test.dart test/host_resolver_test.dart test/mac_oui_resolver_test.dart test/port_scan_service_test.dart test/scan_scheduler_test.dart`

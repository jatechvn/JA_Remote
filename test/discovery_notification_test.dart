import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/ping_engine.dart';
import 'package:ja_remote/services/discovery_service.dart';

Future<({List<String> devices, int notifications})> replay(
  Duration interval,
) async {
  var notifications = 0;
  final done = Completer<void>();
  final service = DiscoveryService(
    initialize: false,
    progressNotificationInterval: interval,
    getLocalIps: () async => {},
    getArpTable: () async => {'172.21.168.1': '00:11:22:33:44:55'},
    resolveHost: (ip) async => 'host-${ip.replaceAll('.', '-')}',
    ping: (ips, _, _) => Stream.fromIterable(
      ips.asMap().entries.map(
        (e) => PingResult(
          ip: e.value,
          isOnline: e.key % 8 == 0,
          latencyMs: e.key % 8 == 0 ? 3 : null,
        ),
      ),
    ),
  );
  service.addListener(() {
    notifications++;
    if (!service.isScanning &&
        service.resolvingHostIps.isEmpty &&
        !done.isCompleted) {
      done.complete();
    }
  });
  try {
    await service.startScan(subnet: '172.21.168.0/21');
    await done.future.timeout(const Duration(seconds: 3));
    return (
      devices: [
        for (final d in service.discoveredDevices)
          '${d.ip}|${d.hostname}|${d.mac}|${d.online}|${d.pingMs}',
      ],
      notifications: notifications,
    );
  } finally {
    service.dispose();
  }
}

void main() {
  test(
    '2046-IP replay preserves every result while coalescing notifications',
    () async {
      final baseline = await replay(Duration.zero);
      final optimized = await replay(const Duration(milliseconds: 50));
      expect(optimized.devices, baseline.devices);
      expect(optimized.devices.length, 256);
      expect(optimized.notifications, lessThan(baseline.notifications ~/ 4));
    },
  );

  test(
    'Stop cancels queued notifications and prevents late progress',
    () async {
      final stream = StreamController<PingResult>();
      var notifications = 0;
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () async => {},
        getArpTable: () async => {},
        ping: (_, _, _) => stream.stream,
      );
      service.addListener(() {
        notifications++;
      });
      await service.startScan(subnet: '192.0.2.0/30');
      stream.add(const PingResult(ip: '192.0.2.1', isOnline: false));
      await Future<void>.delayed(Duration.zero);
      service.stopScan();
      final stopped = notifications;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(notifications, stopped);
      await stream.close();
      service.dispose();
    },
  );
}

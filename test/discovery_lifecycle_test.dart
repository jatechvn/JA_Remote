import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/ping_engine.dart';
import 'package:ja_remote/services/discovery_service.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  for (final hostname in ['192.0.2.1', 'actual-host']) {
    test('late ARP vendor fallback preserves hostname: $hostname', () async {
      var arpCalls = 0;
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () async => {},
        getArpTable: () async =>
            ++arpCalls == 1 ? {} : {'192.0.2.1': 'F8:6F:B0:4A:0B:C3'},
        resolveHost: (_) async => hostname,
        ping: (_, _, _) =>
            Stream.value(const PingResult(ip: '192.0.2.1', isOnline: true)),
      );
      addTearDown(service.dispose);
      await service.startScan(subnet: '192.0.2.0/30');
      await flush();
      expect(service.discoveredDevices.single.mac, 'F8:6F:B0:4A:0B:C3');
      expect(service.discoveredDevices.single.hostname, hostname);
      expect(
        service.discoveredDevices.single.name,
        hostname == '192.0.2.1' ? 'TP-Link (192.0.2.1)' : 'actual-host',
      );
      expect(service.resolvingHostIps, isEmpty);
      expect(service.isScanning, isFalse);
    });
  }
  test(
    'hostname arriving after scan completion still replaces PC-IP',
    () async {
      final name = Completer<String>();
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () async => {},
        getArpTable: () async => {},
        resolveHost: (_) => name.future,
        ping: (_, _, _) =>
            Stream.value(const PingResult(ip: '192.0.2.1', isOnline: true)),
      );
      addTearDown(service.dispose);
      await service.startScan(subnet: '192.0.2.0/30');
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      expect(service.isScanning, isFalse);
      expect(service.isResolvingHost('192.0.2.1'), isTrue);
      name.complete('IQ4-FT3-031');
      await flush();
      expect(service.discoveredDevices.single.name, 'IQ4-FT3-031');
      expect(service.isResolvingHost('192.0.2.1'), isFalse);
    },
  );
  test(
    'start is reserved before local address lookup; stop cancels preparation',
    () async {
      final local = Completer<Set<String>>();
      var lookups = 0;
      var sweeps = 0;
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () {
          lookups++;
          return local.future;
        },
        getArpTable: () async => {},
        ping: (_, _, _) {
          sweeps++;
          return const Stream.empty();
        },
      );
      addTearDown(service.dispose);
      final first = service.startScan(subnet: '192.0.2.0/30');
      expect(service.isScanning, isTrue);
      await service.startScan();
      expect(lookups, 1);
      service.stopScan();
      local.complete({});
      await first;
      expect(sweeps, 0);
      expect(service.isScanning, isFalse);
    },
  );
  test('old hostname and completion cannot change a newer scan', () async {
    final streams = <StreamController<PingResult>>[];
    final names = <Completer<String>>[];
    final service = DiscoveryService(
      initialize: false,
      getLocalIps: () async => {},
      getArpTable: () async => {},
      resolveHost: (_) {
        final c = Completer<String>();
        names.add(c);
        return c.future;
      },
      ping: (_, _, _) {
        final c = StreamController<PingResult>();
        streams.add(c);
        return c.stream;
      },
    );
    addTearDown(service.dispose);
    await service.startScan(subnet: '192.0.2.0/30');
    streams[0].add(const PingResult(ip: '192.0.2.1', isOnline: true));
    await flush();
    await streams[0].close();
    service.stopScan();
    await service.startScan(subnet: '192.0.2.0/30');
    streams[1].add(const PingResult(ip: '192.0.2.1', isOnline: true));
    await flush();
    names[0].complete('stale-host');
    await flush();
    expect(service.isScanning, isTrue);
    expect(service.discoveredDevices.single.hostname, '192.0.2.1');
    names[1].complete('current-host');
    await streams[1].close();
    await flush();
    expect(service.discoveredDevices.single.hostname, 'current-host');
    expect(service.isScanning, isFalse);
    expect(service.progress, 1);
  });
  test(
    'dispose during ARP preparation cannot start a background sweep',
    () async {
      final arp = Completer<Map<String, String>>();
      var sweeps = 0;
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () async => {},
        getArpTable: () => arp.future,
        ping: (_, _, _) {
          sweeps++;
          return const Stream.empty();
        },
      );
      final pending = service.startScan(subnet: '192.0.2.0/30');
      await flush();
      service.dispose();
      arp.complete({});
      await pending;
      expect(sweeps, 0);
    },
  );
  test('preparation failure clears busy state and permits retry', () async {
    var fail = true;
    final service = DiscoveryService(
      initialize: false,
      getLocalIps: () async {
        if (fail) throw StateError('lookup failed');
        return {};
      },
      getArpTable: () async => {},
      ping: (_, _, _) => const Stream.empty(),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.startScan(subnet: '192.0.2.0/30'),
      throwsStateError,
    );
    expect(service.isScanning, isFalse);
    fail = false;
    await service.startScan(subnet: '192.0.2.0/30');
    await flush();
    expect(service.progress, 1);
  });
  test(
    'local host is excluded and invalid worker limits never start',
    () async {
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () async => {'192.0.2.1'},
        getArpTable: () async => {},
        ping: (_, _, _) =>
            Stream.value(const PingResult(ip: '192.0.2.1', isOnline: true)),
      );
      addTearDown(service.dispose);
      await expectLater(service.startScan(concurrency: 0), throwsArgumentError);
      await service.startScan(subnet: '192.0.2.0/30');
      await flush();
      expect(service.discoveredDevices, isEmpty);
      expect(service.isScanning, isFalse);
    },
  );
  test(
    'isResolvingHost tracks active hostname resolution and clears on completion or stop',
    () async {
      final name = Completer<String>();
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () async => {},
        getArpTable: () async => {},
        resolveHost: (_) => name.future,
        ping: (_, _, _) =>
            Stream.value(const PingResult(ip: '192.0.2.5', isOnline: true)),
      );
      addTearDown(service.dispose);

      final scan = service.startScan(subnet: '192.0.2.0/30');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.discoveredDevices.length, 1);
      expect(service.isResolvingHost('192.0.2.5'), isTrue);
      expect(service.resolvingHostIps.contains('192.0.2.5'), isTrue);

      name.complete('PRINTER-05');
      await flush();

      expect(service.isResolvingHost('192.0.2.5'), isFalse);
      expect(service.discoveredDevices.single.name, 'PRINTER-05');
      await scan;
    },
  );
  test(
    'ARP reconciliation recovers devices missed by ICMP ping (cold ARP / firewall)',
    () async {
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () async => {},
        getArpTable: () async => {'192.0.2.2': '9C:47:82:11:22:33'},
        resolveHost: (_) async => '192.0.2.2',
        ping: (_, _, _) => Stream.value(
          const PingResult(ip: '192.0.2.2', isOnline: false), // ICMP drop
        ),
      );
      addTearDown(service.dispose);
      await service.startScan(subnet: '192.0.2.0/30');
      await flush();

      expect(service.discoveredDevices.length, 1);
      final dev = service.discoveredDevices.single;
      expect(dev.ip, '192.0.2.2');
      expect(dev.mac, '9C:47:82:11:22:33');
      expect(dev.name, 'TP-Link (192.0.2.2)');
      expect(
        dev.online,
        isFalse,
      ); // ARP cache alone cannot prove current liveness.
      expect(dev.pingMs, isNull);
      expect(service.isScanning, isFalse);
    },
  );
  test(
    'ARP reconciliation filters out invalid broadcast and multicast MACs',
    () async {
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () async => {},
        getArpTable: () async => {
          '192.0.2.1': 'FF:FF:FF:FF:FF:FF',
          '192.0.2.2': '01:00:5E:00:00:16',
        },
        resolveHost: (_) async => 'host',
        ping: (_, _, _) => const Stream.empty(),
      );
      addTearDown(service.dispose);
      await service.startScan(subnet: '192.0.2.0/30');
      await flush();

      expect(service.discoveredDevices, isEmpty);
      expect(service.isScanning, isFalse);
    },
  );
  test('numeric IP sorting places discovered devices in order', () async {
    final service = DiscoveryService(
      initialize: false,
      getLocalIps: () async => {},
      getArpTable: () async => {
        '192.0.2.10': '00:1A:2B:3C:4D:5E',
        '192.0.2.2': '00:1A:2B:3C:4D:5F',
      },
      resolveHost: (_) async => '',
      ping: (_, _, _) => const Stream.empty(),
    );
    addTearDown(service.dispose);
    await service.startScan(subnet: '192.0.2.0/28');
    await flush();

    expect(service.discoveredDevices.length, 2);
    expect(service.discoveredDevices[0].ip, '192.0.2.2');
    expect(service.discoveredDevices[1].ip, '192.0.2.10');
  });
}

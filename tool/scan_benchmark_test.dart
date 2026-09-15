// Opt-in real-network benchmark; never included in the normal test suite.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/arp_resolver.dart';
import 'package:ja_remote/core/network/host_resolver.dart';
import 'package:ja_remote/core/network/ping_engine.dart';
import 'package:ja_remote/services/discovery_service.dart';

void main() {
  test('explicit subnet benchmark', () async {
    const subnet = String.fromEnvironment('BENCH_SUBNET');
    const label = String.fromEnvironment('BENCH_LABEL');
    const concurrency = int.fromEnvironment('BENCH_WORKERS', defaultValue: 20);
    const notifyMs = int.fromEnvironment('BENCH_NOTIFY_MS', defaultValue: 50);
    if (subnet.isEmpty || !RegExp(r'^[a-z0-9_-]+$').hasMatch(label)) {
      fail('Pass BENCH_SUBNET and a filename-safe BENCH_LABEL explicitly.');
    }
    final watch = Stopwatch()..start();
    final arpMs = <int>[];
    final hosts = <String, Object>{};
    final pingOnline = <String>[];
    var peakHosts = 0;
    var activeHosts = 0;
    var notifications = 0;
    int? pingMs;
    int? scanDoneMs;
    final done = Completer<void>();
    final service = DiscoveryService(
      initialize: false,
      progressNotificationInterval: const Duration(milliseconds: notifyMs),
      getArpTable: () async {
        final w = Stopwatch()..start();
        final value = await ArpResolver.getArpTable();
        arpMs.add(w.elapsedMilliseconds);
        return value;
      },
      resolveHost: (ip) async {
        final w = Stopwatch()..start();
        activeHosts++;
        if (activeHosts > peakHosts) peakHosts = activeHosts;
        try {
          final name = await HostResolver.resolve(ip);
          hosts[ip] = {'name': name, 'ms': w.elapsedMilliseconds};
          return name;
        } finally {
          activeHosts--;
        }
      },
      ping: (ips, workers, timeout) async* {
        final w = Stopwatch()..start();
        await for (final result in PingEngine.pingBatch(
          ips,
          maxConcurrent: workers,
          timeoutMs: timeout,
        )) {
          if (result.isOnline) pingOnline.add(result.ip);
          yield result;
        }
        pingMs = w.elapsedMilliseconds;
      },
    );
    addTearDown(service.dispose);
    service.addListener(() {
      notifications++;
      if (!service.isScanning) {
        scanDoneMs ??= watch.elapsedMilliseconds;
        if (service.resolvingHostIps.isEmpty && !done.isCompleted) {
          done.complete();
        }
      }
    });
    await service.startScan(subnet: subnet, concurrency: concurrency);
    await done.future.timeout(const Duration(minutes: 5));
    final devices = service.discoveredDevices;
    pingOnline.sort();
    final report = <String, Object?>{
      'label': label,
      'subnet': subnet,
      'workers': concurrency,
      'notificationIntervalMs': notifyMs,
      'time': DateTime.now().toIso8601String(),
      'totalMs': watch.elapsedMilliseconds,
      'scanDoneMs': scanDoneMs,
      'pingMs': pingMs,
      'arpMs': arpMs,
      'peakHostLookups': peakHosts,
      'notifications': notifications,
      'pingOnline': pingOnline,
      'hosts': hosts,
      'devices': [
        for (final d in devices)
          {
            'ip': d.ip,
            'hostname': d.hostname,
            'mac': d.mac,
            'pingMs': d.pingMs,
          },
      ],
    };
    final file = File('docs/benchmarks/$label.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    // ignore: avoid_print
    print(
      '$label: total=${report['totalMs']}ms ping=${pingMs}ms '
      'devices=${devices.length} pingOnline=${pingOnline.length} '
      'resolved=${hosts.entries.where((e) => (e.value as Map)['name'] != e.key).length} '
      'arp=$arpMs peakHosts=$peakHosts notifications=$notifications',
    );
  }, timeout: const Timeout(Duration(minutes: 6)));
}

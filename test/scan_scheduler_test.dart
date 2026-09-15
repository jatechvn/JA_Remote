import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/ping_engine.dart';
import 'package:ja_remote/services/discovery_service.dart';

void main() {
  test(
    'local IP and ARP preparation overlap and stop prevents sweep',
    () async {
      final ips = Completer<Set<String>>();
      var arpStarted = false;
      final service = DiscoveryService(
        initialize: false,
        getLocalIps: () => ips.future,
        getArpTable: () async {
          arpStarted = true;
          return <String, String>{};
        },
        ping: (_, _, _) => throw StateError('stopped scan must not ping'),
      );
      final scan = service.startScan(subnet: '192.0.2.0/30');
      expect(arpStarted, isTrue);
      service.stopScan();
      ips.complete(<String>{});
      await scan;
      service.dispose();
    },
  );
  test('bounded workers refill without waiting for the slowest host', () async {
    final pending = <String, Completer<PingResult>>{};
    final results = <PingResult>[];
    final sub = PingEngine.pingBatch(
      ['slow', 'fast', 'next'],
      maxConcurrent: 2,
      probe: (ip, _) => (pending[ip] = Completer<PingResult>()).future,
    ).listen(results.add);
    await Future<void>.delayed(Duration.zero);
    expect(pending.keys, ['slow', 'fast']);
    pending['fast']!.complete(const PingResult(ip: 'fast', isOnline: true));
    await Future<void>.delayed(Duration.zero);
    expect(pending.keys, ['slow', 'fast', 'next']);
    await sub.cancel();
    pending['slow']!.complete(const PingResult(ip: 'slow', isOnline: false));
    pending['next']!.complete(const PingResult(ip: 'next', isOnline: true));
  });
  test('cancel stops queued probes and snapshots input', () async {
    final first = Completer<PingResult>();
    final input = ['first', 'queued'];
    final called = <String>[];
    final stream = PingEngine.pingBatch(
      input,
      maxConcurrent: 1,
      probe: (ip, _) {
        called.add(ip);
        return first.future;
      },
    );
    input.clear();
    final sub = stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    first.complete(const PingResult(ip: 'first', isOnline: true));
    await Future<void>.delayed(Duration.zero);
    expect(called, ['first']);
  });
  test(
    '1000 targets complete once within concurrency cap despite failures',
    () async {
      var active = 0;
      var peak = 0;
      final results = await PingEngine.pingBatch(
        List.generate(1000, (i) => '$i'),
        maxConcurrent: 20,
        probe: (ip, _) async {
          active++;
          if (active > peak) peak = active;
          await Future<void>.delayed(Duration.zero);
          active--;
          if (ip == '7') throw StateError('probe failed');
          return PingResult(ip: ip, isOnline: true);
        },
      ).toList();
      expect(results.length, 1000);
      expect(results.map((r) => r.ip).toSet().length, 1000);
      expect(
        results.singleWhere((r) => r.ip == '7').error,
        contains('probe failed'),
      );
      expect(peak, 20);
      expect(active, 0);
    },
  );
  test('empty input completes; invalid limit cannot hang', () async {
    expect(await PingEngine.pingBatch([]).toList(), isEmpty);
    expect(
      () => PingEngine.pingBatch(['x'], maxConcurrent: 0),
      throwsArgumentError,
    );
    expect(
      () => PingEngine.pingBatch(['x'], timeoutMs: 0),
      throwsArgumentError,
    );
  });
}

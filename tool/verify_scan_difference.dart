import 'dart:convert';
import 'dart:io';
import 'package:ja_remote/core/network/arp_resolver.dart';
import 'package:ja_remote/core/network/ping_engine.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    throw ArgumentError('Expected baseline.json candidate.json output.json');
  }
  final baseline = jsonDecode(await File(args[0]).readAsString()) as Map;
  final candidate = jsonDecode(await File(args[1]).readAsString()) as Map;
  final previous = (baseline['devices'] as List)
      .map((d) => d['ip'] as String)
      .toSet();
  final current = (candidate['devices'] as List)
      .map((d) => d['ip'] as String)
      .toSet();
  final missing = previous.difference(current).toList()..sort();
  final replies = <String, List<bool>>{for (final ip in missing) ip: []};
  for (var pass = 0; pass < 2; pass++) {
    await for (final result in PingEngine.pingBatch(
      missing,
      maxConcurrent: 8,
      timeoutMs: 800,
    )) {
      replies[result.ip]!.add(result.isOnline);
    }
  }
  final arp = await ArpResolver.getArpTable();
  final report = {
    'time': DateTime.now().toIso8601String(),
    'subnet': baseline['subnet'],
    'timeoutMs': 800,
    'workers': 8,
    'results': [
      for (final ip in missing)
        {'ip': ip, 'pingReplies': replies[ip], 'arpMac': arp[ip]},
    ],
  };
  await File(
    args[2],
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
}

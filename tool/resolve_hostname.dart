import 'dart:io';
import 'package:ja_remote/core/network/host_resolver.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Usage: dart run tool/resolve_hostname.dart <IP>');
  }
  final watch = Stopwatch()..start();
  final hostname = await HostResolver.resolve(args.single);
  stdout.writeln(
    '${args.single} -> $hostname (${watch.elapsedMilliseconds} ms)',
  );
}

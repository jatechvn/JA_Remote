import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Resolves hostnames and computer names from IP addresses.
class HostResolver {
  static String? parseNetBiosName(String line) {
    return RegExp(
      r'^\s*([^\s<>]+)\s*<(?:00|20)>\s+UNIQUE\b',
      caseSensitive: false,
    ).firstMatch(line)?.group(1);
  }

  /// nbtstat can print a valid name before spending seconds on other adapters.
  static Future<String> resolveNetBios(
    String ip, {
    Future<Process> Function()? start,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    Process? process;
    StreamSubscription<String>? output;
    StreamSubscription<List<int>>? errors;
    var finished = false;
    try {
      return await (() async {
        final child =
            await (start?.call() ??
                Process.start('nbtstat', ['-A', ip], runInShell: false));
        if (finished) {
          child.kill();
          return ip;
        }
        process = child;
        final name = Completer<String>();
        output = child.stdout
            .transform(const SystemEncoding().decoder)
            .transform(const LineSplitter())
            .listen(
              (line) {
                final found = parseNetBiosName(line);
                if (found != null && !name.isCompleted) name.complete(found);
              },
              onDone: () {
                if (!name.isCompleted) name.complete(ip);
              },
              onError: (Object _) {
                if (!name.isCompleted) name.complete(ip);
              },
            );
        errors = child.stderr.listen((_) {}, onError: (Object _) {});
        return await name.future;
      })().timeout(timeout, onTimeout: () => ip);
    } catch (_) {
      return ip;
    } finally {
      finished = true;
      process?.kill();
      await output?.cancel();
      await errors?.cancel();
    }
  }

  /// Resolves the hostname for a given IP.
  static Future<String> resolve(String ip) async {
    // 1. Try reverse DNS lookup (with tight timeout to prevent hanging scan)
    try {
      final addr = InternetAddress(ip);
      final result = await addr.reverse().timeout(
        const Duration(milliseconds: 750),
      );
      final host = result.host.trim();
      if (host.isNotEmpty && host != ip) {
        return host;
      }
    } catch (_) {}

    // 2. On Windows, try NetBIOS lookup via nbtstat
    if (Platform.isWindows) {
      return resolveNetBios(ip);
    }

    return ip;
  }
}

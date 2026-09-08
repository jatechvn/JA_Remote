import 'dart:io';

/// Resolves hostnames and computer names from IP addresses.
class HostResolver {
  /// Resolves the hostname for a given IP.
  static Future<String> resolve(String ip) async {
    // 1. Try reverse DNS lookup
    try {
      final addr = InternetAddress(ip);
      final result = await addr.reverse();
      final host = result.host.trim();
      if (host.isNotEmpty && host != ip) {
        return host;
      }
    } catch (_) {}

    // 2. On Windows, try NetBIOS lookup via nbtstat
    if (Platform.isWindows) {
      try {
        final res = await Process.run('nbtstat', ['-A', ip], runInShell: false);
        final out = res.stdout.toString();
        // Look for: "    COMPUTER_NAME  <00>  UNIQUE"
        final match = RegExp(
          r'^\s*([A-Za-z0-9_\-]+)\s+<00>\s+UNIQUE',
          multiLine: true,
        ).firstMatch(out);
        if (match != null) {
          final name = match.group(1)?.trim();
          if (name != null && name.isNotEmpty) {
            return name;
          }
        }
      } catch (_) {}
    }

    return ip;
  }
}

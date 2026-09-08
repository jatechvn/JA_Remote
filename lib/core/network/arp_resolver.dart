import 'dart:io';

/// Resolves MAC addresses of local network hosts via Windows ARP cache.
class ArpResolver {
  /// Reads current system ARP table and returns a Map of IP -> Normalized MAC (e.g. AA:BB:CC:DD:EE:FF).
  static Future<Map<String, String>> getArpTable() async {
    final Map<String, String> map = {};
    try {
      final res = await Process.run('arp', ['-a'], runInShell: false);
      final out = res.stdout.toString();
      // Match lines like: "  172.19.116.157    a4-b1-c1-22-33-44     dynamic"
      final regex = RegExp(
        r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+([0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2}[-:][0-9a-fA-F]{2})',
      );

      for (final match in regex.allMatches(out)) {
        final ip = match.group(1);
        final mac = match.group(2)?.replaceAll('-', ':').toUpperCase();
        if (ip != null && mac != null && mac != 'FF:FF:FF:FF:FF:FF') {
          map[ip] = mac;
        }
      }
    } catch (_) {}
    return map;
  }

  /// Resolves MAC address for a specific target IP.
  static Future<String?> resolveMac(String ip) async {
    final table = await getArpTable();
    if (table.containsKey(ip)) {
      return table[ip];
    }
    // Ping first to populate ARP cache if not found
    try {
      await Process.run('ping', ['-n', '1', '-w', '200', ip]);
      final updated = await getArpTable();
      return updated[ip];
    } catch (_) {}
    return null;
  }
}

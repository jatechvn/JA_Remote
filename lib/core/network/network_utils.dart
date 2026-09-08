import 'dart:io';

/// Details of a detected network interface on the host machine.
class NetworkInterfaceDetails {
  final String name;
  final String ip;
  final String subnet;
  final bool isVirtual;
  final bool isPrivateLan;

  const NetworkInterfaceDetails({
    required this.name,
    required this.ip,
    required this.subnet,
    required this.isVirtual,
    required this.isPrivateLan,
  });

  @override
  String toString() =>
      '$name: $ip ($subnet) [${isVirtual ? 'Virtual' : 'Physical LAN'}]';
}

/// Network utility functions for IP, Subnet calculations, and local interface detection.
class NetworkUtils {
  /// Checks if an interface or IP belongs to a virtual / tunnel adapter (Tailscale, Docker, WSL, etc.)
  static bool isVirtualAdapter(String name, String ip) {
    // 1. Check IP patterns
    if (ip.startsWith('127.') || ip.startsWith('169.254.')) {
      return true; // Loopback or APIPA
    }

    // Tailscale / Carrier-Grade NAT (RFC 6598: 100.64.0.0/10: 100.64.0.0 - 100.127.255.255)
    if (ip.startsWith('100.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final secondOctet = int.tryParse(parts[1]) ?? 0;
        if (secondOctet >= 64 && secondOctet <= 127) {
          return true; // Tailscale / CGNAT
        }
      }
      return true; // Any 100.x on Windows is almost universally Tailscale or WAN
    }

    // 2. Check Adapter Name patterns
    final lowerName = name.toLowerCase();
    final virtualKeywords = [
      'tailscale',
      'zerotier',
      'wireguard',
      'wsl',
      'vethernet',
      'virtual',
      'docker',
      'vmware',
      'vmnet',
      'vbox',
      'tap',
      'tun',
      'pseudo',
      'teredo',
      'npcap',
      'hyper-v',
      'openvpn',
      'bluetooth',
    ];

    for (final kw in virtualKeywords) {
      if (lowerName.contains(kw)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if an IP is in a standard RFC 1918 Private LAN range (10.x, 172.16-31.x, 192.168.x)
  static bool isPrivateLanIp(String ip) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
      return true;
    }
    if (ip.startsWith('172.')) {
      final parts = ip.split('.');
      if (parts.length >= 2) {
        final second = int.tryParse(parts[1]) ?? 0;
        if (second >= 16 && second <= 31) {
          return true;
        }
      }
    }
    return false;
  }

  /// Derives /24 CIDR subnet from an IPv4 address (e.g. 172.21.175.40 -> 172.21.175.0/24)
  static String deriveSubnet(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
    }
    return '$ip/24';
  }

  /// Lists all active network adapters on the host machine, classified by type.
  static Future<List<NetworkInterfaceDetails>> getAvailableAdapters() async {
    final List<NetworkInterfaceDetails> list = [];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('127.') || ip.startsWith('169.254.')) {
            continue;
          }

          final isVirtual = isVirtualAdapter(iface.name, ip);
          final isLan = isPrivateLanIp(ip);

          list.add(
            NetworkInterfaceDetails(
              name: iface.name,
              ip: ip,
              subnet: deriveSubnet(ip),
              isVirtual: isVirtual,
              isPrivateLan: isLan,
            ),
          );
        }
      }

      // Sort: Physical private LAN first, physical other second, virtual last
      list.sort((a, b) {
        if (!a.isVirtual && b.isVirtual) return -1;
        if (a.isVirtual && !b.isVirtual) return 1;
        if (a.isPrivateLan && !b.isPrivateLan) return -1;
        if (!a.isPrivateLan && b.isPrivateLan) return 1;
        return a.name.compareTo(b.name);
      });
    } catch (_) {}

    return list;
  }

  /// Detects the primary physical local IPv4 address and derives a default /24 CIDR subnet.
  /// Strictly filters out Tailscale and virtual tunnel adapters.
  static Future<String> getDefaultLocalSubnet() async {
    final adapters = await getAvailableAdapters();

    // 1. Pick first physical private LAN adapter (e.g. Ethernet 2: 172.21.175.40)
    for (final a in adapters) {
      if (!a.isVirtual && a.isPrivateLan) {
        return a.subnet;
      }
    }

    // 2. Fallback to any physical adapter
    for (final a in adapters) {
      if (!a.isVirtual) {
        return a.subnet;
      }
    }

    // 3. Fallback to first available if only virtual exists
    if (adapters.isNotEmpty) {
      return adapters.first.subnet;
    }

    return '192.168.1.0/24';
  }

  /// Lists all local IPv4 addresses currently assigned to active physical interfaces.
  static Future<List<String>> getLocalIpv4Addresses() async {
    final adapters = await getAvailableAdapters();
    return adapters.map((a) => a.ip).toList();
  }

  /// Expands a CIDR subnet (e.g. 172.19.116.0/24) into a list of host IP addresses.
  static List<String> expandSubnet(String cidr) {
    final clean = cidr.trim();
    if (!clean.contains('/')) {
      if (isValidIp(clean)) return [clean];
      return [];
    }

    final parts = clean.split('/');
    final ip = parts[0].trim();
    final prefixLen = int.tryParse(parts[1].trim()) ?? 24;

    final octets = ip.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    if (octets.length != 4) return [];

    final ipInt =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];

    final mask = prefixLen == 0 ? 0 : (~0 << (32 - prefixLen)) & 0xFFFFFFFF;
    final networkInt = ipInt & mask;
    final broadcastInt = networkInt | (~mask & 0xFFFFFFFF);

    final List<String> ips = [];
    final start = networkInt + 1;
    final end = broadcastInt - 1;

    final limit = end - start + 1;
    final maxHosts = limit > 1024 ? 1024 : limit;

    for (int i = 0; i < maxHosts; i++) {
      final cur = start + i;
      final o1 = (cur >> 24) & 0xFF;
      final o2 = (cur >> 16) & 0xFF;
      final o3 = (cur >> 8) & 0xFF;
      final o4 = cur & 0xFF;
      ips.add('$o1.$o2.$o3.$o4');
    }

    return ips;
  }

  /// Validates IPv4 format.
  static bool isValidIp(String ip) {
    final reg = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    final match = reg.firstMatch(ip.trim());
    if (match == null) return false;
    for (int i = 1; i <= 4; i++) {
      final octet = int.tryParse(match.group(i)!) ?? -1;
      if (octet < 0 || octet > 255) return false;
    }
    return true;
  }

  /// Calculates the directed broadcast IP for a given subnet (e.g. 192.168.1.255).
  static String getBroadcastIp(String ipOrCidr) {
    try {
      final clean = ipOrCidr.split('/')[0].trim();
      final parts = clean.split('.');
      if (parts.length == 4) {
        return '${parts[0]}.${parts[1]}.${parts[2]}.255';
      }
    } catch (_) {}
    return '255.255.255.255';
  }
}

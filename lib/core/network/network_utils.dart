import 'dart:io';

/// Details of a detected network interface on the host machine.
class NetworkInterfaceDetails {
  final String name;
  final String ip;
  final String subnet;
  final bool isVirtual;
  final bool isPrivateLan;
  final String? netmask;
  final int prefixLength;
  final List<String> subSlices;

  const NetworkInterfaceDetails({
    required this.name,
    required this.ip,
    required this.subnet,
    required this.isVirtual,
    required this.isPrivateLan,
    this.netmask,
    this.prefixLength = 24,
    this.subSlices = const [],
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

  /// Converts a dotted-decimal subnet mask (e.g. 255.255.248.0) to prefix length (e.g. 21).
  static int maskToPrefixLength(String netmask) {
    final octets = netmask
        .trim()
        .split('.')
        .map((e) => int.tryParse(e) ?? -1)
        .toList();
    if (octets.length != 4 || octets.any((o) => o < 0 || o > 255)) {
      return 24;
    }
    final maskInt =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    int count = 0;
    for (int i = 31; i >= 0; i--) {
      if (((maskInt >> i) & 1) == 1) {
        count++;
      } else {
        break;
      }
    }
    return count > 0 ? count : 24;
  }

  /// Calculates the exact network CIDR given an IP address and optional subnet mask.
  /// If netmask is omitted or invalid, defaults to /24.
  /// Example: 172.21.175.40 with 255.255.248.0 -> 172.21.168.0/21
  static String calculateCidrSubnet(String ip, [String? netmask]) {
    final cleanIp = ip.trim();
    final ipOctets = cleanIp
        .split('.')
        .map((e) => int.tryParse(e) ?? -1)
        .toList();
    if (ipOctets.length != 4 || ipOctets.any((o) => o < 0 || o > 255)) {
      return '$cleanIp/24';
    }

    if (netmask == null || netmask.trim().isEmpty) {
      return '${ipOctets[0]}.${ipOctets[1]}.${ipOctets[2]}.0/24';
    }

    final maskOctets = netmask
        .trim()
        .split('.')
        .map((e) => int.tryParse(e) ?? -1)
        .toList();
    if (maskOctets.length != 4 || maskOctets.any((o) => o < 0 || o > 255)) {
      return '${ipOctets[0]}.${ipOctets[1]}.${ipOctets[2]}.0/24';
    }

    final ipInt =
        (ipOctets[0] << 24) |
        (ipOctets[1] << 16) |
        (ipOctets[2] << 8) |
        ipOctets[3];
    final maskInt =
        (maskOctets[0] << 24) |
        (maskOctets[1] << 16) |
        (maskOctets[2] << 8) |
        maskOctets[3];
    final prefixLen = maskToPrefixLength(netmask);

    final networkInt = ipInt & maskInt;
    final o1 = (networkInt >> 24) & 0xFF;
    final o2 = (networkInt >> 16) & 0xFF;
    final o3 = (networkInt >> 8) & 0xFF;
    final o4 = networkInt & 0xFF;

    return '$o1.$o2.$o3.$o4/$prefixLen';
  }

  /// Derives CIDR subnet from an IPv4 address and optional subnet mask.
  /// Defaults to /24 if netmask is omitted for backward compatibility.
  static String deriveSubnet(String ip, [String? netmask]) {
    return calculateCidrSubnet(ip, netmask);
  }

  /// For supernets with prefix length < 24 (e.g. 172.21.168.0/21),
  /// generates the list of constituent /24 subnets.
  /// Example: 172.21.168.0/21 -> [172.21.168.0/24, ..., 172.21.175.0/24]
  static List<String> getSubnetSlices(String cidr) {
    final clean = cidr.trim();
    if (!clean.contains('/')) return [clean];
    final parts = clean.split('/');
    final ip = parts[0].trim();
    final prefix = int.tryParse(parts[1].trim()) ?? 24;

    if (prefix >= 24) {
      return [clean];
    }
    // Limit slicing down to /16 at most (256 slices max)
    if (prefix < 16) {
      return [clean];
    }

    final octets = ip.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    if (octets.length != 4) return [clean];

    final ipInt =
        (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
    final mask = prefix == 0 ? 0 : (~0 << (32 - prefix)) & 0xFFFFFFFF;
    final networkInt = ipInt & mask;
    final numSlices = 1 << (24 - prefix); // e.g. /21 -> 1 << 3 = 8 slices

    final List<String> slices = [];
    for (int i = 0; i < numSlices; i++) {
      final sliceNetworkInt = networkInt + (i << 8);
      final o1 = (sliceNetworkInt >> 24) & 0xFF;
      final o2 = (sliceNetworkInt >> 16) & 0xFF;
      final o3 = (sliceNetworkInt >> 8) & 0xFF;
      slices.add('$o1.$o2.$o3.0/24');
    }
    return slices;
  }

  /// Fast helper to read actual IPv4 Subnet Masks from Windows network stack.
  static Future<Map<String, String>> _getWindowsSubnetMasks() async {
    final Map<String, String> map = {};
    if (!Platform.isWindows) return map;

    try {
      final res = await Process.run('ipconfig', [], runInShell: false);
      if (res.exitCode == 0) {
        final text = res.stdout.toString();
        // Regex matches an IPv4 followed by a Subnet Mask (255.x.x.x) within 250 characters
        final blockRegex = RegExp(
          r'(\d{1,3}(?:\.\d{1,3}){3})[\s\S]{1,250}?(255\.\d{1,3}\.\d{1,3}\.\d{1,3})',
        );
        for (final match in blockRegex.allMatches(text)) {
          final ip = match.group(1)!;
          final mask = match.group(2)!;
          if (!map.containsKey(ip) && isValidIp(ip) && !ip.startsWith('255.')) {
            map[ip] = mask;
          }
        }
      }
    } catch (_) {}
    return map;
  }

  /// Lists all active network adapters on the host machine, classified by type.
  static Future<List<NetworkInterfaceDetails>> getAvailableAdapters() async {
    final List<NetworkInterfaceDetails> list = [];
    try {
      final netmasks = await _getWindowsSubnetMasks();
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
          final mask = netmasks[ip];
          final subnet = deriveSubnet(ip, mask);
          final prefix = mask != null ? maskToPrefixLength(mask) : 24;
          final slices = getSubnetSlices(subnet);

          list.add(
            NetworkInterfaceDetails(
              name: iface.name,
              ip: ip,
              subnet: subnet,
              isVirtual: isVirtual,
              isPrivateLan: isLan,
              netmask: mask,
              prefixLength: prefix,
              subSlices: slices,
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

  /// Returns all IPv4 addresses assigned to this host machine (physical, virtual, and loopback).
  static Future<Set<String>> getHostDeviceIps() async {
    final Set<String> ips = {'127.0.0.1', 'localhost'};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          ips.add(addr.address);
        }
      }
    } catch (_) {}
    return ips;
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
    final maxHosts = limit > 4096 ? 4096 : limit;

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

  /// Compares two IPv4 addresses numerically.
  /// Example: 172.21.168.2 comes before 172.21.168.10.
  static int compareIps(String ipA, String ipB) {
    final aParts = ipA.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = ipB.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    if (aParts.length == 4 && bParts.length == 4) {
      for (var i = 0; i < 4; i++) {
        final diff = aParts[i].compareTo(bParts[i]);
        if (diff != 0) return diff;
      }
    }
    return ipA.compareTo(ipB);
  }
}

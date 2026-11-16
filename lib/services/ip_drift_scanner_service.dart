import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../core/network/network_utils.dart';
import '../core/network/ping_engine.dart';
import '../data/models/managed_device.dart';

enum IpDriftStatus {
  jumpedByMac,
  jumpedByName,
  ipConflict,
  hostnameMismatch,
  onlineOk,
  offline,
}

class IpDriftTarget {
  final String? deviceId;
  final String name;
  final String expectedIp;
  final String? expectedMac;
  final String group;

  const IpDriftTarget({
    this.deviceId,
    required this.name,
    required this.expectedIp,
    this.expectedMac,
    this.group = 'Default',
  });

  factory IpDriftTarget.fromDevice(ManagedDevice d) {
    return IpDriftTarget(
      deviceId: d.id,
      name: d.name.trim().isNotEmpty
          ? d.name.trim()
          : (d.hostname.trim().isNotEmpty ? d.hostname.trim() : d.ip),
      expectedIp: d.ip.trim(),
      expectedMac: d.mac?.trim(),
      group: d.group,
    );
  }
}

class IpDriftAuditEntry {
  final IpDriftTarget target;
  final IpDriftStatus status;
  final bool oldIpOnline;
  final int? pingMs;
  final String? liveMacAtOldIp;
  final String? liveHostAtOldIp;
  final String? discoveredNewIp;
  final String? discoveredNewMac;
  final String? discoveredNewHost;
  final String detailMessage;

  const IpDriftAuditEntry({
    required this.target,
    required this.status,
    required this.oldIpOnline,
    this.pingMs,
    this.liveMacAtOldIp,
    this.liveHostAtOldIp,
    this.discoveredNewIp,
    this.discoveredNewMac,
    this.discoveredNewHost,
    required this.detailMessage,
  });

  bool get hasJumpedIp =>
      (status == IpDriftStatus.jumpedByMac ||
          status == IpDriftStatus.jumpedByName) &&
      discoveredNewIp != null &&
      discoveredNewIp!.isNotEmpty &&
      discoveredNewIp != target.expectedIp;

  bool get isIssue =>
      status == IpDriftStatus.jumpedByMac ||
      status == IpDriftStatus.jumpedByName ||
      status == IpDriftStatus.ipConflict ||
      status == IpDriftStatus.hostnameMismatch;
}

class _LiveHostProbe {
  final String ip;
  String? mac;
  String? rdpName;
  String? nbName;
  String? dnsName;
  int? latencyMs;

  _LiveHostProbe(this.ip);

  String? get bestHostname {
    if (rdpName != null && rdpName!.isNotEmpty) return rdpName;
    if (nbName != null && nbName!.isNotEmpty) return nbName;
    if (dnsName != null && dnsName!.isNotEmpty) return dnsName;
    return null;
  }
}

/// Smart Network Auditor for detecting IP Drift (DHCP IP jumps), MAC conflicts,
/// and renamed Windows/Linux hosts across factory subnets.
class IpDriftScannerService {
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
  }

  /// Normalizes MAC address to `AA-BB-CC-DD-EE-FF` uppercase format.
  static String? normalizeMac(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final hex = raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
    if (hex.length != 12) return null;
    final parts = <String>[];
    for (var i = 0; i < 12; i += 2) {
      parts.add(hex.substring(i, i + 2));
    }
    return parts.join('-');
  }

  /// Parses a pasted TSV/CSV/whitespace table of `Hostname  IP  MAC` lines
  /// and matches against existing [registeredDevices] when possible.
  static List<IpDriftTarget> parsePastedTargets(
    String rawText,
    List<ManagedDevice> registeredDevices,
  ) {
    final results = <IpDriftTarget>[];
    final ipRegex = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
    final macRegex = RegExp(
      r'\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b|\b[0-9A-Fa-f]{12}\b',
    );

    final byIp = <String, ManagedDevice>{};
    final byName = <String, ManagedDevice>{};
    final byMac = <String, ManagedDevice>{};
    for (final d in registeredDevices) {
      byIp[d.ip.trim()] = d;
      if (d.name.trim().isNotEmpty) {
        byName[d.name.trim().toUpperCase()] = d;
      }
      if (d.hostname.trim().isNotEmpty) {
        byName[d.hostname.trim().toUpperCase()] = d;
      }
      final normMac = normalizeMac(d.mac);
      if (normMac != null) {
        byMac[normMac] = d;
      }
    }

    for (final rawLine in const LineSplitter().convert(rawText)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final ipMatch = ipRegex.firstMatch(line);
      if (ipMatch == null) continue;
      final ip = ipMatch.group(0)!;
      if (!NetworkUtils.isValidIp(ip)) continue;

      final macMatch = macRegex.firstMatch(line);
      final mac = macMatch != null ? normalizeMac(macMatch.group(0)) : null;

      // Extract name by removing IP and MAC tokens from the line
      var namePart = line.replaceFirst(ip, ' ');
      if (macMatch != null) {
        namePart = namePart.replaceFirst(macMatch.group(0)!, ' ');
      }
      namePart = namePart
          .replaceAll('\t', ' ')
          .replaceAll(',', ' ')
          .replaceAll(';', ' ')
          .trim();
      final name = namePart.isNotEmpty ? namePart : ip;

      // Link to registered device if matched
      final matchedDev =
          byName[name.toUpperCase()] ??
          (mac != null ? byMac[mac] : null) ??
          byIp[ip];

      results.add(
        IpDriftTarget(
          deviceId: matchedDev?.id,
          name: name,
          expectedIp: ip,
          expectedMac: mac ?? normalizeMac(matchedDev?.mac),
          group: matchedDev?.group ?? 'Default',
        ),
      );
    }
    return results;
  }

  /// Runs a comprehensive multi-layer IP Drift & Conflict scan.
  Future<List<IpDriftAuditEntry>> runAudit({
    required List<IpDriftTarget> targets,
    bool sweepSubnetsForMissing = true,
    void Function(String phase, double progress)? onProgress,
  }) async {
    _isCancelled = false;
    if (targets.isEmpty) return [];

    // 1. Collect all target /24 subnets to sweep if needed
    onProgress?.call('Đang kiểm tra Ping & ARP các IP mục tiêu...', 0.10);

    final targetIps = targets.map((t) => t.expectedIp).toSet().toList();
    final pingMap = <String, PingResult>{};

    await for (final res in PingEngine.pingBatch(
      targetIps,
      maxConcurrent: 32,
      timeoutMs: 450,
    )) {
      if (_isCancelled) break;
      pingMap[res.ip] = res;
    }

    if (_isCancelled) return [];

    // 2. Sweep /24 subnets of target IPs so ARP cache and live host map are populated
    final subnetIpsToSweep = <String>{};
    if (sweepSubnetsForMissing) {
      final prefixes = <String>{};
      for (final ip in targetIps) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          prefixes.add('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
      // Also include adjacent 172.21.168..175 subnets if targets are in 172.21.168.0/21
      final has17221 = prefixes.any((p) => p.startsWith('172.21.1'));
      if (has17221) {
        for (var oct = 168; oct <= 175; oct++) {
          prefixes.add('172.21.$oct');
        }
      }
      for (final prefix in prefixes) {
        for (var host = 1; host <= 254; host++) {
          subnetIpsToSweep.add('$prefix.$host');
        }
      }
    }

    final liveProbes = <String, _LiveHostProbe>{};
    for (final e in pingMap.entries) {
      if (e.value.isOnline) {
        final probe = _LiveHostProbe(e.key)..latencyMs = e.value.latencyMs;
        liveProbes[e.key] = probe;
      }
    }

    if (sweepSubnetsForMissing && subnetIpsToSweep.isNotEmpty) {
      onProgress?.call(
        'Đang quét nhanh dải mạng (${subnetIpsToSweep.length} IP) để bắt máy nhảy IP...',
        0.30,
      );
      final sweepList = subnetIpsToSweep.toList();
      var done = 0;
      await for (final res in PingEngine.pingBatch(
        sweepList,
        maxConcurrent: 96,
        timeoutMs: 280,
      )) {
        if (_isCancelled) break;
        done++;
        if (res.isOnline) {
          final probe = liveProbes.putIfAbsent(
            res.ip,
            () => _LiveHostProbe(res.ip),
          );
          probe.latencyMs ??= res.latencyMs;
        }
        if (done % 200 == 0) {
          final frac = 0.30 + (done / sweepList.length) * 0.25;
          onProgress?.call(
            'Đang quét dải mạng ($done/${sweepList.length} IP)...',
            frac.clamp(0.30, 0.55),
          );
        }
      }
    }

    if (_isCancelled) return [];

    // 3. Harvest OS ARP / Neighbor Table for MAC addresses
    onProgress?.call('Đang thu thập bảng MAC (ARP / Neighbor Cache)...', 0.60);
    final arpMacByIp = await _readOsArpTable();
    for (final entry in arpMacByIp.entries) {
      final probe = liveProbes.putIfAbsent(
        entry.key,
        () => _LiveHostProbe(entry.key),
      );
      probe.mac = entry.value;
    }

    // 4. Probe RDP Certificate CN (TCP 3389) + NetBIOS (UDP 137) on all live hosts
    final probeIps = liveProbes.keys.toList();
    onProgress?.call(
      'Đang xác thực Hostname qua RDP Cert (3389) & NetBIOS (137) trên ${probeIps.length} máy...',
      0.70,
    );

    const int batchSize = 32;
    for (var i = 0; i < probeIps.length; i += batchSize) {
      if (_isCancelled) break;
      final end = (i + batchSize < probeIps.length)
          ? i + batchSize
          : probeIps.length;
      final batch = probeIps.sublist(i, end);
      await Future.wait(
        batch.map((ip) async {
          final probe = liveProbes[ip]!;
          // Query NetBIOS (UDP 137) and RDP Cert (TCP 3389) in parallel
          final results = await Future.wait([
            _queryNetBios(ip),
            _queryRdpCertCn(ip),
          ]);
          final nb = results[0] as _NetBiosInfo?;
          final rdpCn = results[1] as String?;
          if (nb != null) {
            if (nb.hostname != null && nb.hostname!.isNotEmpty) {
              probe.nbName = nb.hostname;
            }
            if ((probe.mac == null || probe.mac!.isEmpty) &&
                nb.mac != null &&
                nb.mac!.isNotEmpty) {
              probe.mac = nb.mac;
            }
          }
          if (rdpCn != null && rdpCn.isNotEmpty) {
            probe.rdpName = rdpCn;
          }
        }),
      );
      final frac = 0.70 + ((end / probeIps.length) * 0.22);
      onProgress?.call(
        'Đang xác thực Hostname ($end/${probeIps.length})...',
        frac.clamp(0.70, 0.92),
      );
    }

    if (_isCancelled) return [];

    // 5. Index live hosts by normalized MAC and by uppercase Hostname
    onProgress?.call('Đang đối soát nhảy IP & xung đột MAC...', 0.95);
    final ipByMac = <String, String>{};
    final ipByHostname = <String, String>{};

    for (final probe in liveProbes.values) {
      final normMac = normalizeMac(probe.mac);
      if (normMac != null && normMac != '00-00-00-00-00-00') {
        ipByMac[normMac] = probe.ip;
      }
      if (probe.rdpName != null && probe.rdpName!.isNotEmpty) {
        ipByHostname[probe.rdpName!.toUpperCase()] = probe.ip;
      }
      if (probe.nbName != null && probe.nbName!.isNotEmpty) {
        ipByHostname[probe.nbName!.toUpperCase()] = probe.ip;
      }
    }

    // 6. Classify every target
    final entries = <IpDriftAuditEntry>[];
    for (final t in targets) {
      final expectedMac = normalizeMac(t.expectedMac);
      final targetNameUpper = t.name.trim().toUpperCase();
      final pingAtOld = pingMap[t.expectedIp];
      final probeAtOld = liveProbes[t.expectedIp];
      final oldOnline =
          (pingAtOld?.isOnline ?? false) ||
          (probeAtOld?.rdpName != null) ||
          (probeAtOld?.nbName != null);
      final liveMacOld = normalizeMac(probeAtOld?.mac);
      final liveHostOld = probeAtOld?.bestHostname;

      final macFoundAtIp = expectedMac != null ? ipByMac[expectedMac] : null;
      final nameFoundAtIp = ipByHostname[targetNameUpper];

      // Case 1: Expected MAC was found at a DIFFERENT IP!
      if (macFoundAtIp != null && macFoundAtIp != t.expectedIp) {
        final newProbe = liveProbes[macFoundAtIp];
        entries.add(
          IpDriftAuditEntry(
            target: t,
            status: IpDriftStatus.jumpedByMac,
            oldIpOnline: oldOnline,
            pingMs: pingAtOld?.latencyMs ?? newProbe?.latencyMs,
            liveMacAtOldIp: liveMacOld,
            liveHostAtOldIp: liveHostOld,
            discoveredNewIp: macFoundAtIp,
            discoveredNewMac: expectedMac,
            discoveredNewHost: newProbe?.bestHostname,
            detailMessage:
                'NHẢY IP (theo MAC $expectedMac): ${t.expectedIp} → $macFoundAtIp'
                '${newProbe?.bestHostname != null ? " (${newProbe!.bestHostname})" : ""}',
          ),
        );
        continue;
      }

      // Case 2: Expected Hostname was found at a DIFFERENT IP!
      if (nameFoundAtIp != null && nameFoundAtIp != t.expectedIp) {
        final newProbe = liveProbes[nameFoundAtIp];
        entries.add(
          IpDriftAuditEntry(
            target: t,
            status: IpDriftStatus.jumpedByName,
            oldIpOnline: oldOnline,
            pingMs: pingAtOld?.latencyMs ?? newProbe?.latencyMs,
            liveMacAtOldIp: liveMacOld,
            liveHostAtOldIp: liveHostOld,
            discoveredNewIp: nameFoundAtIp,
            discoveredNewMac: normalizeMac(newProbe?.mac) ?? expectedMac,
            discoveredNewHost: newProbe?.bestHostname ?? t.name,
            detailMessage:
                'NHẢY IP (theo Tên máy ${t.name}): ${t.expectedIp} → $nameFoundAtIp'
                '${newProbe?.mac != null ? " [MAC: ${newProbe!.mac}]" : ""}',
          ),
        );
        continue;
      }

      // Case 3: Old IP is reachable or in ARP
      if (oldOnline || liveMacOld != null) {
        // Check if MAC at old IP conflicts with expected MAC
        if (expectedMac != null &&
            liveMacOld != null &&
            expectedMac != liveMacOld) {
          entries.add(
            IpDriftAuditEntry(
              target: t,
              status: IpDriftStatus.ipConflict,
              oldIpOnline: oldOnline,
              pingMs: pingAtOld?.latencyMs,
              liveMacAtOldIp: liveMacOld,
              liveHostAtOldIp: liveHostOld,
              detailMessage:
                  'XUNG ĐỘT IP / THAY CARD MẠNG: Đang bị chiếm bởi ${liveHostOld ?? "máy khác"} (MAC thực tế: $liveMacOld ≠ $expectedMac)',
            ),
          );
          continue;
        }

        // Check if MAC matches (or no expected MAC) but live Hostname is a different PC name
        if (liveHostOld != null &&
            liveHostOld.toUpperCase() != targetNameUpper &&
            !targetNameUpper.contains(liveHostOld.toUpperCase()) &&
            !liveHostOld.toUpperCase().contains(targetNameUpper)) {
          entries.add(
            IpDriftAuditEntry(
              target: t,
              status: IpDriftStatus.hostnameMismatch,
              oldIpOnline: true,
              pingMs: pingAtOld?.latencyMs,
              liveMacAtOldIp: liveMacOld ?? expectedMac,
              liveHostAtOldIp: liveHostOld,
              detailMessage:
                  'Đúng IP & MAC nhưng Tên máy Windows hiện tại là "$liveHostOld"',
            ),
          );
          continue;
        }

        entries.add(
          IpDriftAuditEntry(
            target: t,
            status: IpDriftStatus.onlineOk,
            oldIpOnline: true,
            pingMs: pingAtOld?.latencyMs,
            liveMacAtOldIp: liveMacOld ?? expectedMac,
            liveHostAtOldIp: liveHostOld ?? t.name,
            detailMessage: 'Đúng IP & MAC (${liveHostOld ?? t.name})',
          ),
        );
        continue;
      }

      // Case 4: Offline
      entries.add(
        IpDriftAuditEntry(
          target: t,
          status: IpDriftStatus.offline,
          oldIpOnline: false,
          detailMessage: 'Offline / Không phản hồi trên mạng',
        ),
      );
    }

    onProgress?.call('Hoàn tất kiểm tra ${entries.length} máy!', 1.0);
    return entries;
  }

  /// Reads the OS ARP table (`arp -a`) and returns `IP -> Normalized MAC`.
  Future<Map<String, String>> _readOsArpTable() async {
    final map = <String, String>{};
    try {
      final res = await Process.run('arp', ['-a']);
      if (res.exitCode == 0) {
        final out = res.stdout.toString();
        final lineRegex = RegExp(
          r'(\d{1,3}(?:\.\d{1,3}){3})\s+([0-9a-fA-F]{2}(?:[:-][0-9a-fA-F]{2}){5})',
        );
        for (final match in lineRegex.allMatches(out)) {
          final ip = match.group(1)!;
          final mac = normalizeMac(match.group(2));
          if (mac != null &&
              mac != 'FF-FF-FF-FF-FF-FF' &&
              mac != '00-00-00-00-00-00') {
            map[ip] = mac;
          }
        }
      }
    } catch (_) {}
    return map;
  }

  /// Queries TCP 3389 (RDP) with TLS handshake to read the X.509 Certificate
  /// Subject `CN=...` (Windows ComputerName), which works without credentials!
  Future<String?> _queryRdpCertCn(String ip) async {
    Socket? rawSocket;
    SecureSocket? tlsSocket;
    try {
      rawSocket = await Socket.connect(
        ip,
        3389,
        timeout: const Duration(milliseconds: 550),
      );
      String? extractedSubject;
      tlsSocket = await SecureSocket.secure(
        rawSocket,
        host: ip,
        onBadCertificate: (X509Certificate cert) {
          extractedSubject = cert.subject;
          return true;
        },
      ).timeout(const Duration(milliseconds: 650));
      extractedSubject ??= tlsSocket.peerCertificate?.subject;
      if (extractedSubject != null && extractedSubject!.isNotEmpty) {
        final cnMatch = RegExp(r'CN=([^,/]+)').firstMatch(extractedSubject!);
        final rawCn = (cnMatch != null ? cnMatch.group(1)! : extractedSubject!)
            .trim();
        if (rawCn.isNotEmpty) {
          return rawCn.split('.').first.trim();
        }
      }
    } catch (_) {
      // Many hosts close after bad cert or don't have 3389 open
    } finally {
      try {
        tlsSocket?.destroy();
      } catch (_) {}
      try {
        rawSocket?.destroy();
      } catch (_) {}
    }
    return null;
  }

  /// Sends a UDP 137 NetBIOS Node Status (`NBSTAT`) packet and parses the
  /// workstation name (`<00>` UNIQUE) and unit ID MAC address.
  Future<_NetBiosInfo?> _queryNetBios(String ip) async {
    RawDatagramSocket? udp;
    try {
      udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final packet = Uint8List.fromList([
        0x80,
        0x94,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x20,
        0x43,
        0x4B,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x41,
        0x00,
        0x00,
        0x21,
        0x00,
        0x01,
      ]);

      final completer = Completer<_NetBiosInfo?>();
      udp.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = udp?.receive();
          if (dg != null && dg.data.length > 57) {
            final data = dg.data;
            final numNames = data[56];
            var pos = 57;
            String? host;
            for (var i = 0; i < numNames; i++) {
              if (pos + 18 > data.length) break;
              final nameBytes = data.sublist(pos, pos + 15);
              final type = data[pos + 15];
              final flags = data[pos + 16];
              final isGroup = (flags & 0x80) != 0;
              if (type == 0x00 && !isGroup && host == null) {
                final str = ascii
                    .decode(nameBytes, allowInvalid: true)
                    .replaceAll('\x00', '')
                    .trim();
                if (str.isNotEmpty) {
                  host = str;
                }
              }
              pos += 18;
            }
            String? mac;
            if (pos + 6 <= data.length) {
              final macBytes = data.sublist(pos, pos + 6);
              final candidate = macBytes
                  .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                  .join('-');
              if (candidate != '00-00-00-00-00-00') {
                mac = candidate;
              }
            }
            if (!completer.isCompleted) {
              completer.complete(_NetBiosInfo(hostname: host, mac: mac));
            }
          }
        }
      });

      udp.send(packet, InternetAddress(ip), 137);
      return await completer.future.timeout(
        const Duration(milliseconds: 450),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    } finally {
      try {
        udp?.close();
      } catch (_) {}
    }
  }
}

class _NetBiosInfo {
  final String? hostname;
  final String? mac;

  const _NetBiosInfo({this.hostname, this.mac});
}

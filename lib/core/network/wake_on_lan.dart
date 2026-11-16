import 'dart:io';
import 'dart:typed_data';
import 'network_utils.dart';

/// Wake-on-LAN (WOL) implementation for waking PCs over LAN.
class WakeOnLan {
  /// Builds standard 102-byte Magic Packet for given MAC address.
  static Uint8List createMagicPacket(String mac) {
    final cleanMac = mac
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '')
        .trim();

    if (cleanMac.length != 12) {
      throw FormatException('Invalid MAC address length: $mac');
    }

    final macBytes = Uint8List(6);
    for (int i = 0; i < 6; i++) {
      final hex = cleanMac.substring(i * 2, i * 2 + 2);
      final byte = int.tryParse(hex, radix: 16);
      if (byte == null) {
        throw FormatException('Invalid hex character in MAC: $hex');
      }
      macBytes[i] = byte;
    }

    // 6 bytes of 0xFF + 16 * 6 bytes of MAC = 102 bytes
    final packet = Uint8List(102);
    for (int i = 0; i < 6; i++) {
      packet[i] = 0xFF;
    }

    for (int i = 0; i < 16; i++) {
      packet.setRange(6 + (i * 6), 6 + ((i + 1) * 6), macBytes);
    }

    return packet;
  }

  /// Sends Wake-on-LAN Magic Packet via UDP broadcast.
  ///
  /// When [localBindIp] is supplied alongside a supernet-directed [broadcastIp]
  /// (and optional [extraBroadcastIps]), an additional socket bound directly to
  /// that physical LAN interface is used so virtual adapters cannot hijack
  /// `255.255.255.255` broadcasts.
  static Future<bool> wake({
    required String mac,
    String broadcastIp = '255.255.255.255',
    int port = 9,
    String? localBindIp,
    Iterable<String> extraBroadcastIps = const [],
  }) async {
    try {
      final packet = createMagicPacket(mac);
      final targets = <String>{};
      final cleanPrimary = broadcastIp.trim();
      if (NetworkUtils.isValidIp(cleanPrimary)) {
        targets.add(cleanPrimary);
      }
      for (final extra in extraBroadcastIps) {
        final cleanExtra = extra.trim();
        if (NetworkUtils.isValidIp(cleanExtra)) {
          targets.add(cleanExtra);
        }
      }
      targets.add('255.255.255.255');

      await _sendViaAddress(InternetAddress.anyIPv4, packet, targets, port);

      final cleanBind = localBindIp?.trim();
      if (cleanBind != null &&
          cleanBind.isNotEmpty &&
          cleanBind != '0.0.0.0' &&
          NetworkUtils.isValidIp(cleanBind)) {
        try {
          await _sendViaAddress(
            InternetAddress(cleanBind),
            packet,
            targets,
            port,
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _sendViaAddress(
    InternetAddress bindAddr,
    Uint8List packet,
    Set<String> targets,
    int port,
  ) async {
    final socket = await RawDatagramSocket.bind(bindAddr, 0);
    try {
      socket.broadcastEnabled = true;
      for (final target in targets) {
        final targetAddr = InternetAddress(target);
        socket.send(packet, targetAddr, port);
        if (port != 7) {
          socket.send(packet, targetAddr, 7);
        }
      }
    } finally {
      socket.close();
    }
  }
}

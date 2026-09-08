import 'dart:io';
import 'dart:typed_data';

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
  static Future<bool> wake({
    required String mac,
    String broadcastIp = '255.255.255.255',
    int port = 9,
  }) async {
    try {
      final packet = createMagicPacket(mac);
      final targetAddr = InternetAddress(broadcastIp);

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // Send to primary port and fallback port (9 and 7)
      socket.send(packet, targetAddr, port);
      if (port != 7) {
        socket.send(packet, targetAddr, 7);
      }

      // Also send to global broadcast 255.255.255.255 if directed broadcast was specified
      if (broadcastIp != '255.255.255.255') {
        socket.send(packet, InternetAddress('255.255.255.255'), port);
      }

      socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}

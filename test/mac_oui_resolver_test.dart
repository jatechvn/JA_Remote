import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/mac_oui_resolver.dart';

void main() {
  test(
    'rejects malformed, truncated and locally administered vendor identities',
    () {
      for (final mac in [
        'F86FB0',
        'F8:6F:B0:00:00:00:11',
        'F8:6F:B0:ZZ:00:00',
        'junk F86FB04A0BC3',
      ]) {
        expect(MacOuiResolver.lookup(mac), isNull, reason: mac);
      }
      expect(MacOuiResolver.lookup('FA:1A:67:00:11:22'), isNull);
      expect(
        MacOuiResolver.resolveFriendlyTitle(
          ip: '192.0.2.1',
          mac: 'FA:1A:67:00:11:22',
        ),
        'PC-192.0.2.1',
      );
    },
  );
  group('MacOuiResolver tests', () {
    test(
      'cleanMac normalizes various MAC formats to 12 uppercase hex chars',
      () {
        expect(MacOuiResolver.cleanMac('f8-6f-b0-4a-0b-c3'), 'F86FB04A0BC3');
        expect(MacOuiResolver.cleanMac('F8:6F:B0:4A:0B:C3'), 'F86FB04A0BC3');
        expect(MacOuiResolver.cleanMac('f86f.b04a.0bc3'), 'F86FB04A0BC3');
        expect(MacOuiResolver.cleanMac('F86FB04A0BC3'), 'F86FB04A0BC3');
        expect(MacOuiResolver.cleanMac(null), isNull);
        expect(MacOuiResolver.cleanMac(''), isNull);
        expect(MacOuiResolver.cleanMac('12:34'), isNull);
      },
    );

    test('extractOui extracts first 6 hex characters', () {
      expect(MacOuiResolver.extractOui('f8-6f-b0-4a-0b-c3'), 'F86FB0');
      expect(MacOuiResolver.extractOui('00:00:0c:12:34:56'), '00000C');
      expect(MacOuiResolver.extractOui(null), isNull);
    });

    test('lookup resolves vendors accurately and offline', () {
      // User's specific TP-Link device IP 172.21.174.41
      expect(MacOuiResolver.lookup('f8-6f-b0-4a-0b-c3'), 'TP-Link');
      expect(MacOuiResolver.lookup('50:D4:F7:11:22:33'), 'TP-Link');

      // Major network and hardware vendors
      expect(MacOuiResolver.lookup('00:00:0C:12:34:56'), 'Cisco');
      expect(MacOuiResolver.lookup('00-1B-21-AA-BB-CC'), 'Intel');
      expect(MacOuiResolver.lookup('00:E0:4C:11:22:33'), 'Realtek');
      expect(MacOuiResolver.lookup('00:14:22:33:44:55'), 'Dell');
      expect(MacOuiResolver.lookup('00:1E:0B:AA:BB:CC'), 'HP');
      expect(MacOuiResolver.lookup('00:17:F2:12:34:56'), 'Apple');
      expect(MacOuiResolver.lookup('B8:27:EB:01:02:03'), 'Raspberry Pi');
      expect(MacOuiResolver.lookup('24:0A:C4:AA:BB:CC'), 'Espressif');
      expect(MacOuiResolver.lookup('00:15:6D:11:22:33'), 'Ubiquiti');
      expect(MacOuiResolver.lookup('00:0C:42:44:55:66'), 'MikroTik');
      expect(MacOuiResolver.lookup('00:11:32:77:88:99'), 'Synology');
      expect(MacOuiResolver.lookup('44:19:B6:01:02:03'), 'Hikvision');
      expect(MacOuiResolver.lookup('6C:03:B5:C7:E0:E8'), 'Cisco');
      expect(MacOuiResolver.lookup('C4:AB:4D:50:78:68'), 'Cisco');
      expect(MacOuiResolver.lookup('7C:A6:2A:8F:81:84'), 'HP');
      expect(MacOuiResolver.lookup('F4:EE:14:21:80:28'), 'Mercury');
      expect(MacOuiResolver.lookup('70:79:38:B0:AA:B2'), 'Zhanrui');
      expect(MacOuiResolver.lookup('68:1D:EF:40:EA:BA'), 'CYX');
      expect(MacOuiResolver.lookup('74:49:D2:13:6F:E3'), 'H3C');
      expect(MacOuiResolver.lookup('10:70:FD:88:24:D5'), 'Mellanox');
      expect(MacOuiResolver.lookup('80:AE:54:89:59:73'), 'TP-Link');
      expect(MacOuiResolver.lookup('2C:F0:5D:F3:E6:53'), 'MSI');
      expect(MacOuiResolver.lookup('9C:69:B4:65:48:A9'), 'Jiahua Zhongli');
      expect(MacOuiResolver.lookup('0C:C3:B8:11:22:33'), 'Jiahua Zhongli');
      expect(MacOuiResolver.lookup('98:20:44:CF:23:D3'), 'H3C');
      expect(MacOuiResolver.lookup('9C:47:82:D6:54:93'), 'TP-Link');
      expect(MacOuiResolver.lookup('54:B2:03:18:B4:EC'), 'Pegatron');
      expect(MacOuiResolver.lookup('9C:69:D3:0E:CB:3D'), 'ASIX');
      expect(MacOuiResolver.lookup('28:C5:C8:7D:FD:E8'), 'HP');
      expect(MacOuiResolver.lookup('24:6A:0E:79:A1:9A'), 'HP');
      expect(MacOuiResolver.lookup('00:D0:C9:11:22:33'), 'Advantech');

      // Unknown or null MAC
      expect(MacOuiResolver.lookup('02:00:00:00:00:00'), isNull);
      expect(MacOuiResolver.lookup(null), isNull);
      expect(MacOuiResolver.lookup(''), isNull);
    });

    test('resolveFriendlyTitle handles hostnames, vendors, and fallbacks', () {
      // 1. Hostname present and distinct from IP
      expect(
        MacOuiResolver.resolveFriendlyTitle(
          ip: '192.168.1.10',
          mac: '00:14:22:33:44:55',
          hostname: 'DESKTOP-JOHN',
        ),
        'DESKTOP-JOHN',
      );

      // FQDN hostname
      expect(
        MacOuiResolver.resolveFriendlyTitle(
          ip: '192.168.1.10',
          mac: '00:14:22:33:44:55',
          hostname: 'server01.corp.lan',
        ),
        'server01',
      );

      // 2. No hostname, known vendor (TP-Link from user scenario)
      expect(
        MacOuiResolver.resolveFriendlyTitle(
          ip: '172.21.174.41',
          mac: 'f8-6f-b0-4a-0b-c3',
          hostname: '',
        ),
        'TP-Link (172.21.174.41)',
      );

      // Hostname equals IP, known vendor
      expect(
        MacOuiResolver.resolveFriendlyTitle(
          ip: '172.21.174.41',
          mac: 'f8-6f-b0-4a-0b-c3',
          hostname: '172.21.174.41',
        ),
        'TP-Link (172.21.174.41)',
      );

      // 3. No hostname, unknown MAC
      expect(
        MacOuiResolver.resolveFriendlyTitle(
          ip: '192.168.1.99',
          mac: '02:00:00:00:00:00',
          hostname: '',
        ),
        'PC-192.168.1.99',
      );

      // No MAC at all
      expect(
        MacOuiResolver.resolveFriendlyTitle(
          ip: '192.168.1.99',
          mac: null,
          hostname: null,
        ),
        'PC-192.168.1.99',
      );
    });

    test('isNetworkDevice distinguishes network hardware from PCs', () {
      expect(
        MacOuiResolver.isNetworkDevice('f8-6f-b0-4a-0b-c3'),
        isTrue,
      ); // TP-Link
      expect(
        MacOuiResolver.isNetworkDevice('00:00:0C:12:34:56'),
        isTrue,
      ); // Cisco
      expect(
        MacOuiResolver.isNetworkDevice('00:15:6D:11:22:33'),
        isTrue,
      ); // Ubiquiti
      expect(
        MacOuiResolver.isNetworkDevice('00:0C:42:44:55:66'),
        isTrue,
      ); // MikroTik
      expect(
        MacOuiResolver.isNetworkDevice('00:11:32:77:88:99'),
        isTrue,
      ); // Synology
      expect(
        MacOuiResolver.isNetworkDevice('74:49:D2:13:6F:E3'),
        isTrue,
      ); // H3C
      expect(
        MacOuiResolver.isNetworkDevice('F4:EE:14:21:80:28'),
        isTrue,
      ); // Mercury

      expect(
        MacOuiResolver.isNetworkDevice('00:14:22:33:44:55'),
        isFalse,
      ); // Dell
      expect(
        MacOuiResolver.isNetworkDevice('00:17:F2:12:34:56'),
        isFalse,
      ); // Apple
      expect(MacOuiResolver.isNetworkDevice(null), isFalse);
    });

    test('isLocallyAdministered detects private and randomized MACs', () {
      expect(MacOuiResolver.isLocallyAdministered('5E:7D:B3:FF:FC:30'), isTrue);
      expect(MacOuiResolver.isLocallyAdministered('FA:1A:67:00:11:22'), isTrue);
      expect(
        MacOuiResolver.isLocallyAdministered('F8:6F:B0:4A:0B:C3'),
        isFalse,
      );
      expect(
        MacOuiResolver.isLocallyAdministered('48:EA:62:4F:B6:36'),
        isFalse,
      );
      expect(MacOuiResolver.isLocallyAdministered(null), isFalse);
    });
  });

  group('MacOuiResolver Custom JSON Persistence Tests', () {
    late File tempFile;

    setUp(() async {
      tempFile = File(
        '${Directory.systemTemp.path}/test_mac_oui_${DateTime.now().microsecondsSinceEpoch}.json',
      );
      MacOuiResolver.setStorageFileForTesting(tempFile);
      MacOuiResolver.clearCustomMappingsForTesting();
    });

    tearDown(() async {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      MacOuiResolver.clearCustomMappingsForTesting();
      MacOuiResolver.setStorageFileForTesting(null);
    });

    test('cleanOUI normalizes various prefix and MAC formats', () {
      expect(MacOuiResolver.cleanOUI('9C:69:D3'), '9C69D3');
      expect(MacOuiResolver.cleanOUI('9c-69-d3'), '9C69D3');
      expect(MacOuiResolver.cleanOUI('9c69.d3'), '9C69D3');
      expect(MacOuiResolver.cleanOUI('9c69d3'), '9C69D3');
      expect(MacOuiResolver.cleanOUI('9C:69:D3:0E:CB:3D'), '9C69D3');
      expect(MacOuiResolver.cleanOUI('9C:69'), isNull);
      expect(MacOuiResolver.cleanOUI(''), isNull);
      expect(MacOuiResolver.cleanOUI(null), isNull);
    });

    test(
      'setCustomMapping persists to JSON file and overrides built-in',
      () async {
        // 1. Initial lookup
        expect(MacOuiResolver.lookup('9C:69:D3:0E:CB:3D'), 'ASIX');

        // 2. Set custom override
        final oui = await MacOuiResolver.setCustomMapping(
          '9C:69:D3',
          'Custom ASIX TE Dongle',
        );
        expect(oui, '9C69D3');
        expect(MacOuiResolver.totalCustomCount, 1);
        expect(
          MacOuiResolver.lookup('9C:69:D3:0E:CB:3D'),
          'Custom ASIX TE Dongle',
        );

        // Verify file was written
        expect(await tempFile.exists(), isTrue);
        final jsonContent = jsonDecode(await tempFile.readAsString());
        expect(jsonContent['9C69D3'], 'Custom ASIX TE Dongle');

        // 3. Add brand new custom OUI
        await MacOuiResolver.setCustomMapping('A1:B2:C3', 'My Lab Fixture');
        expect(MacOuiResolver.lookup('A1:B2:C3:44:55:66'), 'My Lab Fixture');
        expect(
          MacOuiResolver.resolveFriendlyTitle(
            ip: '172.21.170.99',
            mac: 'A1:B2:C3:44:55:66',
          ),
          'My Lab Fixture (172.21.170.99)',
        );

        // 4. Remove custom mapping
        final removed = await MacOuiResolver.removeCustomMapping('9C69D3');
        expect(removed, isTrue);

        // Reverts back to built-in ASIX
        expect(MacOuiResolver.lookup('9C:69:D3:0E:CB:3D'), 'ASIX');

        // 5. Test reloading from file
        MacOuiResolver.clearCustomMappingsForTesting();
        expect(MacOuiResolver.totalCustomCount, 0);

        final loadedCount = await MacOuiResolver.loadCustomMappings();
        expect(loadedCount, 1);
        expect(MacOuiResolver.lookup('A1:B2:C3:44:55:66'), 'My Lab Fixture');
      },
    );
  });
}

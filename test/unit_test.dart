import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/network_utils.dart';
import 'package:ja_remote/core/network/wake_on_lan.dart';
import 'package:ja_remote/core/process/process_runner.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/data/models/saved_credential.dart';
import 'package:ja_remote/data/models/command_template.dart';
import 'package:flutter/material.dart';
import 'package:ja_remote/theme/styles_win10.dart';
import 'package:ja_remote/widgets/glass_widgets.dart';
import 'package:ja_remote/services/config_backup_service.dart';
import 'package:ja_remote/services/discovery_service.dart';
import 'package:ja_remote/services/device_service.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/core/utils/everything_search_matcher.dart';

void main() {
  group('NetworkUtils Tests', () {
    test('isValidIp validates IPv4 correctly', () {
      expect(NetworkUtils.isValidIp('172.19.116.157'), isTrue);
      expect(NetworkUtils.isValidIp('192.168.1.1'), isTrue);
      expect(NetworkUtils.isValidIp('256.0.0.1'), isFalse);
      expect(NetworkUtils.isValidIp('abc.def.ghi.jkl'), isFalse);
      expect(NetworkUtils.isValidIp('192.168.1'), isFalse);
    });

    test('expandSubnet expands /24 subnet accurately', () {
      final hosts = NetworkUtils.expandSubnet('172.19.116.0/24');
      expect(hosts.length, equals(254));
      expect(hosts.first, equals('172.19.116.1'));
      expect(hosts.last, equals('172.19.116.254'));
    });

    test('getBroadcastIp returns directed broadcast', () {
      expect(
        NetworkUtils.getBroadcastIp('172.19.116.0/24'),
        equals('172.19.116.255'),
      );
    });

    test(
      'isVirtualAdapter accurately identifies Tailscale and virtual adapters',
      () {
        // Tailscale adapter name or CGNAT IP (100.64.0.0 - 100.127.255.255)
        expect(
          NetworkUtils.isVirtualAdapter('Tailscale', '100.114.185.99'),
          isTrue,
        );
        expect(
          NetworkUtils.isVirtualAdapter('Ethernet', '100.114.185.99'),
          isTrue,
        );
        expect(
          NetworkUtils.isVirtualAdapter('vEthernet (WSL)', '172.28.0.1'),
          isTrue,
        );
        expect(
          NetworkUtils.isVirtualAdapter('TAP-Windows Adapter V9', '10.8.0.2'),
          isTrue,
        );
        expect(NetworkUtils.isVirtualAdapter('docker0', '172.17.0.1'), isTrue);

        // Real physical LAN adapters
        expect(
          NetworkUtils.isVirtualAdapter('Ethernet', '192.168.100.66'),
          isFalse,
        );
        expect(
          NetworkUtils.isVirtualAdapter('Ethernet 2', '172.21.175.40'),
          isFalse,
        );
        expect(NetworkUtils.isVirtualAdapter('Wi-Fi', '192.168.1.50'), isFalse);
      },
    );

    test('isPrivateLanIp correctly checks RFC 1918 subnets', () {
      expect(NetworkUtils.isPrivateLanIp('192.168.100.66'), isTrue);
      expect(NetworkUtils.isPrivateLanIp('172.21.175.40'), isTrue);
      expect(NetworkUtils.isPrivateLanIp('10.0.10.5'), isTrue);

      // Tailscale / CGNAT / Public / Loopback
      expect(NetworkUtils.isPrivateLanIp('100.114.185.99'), isFalse);
      expect(NetworkUtils.isPrivateLanIp('8.8.8.8'), isFalse);
      expect(NetworkUtils.isPrivateLanIp('1.1.1.1'), isFalse);
    });

    test('deriveSubnet generates correct /24 CIDR', () {
      expect(
        NetworkUtils.deriveSubnet('172.21.175.40'),
        equals('172.21.175.0/24'),
      );
      expect(
        NetworkUtils.deriveSubnet('192.168.100.66'),
        equals('192.168.100.0/24'),
      );
    });

    test('maskToPrefixLength calculates prefix length correctly', () {
      expect(NetworkUtils.maskToPrefixLength('255.255.255.0'), equals(24));
      expect(NetworkUtils.maskToPrefixLength('255.255.248.0'), equals(21));
      expect(NetworkUtils.maskToPrefixLength('255.255.252.0'), equals(22));
      expect(NetworkUtils.maskToPrefixLength('255.255.0.0'), equals(16));
      expect(NetworkUtils.maskToPrefixLength('255.0.0.0'), equals(8));
      expect(NetworkUtils.maskToPrefixLength('255.255.255.255'), equals(32));
    });

    test('calculateCidrSubnet computes accurate network CIDR', () {
      // User actual environment: 172.21.175.40 with mask 255.255.248.0 (/21)
      expect(
        NetworkUtils.calculateCidrSubnet('172.21.175.40', '255.255.248.0'),
        equals('172.21.168.0/21'),
      );
      // Fallback without mask
      expect(
        NetworkUtils.calculateCidrSubnet('172.21.175.40'),
        equals('172.21.175.0/24'),
      );
    });

    test('getSubnetSlices divides supernet into /24 constituent subnets', () {
      final slices = NetworkUtils.getSubnetSlices('172.21.168.0/21');
      expect(slices.length, equals(8));
      expect(slices.first, equals('172.21.168.0/24'));
      expect(slices.last, equals('172.21.175.0/24'));
      expect(slices, contains('172.21.169.0/24'));
      expect(slices, contains('172.21.171.0/24'));
      expect(slices, contains('172.21.174.0/24'));
    });

    test('expandSubnet expands full /21 supernet (2046 hosts)', () {
      final hosts = NetworkUtils.expandSubnet('172.21.168.0/21');
      expect(hosts.length, equals(2046));
      expect(hosts.first, equals('172.21.168.1'));
      expect(hosts.last, equals('172.21.175.254'));
      expect(hosts, contains('172.21.171.3'));
      expect(hosts, contains('172.21.174.41'));
      expect(hosts, contains('172.21.175.40'));
    });

    test('compareIps numerically sorts IPv4 addresses correctly', () {
      expect(
        NetworkUtils.compareIps('172.21.168.2', '172.21.168.10'),
        lessThan(0),
      );
      expect(
        NetworkUtils.compareIps('172.21.168.10', '172.21.168.2'),
        greaterThan(0),
      );
      expect(
        NetworkUtils.compareIps('172.21.168.2', '172.21.168.2'),
        equals(0),
      );
      expect(
        NetworkUtils.compareIps('172.21.168.200', '172.21.171.3'),
        lessThan(0),
      );
      expect(NetworkUtils.compareIps('10.0.0.1', '192.168.1.1'), lessThan(0));
    });

    test(
      'getAvailableAdapters detects adapters and calculates supernet if present',
      () async {
        final adapters = await NetworkUtils.getAvailableAdapters();
        expect(adapters, isA<List<NetworkInterfaceDetails>>());
        final eth2 = adapters.where((a) => a.name == 'Ethernet 2').firstOrNull;
        if (eth2 != null) {
          expect(eth2.prefixLength, equals(21));
          expect(eth2.subnet, equals('172.21.168.0/21'));
          expect(eth2.subSlices.length, equals(8));
          expect(eth2.subSlices, contains('172.21.171.0/24'));
          expect(eth2.subSlices, contains('172.21.174.0/24'));
          expect(eth2.subSlices, contains('172.21.175.0/24'));
        }
      },
    );
  });

  group('WakeOnLan Magic Packet Tests', () {
    test(
      'createMagicPacket produces exact 102-byte payload with correct MAC repetition',
      () {
        const mac = 'A4:B1:C1:22:33:44';
        final packet = WakeOnLan.createMagicPacket(mac);

        expect(packet.length, equals(102));

        // Header: 6 bytes of 0xFF
        for (int i = 0; i < 6; i++) {
          expect(packet[i], equals(0xFF));
        }

        // MAC repetition: 16 times
        final expectedMacBytes = [0xA4, 0xB1, 0xC1, 0x22, 0x33, 0x44];
        for (int r = 0; r < 16; r++) {
          final start = 6 + (r * 6);
          for (int b = 0; b < 6; b++) {
            expect(packet[start + b], equals(expectedMacBytes[b]));
          }
        }
      },
    );

    test('createMagicPacket throws FormatException on invalid MAC', () {
      expect(
        () => WakeOnLan.createMagicPacket('INVALID-MAC'),
        throwsFormatException,
      );
    });
  });

  group('ManagedDevice Model Tests', () {
    test('Serialization and Deserialization works seamlessly', () {
      final dev = ManagedDevice(
        id: 'test_pc1',
        name: 'L6-TE01',
        hostname: 'L6-TE01.corp.local',
        ip: '172.19.116.157',
        mac: 'A4:B1:C1:11:22:33',
        os: 'Windows',
        online: true,
        pingMs: 2,
        username: 'Administrator',
        password: 'SecretPassword123',
        group: 'L6',
        note: 'Main station',
      );

      final json = dev.toJson();
      final restored = ManagedDevice.fromJson(json);

      expect(restored.id, equals(dev.id));
      expect(restored.name, equals(dev.name));
      expect(restored.ip, equals(dev.ip));
      expect(restored.mac, equals(dev.mac));
      expect(restored.online, isTrue);
      expect(restored.pingMs, equals(2));
      expect(restored.username, equals('Administrator'));
      expect(restored.password, equals('SecretPassword123'));
      expect(restored.group, equals('L6'));
    });

    test('copyWith updates fields correctly', () {
      final dev = ManagedDevice(
        id: 'test_pc1',
        name: 'L6-TE01',
        hostname: 'L6-TE01.corp.local',
        ip: '172.19.116.157',
        online: false,
      );

      final updated = dev.copyWith(
        online: true,
        pingMs: 5,
        password: 'UpdatedPass',
      );
      expect(updated.online, isTrue);
      expect(updated.pingMs, equals(5));
      expect(updated.password, equals('UpdatedPass'));
      expect(updated.ip, equals('172.19.116.157'));
    });
  });

  group('CommandTemplate Tests', () {
    test(
      'getDefaultTemplates loads predefined commands for Windows and Linux',
      () {
        final list = CommandTemplate.getDefaultTemplates();
        expect(list.isNotEmpty, isTrue);
        expect(list.any((t) => t.platform == 'windows'), isTrue);
        expect(list.any((t) => t.platform == 'linux'), isTrue);
      },
    );
  });

  group('ProcessRunner Tests', () {
    test('toEncodedCommand generates valid UTF-16LE Base64', () {
      const script = 'Write-Output "Hello"';
      final encoded = ProcessRunner.toEncodedCommand(script);
      expect(encoded.isNotEmpty, isTrue);

      final bytes = base64.decode(encoded);
      expect(bytes.length, equals(script.length * 2));
      expect(bytes[0], equals(87)); // 'W'
      expect(bytes[1], equals(0));
    });
  });

  group('SavedCredential Tests', () {
    test('toJson and fromJson work properly', () {
      final cred = SavedCredential(
        id: 'cred_1',
        username: 'Admin',
        password: 'Password123!',
        label: 'Default Admin',
        lastUsed: DateTime(2026, 9, 8, 8, 0),
      );

      final json = cred.toJson();
      final restored = SavedCredential.fromJson(json);

      expect(restored.id, equals('cred_1'));
      expect(restored.username, equals('Admin'));
      expect(restored.password, equals('Password123!'));
      expect(restored.label, equals('Default Admin'));
      expect(restored.lastUsed, equals(DateTime(2026, 9, 8, 8, 0)));
    });

    test('displayTitle formats username and label cleanly', () {
      final cred1 = SavedCredential(
        id: 'cred_1',
        username: 'Admin',
        password: 'pass',
        label: 'Production Key',
      );
      expect(cred1.displayTitle, equals('Admin (Production Key)'));

      final cred2 = SavedCredential(
        id: 'cred_2',
        username: 'root',
        password: 'pass',
      );
      expect(cred2.displayTitle, equals('root'));
    });
  });

  group('ConfigBackupService Tests', () {
    test('previewConfigFile successfully parses config_sample.json', () async {
      final service = ConfigBackupService();
      final preview = await service.previewConfigFile('config_sample.json');

      expect(preview.isValid, isTrue);
      expect(preview.error, isNull);
      expect(preview.deviceCount, equals(5));
      expect(preview.devices.any((d) => d.name == 'CMDL04'), isTrue);
      expect(
        preview.devices.firstWhere((d) => d.name == 'CMDL04').ip,
        equals('172.21.174.208'),
      );
      expect(preview.credentialCount, equals(1));
      expect(preview.credentials.first.username, equals('Administrator'));
    });

    test('previewConfigFile gracefully rejects non-existent file', () async {
      final service = ConfigBackupService();
      final preview = await service.previewConfigFile(
        'non_existent_file_xyz.json',
      );

      expect(preview.isValid, isFalse);
      expect(preview.error, isNotNull);
    });
  });

  group('CommandTemplate & Dropdown Item Tests', () {
    test('CommandTemplate equality and hashCode by id', () {
      const t1 = CommandTemplate(
        id: 'win_uptime',
        name: 'Windows: Xem Uptime',
        platform: 'windows',
        type: 'powershell',
        command: '(get-date)',
      );
      const t2 = CommandTemplate(
        id: 'win_uptime',
        name: 'Different Name',
        platform: 'windows',
        type: 'powershell',
        command: 'different command',
      );
      expect(t1 == t2, isTrue);
      expect(t1.hashCode, equals(t2.hashCode));
    });

    test('GlassDropdownItem holds properties correctly', () {
      const item = GlassDropdownItem<String>(
        value: 'dev1',
        label: 'CMDL04',
        subtitle: '172.21.174.208',
        badge: 'ONLINE',
      );
      expect(item.value, equals('dev1'));
      expect(item.label, equals('CMDL04'));
      expect(item.subtitle, equals('172.21.174.208'));
      expect(item.badge, equals('ONLINE'));
    });

    testWidgets(
      'GlassDropdown inside AnimatedSwitcher transitions tabs without setState during build',
      (tester) async {
        int tab = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => setState(() => tab = tab == 0 ? 1 : 0),
                        child: const Text('Switch Tab'),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: tab == 0
                            ? GlassDropdown<String>(
                                key: const ValueKey('drop'),
                                colors: win10DarkColors,
                                items: const [
                                  GlassDropdownItem(
                                    value: 'opt1',
                                    label: 'Option 1',
                                  ),
                                  GlassDropdownItem(
                                    value: 'opt2',
                                    label: 'Option 2',
                                  ),
                                ],
                                value: 'opt1',
                                onChanged: (_) {},
                              )
                            : const SizedBox(key: ValueKey('empty')),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        expect(find.text('Option 1'), findsOneWidget);

        // Switch tab to trigger AnimatedSwitcher build & deactivation
        await tester.tap(find.text('Switch Tab'));
        await tester.pumpAndSettle();

        // Ensure cleanly transitioned without any exceptions
        expect(find.text('Option 1'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('LanguageProvider Theme & Settings Key Tests', () {
    test(
      'theme_dark and theme_light resolve correctly across all languages',
      () {
        final lp = LanguageProvider(initialLanguage: AppLanguage.vi);

        // Default Vietnamese
        expect(lp.t('theme_dark'), equals('Tối'));
        expect(lp.t('theme_light'), equals('Sáng'));
        expect(lp.t('settings_btn_label'), equals('Cài đặt'));

        // Switch to English
        lp.setLanguage(AppLanguage.en);
        expect(lp.t('theme_dark'), equals('Dark'));
        expect(lp.t('theme_light'), equals('Light'));
        expect(lp.t('settings_btn_label'), equals('Settings'));

        // Switch to Chinese
        lp.setLanguage(AppLanguage.cn);
        expect(lp.t('theme_dark'), equals('深色'));
        expect(lp.t('theme_light'), equals('浅色'));
        expect(lp.t('settings_btn_label'), equals('设置'));
      },
    );
  });

  group('LAN Scanner Search, Filter & Multi-Select Tests', () {
    test(
      'LanguageProvider contains all LAN Scanner search & filter translation keys in VI, EN, CN',
      () {
        final lp = LanguageProvider();
        final keys = [
          'scanner_search_hint',
          'scanner_filter_all',
          'scanner_filter_unadded',
          'scanner_filter_added',
          'scanner_filter_fast',
          'scanner_select_all',
          'scanner_deselect_all',
          'scanner_btn_add_selected',
          'scanner_btn_add_unadded',
          'scanner_showing_count',
          'scanner_no_filter_match',
          'scanner_clear_filter',
          'scanner_toast_added_single',
          'scanner_toast_added_batch',
          'scanner_view_table',
          'scanner_view_grid',
          'scanner_view_list',
          'scanner_toggle_adapters',
          'scanner_col_device',
          'scanner_col_ip',
          'scanner_col_mac',
          'scanner_col_ping',
          'scanner_col_action',
          'scanner_resolving_host',
          'scanner_no_hostname',
        ];

        for (final lang in [AppLanguage.vi, AppLanguage.en, AppLanguage.cn]) {
          lp.setLanguage(lang);
          for (final key in keys) {
            final val = lp.t(key);
            expect(
              val,
              isNot(equals(key)),
              reason: 'Key "$key" should be translated for language $lang',
            );
            expect(
              val.isNotEmpty,
              isTrue,
              reason: 'Key "$key" should not be empty for language $lang',
            );
          }
        }
      },
    );

    test(
      'LAN Scanner filtering logic filters correctly by query and status',
      () {
        final sampleDevices = [
          {
            'ip': '192.168.1.10',
            'host': 'desktop-alpha',
            'mac': 'AA:BB:CC:DD:EE:01',
            'ms': 12,
          },
          {
            'ip': '192.168.1.20',
            'host': 'laptop-beta',
            'mac': 'AA:BB:CC:DD:EE:02',
            'ms': 85,
          },
          {
            'ip': '192.168.1.30',
            'host': 'server-gamma',
            'mac': 'AA:BB:CC:DD:EE:03',
            'ms': 4,
          },
          {
            'ip': '192.168.1.40',
            'host': 'printer-epson',
            'mac': '11:22:33:44:55:66',
            'ms': 120,
          },
        ];
        final savedIps = {'192.168.1.10', '192.168.1.40'};

        // 1. Filter by query: 'desktop'
        final queryDesktop = sampleDevices.where((d) {
          final q = 'desktop'.toLowerCase();
          return (d['ip'] as String).toLowerCase().contains(q) ||
              (d['host'] as String).toLowerCase().contains(q) ||
              (d['mac'] as String).toLowerCase().contains(q);
        }).toList();
        expect(queryDesktop.length, equals(1));
        expect(queryDesktop.first['ip'], equals('192.168.1.10'));

        // 2. Filter by status: unadded
        final unadded = sampleDevices
            .where((d) => !savedIps.contains(d['ip']))
            .toList();
        expect(unadded.length, equals(2));
        expect(
          unadded.map((d) => d['ip']),
          containsAll(['192.168.1.20', '192.168.1.30']),
        );

        // 3. Filter by status: added
        final added = sampleDevices
            .where((d) => savedIps.contains(d['ip']))
            .toList();
        expect(added.length, equals(2));
        expect(
          added.map((d) => d['ip']),
          containsAll(['192.168.1.10', '192.168.1.40']),
        );

        // 4. Filter by status: fast (ms <= 50)
        final fast = sampleDevices
            .where((d) => (d['ms'] as int) <= 50)
            .toList();
        expect(fast.length, equals(2));
        expect(
          fast.map((d) => d['ip']),
          containsAll(['192.168.1.10', '192.168.1.30']),
        );

        // 5. Multi-selection: selecting all unadded in filtered list
        final selectedIps = <String>{};
        for (final d in unadded) {
          selectedIps.add(d['ip'] as String);
        }
        expect(selectedIps.length, equals(2));
        expect(selectedIps.contains('192.168.1.20'), isTrue);
        expect(selectedIps.contains('192.168.1.30'), isTrue);
      },
    );
  });

  group('Devices Batch Actions & Localization Tests', () {
    test(
      'LanguageProvider resolves all batch action translation keys in VI, EN, CN',
      () {
        final lp = LanguageProvider();
        final batchKeys = [
          'dev_batch_selected',
          'dev_batch_wake',
          'dev_batch_restart',
          'dev_batch_shutdown',
          'dev_batch_cmd',
          'dev_batch_deselect',
          'dev_batch_delete',
          'dev_batch_delete_title',
          'dev_batch_delete_msg',
          'dev_batch_delete_confirm_btn',
          'dev_batch_delete_success',
          'dev_batch_change_group',
          'dev_batch_group_title',
          'dev_batch_group_hint',
          'dev_batch_group_confirm_btn',
          'dev_batch_group_success',
          'dev_batch_export_selected',
        ];

        for (final lang in [AppLanguage.vi, AppLanguage.en, AppLanguage.cn]) {
          lp.setLanguage(lang);
          for (final key in batchKeys) {
            final val = lp.t(key, {'count': '3', 'group': 'Station-X'});
            expect(
              val,
              isNot(equals(key)),
              reason: 'Key "$key" should be translated for $lang',
            );
            expect(
              val.isNotEmpty,
              isTrue,
              reason: 'Key "$key" value should not be empty for $lang',
            );
          }
        }
      },
    );

    test(
      'Batch delete and update logic removes and updates items correctly',
      () {
        final list = [
          ManagedDevice(
            id: 'd1',
            name: 'PC1',
            hostname: 'host1',
            ip: '10.0.0.1',
            group: 'Lab1',
          ),
          ManagedDevice(
            id: 'd2',
            name: 'PC2',
            hostname: 'host2',
            ip: '10.0.0.2',
            group: 'Lab1',
          ),
          ManagedDevice(
            id: 'd3',
            name: 'PC3',
            hostname: 'host3',
            ip: '10.0.0.3',
            group: 'Lab2',
          ),
        ];

        // Test batch remove
        final toRemove = {'d1', 'd2'};
        final remaining = list.where((d) => !toRemove.contains(d.id)).toList();
        expect(remaining.length, equals(1));
        expect(remaining.first.id, equals('d3'));

        // Test batch group update
        final updated = list.map((d) {
          if (toRemove.contains(d.id)) {
            return d.copyWith(group: 'Lab3');
          }
          return d;
        }).toList();
        expect(updated[0].group, equals('Lab3'));
        expect(updated[1].group, equals('Lab3'));
        expect(updated[2].group, equals('Lab2'));
      },
    );
  });

  group('EverythingSearchMatcher Tests', () {
    final targets = [
      'PC-SOZ-01',
      '172.21.175.40',
      'host-soz-cmdl',
      '00:1A:2B:3C:4D:5E',
      'Factory',
      'Floor 2',
    ];

    test('empty query matches all', () {
      expect(
        EverythingSearchMatcher.matches(query: '', targets: targets),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(query: '   ', targets: targets),
        isTrue,
      );
    });

    test('single term match case-insensitively', () {
      expect(
        EverythingSearchMatcher.matches(query: 'soz', targets: targets),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(query: 'SOZ', targets: targets),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(query: '175.40', targets: targets),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(query: 'nonexistent', targets: targets),
        isFalse,
      );
    });

    test('multi-term AND logic (space separated)', () {
      // Both terms exist
      expect(
        EverythingSearchMatcher.matches(query: '175 soz', targets: targets),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(
          query: 'factory pc-soz 4d:5e',
          targets: targets,
        ),
        isTrue,
      );
      // One term does not exist
      expect(
        EverythingSearchMatcher.matches(
          query: '175 nonexistent',
          targets: targets,
        ),
        isFalse,
      );
    });

    test('OR logic with | operator', () {
      // Either term exists
      expect(
        EverythingSearchMatcher.matches(
          query: 'soz | nonexistent',
          targets: targets,
        ),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(
          query: 'nonexistent1 | 172.21',
          targets: targets,
        ),
        isTrue,
      );
      // Neither term exists
      expect(
        EverythingSearchMatcher.matches(
          query: 'apple | orange',
          targets: targets,
        ),
        isFalse,
      );
    });

    test('NOT logic with - or ! prefix', () {
      // Has 175 and does NOT have macbook
      expect(
        EverythingSearchMatcher.matches(
          query: '175 -macbook',
          targets: targets,
        ),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(
          query: '175 !macbook',
          targets: targets,
        ),
        isTrue,
      );
      // Has 175 but also has soz, so -soz fails
      expect(
        EverythingSearchMatcher.matches(query: '175 -soz', targets: targets),
        isFalse,
      );
      expect(
        EverythingSearchMatcher.matches(query: '175 !soz', targets: targets),
        isFalse,
      );
    });

    test('quoted phrases logic', () {
      expect(
        EverythingSearchMatcher.matches(query: '"Floor 2"', targets: targets),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(query: '"Floor 3"', targets: targets),
        isFalse,
      );
      expect(
        EverythingSearchMatcher.matches(
          query: '175 -"Floor 3"',
          targets: targets,
        ),
        isTrue,
      );
      expect(
        EverythingSearchMatcher.matches(
          query: '175 -"Floor 2"',
          targets: targets,
        ),
        isFalse,
      );
    });
  });

  group('LanguageProvider Export/Import Labels Test', () {
    test('dev_btn_export and dev_btn_import omit JSON prefix', () {
      final lp = LanguageProvider();
      lp.setLanguage(AppLanguage.vi);
      expect(lp.t('dev_btn_export'), equals('Xuất'));
      expect(lp.t('dev_btn_import'), equals('Nhập'));

      lp.setLanguage(AppLanguage.en);
      expect(lp.t('dev_btn_export'), equals('Export'));
      expect(lp.t('dev_btn_import'), equals('Import'));

      lp.setLanguage(AppLanguage.cn);
      expect(lp.t('dev_btn_export'), equals('导出'));
      expect(lp.t('dev_btn_import'), equals('导入'));
    });
  });

  group('DiscoveryService & DeviceService Tab State Persistence Tests', () {
    test(
      'DiscoveryService retains filterMode, searchQuery, sort and viewMode',
      () {
        final service = DiscoveryService(initialize: false);

        // Default initial states
        expect(service.searchQuery, isEmpty);
        expect(service.filterMode, equals('all'));
        expect(service.sortColumn, equals('ip'));
        expect(service.sortAscending, isTrue);
        expect(service.viewMode, equals('table'));
        expect(service.showAdapters, isFalse);
        expect(service.selectedIps, isEmpty);

        // Mutate UI states
        service.setSearchQuery('TP-Link');
        service.setFilterMode('fast');
        service.setSort('ping', ascending: false);
        service.setViewMode('grid');
        service.toggleShowAdapters();
        service.toggleSelectIp('172.21.174.41');
        service.selectAllIps(['172.21.174.42', '172.21.174.43']);

        expect(service.searchQuery, equals('TP-Link'));
        expect(service.filterMode, equals('fast'));
        expect(service.sortColumn, equals('ping'));
        expect(service.sortAscending, isFalse);
        expect(service.viewMode, equals('grid'));
        expect(service.showAdapters, isTrue);
        expect(
          service.selectedIps,
          containsAll(['172.21.174.41', '172.21.174.42', '172.21.174.43']),
        );

        // Toggle sort flips ascending
        service.setSort('ping');
        expect(service.sortAscending, isTrue);

        // Remove specific selected IPs
        service.removeSelectedIps(['172.21.174.42']);
        expect(service.selectedIps.contains('172.21.174.42'), isFalse);
        expect(service.selectedIps.length, equals(2));

        // Clear filters only resets search and filter mode
        service.clearFilters();
        expect(service.searchQuery, isEmpty);
        expect(service.filterMode, equals('all'));
        expect(service.sortColumn, equals('ping')); // sort preserved
        expect(service.viewMode, equals('grid')); // view mode preserved
        expect(service.selectedIps.length, equals(2)); // selection preserved

        // Deselect all
        service.deselectAllIps();
        expect(service.selectedIps, isEmpty);

        service.dispose();
      },
    );

    test(
      'DeviceService retains sortColumn and sortAscending across changes',
      () {
        final service = DeviceService();

        expect(service.sortColumn, equals('ip'));
        expect(service.sortAscending, isTrue);

        service.setSort('name', ascending: false);
        expect(service.sortColumn, equals('name'));
        expect(service.sortAscending, isFalse);

        service.setSort('name');
        expect(service.sortColumn, equals('name'));
        expect(service.sortAscending, isTrue);

        service.dispose();
      },
    );
  });
}

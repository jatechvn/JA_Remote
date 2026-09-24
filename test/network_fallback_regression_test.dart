import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/network_utils.dart';
import 'package:ja_remote/core/network/ping_engine.dart';

class _Socket extends Fake implements Socket {
  bool destroyed = false;
  @override
  void destroy() => destroyed = true;
}

void main() {
  test(
    'partial netsh result falls back without overwriting known mask',
    () async {
      final commands = <String>[];
      final result = await NetworkUtils.getWindowsSubnetMasks(
        {'172.21.172.151', '10.1.2.3'},
        run: (command, args) async {
          commands.add(command);
          return ProcessResult(1, 0, switch (command) {
            'netsh' => 'IP: 172.21.172.151\nPrefix: 172.21.168.0/21',
            'ipconfig' =>
              'IPv4 Address: 172.21.172.151\nSubnet Mask: 255.255.255.0',
            _ => '10.1.2.3/8',
          }, '');
        },
      );
      expect(commands, ['netsh', 'ipconfig', 'powershell']);
      expect(result, {
        '172.21.172.151': '255.255.248.0',
        '10.1.2.3': '255.0.0.0',
      });
    },
    skip: !Platform.isWindows,
  );

  testWidgets('TCP latency excludes slow ports and closes every success', (
    tester,
  ) async {
    final attempts = <int, Completer<Socket>>{};
    final fast = _Socket();
    final late = _Socket();
    PingResult? result;
    final pending = PingEngine.pingTcp(
      '192.0.2.1',
      connect: (_, port, timeout) {
        expect(timeout.inMilliseconds, 250);
        return (attempts[port] = Completer<Socket>()).future;
      },
    ).then((value) => result = value);
    expect(attempts.length, 7);
    attempts[445]!.complete(fast);
    await tester.pump();
    expect(fast.destroyed, isTrue);
    expect(result, isNull); // Keep worker occupied until all attempts drain.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    attempts[22]!.complete(late);
    for (final entry in attempts.entries) {
      if (entry.key != 445 && entry.key != 22) {
        entry.value.completeError(const SocketException('blocked'));
      }
    }
    await tester.pump();
    await pending;
    expect(result!.isOnline, isTrue);
    expect(result!.latencyMs, lessThan(100));
    expect(late.destroyed, isTrue);
  });

  test('TCP all failures remain offline', () async {
    final result = await PingEngine.pingTcp(
      '192.0.2.1',
      connect: (_, _, _) async {
        throw const SocketException('blocked');
      },
    );
    expect(result.isOnline, isFalse);
    expect(result.latencyMs, isNull);
  });

  test(
    'netsh numeric structure works with translated labels and multiple IPs',
    () {
      final masks = NetworkUtils.parseNetshSubnetMasks('''
接口配置 "以太网"
 IP 地址: 172.21.172.151
 子网前缀: 172.21.168.0/21 (掩码 255.255.248.0)
 默认网关: 172.21.168.1
 网关跃点: 0
 IP-Adresse: 10.1.2.3
 Subnetzpräfix: 10.0.0.0/8 (Subnetzmaske 255.0.0.0)
''');
      expect(masks, {
        '172.21.172.151': '255.255.248.0',
        '10.1.2.3': '255.0.0.0',
      });
      expect(
        NetworkUtils.getSubnetSlices(
          NetworkUtils.calculateCidrSubnet(
            '172.21.172.151',
            masks['172.21.172.151'],
          ),
        ).length,
        8,
      );
    },
  );

  test('netsh rejects stale addresses and invalid or mismatched prefixes', () {
    final masks = NetworkUtils.parseNetshSubnetMasks('''
 IP: 172.21.172.151

 Interface "other"
 Prefix: 172.21.168.0/21
 IP: 10.1.2.3
 Prefix: 192.168.0.0/24
 IP: 10.1.2.3
 Prefix: 10.0.0.0/33
''');
    expect(masks, isEmpty);
  });
}

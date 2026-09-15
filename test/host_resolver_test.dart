import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/network/host_resolver.dart';

class NameProcess implements Process {
  final out = StreamController<List<int>>();
  bool killed = false;
  @override
  Stream<List<int>> get stdout => out.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('full-width names need no space before the NetBIOS type', () {
    expect(
      HostResolver.parseNetBiosName(
        '    DESKTOP-B882FAE<00>  UNIQUE Registered',
      ),
      'DESKTOP-B882FAE',
    );
    expect(
      HostResolver.parseNetBiosName(
        '    TESTWEB-WIN10UB<20>  UNIQUE Registered',
      ),
      'TESTWEB-WIN10UB',
    );
    expect(
      HostResolver.parseNetBiosName(
        '    LONG-WORKGROUP1<00>  GROUP Registered',
      ),
      isNull,
    );
  });
  test(
    'reads hostname before nbtstat finishes probing other adapters',
    () async {
      final child = NameProcess();
      final pending = HostResolver.resolveNetBios(
        '192.0.2.1',
        start: () async => child,
      );
      child.out.add(
        utf8.encode(' WORKGROUP <00> GROUP Registered\r\n IQ4-FT3-'),
      );
      child.out.add(utf8.encode('031 <20> UNIQUE Registered\r\n'));
      expect(await pending.timeout(const Duration(seconds: 1)), 'IQ4-FT3-031');
      expect(child.killed, isTrue);
      await child.out.close();
    },
  );
  test('no reply times out and closes nbtstat', () async {
    final child = NameProcess();
    expect(
      await HostResolver.resolveNetBios(
        '192.0.2.1',
        start: () async => child,
        timeout: const Duration(milliseconds: 20),
      ),
      '192.0.2.1',
    );
    expect(child.killed, isTrue);
    await child.out.close();
  });
  test('workgroup entries are not used as computer names', () {
    expect(
      HostResolver.parseNetBiosName(' WORKGROUP <00> GROUP Registered'),
      isNull,
    );
    expect(
      HostResolver.parseNetBiosName(' PC-01 <00> UNIQUE Registered'),
      'PC-01',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/utils/command_variable_resolver.dart';
import 'package:ja_remote/data/models/managed_device.dart';

void main() {
  group('CommandVariableResolver', () {
    const testDevice = ManagedDevice(
      id: 'dev-1',
      name: 'TE-Station-10',
      hostname: 'TE-10.factory.local',
      ip: '172.19.116.157',
      mac: 'AA:BB:CC:DD:EE:FF',
      group: 'L6',
      os: 'Windows',
      sshPort: 22,
      username: 'te_admin',
    );

    test('resolves single variables properly', () {
      expect(
        CommandVariableResolver.resolve('ping {{IP}}', testDevice),
        equals('ping 172.19.116.157'),
      );
      expect(
        CommandVariableResolver.resolve('hostname: {{HOSTNAME}}', testDevice),
        equals('hostname: TE-10.factory.local'),
      );
      expect(
        CommandVariableResolver.resolve(
          'device: {{NAME}} in {{GROUP}}',
          testDevice,
        ),
        equals('device: TE-Station-10 in L6'),
      );
      expect(
        CommandVariableResolver.resolve('arp {{MAC}}', testDevice),
        equals('arp AA:BB:CC:DD:EE:FF'),
      );
    });

    test('resolves case-insensitively and handles spaces inside braces', () {
      expect(
        CommandVariableResolver.resolve(
          'echo {{ ip }} and {{  hostName  }}',
          testDevice,
        ),
        equals('echo 172.19.116.157 and TE-10.factory.local'),
      );
    });

    test('prefers provided username over device username', () {
      expect(
        CommandVariableResolver.resolve(
          'whoami: {{USER}}',
          testDevice,
          username: 'custom_user',
        ),
        equals('whoami: custom_user'),
      );
      expect(
        CommandVariableResolver.resolve('whoami: {{USER}}', testDevice),
        equals('whoami: te_admin'),
      );
    });

    test('leaves unknown variables untouched', () {
      expect(
        CommandVariableResolver.resolve('test {{UNKNOWN_VAR}}', testDevice),
        equals('test {{UNKNOWN_VAR}}'),
      );
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/services/remote_command_service.dart';

class TestSession implements SSHSession {
  TestSession(this.exitCode, {String output = '', String error = ''}) {
    stdout = Stream.value(Uint8List.fromList(utf8.encode(output)));
    stderr = Stream.value(Uint8List.fromList(utf8.encode(error)));
  }
  @override
  final int? exitCode;
  @override
  SSHSessionExitSignal? get exitSignal => null;
  @override
  late Stream<Uint8List> stdout;
  @override
  late Stream<Uint8List> stderr;
  @override
  Future<void> get done async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestClient implements SSHClient {
  TestClient(this.session);
  final Future<SSHSession> session;
  bool closed = false;
  int executions = 0;
  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
  }) {
    executions++;
    return session;
  }

  @override
  void close() {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final device = ManagedDevice(
    id: 'ssh-test',
    name: 'Fake SSH',
    hostname: 'fake',
    ip: '192.0.2.1',
    os: 'linux',
  );
  Future<RemoteCommandResult> run(TestClient client) => RemoteCommandService(
    connectSsh: (_, _, _, _) async => client,
  ).execute(device: device, command: 'unused', timeoutSeconds: 1);

  test('exit zero with stderr warning succeeds and preserves output', () async {
    final client = TestClient(
      Future.value(TestSession(0, output: 'done', error: 'warning')),
    );
    final result = await run(client);
    expect(result.isSuccess, isTrue);
    expect(result.output, 'done');
    expect(result.error, 'warning');
    expect(client.closed, isTrue);
  });
  test('nonzero or missing exit code fails even without stderr', () async {
    for (final code in <int?>[2, null]) {
      final client = TestClient(Future.value(TestSession(code)));
      final result = await run(client);
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('exit code'));
      expect(client.closed, isTrue);
    }
  });
  test('both output streams are subscribed before either completes', () async {
    final out = StreamController<Uint8List>();
    final err = StreamController<Uint8List>();
    final session = TestSession(0)
      ..stdout = out.stream
      ..stderr = err.stream;
    err.onListen = () {
      out.add(Uint8List.fromList(utf8.encode('ok')));
      unawaited(out.close());
      unawaited(err.close());
    };
    final result = await run(TestClient(Future.value(session)));
    expect(result.isSuccess, isTrue);
    expect(result.output, 'ok');
  });
  test('execute exception closes connection', () async {
    final client = TestClient(
      Future.delayed(
        Duration.zero,
        () => throw StateError('authentication failed'),
      ),
    );
    final result = await run(client);
    expect(result.isSuccess, isFalse);
    expect(result.error, contains('authentication failed'));
    expect(client.closed, isTrue);
  });
  test('stalled execute times out and closes connection', () async {
    final client = TestClient(Completer<SSHSession>().future);
    final result = await run(client);
    expect(result.isSuccess, isFalse);
    expect(result.error, contains('TimeoutException'));
    expect(client.closed, isTrue);
  });
  test('late connection is closed without executing after timeout', () async {
    final connected = Completer<SSHClient>();
    final service = RemoteCommandService(
      connectSsh: (_, _, _, _) => connected.future,
    );
    final result = await service.execute(
      device: device,
      command: 'unused',
      timeoutSeconds: 1,
    );
    expect(result.isSuccess, isFalse);
    final client = TestClient(Future.value(TestSession(0)));
    connected.complete(client);
    await Future<void>.delayed(Duration.zero);
    expect(client.closed, isTrue);
    expect(client.executions, 0);
  });
  test('invalid timeout never starts connection', () async {
    final service = RemoteCommandService(
      connectSsh: (_, _, _, _) async {
        fail('must not connect');
      },
    );
    await expectLater(
      service.execute(device: device, command: '', timeoutSeconds: 0),
      throwsArgumentError,
    );
  });
}

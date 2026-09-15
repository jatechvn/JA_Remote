import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/process/process_runner.dart';

class FakeProcess implements Process {
  final completed = Completer<int>();
  bool killed = false;
  @override
  int get pid => 123;
  @override
  Future<int> get exitCode => completed.future;
  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode('output'));
  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode('warning'));
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!completed.isCompleted) completed.complete(-1);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('preserves exit code and both streams', () async {
    final child = FakeProcess()..completed.complete(3);
    final result = await ProcessRunner.runWithTimeout(
      'unused',
      [],
      timeout: const Duration(seconds: 1),
      start: () async => child,
    );
    expect(result.exitCode, 3);
    expect(result.stdout, 'output');
    expect(result.stderr, 'warning');
  });
  test('timeout kills the local process before returning failure', () async {
    final child = FakeProcess();
    final result = await ProcessRunner.runWithTimeout(
      'unused',
      [],
      timeout: const Duration(milliseconds: 20),
      start: () async => child,
    );
    expect(result.exitCode, -1);
    expect(result.stderr, contains('timed out'));
    expect(child.killed, isTrue);
  });
  test('late process start is killed after deadline', () async {
    final pending = Completer<Process>();
    final result = await ProcessRunner.runWithTimeout(
      'unused',
      [],
      timeout: const Duration(milliseconds: 20),
      start: () => pending.future,
    );
    expect(result.exitCode, -1);
    final child = FakeProcess();
    pending.complete(child);
    await Future<void>.delayed(Duration.zero);
    expect(child.killed, isTrue);
  });
}

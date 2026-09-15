import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/services/remote_command_service.dart';
import 'package:ja_remote/services/config_backup_service.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/data/models/command_template.dart';
import 'package:ja_remote/data/models/saved_credential.dart';

class FakeRemote extends RemoteCommandService {
  final called = <String>[];
  int active = 0;
  int peak = 0;
  @override
  Future<RemoteCommandResult> execute({
    required ManagedDevice device,
    required String command,
    String? typeOverride,
    String? username,
    String? password,
    int timeoutSeconds = 15,
  }) async {
    called.add(device.id);
    active++;
    if (active > peak) peak = active;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    active--;
    if (device.id == '1') throw StateError('simulated failure');
    return RemoteCommandResult(
      device: device,
      isSuccess: true,
      output: 'ok',
      error: '',
      durationMs: 2,
    );
  }
}

void main() {
  final devices = List.generate(
    5,
    (i) => ManagedDevice(
      id: '$i',
      name: 'Test $i',
      hostname: 'test',
      ip: '192.0.2.${i + 1}',
    ),
  );
  test(
    'worker failure produces a result, continues the queue and respects concurrency',
    () async {
      final remote = FakeRemote();
      final progress = <int>[];
      final results = await remote
          .executeBatch(
            devices: devices,
            command: 'unused',
            maxConcurrent: 2,
            onProgress: (n, total, r) {
              progress.add(n);
              expect(total, 5);
            },
          )
          .timeout(const Duration(seconds: 2));
      expect(results.length, 5);
      expect(results.where((r) => !r.isSuccess).single.device.id, '1');
      expect(remote.called.toSet().length, 5);
      expect(remote.peak, 2);
      expect(progress, [1, 2, 3, 4, 5]);
    },
  );
  test(
    'invalid worker limit fails immediately and empty batch completes',
    () async {
      final remote = FakeRemote();
      for (final limit in [0, -1]) {
        await expectLater(
          remote.executeBatch(
            devices: devices,
            command: '',
            maxConcurrent: limit,
          ),
          throwsArgumentError,
        );
      }
      expect(await remote.executeBatch(devices: [], command: ''), isEmpty);
      expect(remote.called, isEmpty);
    },
  );
  test(
    'progress callback failure propagates after all targets finish',
    () async {
      final remote = FakeRemote();
      await expectLater(
        remote.executeBatch(
          devices: devices,
          command: '',
          maxConcurrent: 1,
          onProgress: (_, _, _) => throw StateError('UI callback failed'),
        ),
        throwsStateError,
      );
      expect(remote.called.length, 5);
      expect(remote.active, 0);
    },
  );
  test('batch snapshots its targets before caller changes selection', () async {
    final remote = FakeRemote();
    final selected = List<ManagedDevice>.of(devices);
    final pending = remote.executeBatch(
      devices: selected,
      command: '',
      maxConcurrent: 1,
    );
    selected.clear();
    expect((await pending).length, 5);
  });
  test(
    'template-only import drops devices and credentials from a full bundle',
    () {
      final preview = ConfigImportPreview(
        isValid: true,
        devices: devices,
        credentials: [
          SavedCredential(id: 'c', username: 'test', password: 'test'),
        ],
        commandTemplates: const [
          CommandTemplate(
            id: 't',
            name: 'Test',
            platform: 'windows',
            type: 'powershell',
            command: 'hostname',
          ),
        ],
      );
      final scoped = preview.templatesOnly;
      expect(scoped.isValid, isTrue);
      expect(scoped.devices, isEmpty);
      expect(scoped.credentials, isEmpty);
      expect(scoped.commandTemplates.single.id, 't');
      expect(
        const ConfigImportPreview(isValid: false).templatesOnly.isValid,
        isFalse,
      );
    },
  );
  test(
    'legacy raw templates without platform are recognized as templates',
    () async {
      final dir = await Directory.systemTemp.createTemp('remote_import_test_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/templates.json');
      await file.writeAsString(
        jsonEncode([
          {'id': 't', 'name': 'Legacy', 'command': 'hostname'},
        ]),
      );
      final preview = await ConfigBackupService().previewConfigFile(file.path);
      expect(preview.isValid, isTrue);
      expect(preview.devices, isEmpty);
      expect(preview.commandTemplates.single.platform, 'windows');
    },
  );
}

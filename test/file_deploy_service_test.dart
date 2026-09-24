import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/process/process_runner.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/services/file_deploy_service.dart';

void main() {
  group('DeviceDeployProgress Tests', () {
    final dev = ManagedDevice(
      id: 'd1',
      name: 'Host 1',
      hostname: 'host1',
      ip: '192.168.1.10',
      os: 'windows',
    );

    test('percent calculates progress correctly', () {
      const p1 = DeviceDeployProgress(
        device: ManagedDevice(
          id: 'd1',
          name: 'Host 1',
          hostname: 'host1',
          ip: '1.1.1.1',
        ),
        bytesTransferred: 50,
        totalBytes: 100,
      );
      expect(p1.percent, 0.5);
      expect(p1.formattedPercent, '50.0%');

      const p2 = DeviceDeployProgress(
        device: ManagedDevice(
          id: 'd1',
          name: 'Host 1',
          hostname: 'host1',
          ip: '1.1.1.1',
        ),
        bytesTransferred: 150,
        totalBytes: 100,
      );
      expect(p2.percent, 1.0);
      expect(p2.formattedPercent, '100.0%');
    });

    test('formatBytes formats various magnitudes', () {
      expect(DeviceDeployProgress.formatBytes(500), '500 B');
      expect(DeviceDeployProgress.formatBytes(1536), '1.5 KB');
      expect(DeviceDeployProgress.formatBytes(1024 * 1024 * 5), '5.0 MB');
      expect(
        DeviceDeployProgress.formatBytes(1024 * 1024 * 1024 * 2),
        '2.00 GB',
      );
    });

    test('formattedSpeed formats various transfer rates', () {
      final p1 = DeviceDeployProgress(device: dev, speedBytesPerSec: 512);
      expect(p1.formattedSpeed, '512 B/s');

      final p2 = DeviceDeployProgress(
        device: dev,
        speedBytesPerSec: 2048 * 1024,
      );
      expect(p2.formattedSpeed, '2.0 MB/s');
    });

    test('copyWith properly updates specified fields', () {
      final base = DeviceDeployProgress(
        device: dev,
        status: DeployStatus.pending,
      );
      final updated = base.copyWith(
        status: DeployStatus.transferring,
        bytesTransferred: 500,
        currentFileName: 'update.zip',
      );
      expect(updated.status, DeployStatus.transferring);
      expect(updated.bytesTransferred, 500);
      expect(updated.currentFileName, 'update.zip');
    });
  });

  group('FileDeployService Execution Tests', () {
    late Directory tempDir;
    late File sampleFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ja_remote_deploy_test_');
      sampleFile = File('${tempDir.path}/test_source.txt');
      await sampleFile.writeAsString('Hello Deploy Test 1234567890');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws ArgumentError on empty targets', () async {
      final service = FileDeployService();
      addTearDown(service.dispose);

      final config = FileDeployJobConfig(
        sourcePath: sampleFile.path,
        destDir: '${tempDir.path}/dest',
      );

      expect(
        () => service.startDeploy(targets: [], config: config),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('abort drains active workers before releasing the job', () async {
      final replies = <Completer<ProcessExecutionResult>>[];
      final started = Completer<void>();
      final service = FileDeployService(
        runPowerShell:
            (script, {computerName, username, password, timeoutSeconds = 15}) {
              final reply = Completer<ProcessExecutionResult>();
              replies.add(reply);
              if (replies.length == 2) started.complete();
              return reply.future;
            },
      );
      addTearDown(service.dispose);
      final targets = List.generate(
        3,
        (i) => ManagedDevice(
          id: '$i',
          name: 'Host $i',
          hostname: 'host$i',
          ip: '192.0.2.${i + 1}',
        ),
      );
      final config = FileDeployJobConfig(
        sourcePath: sampleFile.path,
        destDir: r'C:\Temp',
        maxConcurrency: 2,
      );
      final job = service.startDeploy(targets: targets, config: config);
      await started.future;
      service.abort();
      const success = ProcessExecutionResult(
        exitCode: 0,
        stdout: 'DEPLOY_SUCCESS',
        stderr: '',
        isSuccess: true,
      );
      replies.first.complete(success);
      await Future<void>.delayed(Duration.zero);
      expect(service.isRunning, isTrue);
      expect(replies.length, 2);
      await expectLater(
        service.startDeploy(targets: targets, config: config),
        throwsStateError,
      );
      replies.last.complete(success);
      await job;
      expect(service.isRunning, isFalse);
      expect(
        service.progressList.every((p) => p.status == DeployStatus.cancelled),
        isTrue,
      );
    });

    test('throws FileSystemException when source does not exist', () async {
      final service = FileDeployService();
      addTearDown(service.dispose);

      final target = ManagedDevice(
        id: 'dev1',
        name: 'Target 1',
        hostname: 'target1',
        ip: '127.0.0.1',
      );

      final config = FileDeployJobConfig(
        sourcePath: '${tempDir.path}/non_existent_file.xyz',
        destDir: '${tempDir.path}/dest',
      );

      await service.startDeploy(targets: [target], config: config);
      expect(service.failedCount, 0); // Didn't start execution pool
      expect(service.isRunning, isFalse);
    });

    test('successfully deploys file locally to 127.0.0.1', () async {
      final service = FileDeployService();
      addTearDown(service.dispose);

      final target = ManagedDevice(
        id: 'local-1',
        name: 'Local Target',
        hostname: 'localhost',
        ip: '127.0.0.1',
        os: 'windows',
      );

      final destDir = '${tempDir.path}/dest_folder';
      final config = FileDeployJobConfig(
        sourcePath: sampleFile.path,
        destDir: destDir,
      );

      await service.startDeploy(targets: [target], config: config);

      expect(service.isRunning, isFalse);
      expect(service.completedCount, 1);
      expect(service.failedCount, 0);
      expect(service.overallPercent, 1.0);

      final deployedFile = File('$destDir/test_source.txt');
      expect(await deployedFile.exists(), isTrue);
      expect(await deployedFile.readAsString(), 'Hello Deploy Test 1234567890');
    });

    test('supports Windows remote deploy via mock PowerShell runner', () async {
      final service = FileDeployService(
        runPowerShell:
            (
              script, {
              computerName,
              username,
              password,
              timeoutSeconds = 15,
            }) async {
              return const ProcessExecutionResult(
                exitCode: 0,
                stdout: 'DEPLOY_SUCCESS\n',
                stderr: '',
                isSuccess: true,
              );
            },
      );
      addTearDown(service.dispose);

      final remoteWin = ManagedDevice(
        id: 'win-remote',
        name: 'Remote Win PC',
        hostname: 'remotewin',
        ip: '192.168.1.150',
        os: 'windows',
      );

      final config = FileDeployJobConfig(
        sourcePath: sampleFile.path,
        destDir: r'C:\Temp\Deploy',
      );

      await service.startDeploy(targets: [remoteWin], config: config);

      expect(service.completedCount, 1);
      expect(service.failedCount, 0);
      expect(service.progressMap['win-remote']?.status, DeployStatus.completed);
    });

    test('handles failure and allows retryFailed', () async {
      var shouldFail = true;
      final service = FileDeployService(
        runPowerShell:
            (
              script, {
              computerName,
              username,
              password,
              timeoutSeconds = 15,
            }) async {
              if (shouldFail) {
                return const ProcessExecutionResult(
                  exitCode: 1,
                  stdout: '',
                  stderr: 'Access is denied',
                  isSuccess: false,
                );
              } else {
                return const ProcessExecutionResult(
                  exitCode: 0,
                  stdout: 'DEPLOY_SUCCESS',
                  stderr: '',
                  isSuccess: true,
                );
              }
            },
      );
      addTearDown(service.dispose);

      final remoteWin = ManagedDevice(
        id: 'win-retry',
        name: 'Remote PC',
        hostname: 'retrypc',
        ip: '192.168.1.180',
        os: 'windows',
      );

      final config = FileDeployJobConfig(
        sourcePath: sampleFile.path,
        destDir: r'C:\Temp\Deploy',
      );

      // 1. First run fails
      await service.startDeploy(targets: [remoteWin], config: config);
      expect(service.failedCount, 1);
      expect(service.progressMap['win-retry']?.status, DeployStatus.failed);

      // 2. Retry succeeds
      shouldFail = false;
      await service.retryFailed(config: config);
      expect(service.completedCount, 1);
      expect(service.failedCount, 0);
      expect(service.progressMap['win-retry']?.status, DeployStatus.completed);
    });

    test('abort marks queued/running jobs as cancelled', () async {
      final service = FileDeployService(
        runPowerShell:
            (
              script, {
              computerName,
              username,
              password,
              timeoutSeconds = 15,
            }) async {
              await Future.delayed(const Duration(milliseconds: 500));
              return const ProcessExecutionResult(
                exitCode: 0,
                stdout: 'DEPLOY_SUCCESS',
                stderr: '',
                isSuccess: true,
              );
            },
      );
      addTearDown(service.dispose);

      final target = ManagedDevice(
        id: 'win-abort',
        name: 'Abort Target',
        hostname: 'aborttarget',
        ip: '192.168.1.200',
        os: 'windows',
      );

      final config = FileDeployJobConfig(
        sourcePath: sampleFile.path,
        destDir: r'C:\Temp\Deploy',
      );

      final deployFuture = service.startDeploy(
        targets: [target],
        config: config,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      service.abort();
      await deployFuture;

      expect(service.isRunning, isFalse);
      expect(service.progressMap[target.id]?.status, DeployStatus.cancelled);
    });

    test(
      'executes Pre and Post deploy hooks and aborts on pre-deploy failure if configured',
      () async {
        final executedScripts = <String>[];
        var failPreHook = true;

        final service = FileDeployService(
          runPowerShell:
              (
                script, {
                computerName,
                username,
                password,
                timeoutSeconds = 15,
              }) async {
                executedScripts.add(script);
                if (script.contains('pre_deploy_test') && failPreHook) {
                  return const ProcessExecutionResult(
                    exitCode: 1,
                    stdout: '',
                    stderr: 'Pre hook failed',
                    isSuccess: false,
                  );
                }
                return const ProcessExecutionResult(
                  exitCode: 0,
                  stdout: 'DEPLOY_SUCCESS',
                  stderr: '',
                  isSuccess: true,
                );
              },
        );
        addTearDown(service.dispose);

        final target = ManagedDevice(
          id: 'win-hook',
          name: 'Hook Target',
          hostname: 'hooktarget',
          ip: '192.168.1.150',
          os: 'windows',
        );

        final config = FileDeployJobConfig(
          sourcePath: sampleFile.path,
          destDir: r'C:\Temp\Deploy',
          preDeployScript: 'echo pre_deploy_test for {{IP}}',
          postDeployScript: 'echo post_deploy_test for {{IP}}',
          abortOnPreFail: true,
        );

        // 1. Should fail because pre-deploy hook fails
        await service.startDeploy(targets: [target], config: config);
        expect(service.failedCount, 1);
        expect(service.progressMap[target.id]?.status, DeployStatus.failed);
        expect(
          service.progressMap[target.id]?.error,
          contains('Pre-deploy hook failed'),
        );

        // 2. Should succeed when pre-hook succeeds
        failPreHook = false;
        executedScripts.clear();
        await service.startDeploy(targets: [target], config: config);
        expect(service.completedCount, 1);
        expect(
          executedScripts.any(
            (s) => s.contains('echo pre_deploy_test for 192.168.1.150'),
          ),
          isTrue,
        );
        expect(
          executedScripts.any(
            (s) => s.contains('echo post_deploy_test for 192.168.1.150'),
          ),
          isTrue,
        );
      },
    );
  });
}

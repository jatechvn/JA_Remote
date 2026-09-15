import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/process/process_runner.dart';
import 'package:ja_remote/services/file_deploy_service.dart';
import 'package:ja_remote/data/models/managed_device.dart';

void main() {
  const target = ManagedDevice(
    id: 'local',
    name: 'Local',
    hostname: 'localhost',
    ip: '127.0.0.1',
  );
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ja_unlock_');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  test(
    'remote script copies literal paths through session adapter',
    () async {
      final source = await File(
        "${temp.path}/source [1]'s.txt",
      ).writeAsString('remote content');
      final dest = await Directory('${temp.path}/remote').create();
      final service = FileDeployService(
        runPowerShell:
            (
              script, {
              computerName,
              username,
              password,
              timeoutSeconds = 15,
            }) async {
              const adapter = r'''
function New-PSSession { param($ComputerName) return 'test-session' }
function Remove-PSSession { param($Session) }
function Invoke-Command { param($Session, $ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
function Copy-Item { param($LiteralPath, $Destination, $ToSession, [switch]$Force)
  Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Force
}
''';
              return ProcessRunner.runPowerShell(
                '$adapter\n$script',
                timeoutSeconds: timeoutSeconds,
              );
            },
      );
      addTearDown(service.dispose);
      await service.startDeploy(
        targets: [
          const ManagedDevice(
            id: 'remote',
            name: 'Mock transport',
            hostname: 'mock',
            ip: '192.0.2.1',
          ),
        ],
        config: FileDeployJobConfig(
          sourcePath: source.path,
          destDir: dest.path,
        ),
      );
      expect(
        service.completedCount,
        1,
        reason: service.progressList.first.error,
      );
      expect(
        await File("${dest.path}/source [1]'s.txt").readAsString(),
        'remote content',
      );
    },
    skip: !Platform.isWindows,
  );

  Future<Process> lock(File file) async {
    final path = file.path.replaceAll("'", "''");
    final process = await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      ProcessRunner.toEncodedCommand(
        "\$f = [IO.File]::Open('$path', 'Open', 'ReadWrite', 'None'); Write-Output 'READY'; Start-Sleep -Seconds 40; \$f.Dispose()",
      ),
    ]);
    process.stderr.drain<void>();
    final ready = Completer<void>();
    process.stdout.transform(utf8.decoder).listen((s) {
      if (s.contains('READY') && !ready.isCompleted) ready.complete();
    });
    await ready.future.timeout(const Duration(seconds: 10));
    return process;
  }

  for (final remote in [false, true]) {
    test(
      'rollback restores original after partial copy, remote=$remote',
      () async {
        final source = await File(
          '${temp.path}/rollback.txt',
        ).writeAsString('new');
        final dest = await Directory('${temp.path}/rollback').create();
        final original = await File(
          '${dest.path}/rollback.txt',
        ).writeAsString('original');
        final otherBackup = await File(
          '${dest.path}/other.jad_old_keep',
        ).writeAsString('keep');
        final service = FileDeployService(
          copyFile: (_, path) async {
            await File(path).writeAsString('partial');
            throw const FileSystemException('Injected copy failure');
          },
          runPowerShell:
              (
                script, {
                computerName,
                username,
                password,
                timeoutSeconds = 15,
              }) async {
                expect(script, isNot(contains('taskkill.exe')));
                expect(
                  script,
                  isNot(contains('Get-CimInstance Win32_Process')),
                );
                const adapter = r'''
function New-PSSession { param($ComputerName) return 'test' }
function Remove-PSSession { param($Session) }
function Invoke-Command { param($Session, $ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
function Copy-Item { param($LiteralPath, $Destination, $ToSession, [switch]$Force)
  [IO.File]::WriteAllText($Destination, 'partial')
  throw 'Injected copy failure'
}
''';
                return ProcessRunner.runPowerShell(
                  '$adapter\n$script',
                  timeoutSeconds: timeoutSeconds,
                );
              },
        );
        try {
          await service.startDeploy(
            targets: [
              ManagedDevice(
                id: 'test',
                name: 'test',
                hostname: 'test',
                ip: remote ? '192.0.2.1' : '127.0.0.1',
              ),
            ],
            config: FileDeployJobConfig(
              sourcePath: source.path,
              destDir: dest.path,
            ),
          );
          expect(service.failedCount, 1);
          expect(await original.readAsString(), 'original');
          expect(await otherBackup.readAsString(), 'keep');
        } finally {
          service.dispose();
        }
      },
      skip: !Platform.isWindows,
    );
  }

  test(
    'overwrite disabled preserves contents and never calls unlock',
    () async {
      final source = await File('${temp.path}/source.txt').writeAsString('new');
      final dest = await Directory('${temp.path}/dest').create();
      final existing = await File(
        '${dest.path}/source.txt',
      ).writeAsString('old');
      var calls = 0;
      final service = FileDeployService(
        runPowerShell:
            (
              script, {
              computerName,
              username,
              password,
              timeoutSeconds = 15,
            }) async {
              calls++;
              throw StateError('Must not unlock');
            },
      );
      addTearDown(service.dispose);
      await service.startDeploy(
        targets: [target],
        config: FileDeployJobConfig(
          sourcePath: source.path,
          destDir: dest.path,
          overwrite: false,
          autoKillIfInUse: true,
        ),
      );
      expect(service.failedCount, 1);
      expect(await existing.readAsString(), 'old');
      expect(calls, 0);
    },
  );

  test(
    'folder overwrite closes only actual destination lock holder',
    () async {
      final source = await Directory('${temp.path}/source').create();
      await File('${source.path}/update.txt').writeAsString('new version');
      final dest = await Directory('${temp.path}/dest').create();
      final existing = await File(
        '${dest.path}/update.txt',
      ).writeAsString('old');
      final unrelated = await File(
        '${dest.path}/unrelated.txt',
      ).writeAsString('keep');
      final holder = await lock(existing);
      final other = await lock(unrelated);
      var otherExited = false;
      other.exitCode.then((_) {
        otherExited = true;
      });
      final service = FileDeployService();
      final logs = <String>[];
      final subscription = service.eventStream.listen(logs.add);
      try {
        await service.startDeploy(
          targets: [target],
          config: FileDeployJobConfig(
            sourcePath: source.path,
            isDirectory: true,
            destDir: dest.path,
            overwrite: true,
            autoKillIfInUse: true,
          ),
        );
        expect(
          service.completedCount,
          1,
          reason: service.progressList.first.error,
        );
        expect(await existing.readAsString(), 'new version');
        await holder.exitCode.timeout(const Duration(seconds: 5));
        expect(otherExited, isFalse);
        expect(
          logs.any((s) => s.contains('AUTO_KILL PID=${holder.pid}')),
          isTrue,
        );
      } finally {
        holder.kill();
        other.kill();
        await Future.wait([holder.exitCode, other.exitCode]);
        await subscription.cancel();
        service.dispose();
      }
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'user-mapped section file is replaced via safe rename without error',
    () async {
      final source = await File(
        '${temp.path}/source.bin',
      ).writeAsString('v2_data');
      final dest = await Directory('${temp.path}/dest_mmf').create();
      final existing = await File(
        '${dest.path}/source.bin',
      ).writeAsString('v1_data');

      // Create a memory mapped file with user-mapped section open
      final path = existing.path.replaceAll("'", "''");
      final mmfProc = await Process.start('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-EncodedCommand',
        ProcessRunner.toEncodedCommand(
          "\$fs = [IO.File]::Open('$path', 'Open', 'ReadWrite', [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete);"
          "\$mmf = [IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile(\$fs, 'map_' + [Guid]::NewGuid().ToString('N'), 0, [IO.MemoryMappedFiles.MemoryMappedFileAccess]::ReadWrite, \$null, [IO.HandleInheritability]::None, \$false);"
          "\$acc = \$mmf.CreateViewAccessor();"
          "Write-Output 'MMF_READY';"
          "Start-Sleep -Seconds 30;"
          "\$acc.Dispose(); \$mmf.Dispose(); \$fs.Dispose();",
        ),
      ]);
      mmfProc.stderr.drain<void>();
      final ready = Completer<void>();
      mmfProc.stdout.transform(utf8.decoder).listen((s) {
        if (s.contains('MMF_READY') && !ready.isCompleted) ready.complete();
      });
      await ready.future.timeout(const Duration(seconds: 10));

      final service = FileDeployService();
      try {
        await service.startDeploy(
          targets: [target],
          config: FileDeployJobConfig(
            sourcePath: source.path,
            destDir: dest.path,
            overwrite: true,
            autoKillIfInUse: true,
          ),
        );
        expect(
          service.completedCount,
          1,
          reason: service.progressList.first.error,
        );
        expect(await File('${dest.path}/source.bin').readAsString(), 'v2_data');
      } finally {
        mmfProc.kill();
        await mmfProc.exitCode;
        service.dispose();
      }
    },
    skip: !Platform.isWindows,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

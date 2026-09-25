import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/process/process_runner.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/services/file_deploy_service.dart';

void main() {
  const local = ManagedDevice(
    id: 'local',
    name: 'Local',
    hostname: 'localhost',
    ip: '127.0.0.1',
  );
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('ja_deploy_review_');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });

  for (final cancel in [false, true]) {
    test(
      cancel
          ? 'abort stops retries and restores original'
          : 'permanent error text cannot trigger sharing retry',
      () async {
        final source = await File('${temp.path}/file.txt').writeAsString('new');
        final dest = await Directory('${temp.path}/dest').create();
        final existing = await File(
          '${dest.path}/file.txt',
        ).writeAsString('old');
        var calls = 0;
        late FileDeployService service;
        service = FileDeployService(
          copyFile: (_, path) async {
            calls++;
            await File(path).writeAsString('partial');
            if (cancel) service.abort();
            throw FileSystemException(
              'sharing violation: used by another process',
              path,
              OSError('injected', cancel ? 32 : 5),
            );
          },
        );
        addTearDown(service.dispose);
        await service.startDeploy(
          targets: [local],
          config: FileDeployJobConfig(
            sourcePath: source.path,
            destDir: dest.path,
            autoKillIfInUse: false,
          ),
        );
        expect(calls, 1);
        expect(await existing.readAsString(), 'old');
        expect(service.completedCount, 0);
      },
    );
  }

  test('all destinations are checked before manifest unlock', () async {
    final source = await Directory('${temp.path}/src').create();
    await File('${source.path}/first.txt').writeAsString('new');
    await File('${source.path}/second.txt').writeAsString('new');
    final dest = await Directory('${temp.path}/dest').create();
    await File('${dest.path}/first.txt').writeAsString('old');
    await Directory('${dest.path}/second.txt').create();
    var unlocks = 0;
    final service = FileDeployService(
      runPowerShell:
          (
            script, {
            computerName,
            username,
            password,
            timeoutSeconds = 15,
          }) async {
            unlocks++;
            throw StateError('Must validate before unlock');
          },
    );
    addTearDown(service.dispose);
    await service.startDeploy(
      targets: [local],
      config: FileDeployJobConfig(
        sourcePath: source.path,
        isDirectory: true,
        destDir: dest.path,
      ),
    );
    expect(unlocks, 0);
    expect(service.failedCount, 1);
    expect(await File('${dest.path}/first.txt').readAsString(), 'old');
  });

  for (final nativeCode in [32, 5]) {
    test('remote retry uses native error code $nativeCode', () async {
      final source = await File('${temp.path}/file.txt').writeAsString('new');
      final dest = await Directory('${temp.path}/dest').create();
      final count = File('${temp.path}/attempts.txt');
      final service = FileDeployService(
        runPowerShell:
            (
              script, {
              computerName,
              username,
              password,
              timeoutSeconds = 15,
            }) async {
              final adapter = r'''
function New-PSSession { param($ComputerName) return 'test' }
function Remove-PSSession { param($Session) }
function Invoke-Command { param($Session, $ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
function Copy-Item { param($LiteralPath, $Destination, $ToSession, [switch]$Force)
  [IO.File]::AppendAllText($countPath, 'x')
  [IO.File]::WriteAllText($Destination, 'partial')
  throw [IO.IOException]::new('used by another process', $testHresult)
}
''';
              final prefix =
                  "\$countPath = '${count.path.replaceAll("'", "''")}'\n\$testHresult = ${-2147024896 + nativeCode}\n";
              return ProcessRunner.runPowerShell(
                '$prefix$adapter\n$script',
                timeoutSeconds: timeoutSeconds,
              );
            },
      );
      addTearDown(service.dispose);
      await service.startDeploy(
        targets: [
          const ManagedDevice(
            id: 'remote',
            name: 'Adapter',
            hostname: 'test',
            ip: '192.0.2.1',
          ),
        ],
        config: FileDeployJobConfig(
          sourcePath: source.path,
          destDir: dest.path,
          autoKillIfInUse: false,
        ),
      );
      expect(service.failedCount, 1);
      expect(
        await count.readAsString(),
        nativeCode == 32 ? 'xxx' : 'x',
        reason: service.progressList.first.error,
      );
      expect(await File('${dest.path}/file.txt').exists(), false);
    }, skip: !Platform.isWindows);
  }

  test(
    'WinRM manifest passes each path separately and surfaces backup warnings',
    () async {
      final source = await Directory('${temp.path}/src').create();
      final dest = await Directory('${temp.path}/dest').create();
      for (final name in ['one.txt', 'two.txt']) {
        await File('${source.path}/$name').writeAsString('new');
        await File('${dest.path}/$name').writeAsString('old');
      }
      final service = FileDeployService(
        runPowerShell:
            (
              script, {
              computerName,
              username,
              password,
              timeoutSeconds = 15,
            }) async {
              // Substitute only lock discovery to assert the actual transported argument shape.
              final adjusted = script.replaceFirst(
                'Unlock-DeployManifest \$files',
                r'''
if ($files.Count -ne 2) { throw "Wrong manifest count: $($files.Count)" }
foreach ($file in $files) { if (!(Test-Path -LiteralPath $file -PathType Leaf)) { throw "Wrong manifest path: $file" } }
Write-Output 'WARNING: Backup retained at test-backup'
''',
              );
              const adapter = r'''
function New-PSSession { param($ComputerName) return 'test' }
function Remove-PSSession { param($Session) }
function Invoke-Command { param($Session, $ScriptBlock, $ArgumentList) & $ScriptBlock @ArgumentList }
function Copy-Item { param($LiteralPath, $Destination, $ToSession, [switch]$Force) [IO.File]::Copy($LiteralPath, $Destination, $true) }
''';
              return ProcessRunner.runPowerShell(
                '$adapter\n$adjusted',
                timeoutSeconds: timeoutSeconds,
              );
            },
      );
      addTearDown(service.dispose);
      final logs = <String>[];
      final subscription = service.eventStream.listen(logs.add);
      addTearDown(subscription.cancel);
      await service.startDeploy(
        targets: [
          const ManagedDevice(
            id: 'remote',
            name: 'Adapter',
            hostname: 'test',
            ip: '192.0.2.1',
          ),
        ],
        config: FileDeployJobConfig(
          sourcePath: source.path,
          isDirectory: true,
          destDir: dest.path,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        service.completedCount,
        1,
        reason: service.progressList.first.error,
      );
      expect(
        logs.any(
          (line) => line.contains('WARNING: Backup retained at test-backup'),
        ),
        true,
      );
      expect(await File('${dest.path}/two.txt').readAsString(), 'new');
    },
    skip: !Platform.isWindows,
  );
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/data/repositories/file_deploy_history_repository.dart';

void main() {
  late File tempFile;
  late FileDeployHistoryRepository repo;

  setUp(() async {
    tempFile = File(
      '${Directory.systemTemp.path}/test_deploy_history_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    repo = FileDeployHistoryRepository();
    repo.setStorageFileForTesting(tempFile);
  });

  tearDown(() async {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });

  test('saves and restores last source and destination paths', () async {
    expect(await repo.getLastSourcePath(), isNull);
    expect(await repo.getLastDestPath(), equals(r'C:\Temp\Deploy'));

    await repo.saveLastState(
      sourcePath: r'C:\MyFiles\test.bin',
      isDirectory: false,
      destPath: r'D:\DeployTarget',
    );

    // Re-instantiate or re-load
    final newRepo = FileDeployHistoryRepository();
    newRepo.setStorageFileForTesting(tempFile);

    expect(await newRepo.getLastSourcePath(), equals(r'C:\MyFiles\test.bin'));
    expect(await newRepo.getLastSourceIsDir(), isFalse);
    expect(await newRepo.getLastDestPath(), equals(r'D:\DeployTarget'));
  });

  test('cleared destination remains empty after reload', () async {
    await repo.saveLastState(destPath: r'D:\Previous');
    await repo.saveLastState(destPath: '');
    repo.setStorageFileForTesting(tempFile);
    expect(await repo.getLastDestPath(), '');
  });

  test(
    'Linux destinations preserve case while Windows paths deduplicate',
    () async {
      await repo.addDestHistory('/opt/App');
      await repo.addDestHistory('/opt/app');
      await repo.addDestHistory(r'C:\Tools');
      await repo.addDestHistory(r'c:\tools');
      repo.setStorageFileForTesting(tempFile);
      expect(await repo.getDestHistory(), [
        r'c:\tools',
        '/opt/app',
        '/opt/App',
      ]);
      await repo.removeDestHistory('/opt/App');
      expect(await repo.getDestHistory(), [r'c:\tools', '/opt/app']);
    },
  );

  test('manages source history with reordering and cap at 10 items', () async {
    await repo.addSourceHistory(r'C:\FileA.txt', false);
    await repo.addSourceHistory(r'C:\FolderB', true);
    await repo.addSourceHistory(
      r'C:\FileA.txt',
      false,
    ); // Duplicate moves to top

    var sources = await repo.getSourceHistory();
    expect(sources.length, 2);
    expect(sources.first.path, equals(r'C:\FileA.txt'));
    expect(sources.first.isDirectory, isFalse);
    expect(sources[1].path, equals(r'C:\FolderB'));
    expect(sources[1].isDirectory, isTrue);

    // Cap at 10
    for (int i = 0; i < 15; i++) {
      await repo.addSourceHistory('C:\\Source_$i.bin', false);
    }
    sources = await repo.getSourceHistory();
    expect(sources.length, 10);
    expect(sources.first.path, equals(r'C:\Source_14.bin'));
  });

  test('manages destination history with deletion and clear', () async {
    await repo.addDestHistory(r'C:\Temp\One');
    await repo.addDestHistory(r'C:\Temp\Two');
    await repo.addDestHistory(r'C:\Temp\Three');

    var dests = await repo.getDestHistory();
    expect(dests, equals([r'C:\Temp\Three', r'C:\Temp\Two', r'C:\Temp\One']));

    await repo.removeDestHistory(r'C:\Temp\Two');
    dests = await repo.getDestHistory();
    expect(dests, equals([r'C:\Temp\Three', r'C:\Temp\One']));

    await repo.clearDestHistory();
    dests = await repo.getDestHistory();
    expect(dests, isEmpty);
  });
}

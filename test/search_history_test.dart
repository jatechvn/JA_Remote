import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/data/repositories/search_history_repository.dart';

void main() {
  late File tempFile;
  late SearchHistoryRepository repo;

  setUp(() async {
    tempFile = File(
      '${Directory.systemTemp.path}/test_search_history_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    repo = SearchHistoryRepository();
    repo.setStorageFileForTesting(tempFile);
  });

  tearDown(() async {
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  });

  test(
    'SearchHistoryRepository adds, reorders, and deduplicates queries',
    () async {
      var history = await repo.getHistory('devices');
      expect(history, isEmpty);

      await repo.addQuery('devices', 'CMDL');
      await repo.addQuery('devices', '172.21');
      await repo.addQuery('devices', 'CMDL'); // Duplicate should move to top

      history = await repo.getHistory('devices');
      expect(history, equals(['CMDL', '172.21']));
    },
  );

  test('SearchHistoryRepository limits to 10 items per category', () async {
    for (int i = 0; i < 15; i++) {
      await repo.addQuery('scanner', 'query_$i');
    }

    final history = await repo.getHistory('scanner');
    expect(history.length, equals(10));
    expect(history.first, equals('query_14'));
    expect(history.last, equals('query_5'));
  });

  test('SearchHistoryRepository removes item and clears history', () async {
    await repo.addQuery('devices', 'query_a');
    await repo.addQuery('devices', 'query_b');

    await repo.removeQuery('devices', 'query_a');
    var history = await repo.getHistory('devices');
    expect(history, equals(['query_b']));

    await repo.clearHistory('devices');
    history = await repo.getHistory('devices');
    expect(history, isEmpty);
  });
}

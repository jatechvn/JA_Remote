import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/data/repositories/credential_repository.dart';

void main() {
  late Directory tempDir;
  late File tempFile;
  late CredentialRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cred_test_');
    tempFile = File('${tempDir.path}/credentials_test.json');
    repo = CredentialRepository();
    repo.setStorageFileForTesting(tempFile);
  });

  tearDown(() async {
    repo.setStorageFileForTesting(null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CredentialRepository with DPAPI', () {
    test(
      'saves passwords encrypted with dpapi on disk and decrypts when loaded',
      () async {
        await repo.recordCredential(
          'admin',
          'P@ssword123',
          label: 'Factory Admin',
        );

        // Check on disk content is encrypted
        expect(await tempFile.exists(), isTrue);
        final rawContent = await tempFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(rawContent);
        expect(jsonList.length, 1);
        final storedPass = jsonList[0]['password'] as String;
        expect(storedPass.startsWith('dpapi:'), isTrue);
        expect(storedPass, isNot(contains('P@ssword123')));

        // Load via repo
        final loaded = await repo.loadCredentials();
        expect(loaded.length, 1);
        expect(loaded[0].username, 'admin');
        expect(loaded[0].password, 'P@ssword123');
      },
    );

    test(
      'backward compatibility: loads plaintext passwords seamlessly',
      () async {
        final legacyJson = [
          {
            'id': 'legacy_1',
            'username': 'legacy_user',
            'password': 'plain_secret_password',
            'label': 'Legacy',
            'lastUsed': DateTime.now().toIso8601String(),
          },
        ];
        await tempFile.writeAsString(jsonEncode(legacyJson));

        final loaded = await repo.loadCredentials();
        expect(loaded.length, 1);
        expect(loaded[0].password, 'plain_secret_password');

        // Next save automatically encrypts it
        await repo.saveAll(loaded);
        final rawUpdated = await tempFile.readAsString();
        final List<dynamic> updatedJson = jsonDecode(rawUpdated);
        expect(
          (updatedJson[0]['password'] as String).startsWith('dpapi:'),
          isTrue,
        );
      },
    );
  });
}

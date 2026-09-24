import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/services/ota_update_service.dart';

Future<String> _sha256ForTest(File file) async {
  final result = await Process.run('certutil', [
    '-hashfile',
    file.path,
    'SHA256',
  ]);
  final hash = RegExp(
    r'(?<![A-Fa-f0-9])([A-Fa-f0-9]{64})(?![A-Fa-f0-9])',
  ).firstMatch('${result.stdout}\n${result.stderr}')?.group(1);
  if (result.exitCode != 0 || hash == null) {
    throw StateError('Could not calculate test checksum');
  }
  return hash.toLowerCase();
}

void main() {
  group('SemanticVersion Tests', () {
    test('tryParse parses standard and prefixed version strings', () {
      final v1 = SemanticVersion.tryParse('1.2.1');
      expect(v1, isNotNull);
      expect(v1!.major, equals(1));
      expect(v1.minor, equals(2));
      expect(v1.patch, equals(1));
      expect(v1.build, isNull);
      expect(v1.displayVersion, equals('v1.2.1'));

      final v2 = SemanticVersion.tryParse('v1.3.0');
      expect(v2, isNotNull);
      expect(v2!.major, equals(1));
      expect(v2.minor, equals(3));
      expect(v2.patch, equals(0));

      final v3 = SemanticVersion.tryParse('1.2.1+4');
      expect(v3, isNotNull);
      expect(v3!.build, equals(4));

      final v4 = SemanticVersion.tryParse('2.0.0-beta.1');
      expect(v4, isNotNull);
      expect(v4!.prerelease, equals('beta.1'));

      expect(SemanticVersion.tryParse('invalid'), isNull);
      expect(SemanticVersion.tryParse(''), isNull);
      expect(SemanticVersion.tryParse(null), isNull);
    });

    test('SemanticVersion comparisons work accurately', () {
      final v100 = SemanticVersion.tryParse('1.0.0')!;
      final v110 = SemanticVersion.tryParse('1.1.0')!;
      final v111 = SemanticVersion.tryParse('1.1.1')!;
      final v200 = SemanticVersion.tryParse('2.0.0')!;

      expect(v110 > v100, isTrue);
      expect(v111 > v110, isTrue);
      expect(v200 > v111, isTrue);
      expect(v100 < v110, isTrue);

      final vBuild1 = SemanticVersion.tryParse('1.2.1+1')!;
      final vBuild2 = SemanticVersion.tryParse('1.2.1+2')!;
      expect(vBuild2 > vBuild1, isTrue);

      final vPre = SemanticVersion.tryParse('1.2.0-beta')!;
      final vRelease = SemanticVersion.tryParse('1.2.0')!;
      expect(vRelease > vPre, isTrue);

      final vSame1 = SemanticVersion.tryParse('v1.2.1')!;
      final vSame2 = SemanticVersion.tryParse('1.2.1')!;
      expect(vSame1 == vSame2, isTrue);
      expect(vSame1.hashCode, equals(vSame2.hashCode));
    });
  });

  group('OtaUpdateConfig Tests', () {
    test('defaults provide sensible baseline configuration', () {
      final config = OtaUpdateConfig.defaults();
      expect(config.serverPath, contains('JA_Remote'));
      expect(config.checkInterval, equals('daily'));
    });

    test('toJson and fromJson serialize symmetrically', () {
      final now = DateTime(2026, 9, 21, 15, 30);
      final config = OtaUpdateConfig(
        serverPath: r'\\192.168.1.100\Updates',
        username: 'admin',
        password: 'secretPassword',
        checkInterval: 'weekly',
        lastCheckTime: now,
        cachedUpdateVersion: '1.2.2',
      );

      final json = config.toJson();
      expect(json['password'], isNot(equals(config.password)));
      expect((json['password'] as String).startsWith('dpapi:'), isTrue);
      final revived = OtaUpdateConfig.fromJson(json);

      expect(revived.serverPath, equals(config.serverPath));
      expect(revived.username, equals(config.username));
      expect(revived.password, equals(config.password));
      expect(revived.checkInterval, equals('weekly'));
      expect(revived.lastCheckTime, equals(now));
      expect(revived.cachedUpdateVersion, equals('1.2.2'));
    });

    test('copyWith updates specific properties immutably', () {
      final config = OtaUpdateConfig.defaults();
      final updated = config.copyWith(
        serverPath: r'D:\LocalTestShare',
        checkInterval: 'off',
      );
      expect(updated.serverPath, equals(r'D:\LocalTestShare'));
      expect(updated.checkInterval, equals('off'));
      expect(updated.username, equals(config.username));
    });
  });

  group('OtaUpdateService Logic Tests', () {
    final service = OtaUpdateService();

    test('shouldCheckForUpdates obeys configured intervals', () {
      final now = DateTime(2026, 9, 21, 12, 0, 0);

      // Never checked -> always true
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: null,
          now: now,
        ),
        isTrue,
      );

      // Off interval -> always false
      expect(
        service.shouldCheckForUpdates(
          interval: 'off',
          lastCheckTime: null,
          now: now,
        ),
        isFalse,
      );

      // Daily: 25h elapsed -> true, 2h elapsed -> false
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: now.subtract(const Duration(hours: 25)),
          now: now,
        ),
        isTrue,
      );
      expect(
        service.shouldCheckForUpdates(
          interval: 'daily',
          lastCheckTime: now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        isFalse,
      );

      // Weekly: 8d elapsed -> true, 3d elapsed -> false
      expect(
        service.shouldCheckForUpdates(
          interval: 'weekly',
          lastCheckTime: now.subtract(const Duration(days: 8)),
          now: now,
        ),
        isTrue,
      );
      expect(
        service.shouldCheckForUpdates(
          interval: 'weekly',
          lastCheckTime: now.subtract(const Duration(days: 3)),
          now: now,
        ),
        isFalse,
      );
    });

    test('extractSmbShareRoot isolates root UNC server share', () {
      expect(
        OtaUpdateService.extractSmbShareRoot(
          r'\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_Remote',
        ),
        equals(r'\\10.81.141.226\temp'),
      );
      expect(
        OtaUpdateService.extractSmbShareRoot(r'\\192.168.1.50\PublicShare'),
        equals(r'\\192.168.1.50\PublicShare'),
      );
      expect(
        OtaUpdateService.extractSmbShareRoot(r'C:\LocalDir\SubDir'),
        isNull,
      );
    });

    test(
      'isValidPackageName validates file name syntax and prevents path traversal',
      () {
        expect(
          OtaUpdateService.isValidPackageName(
            'JA_Remote_v1.2.2_Windows_x64.zip',
          ),
          isTrue,
        );
        expect(
          OtaUpdateService.isValidPackageName('JA_Remote_1.3.0.zip'),
          isTrue,
        );
        expect(
          OtaUpdateService.isValidPackageName('JA_Remote_v1.2.2-beta.zip'),
          isTrue,
        );
        // Malicious or mismatched names
        expect(
          OtaUpdateService.isValidPackageName('JA_Remote_.._escape.zip'),
          isFalse,
        );
        expect(OtaUpdateService.isValidPackageName('other_app.zip'), isFalse);
        expect(
          OtaUpdateService.isValidPackageName('JA_Remote_v1.2.2.exe'),
          isFalse,
        );
      },
    );

    test('isValidSha256 accepts only complete SHA-256 values', () {
      expect(OtaUpdateService.isValidSha256('a' * 64), isTrue);
      expect(OtaUpdateService.isValidSha256('a' * 63), isFalse);
      expect(OtaUpdateService.isValidSha256('z' * 64), isFalse);
    });

    test('generateApplyUpdateScript generates secure batch script', () {
      final script = OtaUpdateService.generateApplyUpdateScript(
        oldPid: 1234,
        sourceDir: r'C:\Temp\UpdatePayload',
        targetDir: r'C:\Apps\JA_Remote',
        exeName: 'ja_remote.exe',
      );

      expect(script, contains('set "OLD_PID=1234"'));
      expect(script, contains(r'set "SRC_DIR=C:\Temp\UpdatePayload"'));
      expect(script, contains(r'set "DST_DIR=C:\Apps\JA_Remote"'));
      expect(script, contains('set "EXE_NAME=ja_remote.exe"'));
      expect(script, contains('robocopy "%DST_DIR%" "%BACKUP_DIR%"'));
      expect(script, contains('robocopy "%SRC_DIR%" "%DST_DIR%"'));
      expect(script, contains(':rollback'));

      // Reject path injections
      expect(
        () => OtaUpdateService.generateApplyUpdateScript(
          oldPid: 1234,
          sourceDir: 'C:\\Bad"Path',
          targetDir: 'C:\\Apps',
          exeName: 'ja_remote.exe',
        ),
        throwsArgumentError,
      );
    });

    test(
      'checkForUpdates detects updates from mock version.json server folder',
      () async {
        final tempServer = await Directory.systemTemp.createTemp(
          'mock_ota_server_',
        );
        try {
          // Create mock release package
          final mockZip = File(
            '${tempServer.path}/JA_Remote_v9.9.9_Windows_x64.zip',
          );
          await mockZip.writeAsString('MOCK_ZIP_CONTENT');

          // Create version.json
          final versionJson = File('${tempServer.path}/version.json');
          await versionJson.writeAsString(
            jsonEncode({
              'version': '9.9.9',
              'fileName': 'JA_Remote_v9.9.9_Windows_x64.zip',
              'sha256': 'a' * 64,
              'releaseNotes': 'Major new features and stability improvements',
              'releaseDate': '2026-09-21',
            }),
          );

          service.setCustomServerDirForTesting(tempServer);
          service.setCustomConfigFileForTesting(
            File('${tempServer.path}/update_config.json'),
          );

          final result = await service.checkForUpdates(
            overrideServerPath: tempServer.path,
            overrideCurrentVersion: '1.2.1',
          );

          expect(result.isConnectionSuccess, isTrue);
          expect(result.hasUpdate, isTrue);
          expect(result.packageInfo, isNotNull);
          expect(result.packageInfo!.version.toString(), equals('9.9.9'));
          expect(
            result.packageInfo!.releaseNotes,
            contains('Major new features'),
          );
        } finally {
          service.setCustomServerDirForTesting(null);
          service.setCustomConfigFileForTesting(null);
          await tempServer.delete(recursive: true);
        }
      },
    );

    test('allows update without a SHA-256 checksum', () async {
      final tempServer = await Directory.systemTemp.createTemp(
        'mock_ota_unsigned_',
      );
      try {
        await File(
          '${tempServer.path}/JA_Remote_v9.9.9_Windows_x64.zip',
        ).writeAsString('MOCK_ZIP_CONTENT');
        await File('${tempServer.path}/version.json').writeAsString(
          jsonEncode({
            'version': '9.9.9',
            'fileName': 'JA_Remote_v9.9.9_Windows_x64.zip',
          }),
        );
        service.setCustomServerDirForTesting(tempServer);
        service.setCustomConfigFileForTesting(
          File('${tempServer.path}/update_config.json'),
        );

        final result = await service.checkForUpdates(
          overrideCurrentVersion: '1.2.1',
        );

        expect(result.hasUpdate, isTrue);
        expect(result.packageInfo, isNotNull);
        expect(result.packageInfo!.version.toString(), equals('9.9.9'));
        expect(result.packageInfo!.sha256, isNull);
      } finally {
        service.setCustomServerDirForTesting(null);
        service.setCustomConfigFileForTesting(null);
        await tempServer.delete(recursive: true);
      }
    });

    test(
      'handles server candidate without version.json when already up to date',
      () async {
        final tempServer = await Directory.systemTemp.createTemp(
          'mock_ota_same_ver_',
        );
        try {
          await File(
            '${tempServer.path}/JA_Remote_v1.2.1_Windows_x64.zip',
          ).writeAsString('MOCK_CONTENT');
          service.setCustomServerDirForTesting(tempServer);
          service.setCustomConfigFileForTesting(
            File('${tempServer.path}/update_config.json'),
          );

          final result = await service.checkForUpdates(
            overrideServerPath: tempServer.path,
            overrideCurrentVersion: '1.2.1',
          );

          expect(result.hasUpdate, isFalse);
          expect(result.errorMessage, isNull);
          expect(result.packageInfo, isNotNull);
          expect(result.packageInfo!.version.toString(), equals('1.2.1'));
        } finally {
          service.setCustomServerDirForTesting(null);
          service.setCustomConfigFileForTesting(null);
          await tempServer.delete(recursive: true);
        }
      },
    );

    test(
      'detects update from zip fallback via SHA256SUMS.txt when version.json is missing',
      () async {
        final tempServer = await Directory.systemTemp.createTemp(
          'mock_ota_sums_',
        );
        try {
          final zipName = 'JA_Remote_v1.3.0_Windows_x64.zip';
          await File(
            '${tempServer.path}/$zipName',
          ).writeAsString('NEW_VERSION');
          final fakeHash = 'b' * 64;
          await File(
            '${tempServer.path}/SHA256SUMS.txt',
          ).writeAsString('$fakeHash *$zipName\n');
          service.setCustomServerDirForTesting(tempServer);
          service.setCustomConfigFileForTesting(
            File('${tempServer.path}/update_config.json'),
          );

          final result = await service.checkForUpdates(
            overrideServerPath: tempServer.path,
            overrideCurrentVersion: '1.2.1',
          );

          expect(result.hasUpdate, isTrue);
          expect(result.errorMessage, isNull);
          expect(result.packageInfo, isNotNull);
          expect(result.packageInfo!.version.toString(), equals('1.3.0'));
          expect(result.packageInfo!.sha256, equals(fakeHash));
        } finally {
          service.setCustomServerDirForTesting(null);
          service.setCustomConfigFileForTesting(null);
          await tempServer.delete(recursive: true);
        }
      },
    );

    test(
      'detects update from zip alone without version.json or checksum file (JA_LAN_Messenger behavior)',
      () async {
        final tempServer = await Directory.systemTemp.createTemp(
          'mock_ota_zip_only_',
        );
        try {
          final zipName = 'JA_Remote_v1.3.0_Windows_x64.zip';
          await File(
            '${tempServer.path}/$zipName',
          ).writeAsString('NEW_VERSION_ALONE');
          service.setCustomServerDirForTesting(tempServer);
          service.setCustomConfigFileForTesting(
            File('${tempServer.path}/update_config.json'),
          );

          final result = await service.checkForUpdates(
            overrideServerPath: tempServer.path,
            overrideCurrentVersion: '1.2.1',
          );

          expect(result.hasUpdate, isTrue);
          expect(result.errorMessage, isNull);
          expect(result.packageInfo, isNotNull);
          expect(result.packageInfo!.version.toString(), equals('1.3.0'));
          expect(result.packageInfo!.sha256, isNull);
        } finally {
          service.setCustomServerDirForTesting(null);
          service.setCustomConfigFileForTesting(null);
          await tempServer.delete(recursive: true);
        }
      },
    );

    test('requires files and a directory for the extracted payload', () async {
      final payload = await Directory.systemTemp.createTemp('ota_payload_');
      try {
        await File('${payload.path}/ja_remote.exe').writeAsString('exe');
        await File('${payload.path}/flutter_windows.dll').writeAsString('dll');
        await File('${payload.path}/data').writeAsString('not a directory');

        await expectLater(
          service.validatePayloadForTesting(payload),
          throwsA(isA<StateError>()),
        );
      } finally {
        await payload.delete(recursive: true);
      }
    });

    test('verifies a real ZIP before accepting its Flutter payload', () async {
      final root = await Directory.systemTemp.createTemp('ota_archive_');
      Directory? extracted;
      try {
        final payload = Directory('${root.path}/payload');
        await payload.create();
        await File('${payload.path}/ja_remote.exe').writeAsString('exe');
        await File('${payload.path}/flutter_windows.dll').writeAsString('dll');
        await Directory('${payload.path}/data').create();
        final archive = File('${root.path}/JA_Remote_v9.9.9_Windows_x64.zip');
        final zip = await Process.run('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Compress-Archive -LiteralPath "${payload.path}" -DestinationPath "${archive.path}" -Force',
        ]);
        expect(zip.exitCode, equals(0));

        extracted = await service.validatePackageForTesting(
          UpdatePackageInfo(
            version: SemanticVersion.tryParse('9.9.9')!,
            fileName: archive.uri.pathSegments.last,
            fullPath: archive.path,
            fileSize: await archive.length(),
            sha256: await _sha256ForTest(archive),
          ),
        );
        expect(await File('${extracted.path}/ja_remote.exe').exists(), isTrue);
        expect(await Directory('${extracted.path}/data').exists(), isTrue);
      } finally {
        if (extracted != null && await extracted.parent.parent.exists()) {
          await extracted.parent.parent.delete(recursive: true);
        }
        await root.delete(recursive: true);
      }
    });
  });
}

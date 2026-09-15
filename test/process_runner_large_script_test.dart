import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/process/process_runner.dart';

void main() {
  group('ProcessRunner Large Script Tests', () {
    test(
      'executes large script exceeding 32k command-line limit without error',
      () async {
        // Construct a script > 45,000 characters which would fail with
        // "ProcessThe filename or extension is too long" if passed via -EncodedCommand
        final commentPadding = '# ${'X' * 45000}';
        final script = '$commentPadding\nWrite-Output "LARGE_SCRIPT_SUCCESS"';

        final result = await ProcessRunner.runPowerShell(
          script,
          timeoutSeconds: 15,
        );

        expect(result.isSuccess, isTrue, reason: 'Stderr: ${result.stderr}');
        expect(result.stdout, contains('LARGE_SCRIPT_SUCCESS'));
      },
      skip: !Platform.isWindows,
    );

    test(
      'preserves UTF-8 BOM encoding for special characters in large script',
      () async {
        final commentPadding = '# ${'Y' * 20000}';
        final temp = await Directory.systemTemp.createTemp('ja_utf8_test_');
        addTearDown(() => temp.delete(recursive: true));
        final outPath = '${temp.path}\\out.txt'.replaceAll("'", "''");
        const specialText =
            'Dữ liệu tiếng Việt: C:\\Kiểm tra\\Thư mục [1] #123';
        final safeSpecial = specialText.replaceAll("'", "''");
        final script =
            '''
$commentPadding
[IO.File]::WriteAllText('$outPath', '$safeSpecial', [Text.Encoding]::UTF8)
Write-Output "WRITE_DONE"
''';

        final result = await ProcessRunner.runPowerShell(
          script,
          timeoutSeconds: 15,
        );

        expect(result.isSuccess, isTrue, reason: result.stderr);
        expect(result.stdout, contains('WRITE_DONE'));
        final readBack = await File('${temp.path}\\out.txt').readAsString();
        expect(readBack, specialText);
      },
      skip: !Platform.isWindows,
    );
  });
}

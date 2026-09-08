import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/core/process/process_runner.dart';

void main() {
  group('ProcessRunner CLIXML Decoder Tests', () {
    test(
      'decodeClixml correctly extracts stderr text from PowerShell CLIXML',
      () {
        const raw = '''#< CLIXML
<Objs Version="1.1.0.1" xmlns="http://schemas.microsoft.com/powershell/2004/04"><Obj S="progress" RefId="0"><TN RefId="0"><T>System.Management.Automation.PSCustomObject</T><T>System.Object</T></TN><MS><I64 N="SourceId">1</I64><PR N="Record"><AV>Preparing modules for first use.</AV><AI>0</AI><Nil /><PI>-1</PI><PC>-1</PC><T>Completed</T><SR>-1</SR><SD /></PR></MS></Obj><S S="Error">* daemon not running; starting now at tcp:5037_x000D__x000A_</S><S S="Error">    + CategoryInfo          : NotSpecified: (* daemon not ru...now at tcp:5037:String) [], RemoteException_x000D__x000A_</S><S S="Error">    + FullyQualifiedErrorId : NativeCommandError_x000D__x000A_</S><S S="Error">    + PSComputerName        : 172.21.174.208_x000D__x000A_</S><S S="Error">_x000D__x000A_</S><S S="Error">* daemon started successfully_x000D__x000A_</S></Objs>''';

        final result = ProcessRunner.decodeClixml(raw);
        expect(
          result,
          contains('* daemon not running; starting now at tcp:5037'),
        );
        expect(result, contains('* daemon started successfully'));
        expect(result, isNot(contains('#< CLIXML')));
        expect(result, isNot(contains('Preparing modules for first use.')));
        expect(result, isNot(contains('NativeCommandError')));
        expect(result, isNot(contains('_x000D__x000A_')));
      },
    );

    test('decodeClixml returns raw text if not CLIXML', () {
      const plain = 'Normal error message';
      expect(ProcessRunner.decodeClixml(plain), equals(plain));
    });
  });
}

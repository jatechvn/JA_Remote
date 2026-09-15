import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/data/repositories/file_deploy_history_repository.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/widgets/glass_deploy_dest_field.dart';

void main() {
  late File tempFile;
  late FileDeployHistoryRepository repo;

  setUp(() async {
    tempFile = File(
      '${Directory.systemTemp.path}/test_deploy_ui_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    repo = FileDeployHistoryRepository();
    repo.setStorageFileForTesting(tempFile);
    await repo.addDestHistory(r'C:\Temp\Deploy');
    await repo.addDestHistory(r'D:\Tools\Outputs');
  });

  tearDown(() async {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  });

  Widget createWidget({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Focus(
            autofocus: true,
            child: Center(child: SizedBox(width: 400, child: child)),
          ),
        ),
      ),
    );
  }

  testWidgets('GlassDeployDestField displays text and shows history on tap', (
    tester,
  ) async {
    final prevHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      prevHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = prevHandler);

    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      createWidget(
        child: Builder(
          builder: (context) {
            final colors = context.read<ThemeProvider>().colors;
            final language = context.read<LanguageProvider>();
            return GlassDeployDestField(
              controller: controller,
              focusNode: focusNode,
              colors: colors,
              language: language,
              historyRepo: repo,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on the text field to open history overlay
    await tester.tap(find.byType(TextField), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    // Verify suggestions are visible in dropdown
    expect(find.text(r'D:\Tools\Outputs'), findsOneWidget);

    // Tap the suggestion item to select it
    await tester.tap(
      find.text(r'D:\Tools\Outputs'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    // Text in controller should be updated to D:\Tools\Outputs
    expect(controller.text, equals(r'D:\Tools\Outputs'));
  });

  testWidgets('GlassDeployDestField clear button empties the text', (
    tester,
  ) async {
    final controller = TextEditingController(text: r'C:\Temp\Deploy');

    await tester.pumpWidget(
      createWidget(
        child: Builder(
          builder: (context) {
            final colors = context.watch<ThemeProvider>().colors;
            final language = context.watch<LanguageProvider>();
            return GlassDeployDestField(
              controller: controller,
              colors: colors,
              language: language,
              historyRepo: repo,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final clearBtn = find.byIcon(Icons.close_rounded);
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    expect(controller.text, isEmpty);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}

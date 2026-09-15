import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/data/repositories/search_history_repository.dart';
import 'package:ja_remote/widgets/glass_search_history_field.dart';

void main() {
  late File tempFile;
  late SearchHistoryRepository repo;

  setUp(() async {
    tempFile = File(
      '${Directory.systemTemp.path}/test_search_history_field_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    repo = SearchHistoryRepository();
    repo.setStorageFileForTesting(tempFile);
    await repo.addQuery('test_cat', 'MMI|CMDL');
  });

  tearDown(() async {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}
  });

  testWidgets('Tapping on history item selects it and populates text field', (
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
    String changedVal = '';
    String submittedVal = '';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Focus(
              autofocus: true,
              child: Center(
                child: SizedBox(
                  width: 400,
                  child: GlassSearchHistoryField(
                    controller: controller,
                    focusNode: focusNode,
                    category: 'test_cat',
                    hintText: 'Search...',
                    onChanged: (val) => changedVal = val,
                    onSubmitted: (val) => submittedVal = val,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on the text field to open history
    await tester.tap(find.byType(TextField), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    // Verify overlay shows item
    expect(find.text('MMI|CMDL'), findsOneWidget);

    // Tap on the history item with mouse
    await tester.tap(find.text('MMI|CMDL'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    // Check if controller.text is set
    expect(controller.text, equals('MMI|CMDL'));
    expect(changedVal, equals('MMI|CMDL'));
    expect(submittedVal, equals('MMI|CMDL'));
  });

  testWidgets('Tapping delete button on history item deletes it', (
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
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: GlassSearchHistoryField(
                  controller: controller,
                  focusNode: focusNode,
                  category: 'test_cat',
                  hintText: 'Search...',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap text field to open overlay
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('MMI|CMDL'), findsOneWidget);

    // Tap delete icon
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    // Verify item is removed from repo
    final history = await repo.getHistory('test_cat');
    expect(history, isEmpty);
  });
}

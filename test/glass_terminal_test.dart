import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/theme/language_provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/widgets/glass_terminal.dart';
import 'package:provider/provider.dart';

Widget _createTerminalTestApp({
  String? title,
  String? welcomeText,
  Future<String?> Function(String)? onCommand,
  GlassTerminalController? controller,
  AppLanguage language = AppLanguage.en,
}) {
  final langProvider = LanguageProvider()..setLanguage(language);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider.value(value: langProvider),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: GlassTerminalPanel(
          key: ValueKey('test_terminal_${language.code}'),
          terminalTitle: title,
          initialWelcomeText: welcomeText,
          onCommand: onCommand,
          controller: controller,
        ),
      ),
    ),
  );
}

void main() {
  group('GlassTerminalPanel Tests', () {
    testWidgets(
      'Renders terminal window chrome, badge and initial welcome message',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _createTerminalTestApp(
            title: 'test@ja-host:~',
            welcomeText: 'Welcome to JA Test Terminal',
          ),
        );
        await tester.pump();

        expect(find.text('test@ja-host:~'), findsOneWidget);
        expect(find.text('LIVE • READY'), findsOneWidget);
        expect(find.text('Welcome to JA Test Terminal'), findsOneWidget);
        expect(find.text('➜ ~'), findsOneWidget);
      },
    );

    testWidgets('Executes "help" command and displays English command list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_createTerminalTestApp(language: AppLanguage.en));
      await tester.pump();

      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);

      await tester.enterText(inputFinder, 'help');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('➜ ~ help'), findsOneWidget);
      expect(
        find.text('Available Diagnostic & Shell Commands:'),
        findsOneWidget,
      );
      expect(
        find.text(
          '  status          Print runtime status, graphic tier & hardware specs',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Executes "help" command and displays Vietnamese command list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_createTerminalTestApp(language: AppLanguage.vi));
      await tester.pump();

      final viInputFinder = find.byType(TextField);
      await tester.enterText(viInputFinder, 'help');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('➜ ~ help'), findsOneWidget);
      expect(
        find.text('Các lệnh chẩn đoán & hệ thống khả dụng:'),
        findsOneWidget,
      );
      expect(
        find.text(
          '  status          In trạng thái runtime, phân tầng đồ họa & phần cứng',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Tapping quick action chip executes command immediately', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_createTerminalTestApp());
      await tester.pump();

      final nodesChip = find.text('nodes');
      expect(nodesChip, findsOneWidget);

      await tester.tap(nodesChip);
      await tester.pump();

      expect(find.text('➜ ~ nodes'), findsOneWidget);
      expect(find.textContaining('JA-EDGE-01'), findsOneWidget);
      expect(find.textContaining('Primary Core'), findsOneWidget);
    });

    testWidgets('GlassTerminalController appends lines and clears stream', (
      WidgetTester tester,
    ) async {
      final controller = GlassTerminalController();
      await tester.pumpWidget(_createTerminalTestApp(controller: controller));
      await tester.pump();

      controller.appendLine(
        'Remote stdout result',
        type: TerminalLineType.output,
      );
      controller.appendLine(
        '[OK] Success execution',
        type: TerminalLineType.success,
      );
      await tester.pump();

      expect(find.text('Remote stdout result'), findsOneWidget);
      expect(find.text('[OK] Success execution'), findsOneWidget);

      controller.clear();
      await tester.pump();

      expect(find.text('Remote stdout result'), findsNothing);
      expect(find.text('[OK] Success execution'), findsNothing);
    });

    testWidgets('Executes "help" command and displays Chinese command list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_createTerminalTestApp(language: AppLanguage.cn));
      await tester.pump();

      final cnInputFinder = find.byType(TextField);
      await tester.enterText(cnInputFinder, 'help');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('➜ ~ help'), findsOneWidget);
      expect(find.text('可用诊断与系统命令:'), findsOneWidget);
      expect(find.text('  status          打印运行时状态、图形档位与硬件配置'), findsOneWidget);
    });

    testWidgets(
      'Renders localized initial subsystem init and welcome banner per language',
      (WidgetTester tester) async {
        // English
        await tester.pumpWidget(
          _createTerminalTestApp(language: AppLanguage.en),
        );
        await tester.pump();
        expect(find.text('JA Terminal Subsystem Initialized'), findsOneWidget);

        // Vietnamese
        await tester.pumpWidget(
          _createTerminalTestApp(language: AppLanguage.vi),
        );
        await tester.pump();
        expect(
          find.text('Đã khởi tạo hệ thống con JA Terminal'),
          findsOneWidget,
        );

        // Chinese
        await tester.pumpWidget(
          _createTerminalTestApp(language: AppLanguage.cn),
        );
        await tester.pump();
        expect(find.text('JA 终端子系统已初始化'), findsOneWidget);
      },
    );

    testWidgets('Renders localized command not found message', (
      WidgetTester tester,
    ) async {
      // English
      await tester.pumpWidget(_createTerminalTestApp(language: AppLanguage.en));
      await tester.pump();

      var input = find.byType(TextField);
      await tester.enterText(input, 'badcmd');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        find.text(
          'zsh: command not found: badcmd. Type "help" for a list of commands.',
        ),
        findsOneWidget,
      );

      // Vietnamese
      await tester.pumpWidget(_createTerminalTestApp(language: AppLanguage.vi));
      await tester.pump();

      input = find.byType(TextField);
      await tester.enterText(input, 'badcmd');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        find.text(
          'zsh: không tìm thấy lệnh: badcmd. Gõ "help" để xem danh sách lệnh.',
        ),
        findsOneWidget,
      );
    });
  });
}

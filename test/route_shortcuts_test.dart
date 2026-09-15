import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_remote/widgets/route_shortcuts.dart';

void main() {
  testWidgets(
    'route commands precede editor handlers, preserve typing, ignore repeat and remove handlers on dispose',
    (tester) async {
      var runs = 0;
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RouteShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.enter,
                control: true,
              ): () =>
                  runs++,
            },
            child: Scaffold(
              body: Focus(
                onKeyEvent: (_, _) => KeyEventResult.handled,
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  autofocus: true,
                  maxLines: null,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'echo test');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(runs, 1);
      expect(controller.text, 'echo test');
      await tester.pumpWidget(const SizedBox());
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(runs, 1);
    },
  );

  testWidgets(
    'outgoing page cannot consume active page shortcut during animation',
    (tester) async {
      var oldCalls = 0;
      var newCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TickerMode(
                  enabled: false,
                  child: RouteShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.f5): () =>
                          oldCalls++,
                    },
                    child: const Text('outgoing'),
                  ),
                ),
                RouteShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.f5): () =>
                        newCalls++,
                  },
                  child: const Text('current'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      expect(oldCalls, 0);
      expect(newCalls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

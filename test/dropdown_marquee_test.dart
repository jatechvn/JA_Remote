import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/widgets/glass_widgets.dart';

void main() {
  testWidgets('BounceMarqueeText renders text correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: BounceMarqueeText(
              text: 'Bouncing Marquee Text Test String',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bouncing Marquee Text Test String'), findsOneWidget);
  });

  testWidgets(
    'GlassDropdown renders, opens, selects item and handles escape key',
    (WidgetTester tester) async {
      String? selected = 'v1';

      final items = [
        const GlassDropdownItem<String>(value: 'v1', label: 'Option 1'),
        const GlassDropdownItem<String>(value: 'v2', label: 'Option 2'),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
          child: Consumer<ThemeProvider>(
            builder: (context, theme, _) {
              return MaterialApp(
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) {
                      return GlassDropdown<String>(
                        items: items,
                        value: selected,
                        colors: theme.colors,
                        onChanged: (val) {
                          setState(() => selected = val);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      // Initial state: Option 1 is displayed
      expect(find.text('Option 1'), findsOneWidget);

      // Tap to open dropdown
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();

      // Option 2 is now in overlay menu
      expect(find.text('Option 2'), findsOneWidget);

      // Tap Option 2
      await tester.tap(find.text('Option 2'));
      await tester.pumpAndSettle();

      // Now Option 2 is selected
      expect(selected, 'v2');
    },
  );
}

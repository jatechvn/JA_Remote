import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/features/file_deploy/file_deploy_view.dart';
import 'package:ja_remote/services/device_service.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/theme/language_provider.dart';

void main() {
  Widget createTestWidget({required double width, required double height}) {
    final deviceService = DeviceService(initialize: false);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider()..setPerfTierMode(PerfTierMode.lite),
        ),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider<DeviceService>.value(value: deviceService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: const FileDeployView(isActive: true),
          ),
        ),
      ),
    );
  }

  testWidgets('Target Devices card auto-collapses on compact height (<720)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(width: 1200, height: 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // When height < 720, the Target Devices card AnimatedCrossFade should be showFirst (collapsed)
    final crossFades = tester.widgetList<AnimatedCrossFade>(
      find.byType(AnimatedCrossFade),
    );
    expect(crossFades.isNotEmpty, isTrue);
    final targetDevicesCrossFade = crossFades.first;
    expect(
      targetDevicesCrossFade.crossFadeState,
      CrossFadeState.showFirst,
      reason: 'Should be collapsed on compact height',
    );

    // Verify chevron down icon is shown when collapsed
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsWidgets);

    // Tapping the Target Devices header toggles it open
    final headerFinder = find.byIcon(Icons.devices_rounded);
    expect(headerFinder, findsOneWidget);
    await tester.tap(headerFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now it should be expanded (showSecond)
    final crossFadesAfterTap = tester.widgetList<AnimatedCrossFade>(
      find.byType(AnimatedCrossFade),
    );
    expect(
      crossFadesAfterTap.first.crossFadeState,
      CrossFadeState.showSecond,
      reason: 'Should be expanded after manual tap',
    );
  });

  testWidgets('Target Devices card stays expanded on tall height (>=720)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget(width: 1200, height: 900));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // When height >= 720, the Target Devices card starts expanded (showSecond)
    final crossFades = tester.widgetList<AnimatedCrossFade>(
      find.byType(AnimatedCrossFade),
    );
    expect(crossFades.isNotEmpty, isTrue);
    expect(
      crossFades.first.crossFadeState,
      CrossFadeState.showSecond,
      reason: 'Should be expanded on tall viewport',
    );
  });
}

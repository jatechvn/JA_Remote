import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_remote/data/models/managed_device.dart';
import 'package:ja_remote/features/devices/devices_view.dart';
import 'package:ja_remote/services/device_service.dart';
import 'package:ja_remote/theme/theme_provider.dart';
import 'package:ja_remote/theme/language_provider.dart';

class SortDevices extends DeviceService {
  SortDevices() : super(initialize: false);
  @override
  List<ManagedDevice> get filteredDevices => const [
    ManagedDevice(
      id: 'a',
      name: 'Sort-A',
      hostname: 'a',
      ip: '192.0.2.100',
      pingMs: 20,
    ),
    ManagedDevice(
      id: 'b',
      name: 'Sort-B',
      hostname: 'b',
      ip: '192.0.2.2',
      pingMs: 3,
    ),
    ManagedDevice(id: 'c', name: 'Sort-C', hostname: 'c', ip: '192.0.2.10'),
  ];
}

void main() {
  testWidgets(
    'IP sort is numeric and missing ping stays last both directions',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = SortDevices();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DeviceService>.value(value: service),
            ChangeNotifierProvider(
              create: (_) =>
                  ThemeProvider()..setPerfTierMode(PerfTierMode.lite),
            ),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: const MaterialApp(home: Scaffold(body: DevicesView())),
        ),
      );
      await tester.pump();
      double y(String name) => tester.getTopLeft(find.text(name).first).dy;
      expect(y('Sort-B'), lessThan(y('Sort-C')));
      expect(y('Sort-C'), lessThan(y('Sort-A')));
      service.setSort('ping', ascending: true);
      await tester.pump();
      expect(y('Sort-B'), lessThan(y('Sort-A')));
      expect(y('Sort-A'), lessThan(y('Sort-C')));
      service.setSort('ping');
      await tester.pump();
      expect(y('Sort-A'), lessThan(y('Sort-B')));
      expect(y('Sort-B'), lessThan(y('Sort-C')));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

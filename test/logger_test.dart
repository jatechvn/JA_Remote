import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:ja_remote/modules/build_info.dart';
import 'package:ja_remote/modules/constants.dart';
import 'package:ja_remote/modules/logger_config.dart';

void main() {
  test('BuildInfo isDebug reflects CLI debug flag and constants', () {
    expect(BuildInfo.version, appVersion);
    expect(BuildInfo.debugTimestamp.isNotEmpty, true);

    BuildInfo.isCliDebug = true;
    expect(BuildInfo.isDebug, true);
  });

  test('Logger initializes debug logs directory and sink properly', () {
    BuildInfo.isCliDebug = true;
    setupLogger();

    final log = Logger('TestLogger');
    log.info('Test log message');

    final logDir = Directory('logs');
    expect(logDir.existsSync(), true);

    disposeLogger();
  });

  test('Logger setup is idempotent and does not duplicate records', () async {
    final originalDebugPrint = debugPrint;
    final messages = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };

    addTearDown(() {
      debugPrint = originalDebugPrint;
      disposeLogger();
      BuildInfo.isCliDebug = false;
    });

    BuildInfo.isCliDebug = true;
    setupLogger();
    setupLogger();

    const marker = 'idempotent logger marker';
    Logger('IdempotentLogger').info(marker);
    await Future<void>.delayed(Duration.zero);

    final matchingMessages = messages
        .where((message) => message.contains(marker))
        .toList(growable: false);
    expect(matchingMessages, hasLength(1));
  });
}

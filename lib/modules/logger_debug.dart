import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

IOSink? _debugLogSink;
StreamSubscription<LogRecord>? _debugLogSubscription;

void setupDebugLogger() {
  disposeDebugLogger();
  Logger.root.level = Level.ALL;
  final logDir = Directory(p.join(Directory.current.path, 'logs'));
  if (!logDir.existsSync()) {
    try {
      logDir.createSync(recursive: true);
    } catch (_) {}
  }

  final now = DateTime.now();
  final logFileName =
      'debug_${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}.log';
  try {
    _debugLogSink = File(
      p.join(logDir.path, logFileName),
    ).openWrite(mode: FileMode.append);
    _debugLogSink?.writeln(
      '=== DEBUG LOG SESSION STARTED: ${now.toIso8601String()} ===',
    );
  } catch (_) {}

  _debugLogSubscription = Logger.root.onRecord.listen((record) {
    final buffer = StringBuffer()
      ..write(
        '[${record.time.toIso8601String()}] [DEBUG] ${record.level.name}: ${record.loggerName} - ${record.message}',
      );
    if (record.error != null) buffer.write('\n  ERROR: ${record.error}');
    if (record.stackTrace != null) {
      buffer.write('\n  STACKTRACE: ${record.stackTrace}');
    }
    final logText = buffer.toString();
    debugPrint(logText);
    _debugLogSink?.writeln(logText);
  });
  rotateDebugLogs(logDir);
}

void rotateDebugLogs(Directory logDir) {
  try {
    final limit = DateTime.now().subtract(const Duration(days: 7));
    logDir.listSync().forEach((entity) {
      if (entity is File && entity.path.endsWith('.log')) {
        if (entity.statSync().modified.isBefore(limit)) {
          entity.deleteSync();
        }
      }
    });
  } catch (_) {}
}

void disposeDebugLogger() {
  _debugLogSubscription?.cancel();
  _debugLogSubscription = null;
  _debugLogSink?.writeln('=== DEBUG LOG SESSION ENDED ===');
  _debugLogSink?.close();
  _debugLogSink = null;
}

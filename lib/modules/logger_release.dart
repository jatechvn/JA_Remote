import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

IOSink? _releaseLogSink;
StreamSubscription<LogRecord>? _releaseLogSubscription;

void setupReleaseLogger() {
  disposeReleaseLogger();
  Logger.root.level = Level.INFO;
  final logDir = Directory(p.join(Directory.current.path, 'logs'));
  if (!logDir.existsSync()) {
    try {
      logDir.createSync(recursive: true);
    } catch (_) {}
  }

  final now = DateTime.now();
  final logFileName =
      '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}.log';
  try {
    _releaseLogSink = File(
      p.join(logDir.path, logFileName),
    ).openWrite(mode: FileMode.append);
    _releaseLogSink?.writeln(
      '=== RELEASE LOG SESSION STARTED: ${now.toIso8601String()} ===',
    );
  } catch (_) {}

  _releaseLogSubscription = Logger.root.onRecord.listen((record) {
    if (record.level < Level.INFO) return;
    final timeStr = record.time.toIso8601String().substring(11, 19);
    final buffer = StringBuffer()
      ..write(
        '[$timeStr] [${record.level.name}] ${record.loggerName} - ${record.message}',
      );
    if (record.error != null) buffer.write('\n  ERROR: ${record.error}');
    final logText = buffer.toString();
    debugPrint(logText);
    _releaseLogSink?.writeln(logText);
  });
  rotateReleaseLogs(logDir);
}

void rotateReleaseLogs(Directory logDir) {
  try {
    final limit = DateTime.now().subtract(const Duration(days: 30));
    logDir.listSync().forEach((entity) {
      if (entity is File && entity.path.endsWith('.log')) {
        if (entity.statSync().modified.isBefore(limit)) {
          entity.deleteSync();
        }
      }
    });
  } catch (_) {}
}

void disposeReleaseLogger() {
  _releaseLogSubscription?.cancel();
  _releaseLogSubscription = null;
  _releaseLogSink?.writeln('=== RELEASE LOG SESSION ENDED ===');
  _releaseLogSink?.close();
  _releaseLogSink = null;
}

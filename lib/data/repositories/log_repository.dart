import 'dart:collection';
import '../models/action_log.dart';

/// In-memory & reactive repository for audit and action logs.
class LogRepository {
  static final LogRepository _instance = LogRepository._internal();
  factory LogRepository() => _instance;
  LogRepository._internal();

  final int _maxLogs = 500;
  final List<ActionLog> _logs = [];

  List<ActionLog> get logs => UnmodifiableListView(_logs);

  void addLog({
    required String deviceName,
    required String deviceIp,
    required String action,
    required String status,
    required String message,
  }) {
    final entry = ActionLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_logs.length}',
      timestamp: DateTime.now(),
      deviceName: deviceName,
      deviceIp: deviceIp,
      action: action,
      status: status,
      message: message,
    );

    _logs.insert(0, entry);
    if (_logs.length > _maxLogs) {
      _logs.removeRange(_maxLogs, _logs.length);
    }
  }

  void clear() {
    _logs.clear();
  }
}

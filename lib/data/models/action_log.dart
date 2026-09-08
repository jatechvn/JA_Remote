/// Audit and activity log entry.
class ActionLog {
  final String id;
  final DateTime timestamp;
  final String deviceName;
  final String deviceIp;
  final String
  action; // 'PING', 'WAKE', 'RESTART', 'SHUTDOWN', 'POWERSHELL', 'SSH', 'RDP'
  final String status; // 'SUCCESS', 'FAILED', 'INFO'
  final String message;

  const ActionLog({
    required this.id,
    required this.timestamp,
    required this.deviceName,
    required this.deviceIp,
    required this.action,
    required this.status,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'deviceName': deviceName,
    'deviceIp': deviceIp,
    'action': action,
    'status': status,
    'message': message,
  };

  factory ActionLog.fromJson(Map<String, dynamic> json) {
    return ActionLog(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceName: json['deviceName'] as String? ?? 'Unknown',
      deviceIp: json['deviceIp'] as String? ?? '0.0.0.0',
      action: json['action'] as String? ?? 'INFO',
      status: json['status'] as String? ?? 'INFO',
      message: json['message'] as String? ?? '',
    );
  }
}

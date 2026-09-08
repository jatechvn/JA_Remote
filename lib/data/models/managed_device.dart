/// Represents a managed PC / device in the network.
class ManagedDevice {
  final String id;
  final String name;
  final String hostname;
  final String ip;
  final String? mac;
  final String os; // 'Windows', 'Linux', 'Other'
  final bool online;
  final int? pingMs;
  final bool sshEnabled;
  final int sshPort;
  final bool powershellEnabled;
  final bool wolEnabled;
  final String? username;
  final String? password;
  final String group; // 'L6', 'L10', 'Factory', 'Office', etc.
  final String? note;
  final DateTime? lastSeen;

  const ManagedDevice({
    required this.id,
    required this.name,
    required this.hostname,
    required this.ip,
    this.mac,
    this.os = 'Windows',
    this.online = false,
    this.pingMs,
    this.sshEnabled = true,
    this.sshPort = 22,
    this.powershellEnabled = true,
    this.wolEnabled = true,
    this.username,
    this.password,
    this.group = 'Factory',
    this.note,
    this.lastSeen,
  });

  ManagedDevice copyWith({
    String? id,
    String? name,
    String? hostname,
    String? ip,
    String? mac,
    String? os,
    bool? online,
    int? pingMs,
    bool? sshEnabled,
    int? sshPort,
    bool? powershellEnabled,
    bool? wolEnabled,
    String? username,
    String? password,
    String? group,
    String? note,
    DateTime? lastSeen,
  }) {
    return ManagedDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      os: os ?? this.os,
      online: online ?? this.online,
      pingMs: pingMs ?? this.pingMs,
      sshEnabled: sshEnabled ?? this.sshEnabled,
      sshPort: sshPort ?? this.sshPort,
      powershellEnabled: powershellEnabled ?? this.powershellEnabled,
      wolEnabled: wolEnabled ?? this.wolEnabled,
      username: username ?? this.username,
      password: password ?? this.password,
      group: group ?? this.group,
      note: note ?? this.note,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hostname': hostname,
    'ip': ip,
    'mac': mac,
    'os': os,
    'online': online,
    'pingMs': pingMs,
    'sshEnabled': sshEnabled,
    'sshPort': sshPort,
    'powershellEnabled': powershellEnabled,
    'wolEnabled': wolEnabled,
    'username': username,
    'password': password,
    'group': group,
    'note': note,
    'lastSeen': lastSeen?.toIso8601String(),
  };

  factory ManagedDevice.fromJson(Map<String, dynamic> json) {
    return ManagedDevice(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Unnamed PC',
      hostname:
          json['hostname'] as String? ?? (json['ip'] as String? ?? 'localhost'),
      ip: json['ip'] as String? ?? '127.0.0.1',
      mac: json['mac'] as String?,
      os: json['os'] as String? ?? 'Windows',
      online: json['online'] as bool? ?? false,
      pingMs: json['pingMs'] as int?,
      sshEnabled: json['sshEnabled'] as bool? ?? true,
      sshPort: json['sshPort'] as int? ?? 22,
      powershellEnabled: json['powershellEnabled'] as bool? ?? true,
      wolEnabled: json['wolEnabled'] as bool? ?? true,
      username: json['username'] as String?,
      password: json['password'] as String?,
      group: json['group'] as String? ?? 'Factory',
      note: json['note'] as String?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String)
          : null,
    );
  }
}

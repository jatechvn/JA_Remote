/// Predefined or custom command template for remote execution.
class CommandTemplate {
  final String id;
  final String name;
  final String platform; // 'windows', 'linux', 'all'
  final String type; // 'powershell', 'ssh', 'cmd'
  final String command;
  final String description;

  const CommandTemplate({
    required this.id,
    required this.name,
    required this.platform,
    required this.type,
    required this.command,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'platform': platform,
    'type': type,
    'command': command,
    'description': description,
  };

  factory CommandTemplate.fromJson(Map<String, dynamic> json) {
    return CommandTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String? ?? 'windows',
      type: json['type'] as String? ?? 'powershell',
      command: json['command'] as String,
      description: json['description'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  static List<CommandTemplate> getDefaultTemplates() {
    return const [
      CommandTemplate(
        id: 'win_uptime',
        name: 'Windows: Xem Uptime',
        platform: 'windows',
        type: 'powershell',
        command: '(get-date) - (gcim Win32_OperatingSystem).LastBootUpTime',
        description: 'Lấy thời gian máy đã hoạt động liên tục',
      ),
      CommandTemplate(
        id: 'win_hostname',
        name: 'Windows: Xem Hostname & OS',
        platform: 'windows',
        type: 'powershell',
        command:
            'Get-ComputerInfo | Select-Object CsName, WindowsProductName, WindowsVersion',
        description: 'Kiểm tra tên máy và phiên bản Windows',
      ),
      CommandTemplate(
        id: 'win_adb_restart',
        name: 'Windows: Khởi động lại ADB Server',
        platform: 'windows',
        type: 'powershell',
        command: 'adb kill-server; adb start-server',
        description: 'Reset kết nối ADB cho các thiết bị di động kiểm thử',
      ),
      CommandTemplate(
        id: 'win_disk',
        name: 'Windows: Kiểm tra dung lượng ổ đĩa',
        platform: 'windows',
        type: 'powershell',
        command:
            'Get-PSDrive -PSProvider FileSystem | Select-Object Name, Used, Free',
        description: 'Xem dung lượng trống trên các ổ C, D',
      ),
      CommandTemplate(
        id: 'linux_uptime',
        name: 'Linux: Xem Uptime & Load',
        platform: 'linux',
        type: 'ssh',
        command: 'uptime',
        description: 'Kiểm tra tải hệ thống và thời gian hoạt động',
      ),
      CommandTemplate(
        id: 'linux_disk',
        name: 'Linux: Dung lượng ổ đĩa (df -h)',
        platform: 'linux',
        type: 'ssh',
        command: 'df -h',
        description: 'Hiển thị dung lượng ổ cứng dạng dễ đọc',
      ),
      CommandTemplate(
        id: 'linux_mem',
        name: 'Linux: Bộ nhớ RAM (free -m)',
        platform: 'linux',
        type: 'ssh',
        command: 'free -m',
        description: 'Xem mức RAM đang sử dụng và còn trống',
      ),
    ];
  }
}

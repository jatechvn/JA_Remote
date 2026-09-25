import 'dart:convert';
import '../data/models/command_template.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/utils/app_storage.dart';

/// Supported application languages.
enum AppLanguage {
  vi('VI', 'Tiếng Việt', '🇻🇳'),
  en('EN', 'English', '🇬🇧'),
  cn('CN', '中文', '🇨🇳');

  final String code;
  final String label;
  final String flag;

  const AppLanguage(this.code, this.label, this.flag);
}

/// Language and localization provider for instant 1-click language switching.
class LanguageProvider extends ChangeNotifier {
  File? _customStorageFile;
  late AppLanguage _currentLanguage;
  bool _isLoaded = false;

  /// Detects the system language from the OS locale.
  /// Rules:
  /// - Starts with 'vi' (e.g. 'vi', 'vi_VN', 'vi-VN') -> Tiếng Việt (AppLanguage.vi)
  /// - Starts with 'zh' (e.g. 'zh', 'zh_CN', 'zh_TW', 'zh-Hans') -> Tiếng Trung (AppLanguage.cn)
  /// - All other locales (e.g. 'en', 'en_US', 'ja_JP', etc.) -> Tiếng Anh (AppLanguage.en)
  static AppLanguage detectSystemLanguage([String? rawLocale]) {
    String localeStr = rawLocale ?? '';
    if (localeStr.isEmpty) {
      try {
        localeStr = Platform.localeName;
      } catch (_) {
        try {
          final loc = WidgetsBinding.instance.platformDispatcher.locale;
          localeStr = '${loc.languageCode}_${loc.countryCode ?? ''}';
        } catch (_) {}
      }
    }
    final normalized = localeStr.trim().toLowerCase().replaceAll('-', '_');
    if (normalized.startsWith('vi')) {
      return AppLanguage.vi;
    }
    if (normalized.startsWith('zh')) {
      return AppLanguage.cn;
    }
    return AppLanguage.en;
  }

  /// Creates a LanguageProvider. If [initialLanguage] is provided, it is used directly.
  /// Otherwise, it defaults to the detected system language.
  LanguageProvider({AppLanguage? initialLanguage, File? storageFile}) {
    _customStorageFile = storageFile;
    _currentLanguage = initialLanguage ?? detectSystemLanguage();
  }

  /// Sets custom storage file for testing.
  void setStorageFileForTesting(File? file) {
    _customStorageFile = file;
    _isLoaded = false;
  }

  /// Creates and initializes LanguageProvider with loaded preference from storage.
  static Future<LanguageProvider> create({
    AppLanguage? initialLanguage,
    File? storageFile,
  }) async {
    final provider = LanguageProvider(
      initialLanguage: initialLanguage,
      storageFile: storageFile,
    );
    await provider.loadSavedLanguage();
    return provider;
  }

  Future<File> _getStorageFile() async {
    if (_customStorageFile != null) return _customStorageFile!;
    return AppStorage.getFile('app_settings.json');
  }

  /// Loads saved language from JSON storage. If none found, keeps currentLanguage.
  Future<void> loadSavedLanguage() async {
    if (_isLoaded) return;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic> && decoded['language'] != null) {
            final savedCode = decoded['language'].toString().toUpperCase();
            final matched = AppLanguage.values.firstWhere(
              (lang) => lang.code == savedCode,
              orElse: () => _currentLanguage,
            );
            if (_currentLanguage != matched) {
              _currentLanguage = matched;
              notifyListeners();
            }
          }
        }
      }
    } catch (_) {}
    _isLoaded = true;
  }

  Future<void> _saveLanguage(AppLanguage language) async {
    try {
      final file = await _getStorageFile();
      Map<String, dynamic> data = {};
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        }
      }
      data['language'] = language.code;
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  AppLanguage get currentLanguage => _currentLanguage;

  /// Cycles to the next language: VI -> EN -> CN -> VI
  void cycleLanguage() {
    switch (_currentLanguage) {
      case AppLanguage.vi:
        _currentLanguage = AppLanguage.en;
        break;
      case AppLanguage.en:
        _currentLanguage = AppLanguage.cn;
        break;
      case AppLanguage.cn:
        _currentLanguage = AppLanguage.vi;
        break;
    }
    notifyListeners();
    _saveLanguage(_currentLanguage);
  }

  void setLanguage(AppLanguage language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
      _saveLanguage(language);
    }
  }

  /// Localized Tab Labels
  List<String> get tabLabels {
    switch (_currentLanguage) {
      case AppLanguage.vi:
        return const [
          'Thiết bị',
          'Quét LAN',
          'Thực thi lệnh',
          'Triển khai file',
          'Nhật ký',
        ];
      case AppLanguage.en:
        return const [
          'Devices',
          'LAN Scanner',
          'Commands',
          'File Deploy',
          'Audit Logs',
        ];
      case AppLanguage.cn:
        return const ['设备列表', '局域网扫描', '命令执行', '文件部署', '审计日志'];
    }
  }

  /// Localized String dictionary lookup with variable formatting support
  String t(String key, [Map<String, String>? params]) {
    final entry = _translations[key];
    String text = key;
    if (entry != null) {
      text = entry[_currentLanguage.code.toLowerCase()] ?? entry['vi'] ?? key;
    }
    if (params != null) {
      params.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }

  String templateName(CommandTemplate template) =>
      _templateText(template, false);
  String templateDescription(CommandTemplate template) =>
      _templateText(template, true);
  String _templateText(CommandTemplate template, bool description) {
    final original = description ? template.description : template.name;
    if (template.isCustom) return original;
    for (final standard in CommandTemplate.getDefaultTemplates()) {
      if (standard.id == template.id &&
          original == (description ? standard.description : standard.name)) {
        return t(
          'template_${template.id}_${description ? 'description' : 'name'}',
        );
      }
    }
    return original;
  }

  static const Map<String, Map<String, String>> _translations = {
    'port_scan_invalid_range': {
      'vi':
          'Nhập cổng từ 1 đến 65535; cổng bắt đầu không được lớn hơn cổng kết thúc.',
      'en': 'Enter ports from 1 to 65535; the start must not exceed the end.',
      'cn': '请输入 1 到 65535 的端口，起始端口不能大于结束端口。',
    },
    'snippet_uptime': {
      'vi': 'Thời gian hoạt động',
      'en': 'Uptime',
      'cn': '运行时间',
    },
    'snippet_disk': {'vi': 'Dung lượng trống', 'en': 'Disk Free', 'cn': '可用空间'},
    'snippet_reboot': {'vi': 'Khởi động lại', 'en': 'Reboot', 'cn': '重启'},
    "ui_close": {"vi": "Đóng", "en": "Close", "cn": "关闭"},
    "ui_cancel": {"vi": "Hủy", "en": "Cancel", "cn": "取消"},
    "ui_delete": {"vi": "Xóa", "en": "Delete", "cn": "删除"},
    "ui_restore": {"vi": "Khôi phục", "en": "Restore", "cn": "恢复"},
    "ui_json_save": {
      "vi": "Lưu vào JSON",
      "en": "Save to JSON",
      "cn": "保存到 JSON",
    },
    "ui_merge": {"vi": "Hợp nhất (Merge)", "en": "Merge", "cn": "合并"},
    "ui_overwrite": {"vi": "Ghi đè (Overwrite)", "en": "Overwrite", "cn": "覆盖"},
    "cmd_copy_command": {
      "vi": "Sao chép lệnh (Copy)",
      "en": "Copy command",
      "cn": "复制命令",
    },
    "cmd_winrm_copied": {
      "vi": "Đã sao chép lệnh WinRM!",
      "en": "WinRM command copied!",
      "cn": "已复制 WinRM 命令！",
    },
    "cmd_winrm_script_copied": {
      "vi": "Đã sao chép script WinRM vào Clipboard!",
      "en": "WinRM script copied to clipboard!",
      "cn": "已复制 WinRM 脚本到剪贴板！",
    },
    "cmd_new_script": {"vi": "Kịch bản mới", "en": "New script", "cn": "新脚本"},
    "cmd_edit_script": {
      "vi": "Chỉnh sửa kịch bản mẫu",
      "en": "Edit template",
      "cn": "编辑模板",
    },
    "cmd_name_hint": {
      "vi": "VD: Kiểm tra Uptime & Thông tin OS",
      "en": "e.g. Check uptime and OS information",
      "cn": "例如：检查运行时间和系统信息",
    },
    "cmd_description_hint": {
      "vi": "Mô tả ngắn gọn chức năng của lệnh",
      "en": "Briefly describe the command",
      "cn": "简要描述命令功能",
    },
    "cmd_content_hint": {
      "vi": "Nội dung script cần chạy...",
      "en": "Script to execute...",
      "cn": "要执行的脚本...",
    },
    "cmd_custom_command": {
      "vi": "Lệnh tùy chỉnh",
      "en": "Custom command",
      "cn": "自定义命令",
    },
    "cmd_empty_command": {
      "vi": "Nội dung lệnh không được để trống!",
      "en": "Command cannot be empty!",
      "cn": "命令不能为空！",
    },
    "cmd_restored": {
      "vi": "Đã khôi phục các lệnh mẫu mặc định!",
      "en": "Default templates restored!",
      "cn": "已恢复默认模板！",
    },
    "cmd_no_templates": {
      "vi": "Không tìm thấy lệnh mẫu trong file JSON đã chọn.",
      "en": "No templates found in the selected JSON file.",
      "cn": "所选 JSON 文件中未找到模板。",
    },
    "cmd_json_error": {
      "vi": "Lỗi đọc file JSON",
      "en": "Failed to read JSON file",
      "cn": "读取 JSON 文件失败",
    },
    "cmd_choose_device": {
      "vi": "Chọn máy trạm...",
      "en": "Select a device...",
      "cn": "选择设备...",
    },
    "cmd_edit_selected": {
      "vi": "Sửa kịch bản đang chọn",
      "en": "Edit selected template",
      "cn": "编辑所选模板",
    },
    "cmd_winrm_intro": {
      "vi":
          "Để điều khiển máy trạm từ xa qua mạng LAN (Workgroup / Non-domain), trên MÁY ĐÍCH (Target PC) cần mở PowerShell quyền Administrator và chạy lệnh sau:",
      "en":
          "To control a LAN device in a workgroup, open PowerShell as Administrator on the TARGET PC and run:",
      "cn": "要远程控制工作组中的局域网设备，请在目标电脑上以管理员身份打开 PowerShell 并运行：",
    },
    "cmd_winrm_details": {
      "vi":
          "• Lệnh trên sẽ: Bật dịch vụ WinRM (Port 5985) + Mở Firewall + Cấp quyền cho tài khoản Local Admin điều khiển từ xa (LocalAccountTokenFilterPolicy).\n• Sau khi chạy lệnh trên, nhập Tài khoản & Mật khẩu của máy đó vào ô Xác thực bên trái để thực thi.",
      "en":
          "• Enables WinRM (port 5985), opens the firewall and allows remote access for local administrators (LocalAccountTokenFilterPolicy).\n• Then enter the target account and password in Authentication.",
      "cn":
          "• 启用 WinRM（端口 5985）、开放防火墙并允许本地管理员远程访问（LocalAccountTokenFilterPolicy）。\n• 然后在身份验证中输入目标账户和密码。",
    },
    "cmd_exported": {
      "vi": "Đã xuất {count} kịch bản ra JSON!",
      "en": "Exported {count} templates to JSON!",
      "cn": "已导出 {count} 个模板到 JSON！",
    },
    "cmd_export_error": {
      "vi": "Lỗi xuất file: {error}",
      "en": "Export failed: {error}",
      "cn": "导出失败：{error}",
    },
    "cmd_import_choice": {
      "vi": "Tìm thấy {count} mẫu. Hợp nhất hay ghi đè toàn bộ?",
      "en": "Found {count} templates. Merge or overwrite all?",
      "cn": "找到 {count} 个模板。合并还是全部覆盖？",
    },
    "cmd_merged": {
      "vi": "Đã hợp nhất {count} mẫu!",
      "en": "Merged {count} templates!",
      "cn": "已合并 {count} 个模板！",
    },
    "cmd_overwritten": {
      "vi": "Đã ghi đè {count} mẫu!",
      "en": "Replaced with {count} templates!",
      "cn": "已替换为 {count} 个模板！",
    },
    "cmd_workers": {
      "vi": "{count} luồng song song",
      "en": "{count} parallel workers",
      "cn": "{count} 个并行任务",
    },
    "template_win_uptime_name": {
      "vi": "Windows: Xem Uptime",
      "en": "Windows: Uptime",
      "cn": "Windows：运行时间",
    },
    "template_win_uptime_description": {
      "vi": "Lấy thời gian máy đã hoạt động liên tục",
      "en": "Show time since the last boot",
      "cn": "显示自上次启动以来的运行时间",
    },
    "template_win_hostname_name": {
      "vi": "Windows: Xem Hostname & OS",
      "en": "Windows: Hostname & OS",
      "cn": "Windows：主机名和系统",
    },
    "template_win_hostname_description": {
      "vi": "Kiểm tra tên máy và phiên bản Windows",
      "en": "Check hostname and Windows version",
      "cn": "检查主机名和 Windows 版本",
    },
    "template_win_adb_restart_name": {
      "vi": "Windows: Khởi động lại ADB Server",
      "en": "Windows: Restart ADB Server",
      "cn": "Windows：重启 ADB 服务",
    },
    "template_win_adb_restart_description": {
      "vi": "Reset kết nối ADB cho các thiết bị di động kiểm thử",
      "en": "Reset ADB connections for test devices",
      "cn": "重置测试设备的 ADB 连接",
    },
    "template_win_disk_name": {
      "vi": "Windows: Kiểm tra dung lượng ổ đĩa",
      "en": "Windows: Disk space",
      "cn": "Windows：磁盘空间",
    },
    "template_win_disk_description": {
      "vi": "Xem dung lượng trống trên các ổ C, D",
      "en": "Show free disk space",
      "cn": "显示磁盘可用空间",
    },
    "template_linux_uptime_name": {
      "vi": "Linux: Xem Uptime & Load",
      "en": "Linux: Uptime & load",
      "cn": "Linux：运行时间和负载",
    },
    "template_linux_uptime_description": {
      "vi": "Kiểm tra tải hệ thống và thời gian hoạt động",
      "en": "Check system load and uptime",
      "cn": "检查系统负载和运行时间",
    },
    "template_linux_disk_name": {
      "vi": "Linux: Dung lượng ổ đĩa (df -h)",
      "en": "Linux: Disk space (df -h)",
      "cn": "Linux：磁盘空间 (df -h)",
    },
    "template_linux_disk_description": {
      "vi": "Hiển thị dung lượng ổ cứng dạng dễ đọc",
      "en": "Show disk usage in readable units",
      "cn": "以易读单位显示磁盘使用情况",
    },
    "template_linux_mem_name": {
      "vi": "Linux: Bộ nhớ RAM (free -m)",
      "en": "Linux: Memory (free -m)",
      "cn": "Linux：内存 (free -m)",
    },
    "template_linux_mem_description": {
      "vi": "Xem mức RAM đang sử dụng và còn trống",
      "en": "Show used and available memory",
      "cn": "显示已用和可用内存",
    },
    "dropdown_search": {
      "vi": "Tìm kiếm {count} mục…",
      "en": "Search {count} items…",
      "cn": "搜索 {count} 项…",
    },
    "dropdown_empty": {
      "vi": "Không tìm thấy mục phù hợp",
      "en": "No matching items",
      "cn": "没有匹配项",
    },
    "dropdown_hint": {
      "vi": "Chọn một mục…",
      "en": "Select an item…",
      "cn": "选择一项…",
    },
    "script_snippets": {"vi": "Lệnh nhanh:", "en": "Snippets:", "cn": "快捷命令："},
    'guide_start_title': {
      'vi': 'Bắt đầu với JA Remote v{version}',
      'en': 'Getting started with JA Remote v{version}',
      'cn': '开始使用 JA Remote v{version}',
    },
    'guide_start_desc': {
      'vi':
          'Thêm máy bằng Ctrl+N hoặc quét LAN rồi thêm máy tìm thấy. Kiểm tra IP, nhóm, MAC và các máy đang được chọn trước khi thao tác hàng loạt. F5 cập nhật trạng thái Ping.',
      'en':
          'Add a device with Ctrl+N or scan the LAN and add discovered hosts. Check IP, group, MAC and selected devices before batch actions. F5 refreshes ping status.',
      'cn':
          '使用 Ctrl+N 添加设备，或扫描局域网后添加发现的主机。批量操作前检查 IP、分组、MAC 和已选设备。F5 刷新 Ping 状态。',
    },
    'guide_remote_title': {
      'vi': 'Lệnh từ xa & công cụ quản trị',
      'en': 'Remote commands and administration',
      'cn': '远程命令与管理工具',
    },
    'guide_remote_desc': {
      'vi':
          'Chọn máy ở tab Thiết bị, mở Ctrl+3, chọn PowerShell/SSH, nhập tài khoản và kiểm tra script trước khi Ctrl+Enter. Máy đích cần WinRM hoặc SSH phù hợp. WOL cần MAC và hỗ trợ BIOS/NIC. RDP, C\$ và Computer Management dùng công cụ Windows.',
      'en':
          'Select devices, open Ctrl+3, choose PowerShell/SSH, enter credentials and review the script before Ctrl+Enter. Targets need WinRM or SSH. WOL requires a MAC and BIOS/NIC support. RDP, C\$ and Computer Management launch Windows tools.',
      'cn':
          '选择设备后按 Ctrl+3，选择 PowerShell/SSH，输入凭据并检查脚本，再按 Ctrl+Enter。目标需启用 WinRM 或 SSH。WOL 需要 MAC 及 BIOS/网卡支持。RDP、C\$ 和计算机管理使用 Windows 工具。',
    },
    'guide_data_title': {
      'vi': 'Dữ liệu & xử lý sự cố',
      'en': 'Data and troubleshooting',
      'cn': '数据与故障排查',
    },
    'guide_data_desc': {
      'vi':
          'Danh sách máy và thông tin đăng nhập lưu trong thư mục hỗ trợ ứng dụng của Windows. Nhật ký tác vụ chỉ giữ tối đa 500 mục trong phiên. Dùng Xuất/Nhập để sao lưu cấu hình. Nếu máy Offline, kiểm tra IP, mạng và ICMP firewall; nếu lệnh lỗi, kiểm tra tài khoản, WinRM/SSH và quyền máy đích.',
      'en':
          'Devices and saved credentials are stored in the Windows application support directory. Audit logs retain up to 500 entries in the current session. Export/import configuration for backups. For Offline hosts check IP, connectivity and ICMP firewall; for command failures check credentials, WinRM/SSH and target permissions.',
      'cn':
          '设备及保存的凭据位于 Windows 应用支持目录。审计日志仅保留当前会话最多 500 条记录。使用导出/导入备份配置。离线时检查 IP、网络和 ICMP 防火墙；命令失败时检查凭据、WinRM/SSH 和目标权限。',
    },
    'guide_deploy_title': {
      'vi': 'Triển khai tệp & Quét cổng TCP',
      'en': 'File Deployer & TCP Port Scanner',
      'cn': '文件部署与 TCP 端口扫描',
    },
    'guide_deploy_desc': {
      'vi':
          'Tab File Deployer (Ctrl+4) hỗ trợ gửi tệp/thư mục đồng loạt tới máy đích Windows (WinRM/SMB) hoặc Linux (SFTP), tự động mở khóa tiến trình chiếm giữ và thu gọn giao diện thông minh. Tính năng Quét cổng (Port Scanner) trong Command Palette (Ctrl+P) hoặc menu thiết bị hỗ trợ quét nhanh TCP các cổng dịch vụ (SSH, RDP, Web, WinRM, v.v.).',
      'en':
          'File Deployer tab (Ctrl+4) concurrently deploys files/folders to Windows (WinRM/SMB) or Linux (SFTP) targets with auto-process unlock and responsive layout. Port Scanner via Command Palette (Ctrl+P) or device context menu checks open TCP ports (SSH, RDP, Web, WinRM, etc.).',
      'cn':
          '文件部署标签页 (Ctrl+4) 支持通过 WinRM/SMB 或 SFTP 并发向 Windows/Linux 目标机分发文件/文件夹，具备占用进程自动解锁与自适应折叠。端口扫描工具可通过命令面板 (Ctrl+P) 或设备菜单对 TCP 端口 (SSH, RDP, Web, WinRM 等) 进行高速探测。',
    },
    // Common header & system
    'perf_tooltip': {
      'vi': 'Chế độ đồ họa & Hiệu năng máy',
      'en': 'Graphic Tier & Hardware Profile',
      'cn': '图形档位与硬件配置',
    },
    'lang_tooltip': {
      'vi': 'Chuyển ngôn ngữ nhanh (VI/EN/CN)',
      'en': 'Quick Language Switch (VI/EN/CN)',
      'cn': '快速切换语言 (VI/EN/CN)',
    },
    'theme_tooltip': {
      'vi': 'Chuyển giao diện Sáng / Tối',
      'en': 'Toggle Light / Dark Theme',
      'cn': '切换深色/浅色主题',
    },
    'theme_light': {'vi': 'Sáng', 'en': 'Light', 'cn': '浅色'},
    'theme_dark': {'vi': 'Tối', 'en': 'Dark', 'cn': '深色'},
    'settings_btn_label': {'vi': 'Cài đặt', 'en': 'Settings', 'cn': '设置'},
    'settings_tooltip': {
      'vi': 'Cài đặt hiệu ứng kính mờ & hệ thống',
      'en': 'Glass Tuning & App Settings',
      'cn': '毛玻璃微调与应用设置',
    },
    'settings_dialog_title': {
      'vi': 'Cài đặt Glassmorphism & Giao diện',
      'en': 'Glassmorphism & UI Settings',
      'cn': '毛玻璃效果与界面设置',
    },
    'settings_card_header': {
      'vi': 'Điều chỉnh Liquid Glass & Bento Card',
      'en': 'Liquid Glass & Bento Card Tuning',
      'cn': '液体玻璃与 Bento 卡片微调',
    },
    'settings_default': {'vi': 'Mặc định', 'en': 'Default', 'cn': '默认'},
    'settings_card_blur': {
      'vi': 'Độ mờ Thẻ (Card Blur)',
      'en': 'Card Blur',
      'cn': '卡片模糊',
    },
    'settings_card_opacity': {
      'vi': 'Độ đục Thẻ (Card Opacity)',
      'en': 'Card Opacity',
      'cn': '卡片不透明度',
    },
    'settings_dialog_blur': {
      'vi': 'Độ mờ Hộp thoại (Dialog Blur)',
      'en': 'Dialog Blur',
      'cn': '弹窗模糊',
    },
    'settings_dialog_opacity': {
      'vi': 'Độ đục Hộp thoại (Dialog Opacity)',
      'en': 'Dialog Opacity',
      'cn': '弹窗不透明度',
    },
    'settings_dropdown_blur': {
      'vi': 'Độ mờ Bảng chọn (Dropdown Blur)',
      'en': 'Dropdown Blur',
      'cn': '下拉菜单模糊',
    },
    'settings_dropdown_opacity': {
      'vi': 'Độ đục Bảng chọn (Dropdown Opacity)',
      'en': 'Dropdown Opacity',
      'cn': '下拉菜单不透明度',
    },
    'action_cancel': {'vi': 'Hủy', 'en': 'Cancel', 'cn': '取消'},
    'action_save': {'vi': 'Lưu Cài Đặt', 'en': 'Save Settings', 'cn': '保存设置'},
    'tab_settings_ui': {
      'vi': 'Kính mờ & Giao diện',
      'en': 'Glass & UI',
      'cn': '界面与毛玻璃',
    },
    'tab_settings_oui': {
      'vi': 'Nhận diện MAC OUI',
      'en': 'MAC OUI Vendor',
      'cn': 'MAC OUI 厂商识别',
    },
    'tab_user_guide': {
      'vi': 'Hướng dẫn sử dụng',
      'en': 'User Guide',
      'cn': '使用指南',
    },
    'tab_about': {'vi': 'Giới thiệu', 'en': 'About', 'cn': '关于应用'},

    // MAC OUI Settings Tab
    'oui_header_title': {
      'vi': 'Tùy chỉnh Nhận diện Thiết bị (MAC OUI)',
      'en': 'Custom MAC OUI Device Identification',
      'cn': '自定义 MAC OUI 设备识别',
    },
    'oui_header_desc': {
      'vi':
          'Tự động nhận diện nhà sản xuất phần cứng (ASIX, HP, Dell, Advantech, v.v.) dựa trên tiền tố địa chỉ MAC khi thiết bị chưa có Hostname. Cấu hình được lưu trong file mac_oui.json.',
      'en':
          'Automatically detects hardware vendors (ASIX, HP, Dell, Advantech, etc.) from MAC address prefixes when hostnames are missing. Saved in mac_oui.json.',
      'cn':
          '在设备无主机名时，根据 MAC 地址前缀自动识别硬件厂商 (ASIX, HP, Dell, Advantech 等)。配置保存在 mac_oui.json 中。',
    },
    'oui_btn_open_file': {
      'vi': 'Mở file JSON (Notepad)',
      'en': 'Open JSON File',
      'cn': '打开 JSON 文件',
    },
    'oui_btn_open_folder': {
      'vi': 'Mở thư mục chứa',
      'en': 'Open Folder',
      'cn': '打开所在目录',
    },
    'oui_btn_reload': {
      'vi': 'Tải lại từ file',
      'en': 'Reload File',
      'cn': '重新加载文件',
    },
    'oui_input_prefix_label': {
      'vi': 'Tiền tố MAC / OUI (6 ký tự hex)',
      'en': 'MAC / OUI Prefix (6 hex chars)',
      'cn': 'MAC / OUI 前缀 (6位十六进制)',
    },
    'oui_input_prefix_hint': {
      'vi': 'VD: 9C:69:D3 hoặc 9C69D3',
      'en': 'e.g. 9C:69:D3 or 9C69D3',
      'cn': '例如: 9C:69:D3 或 9C69D3',
    },
    'oui_input_vendor_label': {
      'vi': 'Tên nhà sản xuất / Ghi chú thiết bị',
      'en': 'Hardware Vendor / Device Note',
      'cn': '硬件厂商 / 设备备注',
    },
    'oui_input_vendor_hint': {
      'vi': 'VD: ASIX (USB-LAN), HP, Advantech',
      'en': 'e.g. ASIX (USB-LAN), HP, Advantech',
      'cn': '例如: ASIX (USB-LAN), HP, Advantech',
    },
    'oui_btn_save': {'vi': 'Lưu OUI', 'en': 'Save OUI', 'cn': '保存 OUI'},
    'oui_custom_list_title': {
      'vi': 'Danh sách OUI tùy chỉnh cá nhân ({count})',
      'en': 'Custom OUI Rules ({count})',
      'cn': '自定义 OUI 规则列表 ({count})',
    },
    'oui_empty_custom': {
      'vi':
          'Chưa có OUI tùy chỉnh nào. Hệ thống đang sử dụng cơ sở dữ liệu mặc định ({count} OUI). Bạn có thể thêm OUI mới ở trên hoặc sửa trực tiếp trong file mac_oui.json.',
      'en':
          'No custom OUIs defined yet. Using default built-in database ({count} OUIs). You can add entries above or edit mac_oui.json directly.',
      'cn':
          '暂无自定义 OUI 规则。当前正在使用内置数据库 ({count} 条 OUI)。您可在上方添加新规则，或直接编辑 mac_oui.json 文件。',
    },
    'oui_toast_saved': {
      'vi': 'Đã lưu OUI {oui} -> {vendor} vào mac_oui.json!',
      'en': 'Saved OUI {oui} -> {vendor} to mac_oui.json!',
      'cn': '已保存 OUI {oui} -> {vendor} 到 mac_oui.json！',
    },
    'oui_toast_deleted': {
      'vi': 'Đã xóa OUI {oui} khỏi file cấu hình!',
      'en': 'Deleted OUI {oui} from configuration!',
      'cn': '已从配置文件中删除 OUI {oui}！',
    },
    'oui_toast_reloaded': {
      'vi': 'Đã tải lại {count} OUI tùy chỉnh từ file!',
      'en': 'Reloaded {count} custom OUIs from file!',
      'cn': '已从文件重新加载 {count} 条自定义 OUI！',
    },
    'oui_invalid_prefix': {
      'vi':
          'Tiền tố OUI không hợp lệ! Vui lòng nhập ít nhất 6 ký tự hex (VD: 9C:69:D3).',
      'en':
          'Invalid OUI prefix! Please enter at least 6 hex characters (e.g. 9C:69:D3).',
      'cn': 'OUI 前缀无效！请输入至少6位十六进制字符 (例如: 9C:69:D3)。',
    },
    'oui_vendor_required': {
      'vi': 'Tên nhà sản xuất không được để trống!',
      'en': 'Vendor name cannot be empty!',
      'cn': '厂商名称不能为空！',
    },
    'oui_status_summary': {
      'vi': '{custom} OUI tùy chỉnh • {builtin} OUI mặc định tích hợp',
      'en': '{custom} Custom OUIs • {builtin} Default Built-in OUIs',
      'cn': '{custom} 条自定义 OUI • {builtin} 条内置默认 OUI',
    },
    'guide_shortcuts_title': {
      'vi': 'Phím tắt toàn cục',
      'en': 'Global Shortcuts',
      'cn': '全局快捷键',
    },
    'guide_shortcuts_desc': {
      'vi':
          'Ctrl+1…5: Chuyển tab (Thiết bị, Quét LAN, Commands, Deploy, Nhật ký)\nCtrl+P / Ctrl+K: Mở Command Palette & Công cụ chẩn đoán (↑/↓ chọn, Enter chạy, Esc đóng)\nCtrl+,: Mở cài đặt hệ thống & hiệu ứng kính\nCtrl+F: Tìm kiếm nhanh (tự động lưu & gợi ý lịch sử)\nCtrl+N: Thêm thiết bị mới (tab Thiết bị)\nF5: Làm mới trạng thái Ping / Nhật ký\nCtrl+Shift+A: Chọn thêm các thiết bị đang lọc\nCtrl+Shift+D: Bỏ chọn tất cả thiết bị\nCtrl+Enter: Chạy script trong Commands hoặc bắt đầu File Deploy\nF1: Mở bảng tra cứu phím tắt',
      'en':
          'Ctrl+1…5: Switch tabs (Devices, LAN Scanner, Commands, Deploy, Logs)\nCtrl+P / Ctrl+K: Open Command Palette & Diagnostics (↑/↓ select, Enter run, Esc close)\nCtrl+,: Open settings & glass tuning\nCtrl+F: Quick search (auto-save & history suggestions)\nCtrl+N: Add new device (Devices tab)\nF5: Refresh Ping status / Logs\nCtrl+Shift+A: Select filtered devices\nCtrl+Shift+D: Deselect all devices\nCtrl+Enter: Execute script in Commands or start File Deploy\nF1: Show shortcuts guide',
      'cn':
          'Ctrl+1…5: 切换标签页 (设备, 局域网扫描, 命令执行, 文件部署, 日志)\nCtrl+P / Ctrl+K: 打开命令面板与诊断工具 (↑/↓选择, Enter运行, Esc关闭)\nCtrl+,: 打开系统设置与毛玻璃微调\nCtrl+F: 快速搜索 (自动保存与历史建议)\nCtrl+N: 添加新设备 (设备页)\nF5: 刷新 Ping 状态 / 日志\nCtrl+Shift+A: 勾选当前筛选的设备\nCtrl+Shift+D: 取消全选设备\nCtrl+Enter: 在命令页执行脚本或开始文件部署\nF1: 显示全局快捷键速查',
    },
    'guide_topbar_title': {
      'vi': 'Tương tác TopBar phóng lớn',
      'en': 'TopBar Hover Expansion',
      'cn': '顶栏悬停放大交互',
    },
    'guide_topbar_desc': {
      'vi':
          'Rê chuột qua các nút Cấu hình máy, Ngôn ngữ, Sáng/Tối và Cài đặt để phóng lớn (scale 1.05) và trượt mượt hiển thị nhãn đầy đủ.',
      'en':
          'Hover over Graphic Tier, Language, Light/Dark, and Settings buttons to scale up (1.05x) and smoothly reveal full labels.',
      'cn': '悬停于图形档位、语言、明暗主题与设置按钮，可放大 (1.05x) 并平滑展开完整标签文字。',
    },
    'guide_tier_title': {
      'vi': 'Phân tầng đồ họa máy tính',
      'en': 'Hardware Graphic Tiers',
      'cn': '硬件图形性能档位',
    },
    'guide_tier_desc': {
      'vi':
          '• Ultra: 120 FPS, tối đa hiệu ứng làm mờ Acrylic/Aero.\n• Balanced: 60 FPS, tối ưu hóa cho Laptop và tiết kiệm pin.\n• Lite: Tắt toàn bộ làm mờ, không giật lag trên máy yếu.',
      'en':
          '• Ultra: 120 FPS, maximum Acrylic/Aero glassmorphism.\n• Balanced: 60 FPS, optimized for laptops and battery.\n• Lite: Zero blur, ultra-low power consumption on weak hardware.',
      'cn':
          '• Ultra: 120 FPS，最大化 Acrylic/Aero 毛玻璃模糊效果。\n• Balanced: 60 FPS，专为笔记本与省电优化。\n• Lite: 关闭全部模糊，低端设备流畅不卡顿。',
    },
    'guide_scroll_title': {
      'vi': 'Cuộn bật nảy & Bảng chọn dài',
      'en': 'Bouncing Scroll & Dropdown',
      'cn': '弹性滚动与长下拉列表',
    },
    'guide_scroll_desc': {
      'vi':
          'BouncingScrollPhysics mang lại cảm giác cuộn đàn hồi cao cấp. Bảng chọn kính mờ GlassDropdown tự động kích hoạt ô tìm kiếm trực tiếp khi danh sách vượt quá 5 mục.',
      'en':
          'BouncingScrollPhysics delivers premium elastic physics. GlassDropdown automatically embeds a live search box when items exceed 5.',
      'cn':
          'BouncingScrollPhysics 带来高端弹性物理滚动。当列表超过 5 项时，GlassDropdown 自动启用即时搜索输入框。',
    },
    'about_app_name': {
      'vi': 'JA Remote - TE PC Manager',
      'en': 'JA Remote - TE PC Manager',
      'cn': 'JA Remote - TE 机台管理器',
    },
    'about_app_desc': {
      'vi':
          'Hệ thống quản lý máy trạm kiểm tra TE qua mạng LAN: Bật máy từ xa (Wake-on-LAN), giám sát trạng thái Ping tự động, thực thi PowerShell / WinRM / SSH hàng loạt và lưu trữ nhật ký kiểm toán.',
      'en':
          'LAN TE PC remote manager: Wake-on-LAN (WOL), auto ping status monitoring, batch PowerShell / WinRM / SSH command execution, and audit logging.',
      'cn':
          '局域网 TE 机台远程管理系统: 网络唤醒 (WOL)、自动 Ping 状态监控、批量 PowerShell / WinRM / SSH 命令执行与审计日志。',
    },
    'about_dev_title': {
      'vi': 'Thông tin phát triển & Bản quyền',
      'en': 'Development & Licensing',
      'cn': '开发信息与授权',
    },
    'about_sys_title': {
      'vi': 'Môi trường hệ thống & Phần cứng',
      'en': 'System & Hardware Runtime',
      'cn': '系统环境与硬件运行时',
    },
    'lang_changed_msg': {
      'vi': 'Đã chuyển ngôn ngữ: Tiếng Việt',
      'en': 'Language switched: English',
      'cn': '语言已切换: 中文',
    },
    'status_live': {'vi': 'Giám sát LAN', 'en': 'LAN Active', 'cn': '局域网在线'},
    'status_standby': {'vi': 'Sẵn sàng', 'en': 'Standby', 'cn': '待命'},
    'status_devices': {
      'vi': 'Giám sát trạm TE',
      'en': 'Monitoring TE PCs',
      'cn': '监控TE机台',
    },

    // LAN Scanner View
    'scanner_title': {
      'vi': 'QUÉT MẠNG LAN (SUBNET SCANNER)',
      'en': 'LAN SUBNET SCANNER',
      'cn': '局域网网段扫描',
    },
    'scanner_auto_detect': {
      'vi': 'Tự nhận diện dải IP',
      'en': 'Auto Detect LAN',
      'cn': '自动检测局域网',
    },
    'scanner_detected_toast': {
      'vi': 'Đã nhận diện dải LAN vật lý: {subnet}',
      'en': 'Detected physical LAN subnet: {subnet}',
      'cn': '已识别物理局域网段: {subnet}',
    },
    'scanner_subnet_label': {
      'vi': 'Dải mạng Subnet CIDR (VD: 172.21.168.0/24 hoặc 192.168.1.0/24)',
      'en': 'Subnet CIDR Range (e.g. 172.21.168.0/24 or 192.168.1.0/24)',
      'cn': '子网 CIDR 范围 (例如: 172.21.168.0/24 或 192.168.1.0/24)',
    },
    'scanner_adapter_title': {
      'vi': 'CARD MẠNG VẬT LÝ PHÁT HIỆN:',
      'en': 'DETECTED PHYSICAL LAN ADAPTERS:',
      'cn': '已检测到的物理网卡:',
    },
    'scanner_btn_start': {
      'vi': 'Bắt đầu quét',
      'en': 'Start Scan',
      'cn': '开始扫描',
    },
    'scanner_btn_stop': {'vi': 'Dừng quét', 'en': 'Stop Scan', 'cn': '停止扫描'},
    'scanner_results_header': {
      'vi': 'KẾT QUẢ PHÁT HIỆN ({count} thiết bị online)',
      'en': 'DISCOVERED HOSTS ({count} devices online)',
      'cn': '发现结果 ({count} 台在线设备)',
    },
    'scanner_btn_add_all': {
      'vi': 'Thêm tất cả vào danh sách',
      'en': 'Add All to Devices',
      'cn': '全部添加到设备列表',
    },
    'scanner_toast_added_all': {
      'vi': 'Đã thêm {count} máy vào hệ thống!',
      'en': 'Added {count} devices to managed list!',
      'cn': '已添加 {count} 台设备到管理列表！',
    },
    'scanner_empty_scanning': {
      'vi': 'Đang phát hiện các máy tính trong mạng...',
      'en': 'Scanning network for active hosts...',
      'cn': '正在扫描网络中的在线计算机...',
    },
    'scanner_empty_idle': {
      'vi':
          'Chưa có thiết bị nào được quét. Chọn card mạng hoặc nhấn "Bắt đầu quét".',
      'en': 'No devices scanned yet. Select an adapter or click "Start Scan".',
      'cn': '尚未扫描设备。请选择网卡或点击“开始扫描”。',
    },
    'scanner_saved': {'vi': 'Đã lưu ✓', 'en': 'Saved ✓', 'cn': '已保存 ✓'},
    'scanner_btn_add': {'vi': 'Thêm', 'en': 'Add', 'cn': '添加'},
    'scanner_search_hint': {
      'vi': 'Tìm theo IP, Hostname, Tên máy hoặc MAC...',
      'en': 'Search by IP, Hostname, Name, or MAC...',
      'cn': '按 IP、主机名、设备名或 MAC 搜索...',
    },
    'scanner_filter_all': {'vi': 'Tất cả', 'en': 'All', 'cn': '全部'},
    'scanner_filter_unadded': {
      'vi': 'Chưa thêm',
      'en': 'Ready to Add',
      'cn': '未添加',
    },
    'scanner_filter_added': {
      'vi': 'Đã thêm',
      'en': 'Already Added',
      'cn': '已添加',
    },
    'scanner_filter_fast': {
      'vi': 'Nhanh (≤50ms)',
      'en': 'Fast (≤50ms)',
      'cn': '快速响应 (≤50ms)',
    },
    'scanner_select_all': {'vi': 'Chọn tất cả', 'en': 'Select All', 'cn': '全选'},
    'scanner_deselect_all': {
      'vi': 'Bỏ chọn',
      'en': 'Deselect All',
      'cn': '取消全选',
    },
    'scanner_btn_add_selected': {
      'vi': 'Thêm đã chọn ({count})',
      'en': 'Add Selected ({count})',
      'cn': '添加已选 ({count})',
    },
    'scanner_btn_add_unadded': {
      'vi': 'Thêm máy chưa lưu ({count})',
      'en': 'Add Unadded ({count})',
      'cn': '添加未保存机台 ({count})',
    },
    'scanner_showing_count': {
      'vi': 'Hiển thị {shown}/{total}',
      'en': 'Showing {shown}/{total}',
      'cn': '显示 {shown}/{total}',
    },
    'scanner_no_filter_match': {
      'vi': 'Không tìm thấy thiết bị nào khớp với tìm kiếm hoặc bộ lọc.',
      'en': 'No devices match your search or filter criteria.',
      'cn': '未找到符合搜索或筛选条件的设备。',
    },
    'scanner_clear_filter': {
      'vi': 'Xóa bộ lọc',
      'en': 'Clear Filter',
      'cn': '清除筛选',
    },
    'scanner_toast_added_single': {
      'vi': 'Đã thêm {name} ({ip}) vào danh sách quản trị!',
      'en': 'Added {name} ({ip}) to managed list!',
      'cn': '已将 {name} ({ip}) 添加到管理列表！',
    },
    'scanner_toast_added_batch': {
      'vi': 'Đã thêm thành công {count} máy vào hệ thống!',
      'en': 'Successfully added {count} device(s) to managed list!',
      'cn': '已成功添加 {count} 台机台到系统！',
    },
    'scanner_view_table': {
      'vi': 'Bảng nén gọn',
      'en': 'Compact Table',
      'cn': '紧凑表格',
    },
    'scanner_view_grid': {'vi': 'Lưới 2 cột', 'en': '2-Col Grid', 'cn': '双列网格'},
    'scanner_view_list': {
      'vi': 'Danh sách chi tiết',
      'en': 'Detailed List',
      'cn': '详细列表',
    },
    'scanner_toggle_adapters': {
      'vi': 'Card mạng ({count})',
      'en': 'Adapters ({count})',
      'cn': '网卡 ({count})',
    },
    'scanner_col_device': {
      'vi': 'Thiết bị / Hostname',
      'en': 'Device / Hostname',
      'cn': '机台 / 主机名',
    },
    'scanner_col_ip': {'vi': 'Địa chỉ IP', 'en': 'IP Address', 'cn': 'IP 地址'},
    'scanner_col_mac': {
      'vi': 'Địa chỉ MAC',
      'en': 'MAC Address',
      'cn': 'MAC 地址',
    },
    'scanner_col_ping': {'vi': 'Độ trễ', 'en': 'Ping', 'cn': '延迟'},
    'scanner_col_action': {'vi': 'Thao tác', 'en': 'Action', 'cn': '操作'},
    'scanner_resolving_host': {
      'vi': 'Đang dò hostname...',
      'en': 'Resolving hostname...',
      'cn': '正在解析主机名...',
    },
    'scanner_no_hostname': {
      'vi': 'Chưa có hostname',
      'en': 'No hostname',
      'cn': '未获取到主机名',
    },

    // Devices View
    'dev_search_hint': {
      'vi': 'Tìm kiếm theo tên máy, IP, hostname...',
      'en': 'Search by device name, IP, hostname...',
      'cn': '按设备名、IP、主机名搜索...',
    },
    'search_history_title': {
      'vi': 'Lịch sử tìm kiếm gần đây',
      'en': 'Recent search history',
      'cn': '最近搜索历史',
    },
    'search_history_clear': {
      'vi': 'Xóa toàn bộ lịch sử',
      'en': 'Clear all history',
      'cn': '清空全部历史',
    },
    'search_history_empty': {
      'vi': 'Chưa có lịch sử tìm kiếm',
      'en': 'No search history',
      'cn': '暂无搜索历史',
    },
    'search_history_delete_item': {
      'vi': 'Xóa khỏi lịch sử',
      'en': 'Remove from history',
      'cn': '从历史中移除',
    },
    'dev_group_prefix': {'vi': 'Nhóm: ', 'en': 'Group: ', 'cn': '分组: '},
    'dev_filter_all': {'vi': 'Tất cả', 'en': 'All', 'cn': '全部'},
    'dev_filter_online': {'vi': 'Online', 'en': 'Online', 'cn': '在线'},
    'dev_filter_offline': {'vi': 'Offline', 'en': 'Offline', 'cn': '离线'},
    'dev_tooltip_autoping_on': {
      'vi': 'Auto-Ping (10s): ĐANG BẬT',
      'en': 'Auto-Ping (10s): ACTIVE',
      'cn': '自动Ping (10秒): 开启',
    },
    'dev_tooltip_autoping_off': {
      'vi': 'Auto-Ping: ĐÃ TẮT',
      'en': 'Auto-Ping: DISABLED',
      'cn': '自动Ping: 关闭',
    },
    'dev_tooltip_refresh': {
      'vi': 'Quét lại Ping tất cả máy',
      'en': 'Refresh Ping All Devices',
      'cn': '刷新所有设备Ping',
    },
    'dev_btn_add': {'vi': 'Thêm máy', 'en': 'Add Device', 'cn': '添加设备'},
    'dev_btn_export': {'vi': 'Xuất', 'en': 'Export', 'cn': '导出'},
    'dev_btn_import': {'vi': 'Nhập', 'en': 'Import', 'cn': '导入'},
    'dev_export_success': {
      'vi': 'Đã xuất {count} thiết bị ra file JSON thành công!',
      'en': 'Successfully exported {count} devices to JSON!',
      'cn': '成功导出 {count} 台设备到 JSON 文件！',
    },
    'dev_import_title': {
      'vi': 'Nhập cấu hình máy trạm từ JSON',
      'en': 'Import Managed Devices from JSON',
      'cn': '从 JSON 导入设备配置',
    },
    'dev_import_preview_msg': {
      'vi':
          'Phát hiện {count} máy tính, {creds} thông tin đăng nhập và {templates} lệnh mẫu trong file:',
      'en':
          'Found {count} devices, {creds} credentials, and {templates} command templates in file:',
      'cn': '文件中包含 {count} 台设备、{creds} 条凭据和 {templates} 个命令模板:',
    },
    'dev_import_mode_merge': {
      'vi': 'Gộp thêm (Merge)',
      'en': 'Merge (Add/Update)',
      'cn': '合并导入 (追加/更新)',
    },
    'dev_import_mode_overwrite': {
      'vi': 'Ghi đè (Overwrite)',
      'en': 'Overwrite All',
      'cn': '完全覆盖',
    },
    'dev_import_success': {
      'vi': 'Đã nạp {count} thiết bị vào hệ thống!',
      'en': 'Successfully imported {count} devices!',
      'cn': '成功导入 {count} 台设备！',
    },
    'cmd_saved_passwords': {
      'vi': 'Mật khẩu đã lưu gần đây:',
      'en': 'Recent Saved Passwords:',
      'cn': '最近保存的密码:',
    },
    'cmd_no_saved_passwords': {
      'vi': 'Chưa có mật khẩu nào được lưu.',
      'en': 'No saved passwords yet.',
      'cn': '暂无保存的密码。',
    },
    'dev_count_all': {
      'vi': 'Tổng cộng: {count} máy ({online} Online)',
      'en': 'Total: {count} devices ({online} Online)',
      'cn': '总计: {count} 台设备 ({online} 在线)',
    },
    'dev_count_filtered': {
      'vi': 'Đã lọc: {filtered}/{total} máy',
      'en': 'Filtered: {filtered}/{total} devices',
      'cn': '已筛选: {filtered}/{total} 台设备',
    },
    'search_results_count': {
      'vi': '{count} kết quả',
      'en': '{count} results',
      'cn': '{count} 个结果',
    },
    'dev_col_name': {
      'vi': 'TÊN MÁY / HOSTNAME',
      'en': 'DEVICE / HOSTNAME',
      'cn': '设备名 / 主机名',
    },
    'dev_col_ip': {'vi': 'ĐỊA CHỈ IP', 'en': 'IP ADDRESS', 'cn': 'IP 地址'},
    'dev_col_mac': {'vi': 'ĐỊA CHỈ MAC', 'en': 'MAC ADDRESS', 'cn': 'MAC 地址'},
    'dev_col_ping': {'vi': 'PING', 'en': 'PING', 'cn': 'PING'},
    'dev_col_status': {'vi': 'TRẠNG THÁI', 'en': 'STATUS', 'cn': '状态'},
    'dev_col_actions': {'vi': 'TÁC VỤ', 'en': 'ACTIONS', 'cn': '操作'},
    'dev_batch_selected': {
      'vi': 'Đã chọn {count} máy',
      'en': '{count} devices selected',
      'cn': '已选 {count} 台设备',
    },
    'dev_batch_wake': {
      'vi': 'Bật máy (WOL)',
      'en': 'Wake (WOL)',
      'cn': '唤醒 (WOL)',
    },
    'dev_batch_restart': {'vi': 'Khởi động lại', 'en': 'Restart', 'cn': '重启'},
    'dev_batch_shutdown': {'vi': 'Tắt máy', 'en': 'Shutdown', 'cn': '关机'},
    'dev_batch_cmd': {'vi': 'Chạy lệnh', 'en': 'Run Command', 'cn': '运行命令'},
    'dev_batch_deselect': {'vi': 'Bỏ chọn', 'en': 'Deselect', 'cn': '取消选择'},
    'dev_batch_delete': {
      'vi': 'Xóa máy ({count})',
      'en': 'Delete ({count})',
      'cn': '删除 ({count})',
    },
    'dev_batch_delete_title': {
      'vi': 'Xác nhận xóa {count} máy trạm',
      'en': 'Confirm Delete {count} Devices',
      'cn': '确认删除 {count} 台设备',
    },
    'dev_batch_delete_msg': {
      'vi':
          'Bạn có chắc chắn muốn xóa {count} máy trạm đã chọn khỏi danh sách quản lý? Hành động này sẽ xóa cấu hình lưu trữ và không thể hoàn tác.',
      'en':
          'Are you sure you want to delete {count} selected devices from management list? This action will remove stored configurations and cannot be undone.',
      'cn': '您确定要从管理列表中删除选中的 {count} 台设备吗？此操作将移除保存的配置且无法撤销。',
    },
    'dev_batch_delete_confirm_btn': {
      'vi': 'Xác nhận xóa',
      'en': 'Delete Now',
      'cn': '确认删除',
    },
    'dev_batch_delete_success': {
      'vi': 'Đã xóa thành công {count} máy khỏi hệ thống!',
      'en': 'Successfully deleted {count} device(s)!',
      'cn': '已成功删除 {count} 台设备！',
    },
    'dev_batch_change_group': {
      'vi': 'Đổi nhóm',
      'en': 'Change Group',
      'cn': '修改分组',
    },
    'dev_batch_group_title': {
      'vi': 'Đổi nhóm cho {count} máy trạm',
      'en': 'Change Group for {count} Devices',
      'cn': '为 {count} 台设备修改分组',
    },
    'dev_batch_group_hint': {
      'vi': 'Chọn nhóm hoặc nhập tên nhóm mới...',
      'en': 'Select or enter new group name...',
      'cn': '选择或输入新分组名称...',
    },
    'dev_batch_group_confirm_btn': {
      'vi': 'Áp dụng nhóm',
      'en': 'Apply Group',
      'cn': '应用分组',
    },
    'dev_batch_group_success': {
      'vi': 'Đã chuyển {count} máy sang nhóm "{group}"!',
      'en': 'Moved {count} device(s) to group "{group}"!',
      'cn': '已将 {count} 台设备移动到分组 "{group}"！',
    },
    'dev_batch_export_selected': {
      'vi': 'Xuất đã chọn',
      'en': 'Export Selected',
      'cn': '导出已选',
    },

    // Commands View
    'cmd_config_title': {
      'vi': 'CẤU HÌNH LỆNH THỰC THI',
      'en': 'COMMAND CONFIGURATION',
      'cn': '命令执行配置',
    },
    'cmd_target_label': {
      'vi': 'MỤC TIÊU ÁP DỤNG:',
      'en': 'TARGET COMPUTERS:',
      'cn': '目标设备:',
    },
    'cmd_target_selected': {
      'vi': 'Các máy đã chọn ({count} máy)',
      'en': 'Selected devices ({count} PCs)',
      'cn': '已选设备 ({count} 台)',
    },
    'cmd_target_single': {
      'vi': 'Máy cụ thể',
      'en': 'Specific PC',
      'cn': '指定单台设备',
    },
    'cmd_template_label': {
      'vi': 'LỆNH MẪU CÓ SẴN:',
      'en': 'PRESET TEMPLATES:',
      'cn': '预置命令模板:',
    },
    'cmd_protocol_label': {
      'vi': 'PHƯƠNG THỨC KẾT NỐI:',
      'en': 'PROTOCOL:',
      'cn': '连接协议:',
    },
    'cmd_auth_title': {
      'vi': 'XÁC THỰC TÀI KHOẢN TỪ XA (WINRM / SSH):',
      'en': 'REMOTE CREDENTIALS (WINRM / SSH):',
      'cn': '远程认证凭据 (WINRM / SSH):',
    },
    'cmd_auth_user_hint': {
      'vi': 'Tài khoản (VD: Administrator hoặc admin)',
      'en': 'Username (e.g. Administrator or admin)',
      'cn': '用户名 (例如: Administrator 或 admin)',
    },
    'cmd_auth_pass_hint': {
      'vi': 'Mật khẩu máy đích',
      'en': 'Target PC Password',
      'cn': '目标机台密码',
    },
    'cmd_winrm_guide_btn': {
      'vi': 'Hướng dẫn WinRM',
      'en': 'WinRM Guide',
      'cn': 'WinRM 指南',
    },
    'cmd_winrm_guide_title': {
      'vi': 'Cấu hình kết nối WinRM máy đích',
      'en': 'Target PC WinRM Remote Setup Guide',
      'cn': '目标机台 WinRM 远程配置指南',
    },
    'cmd_content_label': {
      'vi': 'NỘI DUNG LỆNH:',
      'en': 'COMMAND SCRIPT:',
      'cn': '命令脚本内容:',
    },
    'cmd_script_toolbar_title': {
      'vi': 'Kịch bản lệnh',
      'en': 'Command Script',
      'cn': '命令脚本',
    },
    'cmd_script_copy': {
      'vi': 'Sao chép lệnh',
      'en': 'Copy script',
      'cn': '复制脚本',
    },
    'cmd_script_copied': {
      'vi': 'Đã sao chép kịch bản lệnh vào clipboard!',
      'en': 'Script copied to clipboard!',
      'cn': '已复制脚本到剪贴板！',
    },
    'cmd_script_clear': {'vi': 'Xóa sạch', 'en': 'Clear', 'cn': '清空'},
    'cmd_script_lines': {
      'vi': '{count} dòng',
      'en': '{count} lines',
      'cn': '{count} 行',
    },
    'cmd_script_hint': {
      'vi': 'Nhập lệnh hoặc kịch bản cần chạy...',
      'en': 'Enter command or script to execute...',
      'cn': '输入需要执行的命令或脚本...',
    },
    'cmd_btn_run': {'vi': 'Chạy lệnh ngay', 'en': 'Execute Now', 'cn': '立即执行'},
    'cmd_btn_running': {
      'vi': 'Đang thực thi lệnh...',
      'en': 'Executing...',
      'cn': '正在执行...',
    },
    'cmd_console_title': {
      'vi': 'BẢNG KẾT QUẢ ĐẦU RA (OUTPUT CONSOLE)',
      'en': 'OUTPUT CONSOLE',
      'cn': '输出控制台',
    },

    // Logs View
    'logs_search_hint': {
      'vi': 'Tìm kiếm nhật ký theo IP, tên máy, tác vụ...',
      'en': 'Search logs by IP, device name, action...',
      'cn': '按IP、设备名、操作搜索日志...',
    },
    'logs_filter_all': {
      'vi': 'Tất cả ({count})',
      'en': 'All ({count})',
      'cn': '全部 ({count})',
    },
    'logs_filter_success': {'vi': 'Thành công', 'en': 'Success', 'cn': '成功'},
    'logs_filter_failed': {'vi': 'Thất bại', 'en': 'Failed', 'cn': '失败'},
    'logs_btn_clear': {'vi': 'Xóa nhật ký', 'en': 'Clear Logs', 'cn': '清空日志'},
    'logs_col_time': {'vi': 'THỜI GIAN', 'en': 'TIME', 'cn': '时间'},
    'logs_col_action': {'vi': 'TÁC VỤ', 'en': 'ACTION', 'cn': '操作'},
    'logs_col_device': {'vi': 'THIẾT BỊ', 'en': 'DEVICE', 'cn': '设备'},
    'logs_col_result': {'vi': 'KẾT QUẢ', 'en': 'RESULT', 'cn': '结果'},
    'logs_col_details': {'vi': 'CHI TIẾT', 'en': 'DETAILS', 'cn': '详情'},
    'logs_empty': {
      'vi': 'Chưa có dữ liệu nhật ký thao tác nào.',
      'en': 'No audit logs recorded yet.',
      'cn': '暂无操作审计日志。',
    },

    // Dialogs & Device Details
    'dialog_close': {'vi': 'Đóng', 'en': 'Close', 'cn': '关闭'},
    'dialog_cancel': {'vi': 'Hủy bỏ', 'en': 'Cancel', 'cn': '取消'},
    'dialog_save': {'vi': 'Lưu thay đổi', 'en': 'Save Changes', 'cn': '保存更改'},
    'dialog_delete': {'vi': 'Xóa máy', 'en': 'Delete PC', 'cn': '删除设备'},
    'dialog_detail_title': {
      'vi': 'Chi tiết thiết bị: {name}',
      'en': 'Device Details: {name}',
      'cn': '设备详情: {name}',
    },
    'dialog_quick_actions': {
      'vi': 'TÁC VỤ NHANH',
      'en': 'QUICK ACTIONS',
      'cn': '快捷操作',
    },
    'dialog_config_info': {
      'vi': 'THÔNG TIN CẤU HÌNH',
      'en': 'CONFIGURATION INFO',
      'cn': '配置信息',
    },
    'dialog_name_label': {
      'vi': 'Tên máy (Display Name)',
      'en': 'Device Name (Display Name)',
      'cn': '设备名称 (显示名称)',
    },
    'dialog_group_label': {
      'vi': 'Nhóm / Line (Group)',
      'en': 'Group / Line',
      'cn': '分组 / 产线',
    },
    'dialog_mac_label': {
      'vi': 'Địa chỉ MAC (Wake-on-LAN)',
      'en': 'MAC Address (Wake-on-LAN)',
      'cn': 'MAC 地址 (网络唤醒)',
    },
    'dialog_user_label': {
      'vi': 'Tài khoản quản trị (Username)',
      'en': 'Admin Username',
      'cn': '管理员用户名',
    },
    'dialog_pass_label': {
      'vi': 'Mật khẩu quản trị (Password)',
      'en': 'Admin Password',
      'cn': '管理员密码',
    },
    'dialog_note_label': {'vi': 'Ghi chú (Note)', 'en': 'Note', 'cn': '备注'},
    'dialog_add_title': {
      'vi': 'Thêm thiết bị quản trị mới',
      'en': 'Add New Managed Device',
      'cn': '添加新管理设备',
    },
    'dialog_add_btn': {'vi': 'Thêm máy', 'en': 'Add Device', 'cn': '添加设备'},
    'dialog_ip_required': {
      'vi': 'Vui lòng nhập địa chỉ IP!',
      'en': 'Please enter IP address!',
      'cn': '请输入 IP 地址！',
    },
    'dialog_ip_label': {
      'vi': 'Địa chỉ IP (Bắt buộc, VD: 172.21.168.10)',
      'en': 'IP Address (Required, e.g. 172.21.168.10)',
      'cn': 'IP 地址 (必填, 例如: 172.21.168.10)',
    },
    'dialog_added_toast': {
      'vi': 'Đã thêm {name} vào hệ thống!',
      'en': 'Added {name} to managed list!',
      'cn': '已添加 {name} 到管理列表！',
    },
    'dialog_saved_toast': {
      'vi': 'Đã lưu cấu hình {name} thành công!',
      'en': 'Successfully updated {name}!',
      'cn': '已成功更新 {name}！',
    },
    'dialog_deleted_toast': {
      'vi': 'Đã xóa {name} khỏi danh sách.',
      'en': 'Removed {name} from list.',
      'cn': '已从列表中删除 {name}。',
    },
    'dialog_confirm_restart_title': {
      'vi': 'Khởi động lại máy?',
      'en': 'Restart Computer?',
      'cn': '确认重启计算机？',
    },
    'dialog_confirm_restart_msg': {
      'vi': 'Bạn có chắc chắn muốn khởi động lại {name} ({ip}) không?',
      'en': 'Are you sure you want to restart {name} ({ip})?',
      'cn': '您确定要重启 {name} ({ip}) 吗？',
    },
    'dialog_confirm_shutdown_title': {
      'vi': 'Tắt máy tính?',
      'en': 'Shutdown Computer?',
      'cn': '确认关闭计算机？',
    },
    'dialog_confirm_shutdown_msg': {
      'vi': 'Bạn có chắc chắn muốn TẮT máy {name} ({ip}) không?',
      'en': 'Are you sure you want to shutdown {name} ({ip})?',
      'cn': '您确定要关闭 {name} ({ip}) 吗？',
    },
    'dialog_sent_restart': {
      'vi': 'Đã gửi lệnh Restart tới {name}.',
      'en': 'Sent Restart command to {name}.',
      'cn': '已向 {name} 发送重启命令。',
    },
    'dialog_sent_shutdown': {
      'vi': 'Đã gửi lệnh Shutdown tới {name}.',
      'en': 'Sent Shutdown command to {name}.',
      'cn': '已向 {name} 发送关机命令。',
    },
    'dialog_wol_sent': {
      'vi': 'Đã gửi Magic Packet tới {name}!',
      'en': 'Sent WOL Magic Packet to {name}!',
      'cn': '已向 {name} 发送网络唤醒包！',
    },
    'dialog_wol_failed': {
      'vi': 'Không thể gửi WOL: thiếu địa chỉ MAC.',
      'en': 'Cannot send WOL: missing MAC address.',
      'cn': '无法发送唤醒包：缺少 MAC 地址。',
    },

    // Terminal / Console
    'terminal_title': {
      'vi': 'Bảng Điều Khiển Lệnh',
      'en': 'Command Terminal',
      'cn': '命令控制台',
    },
    'terminal_clear': {
      'vi': 'Xóa màn hình',
      'en': 'Clear console',
      'cn': '清空控制台',
    },
    'terminal_copy': {
      'vi': 'Sao chép nhật ký',
      'en': 'Copy console log',
      'cn': '复制日志',
    },
    'terminal_copied': {
      'vi': 'Đã sao chép nhật ký vào bộ nhớ tạm',
      'en': 'Terminal log copied to clipboard',
      'cn': '终端日志已复制到剪贴板',
    },
    'terminal_autoscroll': {
      'vi': 'Tự động cuộn',
      'en': 'Auto-scroll',
      'cn': '自动滚动',
    },
    'terminal_prompt_hint': {
      'vi': 'Nhập lệnh thực thi từ xa (gõ help để xem danh sách)...',
      'en': 'Enter remote command (type help for list)...',
      'cn': '输入远程命令 (输入 help 查看列表)...',
    },

    // Command Runner & Terminal Localization
    'cmd_no_device_selected': {
      'vi': 'Chưa có máy nào được chọn trong danh sách!',
      'en': 'No target device selected in the list!',
      'cn': '列表中未选择任何目标机台！',
    },
    'cmd_toast_selected_cred': {
      'vi': 'Đã chọn mật khẩu đã lưu ({username})',
      'en': 'Selected saved credential ({username})',
      'cn': '已选择已保存的凭据 ({username})',
    },
    'terminal_subsystem_init': {
      'vi': 'Đã khởi tạo hệ thống con JA Terminal',
      'en': 'JA Terminal Subsystem Initialized',
      'cn': 'JA 终端子系统已初始化',
    },
    'terminal_welcome_banner': {
      'vi': 'JA Remote Command Console [Bento Glassmorphic Engine]',
      'en': 'JA Remote Command Console [Bento Glassmorphic Engine]',
      'cn': 'JA Remote 命令控制台 [Bento 毛玻璃引擎]',
    },
    'terminal_welcome_desc': {
      'vi':
          'Sẵn sàng nhận lệnh. Chọn thiết bị và nhấn "Chạy lệnh ngay", hoặc gõ lệnh trực tiếp tại dấu nhắc prompt bên dưới.',
      'en':
          'Ready for commands. Select target devices and click "Execute Command Now", or type commands directly at the prompt below.',
      'cn': '就绪待命。选择目标机台并点击“立即执行命令”，或在下方提示符处直接输入命令。',
    },
    'terminal_default_banner': {
      'vi': 'JA Remote Command Console [Phiên bản 1.2.1]',
      'en': 'JA Remote Command Console [Version 1.2.1]',
      'cn': 'JA Remote 命令控制台 [版本 1.2.1]',
    },
    'terminal_default_help_hint': {
      'vi': 'Gõ "help" để xem danh sách các lệnh chẩn đoán và hệ thống.',
      'en': 'Type "help" to view available diagnostic and system commands.',
      'cn': '输入 "help" 查看可用诊断与系统命令。',
    },
    'terminal_no_target_selected': {
      'vi':
          'Chưa có máy nào được chọn để gửi lệnh từ xa. Vui lòng chọn máy ở bảng bên trái.',
      'en':
          'No target PC selected for remote execution. Please select a machine in the left panel.',
      'cn': '尚未选择远程执行目标机台。请在左侧面板中选择机台。',
    },
    'terminal_sending_direct': {
      'vi': 'Đang gửi lệnh trực tiếp tới {count} máy [{protocol}]: {cmd}',
      'en': 'Sending direct command to {count} machine(s) [{protocol}]: {cmd}',
      'cn': '正在向 {count} 台机台直接发送命令 [{protocol}]: {cmd}',
    },
    'terminal_batch_starting': {
      'vi': 'Bắt đầu thực thi lệnh trên {count} máy [{protocol}]...',
      'en': 'Starting command execution on {count} machine(s) [{protocol}]...',
      'cn': '开始在 {count} 台机台上执行命令 [{protocol}]...',
    },
    'terminal_device_success': {
      'vi': 'Thành công ({ms}ms)',
      'en': 'Success ({ms}ms)',
      'cn': '执行成功 ({ms}ms)',
    },
    'terminal_device_failed': {
      'vi': 'Thất bại ({ms}ms)',
      'en': 'Failed ({ms}ms)',
      'cn': '执行失败 ({ms}ms)',
    },
    'terminal_batch_complete': {
      'vi': 'Hoàn tất thực thi: {success}/{total} máy thành công.',
      'en': 'Execution finished: {success}/{total} machine(s) succeeded.',
      'cn': '执行完毕: {success}/{total} 台机台成功。',
    },
    'terminal_direct_complete': {
      'vi': 'Hoàn tất: {success}/{total} máy thành công.',
      'en': 'Completed: {success}/{total} machine(s) succeeded.',
      'cn': '完成: {success}/{total} 台机台成功。',
    },
    'terminal_error_label': {'vi': 'LỖI', 'en': 'ERROR', 'cn': '错误'},
    'terminal_help_header': {
      'vi': 'Các lệnh chẩn đoán & hệ thống khả dụng:',
      'en': 'Available Diagnostic & Shell Commands:',
      'cn': '可用诊断与系统命令:',
    },
    'terminal_help_cmd_help': {
      'vi': 'Hiển thị danh sách các lệnh khả dụng',
      'en': 'Show this list of available commands',
      'cn': '显示可用命令列表',
    },
    'terminal_help_cmd_status': {
      'vi': 'In trạng thái runtime, phân tầng đồ họa & phần cứng',
      'en': 'Print runtime status, graphic tier & hardware specs',
      'cn': '打印运行时状态、图形档位与硬件配置',
    },
    'terminal_help_cmd_ping': {
      'vi': 'Gửi gói ICMP mô phỏng kèm báo cáo độ trễ latency',
      'en': 'Send simulated ICMP echo packets with latency report',
      'cn': '发送模拟 ICMP 响应包及延迟报告',
    },
    'terminal_help_cmd_nodes': {
      'vi': 'Hiển thị bảng các node phần cứng đang kết nối',
      'en': 'Display connected hardware nodes table',
      'cn': '显示已连接硬件节点表格',
    },
    'terminal_help_cmd_theme': {
      'vi': 'Chuyển đổi phân tầng đồ họa hoặc giao diện ("dark" / "light")',
      'en': 'Toggle or set theme ("dark" or "light")',
      'cn': '切换图形档位或主题 ("dark" 或 "light")',
    },
    'terminal_help_cmd_matrix': {
      'vi': 'Mô phỏng luồng mã kỹ thuật số ma trận Cyber',
      'en': 'Simulate digital cyber code stream',
      'cn': '模拟数字矩阵代码流',
    },
    'terminal_help_cmd_echo': {
      'vi': 'In chuỗi ký tự ra màn hình console',
      'en': 'Print text string to console output',
      'cn': '向控制台输出打印文本',
    },
    'terminal_help_cmd_date': {
      'vi': 'Hiển thị ngày giờ hệ thống hiện tại',
      'en': 'Display current system date and timestamp',
      'cn': '显示当前系统日期与时间戳',
    },
    'terminal_help_cmd_version': {
      'vi': 'In phiên bản terminal & ứng dụng',
      'en': 'Print terminal & application version',
      'cn': '打印终端与应用程序版本',
    },
    'terminal_help_cmd_clear': {
      'vi': 'Xóa sạch bộ đệm màn hình terminal',
      'en': 'Wipe clean terminal stream buffer',
      'cn': '清空终端屏幕缓冲区',
    },
    'terminal_cmd_not_found': {
      'vi': 'zsh: không tìm thấy lệnh: {cmd}. Gõ "help" để xem danh sách lệnh.',
      'en':
          'zsh: command not found: {cmd}. Type "help" for a list of commands.',
      'cn': 'zsh: 未找到命令: {cmd}。输入 "help" 查看命令列表。',
    },
    'terminal_current_time': {
      'vi': 'Thời gian hiện tại',
      'en': 'Current Time',
      'cn': '当前时间',
    },
    // Command Runner & Command Templates
    'cmd_template_hint': {
      'vi': 'Chọn kịch bản lệnh mẫu...',
      'en': 'Choose a command template...',
      'cn': '选择命令模板...',
    },
    'cmd_template_save_btn': {
      'vi': 'Lưu mẫu',
      'en': 'Save Template',
      'cn': '保存模板',
    },
    'cmd_template_save_title': {
      'vi': 'Lưu kịch bản lệnh mẫu',
      'en': 'Save Command Template',
      'cn': '保存命令模板',
    },
    'cmd_template_name_label': {
      'vi': 'Tên kịch bản (VD: Xem Uptime hệ thống)',
      'en': 'Template Name (e.g. Check System Uptime)',
      'cn': '模板名称 (例如: 检查系统运行时间)',
    },
    'cmd_template_desc_label': {
      'vi': 'Mô tả tóm tắt chức năng',
      'en': 'Brief Description',
      'cn': '简要描述',
    },
    'cmd_template_platform_label': {
      'vi': 'Nền tảng mục tiêu',
      'en': 'Target Platform',
      'cn': '目标平台',
    },
    'cmd_template_saved_toast': {
      'vi': 'Đã lưu kịch bản "{name}" vào JSON thành công!',
      'en': 'Saved template "{name}" to JSON successfully!',
      'cn': '已成功保存模板 "{name}" 到 JSON！',
    },
    'cmd_template_delete_btn': {
      'vi': 'Xóa mẫu này',
      'en': 'Delete Template',
      'cn': '删除模板',
    },
    'cmd_template_delete_confirm': {
      'vi': 'Bạn có chắc chắn muốn xóa lệnh mẫu "{name}" khỏi file JSON?',
      'en': 'Are you sure you want to delete template "{name}" from JSON?',
      'cn': '确定要从 JSON 中删除模板 "{name}" 吗？',
    },
    'cmd_template_deleted_toast': {
      'vi': 'Đã xóa lệnh mẫu "{name}"!',
      'en': 'Deleted template "{name}"!',
      'cn': '已删除模板 "{name}"！',
    },
    'cmd_template_manage': {
      'vi': 'Tùy chọn kịch bản mẫu',
      'en': 'Template Options',
      'cn': '模板选项',
    },
    'cmd_template_export': {
      'vi': 'Xuất danh sách lệnh mẫu ra JSON',
      'en': 'Export Templates to JSON',
      'cn': '导出模板到 JSON',
    },
    'cmd_template_import': {
      'vi': 'Nhập lệnh mẫu từ file JSON',
      'en': 'Import Templates from JSON',
      'cn': '从 JSON 导入模板',
    },
    'cmd_template_reset': {
      'vi': 'Khôi phục lệnh mẫu mặc định',
      'en': 'Restore Default Templates',
      'cn': '恢复默认模板',
    },
    'cmd_template_reset_confirm': {
      'vi': 'Khôi phục danh sách lệnh mẫu về mặc định ban đầu?',
      'en': 'Restore command template list to initial defaults?',
      'cn': '恢复命令模板列表至初始默认？',
    },
    // Batch File Deploy
    'dev_batch_deploy': {
      'vi': 'Triển khai file',
      'en': 'Deploy File',
      'cn': '文件分发',
    },
    'deploy_tab_title': {
      'vi': 'Triển khai File hàng loạt',
      'en': 'Batch File Deploy',
      'cn': '批量文件部署',
    },
    'deploy_tab_desc': {
      'vi':
          'Sao chép file hoặc thư mục từ máy điều khiển đến nhiều máy đích qua SFTP (Linux) hoặc PowerShell (Windows)',
      'en':
          'Transfer files or folders from controller PC to multiple targets via SFTP (Linux) or PowerShell (Windows)',
      'cn': '通过 SFTP (Linux) 或 PowerShell (Windows) 将文件或文件夹分发至多台目标主机',
    },
    'deploy_targets_title': {
      'vi': 'Thiết bị đích ({count})',
      'en': 'Target Devices ({count})',
      'cn': '目标设备 ({count})',
    },
    'deploy_target_selected_only': {
      'vi': 'Chỉ máy đang chọn ({count})',
      'en': 'Selected devices only ({count})',
      'cn': '仅已选设备 ({count})',
    },
    'deploy_target_all_online': {
      'vi': 'Tất cả máy Online ({count})',
      'en': 'All Online hosts ({count})',
      'cn': '所有在线主机 ({count})',
    },
    'deploy_source_title': {
      'vi': 'Nguồn truyền tải',
      'en': 'Transfer Source',
      'cn': '传输源',
    },
    'deploy_pick_file': {'vi': 'Chọn File', 'en': 'Select File', 'cn': '选择文件'},
    'deploy_pick_folder': {
      'vi': 'Chọn Thư mục',
      'en': 'Select Folder',
      'cn': '选择文件夹',
    },
    'deploy_source_not_selected': {
      'vi': 'Chưa chọn file hoặc thư mục nguồn',
      'en': 'No source file or folder selected',
      'cn': '未选择源文件或文件夹',
    },
    'deploy_dest_title': {
      'vi': 'Thư mục đích trên máy nhận',
      'en': 'Destination Path on Target',
      'cn': '目标接收路径',
    },
    'deploy_dest_hint': {
      'vi': 'Nhập đường dẫn đích (ví dụ: C:\\Temp\\ hoặc /tmp/)',
      'en': 'Enter destination path (e.g. C:\\Temp\\ or /tmp/)',
      'cn': '输入目标路径 (例如 C:\\Temp\\ 或 /tmp/)',
    },
    'deploy_recent_sources': {
      'vi': 'Nguồn gần đây',
      'en': 'Recent Sources',
      'cn': '最近来源',
    },
    'deploy_source_history_title': {
      'vi': 'Lịch sử file/thư mục nguồn',
      'en': 'Recent Sources History',
      'cn': '最近文件/目录历史',
    },
    'deploy_dest_history_title': {
      'vi': 'Lịch sử đường dẫn đích',
      'en': 'Recent Destinations History',
      'cn': '最近目标路径历史',
    },
    'deploy_source_missing': {
      'vi': 'Đường dẫn nguồn không còn tồn tại trên máy này',
      'en': 'Source path no longer exists on this PC',
      'cn': '源路径在此电脑上不存在',
    },
    'deploy_history_clear': {
      'vi': 'Xóa lịch sử',
      'en': 'Clear History',
      'cn': '清空历史',
    },
    'deploy_opt_create_dir': {
      'vi': 'Tự động tạo thư mục đích nếu chưa có',
      'en': 'Auto-create destination directory if missing',
      'cn': '目标目录不存在时自动创建',
    },
    'deploy_opt_overwrite': {
      'vi': 'Ghi đè file nếu đã tồn tại',
      'en': 'Overwrite existing files',
      'cn': '覆盖已存在的文件',
    },
    'deploy_opt_autokill': {
      'vi': 'Tự động tắt/kill tiến trình nếu file/thư mục đang dùng',
      'en': 'Auto-kill locking processes if file/folder in use',
      'cn': '目标文件/文件夹被占用时自动终止进程',
    },
    'deploy_opt_autokill_hint': {
      'vi':
          'Tự động đóng tiến trình đang giữ file đích trước khi thay thế (kể cả khi hệ thống cho phép đổi tên file đang chạy). Có thể mất dữ liệu chưa lưu. Windows từ xa cần WinRM; Linux cần fuser. Không đóng tiến trình được bảo vệ.',
      'en':
          'Automatically terminates processes holding destination files before replacement (even if the OS permits renaming running files). Unsaved data may be lost. Remote Windows requires WinRM; Linux requires fuser. Protected processes are not stopped.',
      'cn':
          '在替换前自动终止占用目标文件的进程（即使系统允许重命名正在运行的文件）。可能丢失未保存的数据。远程 Windows 需要 WinRM，Linux 需要 fuser。不会终止受保护的系统进程。',
    },
    'deploy_auth_title': {
      'vi': 'Tài khoản & Thiết lập mạng',
      'en': 'Authentication & Concurrency',
      'cn': '身份凭据与并发设置',
    },
    'deploy_concurrency': {
      'vi': 'Luồng song song: {count} máy',
      'en': 'Concurrency: {count} hosts',
      'cn': '并发线程: {count} 台',
    },
    'deploy_btn_start': {
      'vi': 'BẮT ĐẦU TRIỂN KHAI FILE',
      'en': 'START FILE DEPLOY',
      'cn': '开始文件分发',
    },
    'deploy_btn_abort': {
      'vi': 'Dừng tiến trình',
      'en': 'Abort Deploy',
      'cn': '终止分发',
    },
    'deploy_btn_retry_failed': {
      'vi': 'Thử lại các máy lỗi ({count})',
      'en': 'Retry Failed ({count})',
      'cn': '重试失败主机 ({count})',
    },
    'deploy_monitor_title': {
      'vi': 'Tiến độ truyền tải thời gian thực',
      'en': 'Realtime Transfer Monitor',
      'cn': '实时传输监控',
    },
    'deploy_stat_total': {
      'vi': 'Tổng số máy',
      'en': 'Total Devices',
      'cn': '总设备数',
    },
    'deploy_stat_completed': {
      'vi': 'Hoàn thành',
      'en': 'Completed',
      'cn': '已完成',
    },
    'deploy_stat_transferring': {
      'vi': 'Đang truyền',
      'en': 'Transferring',
      'cn': '传输中',
    },
    'deploy_stat_failed': {'vi': 'Lỗi', 'en': 'Failed', 'cn': '失败'},
    'deploy_stat_speed': {
      'vi': 'Tốc độ tổng',
      'en': 'Total Speed',
      'cn': '总速率',
    },
    'deploy_terminal_title': {
      'vi': 'Nhật ký sự kiện truyền tải',
      'en': 'Deployment Event Log',
      'cn': '部署事件日志',
    },
    'deploy_no_targets_alert': {
      'vi': 'Vui lòng chọn ít nhất một thiết bị đích để truyền file!',
      'en': 'Please select at least one target device for deployment!',
      'cn': '请至少选择一台目标设备进行文件部署！',
    },
    'deploy_no_source_alert': {
      'vi': 'Vui lòng chọn file hoặc thư mục nguồn!',
      'en': 'Please select a source file or folder!',
      'cn': '请选择源文件或文件夹！',
    },
    'deploy_no_dest_alert': {
      'vi': 'Vui lòng nhập đường dẫn thư mục đích trên máy nhận!',
      'en': 'Please enter the destination path on target devices!',
      'cn': '请输入目标设备上的接收路径！',
    },
    'deploy_status_idle': {'vi': 'Chờ bắt đầu', 'en': 'Idle', 'cn': '空闲'},
    'deploy_status_pending': {
      'vi': 'Đang xếp hàng',
      'en': 'Queued',
      'cn': '排队中',
    },
    'deploy_status_connecting': {
      'vi': 'Đang kết nối...',
      'en': 'Connecting...',
      'cn': '连接中...',
    },
    'deploy_status_transferring': {
      'vi': 'Đang truyền file...',
      'en': 'Transferring...',
      'cn': '传输中...',
    },
    'deploy_status_completed': {
      'vi': 'Thành công',
      'en': 'Completed',
      'cn': '传输完成',
    },
    'deploy_status_failed': {'vi': 'Thất bại', 'en': 'Failed', 'cn': '传输失败'},
    'deploy_status_cancelled': {'vi': 'Đã hủy', 'en': 'Cancelled', 'cn': '已取消'},
    'dev_online_pill': {'vi': 'máy online', 'en': 'hosts online', 'cn': '在线主机'},
    'deploy_auth_user': {'vi': 'Tài khoản', 'en': 'Username', 'cn': '用户名'},
    'deploy_auth_pass': {'vi': 'Mật khẩu', 'en': 'Password', 'cn': '密码'},
    'deploy_threads': {'vi': 'luồng', 'en': 'threads', 'cn': '线程'},
    'deploy_ready_title': {
      'vi': 'Sẵn sàng triển khai file',
      'en': 'Ready for deployment',
      'cn': '准备分发文件',
    },
    'deploy_ready_desc': {
      'vi': 'Chọn file nguồn, thư mục đích và nhấn Bắt đầu triển khai',
      'en':
          'Select source file/folder, target directory, and click Start Deploy',
      'cn': '选择源文件/文件夹、目标目录并点击开始分发',
    },
    'deploy_auth_collapse_hint': {
      'vi': 'Nhấn để thu gọn / mở rộng',
      'en': 'Click to collapse / expand',
      'cn': '点击折叠/展开',
    },
    'deploy_auth_optional': {
      'vi': 'Tùy chọn (dùng tài khoản lưu sẵn nếu để trống)',
      'en': 'Optional (uses saved device credentials if empty)',
      'cn': '选填（留空则使用已保存的主机凭据）',
    },
    'deploy_pick_file_title': {
      'vi': 'Chọn file nguồn để triển khai',
      'en': 'Select source file to deploy',
      'cn': '选择要分发的源文件',
    },
    'deploy_pick_folder_title': {
      'vi': 'Chọn thư mục nguồn để triển khai',
      'en': 'Select source folder to deploy',
      'cn': '选择要分发的源文件夹',
    },
    'deploy_retry_single': {'vi': 'Thử lại', 'en': 'Retry', 'cn': '重试'},
    'port_scanner_title': {
      'vi': 'Chẩn Đoán & Quét Cổng Mạng (TCP Port Diagnostics)',
      'en': 'TCP Port Diagnostics & Scanner',
      'cn': 'TCP 端口诊断与扫描器',
    },
    'port_scanner_desc': {
      'vi':
          'Kiểm tra trạng thái mở/đóng của từng cổng hoặc quét toàn bộ cổng dịch vụ trên thiết bị mạng.',
      'en':
          'Test open/closed status of specific ports or scan all service ports on network devices.',
      'cn': '测试特定端口的开闭状态或扫描网络设备上的全部服务端口。',
    },
    'port_scanner_mode_single': {
      'vi': '1 Cổng (Single)',
      'en': 'Single Port',
      'cn': '单个端口',
    },
    'port_scanner_mode_common': {
      'vi': 'Cổng Phổ Biến (Top 30)',
      'en': 'Common Ports',
      'cn': '常用端口',
    },
    'port_scanner_mode_range': {
      'vi': 'Dải Cổng (Range)',
      'en': 'Port Range',
      'cn': '端口范围',
    },
    'port_scanner_target_host': {
      'vi': 'Địa chỉ IP / Host',
      'en': 'Target IP / Host',
      'cn': '目标 IP / 主机名',
    },
    'port_scanner_port_number': {
      'vi': 'Số cổng (Port)',
      'en': 'Port Number',
      'cn': '端口号',
    },
    'port_scanner_range_from': {
      'vi': 'Từ cổng',
      'en': 'From Port',
      'cn': '起始端口',
    },
    'port_scanner_range_to': {'vi': 'Đến cổng', 'en': 'To Port', 'cn': '结束端口'},
    'port_scanner_btn_scan': {
      'vi': 'Bắt đầu kiểm tra',
      'en': 'Start Scan',
      'cn': '开始扫描',
    },
    'port_scanner_btn_stop': {
      'vi': 'Dừng quét',
      'en': 'Stop Scan',
      'cn': '停止扫描',
    },
    'port_scanner_status_open': {
      'vi': 'ĐANG MỞ (OPEN)',
      'en': 'OPEN',
      'cn': '开放 (OPEN)',
    },
    'port_scanner_status_closed': {
      'vi': 'ĐÓNG (CLOSED)',
      'en': 'CLOSED',
      'cn': '关闭 (CLOSED)',
    },
    'port_scanner_status_timeout': {
      'vi': 'TIMEOUT / CHẶN',
      'en': 'TIMEOUT',
      'cn': '超时 / 过滤',
    },
    'port_scanner_filter_open_only': {
      'vi': 'Chỉ hiện cổng đang mở',
      'en': 'Show open ports only',
      'cn': '仅显示开放端口',
    },
    'port_scanner_open_ports_found': {
      'vi': 'cổng mở',
      'en': 'open ports',
      'cn': '个开放端口',
    },
    'port_scanner_scanned_count': {
      'vi': 'Đã kiểm tra',
      'en': 'Scanned',
      'cn': '已扫描',
    },
    'port_scanner_action_rdp': {
      'vi': 'Mở RDP (mstsc)',
      'en': 'Launch RDP',
      'cn': '打开 RDP',
    },
    'port_scanner_action_ssh': {
      'vi': 'Kết nối SSH',
      'en': 'Connect SSH',
      'cn': '连接 SSH',
    },
    'port_scanner_action_winrm': {
      'vi': 'Mở WinRM',
      'en': 'Open WinRM',
      'cn': '打开 WinRM',
    },
    'port_scanner_action_web': {
      'vi': 'Mở trình duyệt',
      'en': 'Open in Browser',
      'cn': '打开网页',
    },
    'port_scanner_action_smb': {
      'vi': 'Mở chia sẻ file (SMB)',
      'en': 'Open SMB Share',
      'cn': '打开共享 (SMB)',
    },
    'port_scanner_action_copy': {
      'vi': 'Sao chép IP:Port',
      'en': 'Copy IP:Port',
      'cn': '复制 IP:端口',
    },
    'port_scanner_btn_open_dialog': {
      'vi': 'Quét cổng',
      'en': 'Port Scan',
      'cn': '端口扫描',
    },
    'settings_tab_ota': {
      'vi': 'Cập nhật LAN',
      'en': 'LAN Update',
      'cn': '局域网更新',
    },
    'ota_update_title': {
      'vi': 'Cập nhật phần mềm tự động (OTA LAN)',
      'en': 'Automatic LAN OTA Update',
      'cn': '局域网自动更新 (OTA)',
    },
    'ota_update_desc': {
      'vi':
          'Tự động kiểm tra và nâng cấp phiên bản mới qua thư mục chia sẻ mạng LAN',
      'en':
          'Automatically check and upgrade to the latest version via LAN shared folders',
      'cn': '通过局域网共享文件夹自动检查并升级到最新版本',
    },
    'ota_current_version': {
      'vi': 'Phiên bản hiện tại',
      'en': 'Current Version',
      'cn': '当前版本',
    },
    'ota_last_check': {
      'vi': 'Lần kiểm tra cuối',
      'en': 'Last Checked',
      'cn': '上次检查',
    },
    'ota_never_checked': {
      'vi': 'Chưa kiểm tra bao giờ',
      'en': 'Never checked',
      'cn': '从未检查',
    },
    'ota_check_now': {
      'vi': 'Kiểm tra cập nhật ngay',
      'en': 'Check for Updates Now',
      'cn': '立即检查更新',
    },
    'ota_checking': {
      'vi': 'Đang kiểm tra...',
      'en': 'Checking...',
      'cn': '正在检查...',
    },
    'ota_server_path': {
      'vi': 'Đường dẫn thư mục máy chủ (SMB / UNC / Local)',
      'en': 'Server Share Path (SMB / UNC / Local)',
      'cn': '服务器共享路径 (SMB / UNC / 本地)',
    },
    'ota_server_path_hint': {
      'vi': r'Ví dụ: \\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_Remote',
      'en': r'e.g. \\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_Remote',
      'cn': r'例如: \\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_Remote',
    },
    'ota_username': {
      'vi': 'Tài khoản SMB (nếu có)',
      'en': 'SMB Username (optional)',
      'cn': 'SMB 用户名 (可选)',
    },
    'ota_password': {
      'vi': 'Mật khẩu SMB (nếu có)',
      'en': 'SMB Password (optional)',
      'cn': 'SMB 密码 (可选)',
    },
    'ota_interval': {
      'vi': 'Chu kỳ tự động kiểm tra',
      'en': 'Automatic Check Interval',
      'cn': '自动检查周期',
    },
    'ota_interval_daily': {'vi': 'Hàng ngày', 'en': 'Daily', 'cn': '每天'},
    'ota_interval_weekly': {'vi': 'Hàng tuần', 'en': 'Weekly', 'cn': '每周'},
    'ota_interval_monthly': {'vi': 'Hàng tháng', 'en': 'Monthly', 'cn': '每月'},
    'ota_interval_off': {
      'vi': 'Tắt kiểm tra tự động',
      'en': 'Off (Manual only)',
      'cn': '关闭自动检查',
    },
    'ota_test_connection': {
      'vi': 'Kiểm tra kết nối',
      'en': 'Test Connection',
      'cn': '测试连接',
    },
    'ota_testing_connection': {
      'vi': 'Đang kết nối...',
      'en': 'Testing...',
      'cn': '正在连接...',
    },
    'ota_connection_ok': {
      'vi': 'Kết nối máy chủ thành công!',
      'en': 'Server connection successful!',
      'cn': '服务器连接成功！',
    },
    'ota_connection_failed': {
      'vi': 'Không thể kết nối máy chủ',
      'en': 'Cannot connect to server',
      'cn': '无法连接到服务器',
    },
    'ota_open_config_dir': {
      'vi': 'Mở thư mục cấu hình',
      'en': 'Open Config Folder',
      'cn': '打开配置文件目录',
    },
    'ota_package_size': {
      'vi': 'Dung lượng',
      'en': 'Package Size',
      'cn': '文件大小',
    },
    'ota_release_notes': {
      'vi': 'Ghi chú phát hành & Thay đổi',
      'en': 'Release Notes & Changelog',
      'cn': '版本更新日志',
    },
    'ota_downloading': {
      'vi': 'Đang tải bản cập nhật...',
      'en': 'Downloading update...',
      'cn': '正在下载更新...',
    },
    'ota_progress_preparing': {
      'vi': 'Đang chuẩn bị cập nhật...',
      'en': 'Preparing update...',
      'cn': '正在准备更新...',
    },
    'ota_progress_verifying': {
      'vi': 'Đang xác thực gói cập nhật...',
      'en': 'Verifying update package...',
      'cn': '正在验证更新包...',
    },
    'ota_progress_extracting': {
      'vi': 'Đang giải nén và kiểm tra tệp...',
      'en': 'Extracting and checking files...',
      'cn': '正在解压并检查文件...',
    },
    'ota_progress_handoff': {
      'vi': 'Đang chuẩn bị áp dụng cập nhật...',
      'en': 'Preparing to apply update...',
      'cn': '正在准备应用更新...',
    },
    'ota_ready_restart': {
      'vi': 'Đã sẵn sàng! Khởi động lại ngay...',
      'en': 'Ready to apply! Restarting...',
      'cn': '准备就绪！正在重启...',
    },
    'ota_btn_update_now': {
      'vi': 'Cập nhật ngay',
      'en': 'Update Now',
      'cn': '立即更新',
    },
    'ota_btn_later': {'vi': 'Để sau', 'en': 'Later', 'cn': '稍后再说'},
    'ota_up_to_date': {
      'vi': 'Bạn đang sử dụng phiên bản mới nhất.',
      'en': 'You are already on the latest version.',
      'cn': '您当前使用的是最新版本。',
    },
    'ota_update_available': {
      'vi': 'Phát hiện phiên bản mới: {version}',
      'en': 'New version available: {version}',
      'cn': '发现新版本: {version}',
    },
  };
}

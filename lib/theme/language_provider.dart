import 'package:flutter/material.dart';

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
  late AppLanguage _currentLanguage;

  LanguageProvider() {
    // Default to Tiếng Việt per system rules
    _currentLanguage = AppLanguage.vi;
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
  }

  void setLanguage(AppLanguage language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
    }
  }

  /// Localized Tab Labels
  List<String> get tabLabels {
    switch (_currentLanguage) {
      case AppLanguage.vi:
        return const ['Thiết bị', 'Quét LAN', 'Thực thi lệnh', 'Nhật ký'];
      case AppLanguage.en:
        return const ['Devices', 'LAN Scanner', 'Commands', 'Audit Logs'];
      case AppLanguage.cn:
        return const ['设备列表', '局域网扫描', '命令执行', '审计日志'];
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

  static const Map<String, Map<String, String>> _translations = {
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
    'tab_user_guide': {
      'vi': 'Hướng dẫn sử dụng',
      'en': 'User Guide',
      'cn': '使用指南',
    },
    'tab_about': {'vi': 'Giới thiệu', 'en': 'About', 'cn': '关于应用'},
    'guide_shortcuts_title': {
      'vi': 'Phím tắt toàn cục',
      'en': 'Global Shortcuts',
      'cn': '全局快捷键',
    },
    'guide_shortcuts_desc': {
      'vi':
          'Ctrl+1…4: Chuyển tab\nCtrl+K: Mở Command Palette; ↑/↓ chọn, Enter chạy, Esc đóng\nCtrl+,: Mở cài đặt\nCtrl+F: Tìm kiếm ở Thiết bị, Quét LAN, Nhật ký\nCtrl+N: Thêm thiết bị (tab Thiết bị)\nF5: Làm mới Thiết bị / Nhật ký\nCtrl+Shift+A: Chọn thiết bị đang lọc (giữ lựa chọn trước đó)\nCtrl+Shift+D: Bỏ chọn tất cả thiết bị\nCtrl+Enter: Chạy lệnh trên các đích đã chọn trong Command Runner\nF1: Xem phím tắt',
      'en':
          'Ctrl+1…4: Switch tabs\nCtrl+K: Open Command Palette; ↑/↓ select, Enter execute, Esc close\nCtrl+,: Open settings\nCtrl+F: Search Devices, LAN Scanner or Logs\nCtrl+N: Add device (Devices tab)\nF5: Refresh Devices / Logs\nCtrl+Shift+A: Select filtered devices (retain previous selection)\nCtrl+Shift+D: Deselect all devices\nCtrl+Enter: Execute on selected targets in Command Runner\nF1: Show shortcuts',
      'cn':
          'Ctrl+1…4: 切换标签页\nCtrl+K: 打开命令面板；↑/↓选择，Enter 执行，Esc 关闭\nCtrl+,: 打开设置\nCtrl+F: 搜索设备、局域网扫描或日志\nCtrl+N: 添加设备（设备页）\nF5: 刷新设备 / 日志\nCtrl+Shift+A: 选择筛选后的设备（保留之前的选择）\nCtrl+Shift+D: 取消所有设备选择\nCtrl+Enter: 在命令执行页对所选目标执行命令\nF1: 显示快捷键',
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
      'vi': '🌐 Đã chuyển ngôn ngữ: Tiếng Việt',
      'en': '🌐 Language switched: English',
      'cn': '🌐 语言已切换: 中文',
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

    // Devices View
    'dev_search_hint': {
      'vi': 'Tìm kiếm theo tên máy, IP, hostname...',
      'en': 'Search by device name, IP, hostname...',
      'cn': '按设备名、IP、主机名搜索...',
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
          'Phát hiện {count} máy tính và {creds} thông tin đăng nhập trong file:',
      'en': 'Found {count} devices and {creds} credentials in file:',
      'cn': '文件中包含 {count} 台设备和 {creds} 条凭据:',
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
      'vi': 'JA Remote Command Console [Phiên bản 1.2.0]',
      'en': 'JA Remote Command Console [Version 1.2.0]',
      'cn': 'JA Remote 命令控制台 [版本 1.2.0]',
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
  };
}

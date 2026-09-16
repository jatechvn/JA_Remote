<div align="center">

# JA Remote — TE PC Manager

Quản trị máy trạm qua LAN cho nhà xưởng, trạm kiểm thử và văn phòng.

![Version](https://img.shields.io/badge/version-1.2.1-blue) ![Platform](https://img.shields.io/badge/platform-Windows_x64-0078D4) ![Dart](https://img.shields.io/badge/Dart-%3E%3D3.12.2-0175C2) ![License](https://img.shields.io/badge/license-MIT-green)

[Download](https://github.com/jatechvn/JA_Remote/releases) · [User Guide](USERGUIDE.md) · [Changelog](CHANGELOG.md) · [JA-Tech](https://jatechvn.github.io/)

</div>

## Mục lục

- [Tính năng](#tính-năng)
- [Phím tắt](#phím-tắt)
- [Cài đặt và build](#cài-đặt-và-build)
- [Kiến trúc](#kiến-trúc)
- [Cấu hình và dữ liệu](#cấu-hình-và-dữ-liệu)
- [Thay đổi gần đây](#thay-đổi-gần-đây)
- [Tác giả và giấy phép](#tác-giả-và-giấy-phép)

## Tính năng

### Quản lý thiết bị & Chẩn đoán mạng
- **Danh sách theo nhóm:** tìm IP/hostname với lịch sử gợi ý, lọc nhóm và trạng thái, chọn nhiều máy cùng lúc.
- **Ping & Giám sát:** theo dõi online/offline, latency và polling tự động.
- **LAN Scanner:** quét subnet siêu tốc, đọc bảng ARP/MAC, phân giải hostname và tra cứu OUI nhà sản xuất.
- **TCP Port Scanner:** chẩn đoán mở cổng dịch vụ (SSH 22, RDP 3389, HTTP 80, HTTPS 443, WinRM 5985/5986, SMB 445, ADB 5555, v.v.) hoặc dải cổng tùy chọn (1-65535); hỗ trợ mở kết nối nhanh (RDP, C$, Web).

### Điều khiển từ xa & Triển khai tệp
- **Nguồn & Tiện ích:** Wake-on-LAN (WOL), Restart/Shutdown máy trạm từ xa có xác nhận an toàn; mở RDP, C$ và Computer Management.
- **Command Runner:** PowerShell/WinRM hoặc SSH, script mẫu, quản lý tài khoản, chạy hàng loạt trên các đích đã chọn và hiển thị output độc lập từng máy; bảo toàn dữ liệu khi đổi tab.
- **File Deployer đa thiết bị:** phân phối tệp hoặc toàn bộ thư mục đồng loạt tới máy đích Windows (WinRM/SMB) hoặc Linux (SFTP); tự động quét terminate tiến trình chiếm giữ khóa file và đổi tên an toàn memory-mapped file; tự động chuyển sang file `.ps1` tạm thời tránh giới hạn 32.767 ký tự Win32 CLI; tự động thu gọn khối Target Devices khi màn hình nhỏ.
- **Audit Logs:** ghi lại nhật ký tác vụ trong phiên, tìm kiếm và lọc trạng thái thành công/thất bại.

### Giao diện & Trải nghiệm
- **Hiệu ứng kính Liquid Glass:** Native C++ runner với xử lý theme riêng Windows 10/11; hỗ trợ phân tầng phần cứng (Ultra 120 FPS / Balanced 60 FPS / Lite không giật lag).
- **Phím tắt toàn diện:** chuyển 5 tab qua Ctrl+1…5, Command Palette Ctrl+P/Ctrl+K, F5 refresh, Ctrl+Enter thực thi.
- **Con trỏ thông minh:** tự động focus vào ô tìm kiếm hoặc bảng lệnh khi chuyển tab.
- **Đa ngôn ngữ:** giao diện và tài liệu Tiếng Việt / English / 简体中文.

## Phím tắt

| Phím | Thao tác |
|---|---|
| Ctrl+1…5 | Chuyển tab: Thiết bị / Quét LAN / Commands / File Deploy / Nhật ký |
| Ctrl+P / Ctrl+K | Mở Command Palette; ↑/↓ chọn, Enter chạy, Esc đóng |
| Ctrl+F | Tìm kiếm tại Thiết bị, Quét LAN, Nhật ký (kèm lịch sử gợi ý) |
| Ctrl+N | Thêm thiết bị mới (tab Thiết bị) |
| F5 | Refresh Thiết bị / Nhật ký |
| Ctrl+Shift+A / D | Chọn thêm thiết bị đang lọc / Bỏ chọn tất cả |
| Ctrl+Enter | Chạy script trong Command Runner hoặc bắt đầu File Deploy |
| Ctrl+, | Mở cài đặt hệ thống & hiệu ứng kính |
| F1 | Hướng dẫn và tra cứu phím tắt |

Xem [USERGUIDE.md](USERGUIDE.md) để biết thêm chi tiết và cách xử lý sự cố.

## Cài đặt và build

**Portable:** tải ZIP từ Releases (Draft chỉ hiển thị với người có quyền), giải nén toàn bộ rồi chạy `ja_remote.exe`. Không tách EXE khỏi DLL và `data/`.

**Source:** cần Flutter tương thích Dart >=3.12.2 và Visual Studio với workload Desktop development with C++.

```powershell
git clone https://github.com/jatechvn/JA_Remote.git
cd JA_Remote
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows --release
```

EXE: `build/windows/x64/runner/Release/ja_remote.exe`. `build.bat` build nhanh; `debug.bat` chạy EXE với `-debug`. Bản host được đóng gói cho Windows x64.

## Kiến trúc

```text
lib/
  main.dart                 # Khởi tạo providers và ứng dụng
  layout/                   # Dashboard shell, cài đặt, About và User Guide
  features/                 # devices, discovery, command_runner, file_deploy, logs
  services/                 # Quét mạng, remote, file deploy, port scan, nguồn, import/export
  data/models/              # Thiết bị, credential, script, deploy progress và audit log
  data/repositories/        # Lưu thiết bị/tài khoản, lịch sử tìm kiếm, lịch sử deploy, audit
  core/network/             # Ping, ARP, hostname, WOL, port scan service, OUI resolver
  core/process/             # Windows process runner, file unlock script, CLIXML decoder
  theme/                    # Theme và dictionary VI/EN/中文
  widgets/                  # Thành phần kính, terminal, palette, history fields
windows/runner/             # Native C++ runner
  theme_win10.cpp           # Theme Windows 10 tùy chỉnh
  theme_win11.cpp           # Theme Windows 11 tùy chỉnh
  flutter_window.cpp        # Tích hợp cửa sổ và native channel
windows/flutter/           # Tích hợp Flutter và plugin đăng ký
test/                     # Unit/widget/integration regression tests
ABOUT.txt                  # Thông tin phiên bản và tác giả
USERGUIDE.md               # Hướng dẫn vận hành
CHANGELOG.md               # Lịch sử thay đổi
RELEASE_NOTES.md            # Metadata và nội dung GitHub Release
```

## Cấu hình và dữ liệu

`devices.json` và thông tin đăng nhập đã lưu nằm trong thư mục application support Windows, dưới `JA_Remote`; audit logs trong UI chỉ tồn tại theo phiên. Xuất/Nhập cấu hình từ tab Thiết bị. Các file JSON chứa tài khoản cần được bảo vệ và không đưa vào Git hoặc release.

`config_sample.json` chỉ là mẫu tham khảo; không thay thế kho dữ liệu thiết bị của ứng dụng. Gói phát hành loại cấu hình/log cá nhân và thư mục build/staging lồng nhau.

## Thay đổi gần đây

- **v1.2.1:** Nâng cấp hộp thoại chọn thư mục trong File Deployer lên chuẩn Windows Explorer hiện đại (thanh địa chỉ breadcrumb, dán trực tiếp đường dẫn, tìm kiếm nhanh và Quick Access/Favorites); tự động điều hướng `initialDirectory` thông minh và tối ưu hóa null-safety.
- **v1.2.0:** Tính năng File Deployer đa thiết bị (WinRM/SMB/SFTP) với auto-kill tiến trình chiếm file & safe rename; công cụ quét cổng TCP Port Scanner; xử lý triệt để giới hạn dòng lệnh Win32 CLI (`ProcessThe filename or extension is too long`); responsive auto-collapse; ghi nhớ lịch sử tìm kiếm/đường dẫn; con trỏ thông minh.
- **v1.1.0:** Hệ thống phím tắt toàn cục, Command Palette, sửa lỗi Provider/đổi tab/đích thực thi và đồng bộ tài liệu.
- **v1.0.0:** Nền tảng quản lý thiết bị LAN, remote PowerShell/SSH, quét mạng và giao diện kính mờ Liquid Glass.

Chi tiết: [CHANGELOG.md](CHANGELOG.md).

## Tác giả và giấy phép

Johnny — **JA-Tech System** · [Website](https://jatechvn.github.io/) · [Repository](https://github.com/jatechvn/JA_Remote).

Phát hành theo [MIT License](LICENSE), đồng bộ với thông tin giấy phép trong About.

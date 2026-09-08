<div align="center">

# JA Remote — TE PC Manager

Quản trị máy trạm qua LAN cho nhà xưởng, trạm kiểm thử và văn phòng.

![Version](https://img.shields.io/badge/version-1.1.0-blue) ![Platform](https://img.shields.io/badge/platform-Windows_x64-0078D4) ![Dart](https://img.shields.io/badge/Dart-%3E%3D3.12.2-0175C2) ![License](https://img.shields.io/badge/license-MIT-green)

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

### Quản lý thiết bị
- **Danh sách theo nhóm:** tìm IP/hostname, lọc nhóm và trạng thái, chọn nhiều máy.
- **Ping:** theo dõi online/offline, latency và polling tự động.
- **LAN scanner:** quét subnet, đọc ARP/MAC, phân giải hostname và thêm máy tìm thấy.

### Điều khiển từ xa
- **Nguồn:** Wake-on-LAN và tác vụ restart/shutdown có xác nhận.
- **Công cụ Windows:** RDP, C$ và Computer Management.
- **Command Runner:** PowerShell/WinRM hoặc SSH, script mẫu, tài khoản, đích đã chọn và kết quả từng máy.
- **Audit Logs:** tối đa 500 tác vụ trong phiên, tìm kiếm và lọc trạng thái.

### Giao diện và bàn phím
- **Windows:** native runner với xử lý theme riêng Windows 10/11; Flutter dùng Provider.
- **Tùy chỉnh:** theme sáng/tối, Glass Tuning, các mức hiệu ứng và VI/EN/中文.
- **Command Palette:** Ctrl+K, tìm lệnh rồi dùng ↑/↓ và Enter; Esc để đóng.

## Phím tắt

| Phím | Thao tác |
|---|---|
| Ctrl+1…4 | Thiết bị / Quét LAN / Commands / Nhật ký |
| Ctrl+K | Mở palette; ↑/↓ chọn, Enter chạy, Esc đóng |
| Ctrl+F | Tìm kiếm ở Devices, Discovery, Logs |
| Ctrl+N | Thêm thiết bị ở Devices |
| F5 | Refresh Devices / Logs |
| Ctrl+Shift+A / D | Chọn thêm thiết bị đang lọc / bỏ chọn tất cả |
| Ctrl+Enter | Chạy script trong Command Runner |
| Ctrl+, | Cài đặt |
| F1 | Hướng dẫn phím tắt |

Xem [USERGUIDE.md](USERGUIDE.md) để biết phạm vi phím, lựa chọn thiết bị và cách xử lý sự cố.

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

EXE: `build/windows/x64/runner/Release/ja_remote.exe`. `build.bat` build nhanh; `debug.bat` chạy EXE với `-debug`. Bản host được đóng gói cho Windows x64; chưa xác nhận build host Linux/macOS.

## Kiến trúc

```text
lib/
  main.dart                 # Khởi tạo providers và ứng dụng
  layout/                   # Dashboard, cài đặt, About và User Guide
  features/                 # devices, discovery, command_runner, logs
  services/                 # Quét mạng, remote, nguồn, import/export
  data/models/              # Thiết bị, credential, script và audit log
  data/repositories/        # Lưu thiết bị/tài khoản, audit theo phiên
  core/network/             # Ping, ARP, hostname, WOL, subnet
  core/process/             # Windows process và CLIXML
  theme/                    # Theme và dictionary VI/EN/中文
  widgets/                  # Thành phần kính, terminal, palette
windows/runner/             # Native C++ runner
  theme_win10.cpp           # Theme Windows 10 tùy chỉnh
  theme_win11.cpp           # Theme Windows 11 tùy chỉnh
  flutter_window.cpp        # Tích hợp cửa sổ và native channel
windows/flutter/           # Tích hợp Flutter và plugin đăng ký
test/                     # Unit/widget regression tests
ABOUT.txt                  # Thông tin phiên bản và tác giả
USERGUIDE.md               # Hướng dẫn vận hành
CHANGELOG.md               # Lịch sử thay đổi
RELEASE_NOTES.md            # Metadata và nội dung GitHub Release
```

## Cấu hình và dữ liệu

`devices.json` và thông tin đăng nhập đã lưu nằm trong thư mục application support Windows, dưới `JA_Remote`; audit logs trong UI chỉ tồn tại theo phiên. Xuất/Nhập cấu hình từ tab Thiết bị. Các file JSON chứa tài khoản cần được bảo vệ và không đưa vào Git hoặc release.

`config_sample.json` chỉ là mẫu tham khảo; không thay thế kho dữ liệu thiết bị của ứng dụng. Gói phát hành loại cấu hình/log cá nhân và thư mục build/staging lồng nhau.

## Thay đổi gần đây

- **v1.1.0:** phím tắt, keyboard palette, sửa lỗi Provider/đổi tab/đích thực thi và tài liệu đồng bộ.
- **v1.0.0:** nền quản lý thiết bị LAN, remote, quét mạng và giao diện kính.

Chi tiết: [CHANGELOG.md](CHANGELOG.md).

## Tác giả và giấy phép

Johnny — **JA-Tech System** · [Website](https://jatechvn.github.io/) · [Repository](https://github.com/jatechvn/JA_Remote).

Phát hành theo [MIT License](LICENSE), đồng bộ với thông tin giấy phép trong About.

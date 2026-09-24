TAG=v1.3.0
TITLE=JA Remote v1.3.0 — LAN OTA Updates, Zero-Admin Windows Installer & DPAPI Vault
BODY=
## JA Remote v1.3.0 — LAN OTA Updates, Zero-Admin Windows Installer & DPAPI Vault

- **Hệ thống Cập nhật Mạng LAN (LAN Over-The-Air OTA Updates):** Tự động phát hiện và cập nhật ứng dụng từ thư mục chia sẻ mạng SMB/UNC (`\\server\share\...`) với xác thực an toàn; kiểm tra tính toàn vẹn SHA-256 (`certutil`) và cấu trúc gói phát hành; kịch bản bàn giao `apply_update.bat` chạy nền độc lập bảo tồn 100% dữ liệu người dùng (`logs`, `config.json`, `credentials.json`, `devices.json`, `update_config.json`) với cơ chế rollback khi lỗi.
- **Giao diện cập nhật Bento Glass & Tab Cài đặt:** Hộp thoại `GlassUpdateDialog` kính mờ hiển thị version diff, dung lượng, changelog cuộn và thanh tiến trình tải xuống thời gian thực; tích hợp tab "Cập nhật LAN" trong Settings và TopBar OTA Update Badge.
- **Bộ Cài đặt & Gỡ bỏ Chuẩn Windows (Zero-Admin Installer Suite):** Cung cấp `install.bat` cài đặt 1-click vào `%LOCALAPPDATA%\Programs\JA_Remote` không cần quyền Administrator (UAC), tạo shortcut Desktop/Start Menu và đăng ký chính quy trong Control Panel & Windows Settings; đi kèm kịch bản gỡ cài đặt sạch sẽ `uninstall.bat` (staging qua `%TEMP%`) và `uninstall.ps1` có tùy chọn xóa dữ liệu cá nhân (`purge`).
- **Bảo mật Tài khoản (Windows DPAPI Vault):** Mã hóa bảo vệ thông tin xác thực lưu trữ bằng Windows Data Protection API (DPAPI); hỗ trợ cấu hình tài khoản ghi đè riêng cho từng thiết bị (Per-Device Credential Overrides) và biến động trong kịch bản lệnh (`{{host}}`, `{{username}}`, `{{password}}`, `{{device_name}}`).
- **Tối ưu Subnet Scanner & Ping Engine Fallback:** Nâng cấp nhận diện netmask /21 trên Windows và cơ chế TCP port fallback độc lập từng cổng giúp phát hiện máy trạm chính xác hơn.
- **Chuẩn hóa Đóng gói & Kỹ năng `dart-build-pro`:** Cập nhật `build.bat` tự động bung sẵn toàn bộ app và bộ cài vào thư mục `dist/` bên cạnh release ZIP; đồng bộ đặc tả kỹ năng `dart-build-pro` trên toàn bộ 4 agent environments.
- **Đồng bộ tài liệu & Metadata:** Cập nhật đầy đủ `pubspec.yaml`, `constants.dart`, `Runner.rc`, `ABOUT.txt`, `README.md`, `CHANGELOG.md`, `USERGUIDE.md`.

### Cài đặt
- **Cài đặt tiện lợi (Khuyên dùng):** Chạy `install.bat` (hoặc `install.bat /silent`) để cài ứng dụng vào máy trạm không cần quyền Admin.
- **Sử dụng Portable:** Giải nén toàn bộ `JA_Remote_v1.3.0_Windows_x64.zip` và chạy trực tiếp `ja_remote.exe`. Xem `USERGUIDE.md` trong gói.

# CHANGELOG — JA Remote

## [v1.1.0] - 2026-09-08

### Tính năng
- **Phím tắt:** chuyển tab, mở cài đặt, tìm kiếm, thêm máy, refresh và chọn/bỏ chọn thiết bị.
- **Command Runner:** Ctrl+Enter chạy lệnh; bỏ qua key repeat và không chạy batch trùng trong cùng màn hình.
- **Command Palette:** ↑/↓ chọn lệnh, Enter thực thi, xử lý kết quả rỗng và reset lựa chọn sau khi lọc.
- **Hướng dẫn:** F1 và User Guide VI/EN/中文 dùng chung nội dung phím tắt; bổ sung hướng dẫn thiết bị, remote và xử lý sự cố.

### Sửa lỗi
- **Provider:** dùng read trong callback mở palette, tránh assertion do watch ngoài build.
- **Tìm kiếm:** khôi phục nội dung ô tìm thiết bị khi trở lại tab, đồng bộ với bộ lọc còn hiệu lực.
- **Vòng đời:** bỏ qua cập nhật UI của batch command sau khi màn hình bị dispose.
- **Đích thực thi:** không tự chọn máy đầu tiên khi thiết bị đích không còn tồn tại.
- **Debug launcher:** sửa tên EXE mẫu thành ja_remote.exe.

### Phát hành
- Đồng bộ version 1.1.0+2, About, README, USERGUIDE, LICENSE MIT và release notes.
- Gói Windows x64 có một thư mục cha, không kèm dữ liệu vận hành.

## [v1.0.0] - Bản nền trước release

- Quản lý thiết bị LAN, quét subnet, ping, WOL, RDP, WinRM/SSH và tác vụ hàng loạt.
- Provider, giao diện kính Windows 10/11 và giao diện VI/EN/中文.
- Không có Git history tại workspace để xác định ngày phát hành bản nền.

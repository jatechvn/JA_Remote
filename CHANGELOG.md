# CHANGELOG — JA Remote

## [v1.2.0] - 2026-09-15

### 🚀 Tính năng & Nâng cấp lớn
- **Triển khai tệp thông minh (File Deployer - Ctrl+4):**
  - Phân phối file hoặc thư mục đồng loạt tới các thiết bị đích Windows (qua WinRM/PSSession hoặc SMB Admin Share) và Linux (qua SFTP SSH).
  - Bảng điều khiển đa luồng (1–8 workers), thanh tiến trình và tốc độ truyền tải thời gian thực theo từng máy trạm.
  - Tự động ghi nhớ đường dẫn nguồn/đích gần nhất và lịch sử gợi ý thả xuống (`GlassDeployDestField`).
  - Hỗ trợ tùy chọn tạo thư mục cha tự động, ghi đè file và tự động đóng tiến trình đang chiếm giữ khóa file.
- **Chẩn đoán cổng dịch vụ (TCP Port Scanner):**
  - Quét kiểm tra trạng thái mở cổng TCP siêu tốc với preset thông dụng (SSH 22, RDP 3389, HTTP 80, HTTPS 443, WinRM 5985/5986, SMB 445, ADB 5555, v.v.) hoặc dải cổng tùy chỉnh (1–65535).
  - Tùy biến timeout (50ms - 5000ms) và số luồng song song (5–200 workers).
  - Tích hợp phím tắt Command Palette (`Ctrl+P`), nút mạng trên card thiết bị và menu ngữ cảnh; hỗ trợ mở kết nối nhanh (RDP, C$, Web browser).
- **Ghi nhớ lịch sử tìm kiếm & Gợi ý tự động:**
  - Tích hợp `GlassSearchHistoryField` cho ô tìm kiếm ở các tab Thiết bị, Quét LAN và Nhật ký.
  - Tự động lưu tối đa 10 mục tìm kiếm gần nhất, hỗ trợ xóa từng mục hoặc xóa toàn bộ lịch sử.
- **Con trỏ thông minh (Smart Focus Auto-Preparation):**
  - Tự động đặt con trỏ vào ô tìm kiếm khi chuyển sang các tab Thiết bị, Quét LAN, Nhật ký.
  - Tự động đặt con trỏ vào ô soạn thảo lệnh ở Command Runner và ô đường dẫn ở File Deployer.

### 🐛 Sửa lỗi & Tối ưu hóa
- **Khắc phục giới hạn dòng lệnh Windows CLI (`ProcessThe filename or extension is too long`):**
  - Trong `ProcessRunner.runPowerShell`, khi payload kịch bản vượt quá 8.192 ký tự (như khi deploy thư mục gồm nhiều file kèm danh sách Base64), tự động chuyển sang ghi file tạm `.ps1` (UTF-8 kèm BOM) và thực thi qua `-File`, xóa sạch sau khi hoàn tất. Triệt tiêu hoàn toàn lỗi Win32 32.767 ký tự.
- **Mở khóa tệp chiếm giữ & Safe Rename cho Memory-Mapped File:**
  - Tự động quét và terminate các tiến trình chiếm giữ tệp (`Stop-Process -Force` / `taskkill.exe /F /T`) loại trừ các tiến trình hệ thống an toàn.
  - Áp dụng cơ chế an toàn đổi tên (`.jad_old_<guid>`) giúp thay thế các tệp thực thi hoặc thư viện DLL đang được ánh xạ vào bộ nhớ (User-mapped Section) mà không làm ngắt quãng phiên deploy.
- **Responsive Auto-Collapse cho khối Target Devices:**
  - Trong `FileDeployView`, tự động thu gọn Card Target Devices khi chiều cao khả dụng < 720px để nút **Start File Deploy** luôn hiện trọn vẹn trên màn hình; hỗ trợ click thủ công accordion header để mở rộng/thu gọn tùy ý.
- **Bảo toàn dữ liệu soạn thảo khi chuyển tab (Tab Persistence):**
  - Giữ nguyên nội dung lệnh đang gõ dở, script draft và output terminal khi chuyển tab ở Command Runner và File Deployer.

### 📦 Phát hành
- Đồng bộ version 1.2.0+3 trong `pubspec.yaml`, `constants.dart`, `Runner.rc`, `ABOUT.txt`, `config_sample.json`, `USERGUIDE.md`, `README.md`, `RELEASE_NOTES.md`.

---

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

---

## [v1.0.0] - Bản nền trước release

- Quản lý thiết bị LAN, quét subnet, ping, WOL, RDP, WinRM/SSH và tác vụ hàng loạt.
- Provider, giao diện kính Windows 10/11 và giao diện VI/EN/中文.
- Không có Git history tại workspace để xác định ngày phát hành bản nền.

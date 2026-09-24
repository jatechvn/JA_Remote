# CHANGELOG — JA Remote

## [v1.3.0] - 2026-09-24

### 🚀 Tính năng & Nâng cấp lớn
- **Hệ thống Cập nhật Mạng LAN (LAN Over-The-Air OTA Updates):**
  - Tự động phát hiện và tải bản cập nhật từ máy chủ chia sẻ nội bộ SMB/UNC (`\\server\share\...`) với xác thực `net use` ẩn mật khẩu.
  - Bảo mật tuyệt đối: mã hóa thông tin xác thực SMB lưu trữ qua Windows DPAPI, kiểm tra mã băm SHA-256 bằng `certutil`, phòng chống tấn công Zip-Slip và kiểm tra cấu trúc payload (`ja_remote.exe`, `flutter_windows.dll`, `data/`).
  - Kịch bản tự bàn giao cập nhật độc lập `apply_update.bat` chạy nền tách biệt (`detached`), tự động sao lưu bản cũ, nâng cấp nguyên tử bằng Robocopy với quy tắc loại trừ bảo tồn 100% dữ liệu người dùng (`logs`, `config.json`, `credentials.json`, `devices.json`, `update_config.json`, v.v.), tự khôi phục (rollback) khi có sự cố và khởi động lại app mới.
  - Giao diện Bento Frosted Glass `GlassUpdateDialog` hiển thị version diff, dung lượng gói, vùng cuộn Release Notes markdown và thanh tiến trình tải xuống thời gian thực.
  - Thêm tab "Cập nhật LAN" trong hộp thoại Cài đặt (cho phép cấu hình đường dẫn server, credentials, chu kỳ kiểm tra, test kết nối) và huy hiệu thông báo bản mới (TopBar OTA Badge) sinh động trên thanh tiêu đề.
- **Bộ Cài đặt & Gỡ bỏ Chuẩn Windows (Zero-Admin Installer Suite):**
  - `install.bat`: Bộ cài đặt 1-click vào `%LOCALAPPDATA%\Programs\JA_Remote` (Zero-Admin, không cần quyền UAC), kiểm tra ứng dụng đang chạy, tự động sao lưu và bảo tồn dữ liệu người dùng, tạo shortcut Desktop, Start Menu và đăng ký chính quy trong Control Panel & Windows Settings (`Uninstall\JA_Remote`). Hỗ trợ cờ chạy ngầm `/silent` hoặc `/s`.
  - `uninstall.bat` & `uninstall.ps1`: Kịch bản staging wrapper tự sao chép qua `%TEMP%` để xóa sạch toàn bộ thư mục cài đặt mà không bị Windows khóa file batch; bảo vệ chống chạy nhầm trên thư mục portable/source; xác nhận tương tác tùy chọn xóa dữ liệu cá nhân (`purge`); đóng an toàn tiến trình đang chạy và dọn dẹp shortcuts, Run key và Registry.
  - Kiểm thử tự động cách ly trong môi trường sandbox (`test/installer_scripts_test.dart`).
- **Bảo mật Tài khoản & Két thông tin đăng nhập (Windows DPAPI Vault):**
  - Bảo vệ các thông tin xác thực nhạy cảm lưu trữ bằng Windows Data Protection API (DPAPI).
  - Hỗ trợ thiết lập thông tin xác thực ghi đè riêng biệt cho từng thiết bị (Per-Device Credential Overrides) bên cạnh tài khoản mặc định.
  - Bổ sung bộ biến động kịch bản (Dynamic Command Variables): `{{host}}`, `{{username}}`, `{{password}}`, `{{device_name}}`.
- **Tối ưu Subnet Scanner & Ping Engine Fallback:**
  - Cải tiến logic nhận diện netmask qua `netsh` và `ipconfig`, khắc phục hiện tượng quét sót dải IP trên các supernet lớn (như /21).
  - Cơ chế đo đạc TCP fallback độc lập từng cổng giúp phát hiện máy trạm chính xác và thu hồi socket sạch sẽ.

### 🐛 Sửa lỗi & Hoàn thiện
- **Chuẩn hóa Đóng gói & Kỹ năng `dart-build-pro`:**
  - Cập nhật kịch bản `build.bat` tự động copy `install.bat`, `uninstall.bat`, `uninstall.ps1` vào `Release/`, bung sẵn ra `dist/` và đóng gói vào release ZIP.
  - Đồng bộ chuẩn hóa toàn bộ 4 thư mục skill: `.agents/skills/`, `skills/`, `.claude/skills/`, `.codex/skills/`.
- **Đa ngôn ngữ hoàn thiện:** Bổ sung đầy đủ các chuỗi dịch thuật OTA và Installer cho cả 3 ngôn ngữ Tiếng Việt (VI), English (EN) và 中文 (CN).

### 📦 Phát hành
- Đồng bộ version 1.3.0+5 trong `pubspec.yaml`, `constants.dart`, `Runner.rc`, `ABOUT.txt`, `install.bat`, `build.bat`, `USERGUIDE.md`, `README.md`, `RELEASE_NOTES.md`.

---

## [v1.2.1] - 2026-09-16

### 🚀 Nâng cấp & Tối ưu hóa
- **Hộp thoại chọn thư mục chuẩn Windows Explorer hiện đại (Modern Folder Picker):**
  - Nâng cấp `FileDialogHelper.pickDirectory` sử dụng giao diện chuẩn Windows Shell `IFileOpenDialog` (`FOS_PICKFOLDERS`) thông qua reflection, thay thế hoàn toàn hộp thoại cây thư mục cổ điển Win95 (`FolderBrowserDialog`).
  - Hỗ trợ thanh địa chỉ breadcrumb, ô dán trực tiếp đường dẫn, thanh tìm kiếm và cây truy cập nhanh Quick Access/Favorites.
  - Tích hợp điều hướng `initialDirectory` thông minh: tự động trỏ ngay tới thư mục nguồn hiện tại khi mở hộp thoại Chọn File hoặc Chọn Thư mục thay vì phải duyệt lại từ Desktop.
  - Cơ chế dự phòng an toàn (tự động fallback về `FolderBrowserDialog` nếu môi trường Windows bị hạn chế reflection).

### 🐛 Sửa lỗi & Hoàn thiện
- **Tối ưu Null-Safety & Biến toàn cục:**
  - Xử lý triệt để kiểm tra biến nullable cục bộ khi trích xuất đường dẫn thư mục gốc trong `_pickFile` và `_pickFolder`.
  - Thay thế chuỗi phiên bản hardcoded trong `glass_terminal.dart` bằng hằng số `appVersion` tập trung.

### 📦 Phát hành
- Đồng bộ version 1.2.1+4 trong `pubspec.yaml`, `constants.dart`, `Runner.rc`, `ABOUT.txt`, `config_sample.json`, `USERGUIDE.md`, `README.md`, `RELEASE_NOTES.md`.

---

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

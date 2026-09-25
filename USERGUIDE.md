# Hướng dẫn sử dụng JA Remote v1.3.1

## Cài đặt ứng dụng

### 1. Cài đặt 1-Click (Khuyên dùng)
- Chạy file `install.bat` (hoặc mở cmd chạy `install.bat /silent`).
- Ứng dụng sẽ tự động được cài đặt vào `%LOCALAPPDATA%\Programs\JA_Remote` (Zero-Admin, không cần quyền Administrator/UAC).
- Tự động tạo Shortcut trên Desktop (`JA Remote.lnk`) và trong menu Start (`Programs\JA Remote`).
- Đăng ký mục gỡ cài đặt chính quy trong Windows Settings & Control Panel. Khi muốn gỡ bỏ, bạn có thể gỡ từ Control Panel hoặc chạy `uninstall.bat`.

### 2. Sử dụng bản Portable
- Giải nén toàn bộ `JA_Remote_v1.3.1_Windows_x64.zip`, giữ nguyên thư mục `data/` và các DLL cạnh `ja_remote.exe`, rồi chạy trực tiếp `ja_remote.exe`.
- Chạy `debug.bat` khi cần bật chế độ debug ghi log chẩn đoán và hiển thị badge thời gian build. Bản phát hành dành cho Windows x64.

## Thiết bị và quét LAN

1. Nhấn **Ctrl+N** ở tab Thiết bị để thêm máy với IP/hostname, tên, nhóm và MAC nếu dùng WOL.
2. Hoặc nhấn **Ctrl+2**, kiểm tra subnet trước khi bắt đầu quét rồi thêm các máy tìm thấy.
3. Dùng **Ctrl+F** để tìm kiếm; bộ lọc nhóm và trạng thái giúp thu hẹp danh sách. Ô tìm kiếm tự động ghi nhớ và gợi ý lịch sử truy vấn trước đó.
4. Con trỏ soạn thảo luôn tự động sẵn sàng tại ô tìm kiếm khi chuyển sang các tab Thiết bị, Quét LAN hoặc Nhật ký.
5. Chọn checkbox của các máy cần thao tác; kiểm tra số lượng và danh sách đích trước tác vụ hàng loạt. **Ctrl+Shift+A** cộng thêm các máy đang lọc vào lựa chọn trước đó, không loại các máy đã chọn đang bị ẩn.
6. **F5** cập nhật Ping; có thể tạm dừng Auto-Ping bằng nút trên thanh công cụ.

## Remote và thực thi lệnh

- **RDP, C$ và Computer Management:** mở các công cụ quản trị Windows tương ứng.
- **WOL:** cần MAC hợp lệ và cấu hình BIOS/NIC cho phép Wake-on-LAN.
- **Command Runner (Ctrl+3):** chọn máy, chọn PowerShell/WinRM hoặc SSH; nhập tài khoản, xem lại script rồi nhấn **Ctrl+Enter** để chạy ngay trên các đích đã chọn. Con trỏ tự động sẵn sàng tại ô nhập lệnh.
- Khởi động lại/tắt máy dùng hộp thoại xác nhận của thao tác tương ứng.
- Chuyển tab khi lệnh đang chạy không hủy tác vụ đã gửi đến máy đích, toàn bộ nội dung lệnh gõ dở và lịch sử output được bảo toàn trọn vẹn.

## Triển khai tệp đa thiết bị (File Deployer - Ctrl+4)

1. **Chọn nguồn:** Bấm *Chọn File* hoặc *Chọn Thư mục* để chọn tệp/gói cập nhật cần phân phối. Hộp thoại chọn thư mục đã được nâng cấp lên chuẩn Windows Explorer hiện đại (hỗ trợ thanh địa chỉ breadcrumb, dán đường dẫn trực tiếp, Quick Access và tự động mở đúng thư mục nguồn hiện tại). App hỗ trợ tự động ghi nhớ các đường dẫn nguồn gần nhất.
2. **Chọn đích:** Nhập đường dẫn đích trên máy từ xa (ví dụ `C:\Temp\Deploy` hoặc `/tmp/deploy/`) hoặc chọn từ các nút Preset / lịch sử gợi ý.
3. **Tùy chọn nâng cao:**
   - *Tạo thư mục nếu chưa có:* Tự động tạo cây thư mục đích nếu máy từ xa chưa tồn tại.
   - *Ghi đè file nếu đã tồn tại:* Cho phép ghi đè phiên bản mới.
   - *Tự động đóng file/tiến trình đang chạy:* Tự động truy vấn Windows Restart Manager (`rstrtmgr.dll`) trước khi đổi tên/di chuyển, đóng chính xác tiến trình giữ file đích sắp thay thế; tuyệt đối không kill theo thư mục; hỗ trợ bounded micro-retry 3 lần và bảo toàn rollback khôi phục backup hoặc dọn partial file.
4. **Hỗ trợ thư mục lớn:** Hệ thống tự động chuyển giao thức kịch bản sang file UTF-8 BOM tạm thời khi khối lượng danh sách file lớn, triệt tiêu hoàn toàn giới hạn 32.767 ký tự của dòng lệnh Windows (`ProcessThe filename or extension is too long`).
5. **Giao diện tự động thích ứng (Responsive Auto-Collapse):** Khi màn hình có chiều cao hạn chế (< 720px), khối *Target Devices* tự động thu gọn để đảm bảo nút **Start File Deploy** luôn hiện rõ trong tầm nhìn; người dùng có thể click vào thanh tiêu đề để mở rộng/thu gọn thủ công bất cứ lúc nào.

## Quét cổng mạng (TCP Port Scanner)

1. **Khởi chạy:** Nhấn **Ctrl+P** hoặc **Ctrl+K** để mở Command Palette rồi gõ *Scan Ports*, hoặc bấm vào biểu tượng mạng trên thẻ thiết bị, hoặc chọn *Quét cổng (Port Scanner)* trong menu ngữ cảnh.
2. **Chế độ quét:**
   - *Cổng thông dụng (Presets):* Quét nhanh các cổng dịch vụ tiêu chuẩn: SSH (22), RDP (3389), Web HTTP/HTTPS (80, 443), WinRM (5985, 5986), SMB (445), ADB (5555), FTP (21), Telnet (23), Database (3306, 6379), VNC (5900).
   - *Dải cổng tùy chọn (Custom Range):* Nhập cổng bắt đầu và kết thúc (từ 1 đến 65535).
3. **Cấu hình hiệu năng:** Cho phép điều chỉnh Timeout (50ms - 5000ms) và Số luồng đồng thời (Concurrency từ 5 đến 200 workers) để quét siêu tốc trong mạng LAN.
4. **Hành động nhanh từ kết quả:** Bấm trực tiếp vào các nút thao tác nhanh bên cạnh cổng mở:
   - Cổng 3389: Mở ngay Remote Desktop (RDP).
   - Cổng 445: Mở ngay chia sẻ mạng Windows Explorer (`\\IP\c$`).
   - Cổng 80/443: Mở trang Web quản trị trên trình duyệt mặc định.
   - Cổng 22: Mở phiên SSH terminal.

## Cập nhật ứng dụng qua mạng LAN (LAN OTA Update)

1. **Cấu hình máy chủ cập nhật:**
   - Nhấn **Ctrl+,** để mở Cài đặt và chuyển sang tab **Cập nhật LAN**.
   - Nhập đường dẫn thư mục chia sẻ nội bộ SMB/UNC (ví dụ `\\172.21.168.10\share\JA_Remote` hoặc đường dẫn ổ đĩa mạng).
   - Nếu máy chủ yêu cầu xác thực, nhập Tên đăng nhập và Mật khẩu (thông tin mật khẩu được bảo vệ an toàn bằng két mã hóa Windows DPAPI Vault).
   - Chọn Chu kỳ kiểm tra tự động: Khởi động, 1 giờ, 6 giờ, 12 giờ, 24 giờ, hoặc Tắt.
   - Bấm **Kiểm tra kết nối** để xác nhận quyền truy cập máy chủ.
2. **Kiểm tra & Cập nhật:**
   - Bấm **Kiểm tra bản cập nhật ngay** để quét bản mới nhất lập tức.
   - Khi có phiên bản mới, biểu tượng huy hiệu (Badge) màu xanh ngọc sẽ xuất hiện ở góc trên thanh công cụ TopBar. Bấm vào huy hiệu để mở hộp thoại Bento `GlassUpdateDialog`.
   - Xem Release Notes, dung lượng gói và bấm **Cập nhật ngay**. Quá trình tải xuống và giải nén được xử lý tự động với tiến trình thời gian thực.
   - Kịch bản `apply_update.bat` sẽ tự động sao lưu phiên bản cũ và nâng cấp an toàn bằng Robocopy, bảo tồn 100% các file cấu hình `config.json`, `credentials.json`, `devices.json`, `logs/`.

## Phím tắt toàn cục

- **Ctrl+1…5:** Chuyển nhanh 5 tab (Thiết bị, Quét LAN, Commands, File Deploy, Nhật ký).
- **Ctrl+P / Ctrl+K:** Mở Command Palette & Công cụ chẩn đoán nhanh; ↑/↓ chọn, Enter chạy, Esc đóng.
- **Ctrl+,:** Mở cài đặt hệ thống & hiệu ứng kính.
- **Ctrl+F:** Tìm kiếm ở Thiết bị, Quét LAN, Nhật ký (kèm lịch sử gợi ý).
- **Ctrl+N:** Thêm thiết bị (tab Thiết bị).
- **F5:** Làm mới Thiết bị / Nhật ký.
- **Ctrl+Shift+A:** Chọn thêm thiết bị đang lọc (giữ lựa chọn trước đó).
- **Ctrl+Shift+D:** Bỏ chọn tất cả thiết bị.
- **Ctrl+Enter:** Chạy lệnh trong Command Runner hoặc kích hoạt Start File Deploy.
- **F1:** Xem bảng tra cứu phím tắt.

Phím theo tab chỉ áp dụng trong màn hình tương ứng; Ctrl+A/C/V trong ô nhập vẫn phục vụ soạn thảo bình thường.

## Cài đặt và dữ liệu

**Ctrl+,** mở Cài đặt gồm: Tinh chỉnh hiệu ứng kính (Glass Tuning), Cập nhật LAN (OTA Updates), Quản lý OUI nhà sản xuất MAC, Hướng dẫn sử dụng và About. Ngôn ngữ giao diện hỗ trợ Việt/Anh/Trung. F1 và User Guide trong app hiển thị cùng danh sách phím tắt và tài liệu hướng dẫn.

Danh sách thiết bị và thông tin đăng nhập đã lưu nằm trong thư mục application support của Windows (`JA_Remote`). Các thông tin nhạy cảm (mật khẩu máy trạm, token và SMB credentials) được mã hóa tại chỗ bằng két bảo mật **Windows Data Protection API (DPAPI)**. Người dùng có thể thiết lập tài khoản đăng nhập ghi đè riêng cho từng thiết bị và chèn biến động `{{host}}`, `{{username}}`, `{{password}}` trong script kịch bản. Nhật ký tác vụ giữ tối đa 500 mục trong bộ nhớ của phiên hiện tại.

Dùng Xuất/Nhập ở tab Thiết bị để sao lưu/khôi phục cấu hình. Kiểm tra nội dung file xuất trước khi chia sẻ. Gói release không chứa thiết bị, tài khoản, cấu hình hoặc log cá nhân.

## Xử lý sự cố

- **Offline:** kiểm tra IP/subnet, kết nối LAN, ICMP firewall; Ping thất bại không luôn đồng nghĩa máy đã tắt — hãy dùng tính năng **Quét cổng (Port Scanner)** để kiểm tra xem cổng 3389 (RDP) hoặc 5985 (WinRM) có đang phản hồi không.
- **Lệnh thất bại:** kiểm tra tài khoản, quyền và dịch vụ WinRM/SSH ở máy đích.
- **Lỗi file đang bị chiếm giữ:** kích hoạt tùy chọn *Tự động đóng file/tiến trình đang chạy* trong File Deployer để app tự giải phóng khóa tiến trình trước khi ghi đè.
- **Thiếu DLL khi chạy:** giải nén toàn bộ ZIP; nếu thiếu Microsoft Visual C++ runtime, cài runtime x64 theo yêu cầu hệ thống.
- **Palette:** Ctrl+P hoặc Ctrl+K, nhập từ khóa, ↑/↓, Enter. Esc đóng mà không chạy lệnh.

Website: https://jatechvn.github.io/ · Repository: https://github.com/jatechvn/JA_Remote

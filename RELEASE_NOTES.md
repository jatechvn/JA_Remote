TAG=v1.2.0
TITLE=JA Remote v1.2.0 — File Deployer, TCP Port Scanner & Smart UX
BODY=
## JA Remote v1.2.0 — File Deployer, TCP Port Scanner & Smart UX

- **File Deployer đa thiết bị (Ctrl+4):** phân phối tệp/thư mục đồng loạt tới máy đích Windows (WinRM/SMB) hoặc Linux (SFTP); tự động quét & terminate tiến trình chiếm giữ khóa file; đổi tên an toàn memory-mapped file; hỗ trợ truyền tải đa luồng thời gian thực.
- **TCP Port Scanner:** công cụ chẩn đoán cổng mở siêu tốc tích hợp Command Palette (Ctrl+P) hoặc menu thiết bị; hỗ trợ preset dịch vụ chuẩn (SSH, RDP, HTTP/HTTPS, WinRM, SMB, ADB, v.v.) hoặc dải cổng tùy chỉnh; mở kết nối nhanh (RDP, C$, Web).
- **Khắc phục lỗi dòng lệnh Windows CLI:** tự động chuyển đổi sang script `.ps1` tạm thời UTF-8 BOM khi payload lớn, triệt tiêu hoàn toàn lỗi Win32 `ProcessThe filename or extension is too long` (32.767 ký tự).
- **Responsive Auto-Collapse:** tự động thu gọn Card Target Devices trên màn hình nhỏ (<720px) giúp nút Start File Deploy luôn nằm trọn vẹn trong tầm nhìn; hỗ trợ accordion header đóng/mở thủ công linh hoạt.
- **Smart Focus & Lịch sử tìm kiếm:** tự động focus con trỏ vào ô tìm kiếm hoặc bảng lệnh khi chuyển tab; ghi nhớ và gợi ý lịch sử truy vấn và đường dẫn deploy gần nhất.
- **Bảo toàn dữ liệu chuyển tab (Tab Persistence):** giữ nguyên nội dung lệnh gõ dở, script draft và output terminal khi chuyển đổi qua lại giữa các tab.
- **Đồng bộ tài liệu:** cập nhật About, User Guide VI/EN/中文, README, USERGUIDE.md, CHANGELOG.md và ABOUT.txt.

### Cài đặt
Giải nén toàn bộ JA_Remote_v1.2.0_Windows_x64.zip và chạy ja_remote.exe. Xem USERGUIDE.md trong gói.

# Hướng dẫn sử dụng JA Remote v1.1.0

## Cài đặt portable

Giải nén toàn bộ `JA_Remote_v1.1.0_Windows_x64.zip`, giữ nguyên thư mục `data/` và các DLL cạnh `ja_remote.exe`, rồi chạy EXE. Chạy `debug.bat` khi cần ghi log chẩn đoán. Bản phát hành dành cho Windows x64.

## Thiết bị và quét LAN

1. Nhấn Ctrl+N ở tab Thiết bị để thêm máy với IP/hostname, tên, nhóm và MAC nếu dùng WOL.
2. Hoặc nhấn Ctrl+2, kiểm tra subnet trước khi bắt đầu quét rồi thêm các máy tìm thấy.
3. Dùng Ctrl+F để tìm kiếm; bộ lọc nhóm và trạng thái giúp thu hẹp danh sách.
4. Chọn checkbox của các máy cần thao tác; kiểm tra số lượng và danh sách đích trước tác vụ hàng loạt. Ctrl+Shift+A cộng thêm các máy đang lọc vào lựa chọn trước đó, không loại các máy đã chọn đang bị ẩn.
5. F5 cập nhật Ping; có thể tạm dừng Auto-Ping bằng nút trên thanh công cụ.

## Remote và thực thi lệnh

- RDP, C$ và Computer Management mở các công cụ quản trị Windows tương ứng.
- WOL cần MAC hợp lệ và cấu hình BIOS/NIC cho phép Wake-on-LAN.
- Chọn máy, nhấn Ctrl+3, chọn PowerShell/WinRM hoặc SSH; nhập tài khoản, xem lại script rồi nhấn Ctrl+Enter để chạy ngay trên các đích đã chọn.
- Khởi động lại/tắt máy dùng hộp thoại xác nhận của thao tác tương ứng.
- Chuyển tab khi lệnh đang chạy không hủy tác vụ đã gửi đến máy đích.

## Phím tắt

- Ctrl+1…4: Chuyển tab
- Ctrl+K: Mở Command Palette; ↑/↓ chọn, Enter chạy, Esc đóng
- Ctrl+,: Mở cài đặt
- Ctrl+F: Tìm kiếm ở Thiết bị, Quét LAN, Nhật ký
- Ctrl+N: Thêm thiết bị (tab Thiết bị)
- F5: Làm mới Thiết bị / Nhật ký
- Ctrl+Shift+A: Chọn thiết bị đang lọc (giữ lựa chọn trước đó)
- Ctrl+Shift+D: Bỏ chọn tất cả thiết bị
- Ctrl+Enter: Chạy lệnh trên các đích đã chọn trong Command Runner
- F1: Xem phím tắt

Phím theo tab chỉ áp dụng trong màn hình tương ứng; Ctrl+A/C/V trong ô nhập vẫn phục vụ soạn thảo. Nhấn Tab/Shift+Tab để đi qua các điều khiển hỗ trợ focus.

## Cài đặt và dữ liệu

Ctrl+, mở Cài đặt gồm Glass Tuning, Hướng dẫn sử dụng và About. Ngôn ngữ giao diện hỗ trợ Việt/Anh/Trung. F1 và User Guide trong app hiển thị cùng danh sách phím tắt.

Danh sách thiết bị và thông tin đăng nhập đã lưu nằm trong thư mục application support của Windows, thư mục con `JA_Remote`. Thông tin đăng nhập được lưu bằng JSON; bảo vệ quyền truy cập tài khoản Windows và không chia sẻ các tệp này. Nhật ký tác vụ giữ tối đa 500 mục trong bộ nhớ của phiên hiện tại. Log chẩn đoán không thay thế cơ chế lưu audit dài hạn.

Dùng Xuất/Nhập ở tab Thiết bị để sao lưu/khôi phục cấu hình. Kiểm tra nội dung file xuất trước khi chia sẻ. Gói release không chứa thiết bị, tài khoản, cấu hình hoặc log cá nhân.

## Xử lý sự cố

- **Offline:** kiểm tra IP/subnet, kết nối LAN, ICMP firewall; Ping thất bại không luôn đồng nghĩa máy đã tắt.
- **Lệnh thất bại:** kiểm tra tài khoản, quyền và dịch vụ WinRM/SSH ở máy đích.
- **Không có đích:** chọn lại thiết bị; Command Runner không tự chuyển sang máy đầu tiên khi đích đã bị xóa.
- **Thiếu DLL khi chạy:** giải nén toàn bộ ZIP; nếu thiếu Microsoft Visual C++ runtime, cài runtime x64 theo yêu cầu hệ thống.
- **Palette:** Ctrl+K, nhập từ khóa, ↑/↓, Enter. Esc đóng mà không chạy lệnh.

Website: https://jatechvn.github.io/ · Repository: https://github.com/jatechvn/JA_Remote

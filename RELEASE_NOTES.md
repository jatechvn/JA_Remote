TAG=v1.4.0
TITLE=JA Remote v1.4.0 — 4-Tier Power Optimizer, 4-Layer WoL Inspector & Smart IP Drift Auditor
BODY=
## JA Remote v1.4.0 — 4-Tier Power Optimizer, 4-Layer WoL Inspector & Smart IP Drift Auditor

- **Bộ tối ưu năng lượng 4 tầng & Chế độ ngủ rảnh tay (4-Tier Power Optimizer):** Tích hợp `AppPowerManager` quản lý 4 trạng thái cửa sổ (Active, Inactive, Unfocused, Hidden/Minimized) kết hợp chế độ Idle Sleep Mode (12s/30s/60s) tự động ngắt render loop, giảm thiểu tối đa mức tiêu thụ CPU & GPU trên máy trạm Windows Desktop.
- **Trình chẩn đoán & Tối ưu Wake-on-LAN 4 tầng (4-Layer WoL Inspector & Auto-Fix):** Kiểm tra toàn diện BIOS/ACPI, Driver NIC & EEE, tính bền vững reboot/shutdown và Fast Startup; tự động sửa qua UAC, WinRM an toàn không rớt mạng hoặc SSH + sudo offline cho Linux.
- **Trình rà soát lệch IP & Xung đột MAC (Smart IP Drift & MAC Conflict Auditor):** Tự động phát hiện máy trạm đổi IP (DHCP drift) hoặc trùng MAC qua ICMP Ping, ARP cache, RDP X.509 CN và NetBIOS; hỗ trợ cập nhật IP 1-click.
- **Native Windows Title & PE Metadata:** Đảm bảo cửa sổ mang tên chính quy trên Taskbar và khay chuyển Alt+Tab.
- **Tái cấu trúc module giao diện Cài đặt:** Tách nhỏ module cài đặt thành các part files trực quan, nâng cao tính bảo trì.
- **Đồng bộ tài liệu & Metadata:** Cập nhật phiên bản 1.4.0+8 trên toàn bộ hệ thống (Runner.rc, pubspec.yaml, constants.dart, ABOUT.txt, config_sample.json, install.bat, build.bat, USERGUIDE.md, README.md).

### Cài đặt
- **Cài đặt tiện lợi (Khuyên dùng):** Chạy `install.bat` (hoặc `install.bat /silent`) để cài ứng dụng vào máy trạm không cần quyền Admin.
- **Sử dụng Portable:** Giải nén toàn bộ `JA_Remote_v1.4.0_Windows_x64.zip` và chạy trực tiếp `ja_remote.exe`. Xem `USERGUIDE.md` trong gói.

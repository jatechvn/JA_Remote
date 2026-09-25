TAG=v1.3.1
TITLE=JA Remote v1.3.1 — Preflight Manifest Unlock, Scoped Process Termination & Bounded Retry
BODY=
## JA Remote v1.3.1 — Preflight Manifest Unlock, Scoped Process Termination & Bounded Retry

- **Preflight Manifest Unlock cho File Deploy:** Tự động truy vấn Windows Restart Manager (`rstrtmgr.dll`) trên các file đích trong gói deploy (cả local và remote WinRM) trước khi đổi tên hoặc di chuyển bất kỳ file nào.
- **Dừng chính xác tiến trình giữ file:** Chỉ đóng các tiến trình được xác minh giữ đúng file đích sắp thay thế, giải quyết triệt để lỗi khóa file tài nguyên (`IOException: The process cannot access the file because it is being used by another process`).
- **Không kill theo thư mục:** Tuyệt đối không dừng ứng dụng theo prefix thư mục hoặc tên tiến trình; bảo vệ nguyên vẹn các ứng dụng khác đang chạy cùng thư mục đích.
- **Xác thực định danh & Chống PID Reuse:** Deduplicate danh sách lock holder theo `(PID, StartTime)`, kiểm tra thời điểm khởi động StartTime chống race condition tái sử dụng PID.
- **Bảo vệ hệ thống tối đa:** Kiểm tra không phân biệt hoa thường và bảo vệ tuyệt đối các tiến trình `ja_remote`, `wsmprovhost`, `explorer` và dịch vụ hệ thống quan trọng.
- **Bounded Micro-Retry:** Giới hạn tối đa 3 lần copy với exponential backoff (300ms rồi 600ms) trên các lỗi sharing/lock violation đã phân loại (`0x80070020`, `0x80070021`, Win32 32/33, `NewItemIOError`).
- **Bảo toàn Rollback & Dọn file dở dang:** Khôi phục file gốc từ backup nếu copy thất bại; tự động dọn sạch partial file nếu đích là file mới; từ chối path traversal (`..`, `:`) và deploy trùng file nguồn.
- **Cập nhật chia sẻ LAN OTA:** Đồng bộ và cập nhật gói cài đặt lên thư mục mạng `\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update`.

### Cài đặt
- **Cài đặt tiện lợi (Khuyên dùng):** Chạy `install.bat` (hoặc `install.bat /silent`) để cài ứng dụng vào máy trạm không cần quyền Admin.
- **Sử dụng Portable:** Giải nén toàn bộ `JA_Remote_v1.3.1_Windows_x64.zip` và chạy trực tiếp `ja_remote.exe`. Xem `USERGUIDE.md` trong gói.

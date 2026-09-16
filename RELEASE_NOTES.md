TAG=v1.2.1
TITLE=JA Remote v1.2.1 — Modern Folder Picker & Explorer Breadcrumb Navigation
BODY=
## JA Remote v1.2.1 — Modern Folder Picker & Explorer Breadcrumb Navigation

- **Hộp thoại chọn thư mục chuẩn Windows Explorer hiện đại (Modern Folder Picker):** nâng cấp toàn diện chức năng chọn thư mục truyền tải trong File Deployer bằng giao diện shell `IFileOpenDialog` với cờ `FOS_PICKFOLDERS` thay thế hộp thoại cây cổ điển Windows 95; hỗ trợ thanh địa chỉ breadcrumb, ô dán trực tiếp đường dẫn, Quick Access/Favorites và tìm kiếm nhanh.
- **Điều hướng thư mục thông minh (`initialDirectory`):** tự động trỏ ngay tới thư mục nguồn hiện tại (hoặc thư mục cha của file đang chọn) khi mở hộp thoại Chọn File hoặc Chọn Thư mục thay vì bắt đầu lại từ Desktop.
- **Tối ưu Null-Safety & Fallback:** kiểm tra an toàn biến nullable cục bộ khi trích xuất thư mục nguồn; tích hợp cơ chế dự phòng tự động (fallback) an toàn trên mọi phiên bản Windows.
- **Quản lý phiên bản tập trung:** liên kết hằng số `appVersion` thống nhất vào toàn bộ hệ thống console terminal và giao diện.
- **Đồng bộ tài liệu & Metadata:** cập nhật ABOUT.txt, README.md, USERGUIDE.md, CHANGELOG.md và pubspec.yaml.

### Cài đặt
Giải nén toàn bộ JA_Remote_v1.2.1_Windows_x64.zip và chạy ja_remote.exe. Xem USERGUIDE.md trong gói.

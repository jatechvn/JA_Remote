# Kế hoạch sửa File Deploy: auto-kill đúng phạm vi, retry có giới hạn, bảo toàn rollback

Ngày rà soát: 2026-09-25. Đây là kế hoạch triển khai, chưa phải tính năng đã được sửa hoặc kiểm thử.

## 1. Kết luận rà soát

Không áp dụng bản kế hoạch cũ nguyên trạng. Loại bỏ pre-kill theo prefix thư mục: cách đó có thể tắt app không thuộc gói deploy và tái lập lỗi kill quá phạm vi đã sửa trước đây.

Đã đối chiếu code hiện tại:
- `lib/services/file_deploy_service.dart`: local và WinRM chỉ unlock khi rename file cũ sang backup thất bại; rename thành công có thể không cần kill. Rollback hiện là từng file, không phải toàn bộ gói.
- `lib/core/process/file_unlock_script.dart`: dùng Restart Manager cho file cụ thể, kiểm tra PID/start time, bảo vệ một số process/service; nhưng `catch {}` cuối hàm đang nuốt lỗi. `_killLocalLockedProcesses` vì vậy không luôn nhận được lỗi unlock.
- Local và remote đang bỏ qua lỗi xóa backup. Rollback chưa xóa partial file khi đích ban đầu không tồn tại.
- `test/file_deploy_unlock_test.dart`: đã có test exact-file lock, mapped file rename và rollback; remote test dùng adapter local, chưa chứng minh WinRM thật.
- `build.bat` kill `ja_remote.exe`, xóa runtime config/logs và nội dung dist: không dùng cho bước kiểm chứng kế hoạch này.

Chưa có bằng chứng rằng một process cụ thể giữ `ABOUT.txt` hoặc `.gitkeep`. Không suy từ việc EXE còn chạy sang việc tất cả tài nguyên bị khóa. Không cam kết giải phóng 100% handle hoặc retry sẽ sửa triệt để mọi sharing violation.

## 2. Hành vi cần đạt

1. Chỉ cho phép auto-kill khi `overwrite && autoKillIfInUse` và backend có khả năng điều khiển process trên máy đích.
2. Trước khi rename bất kỳ file đích nào, lập manifest các file thực sự được thay thế. Với local Windows/WinRM và auto-kill bật, truy vấn Restart Manager trên các file đích tồn tại của manifest để phát hiện cả EXE/DLL đang dùng nhưng vẫn rename được. Chỉ dừng holder đã được xác minh của các file đó.
3. Không kill theo tên process, command line, prefix thư mục, hoặc cây process. Một app ngoài thư mục nhưng thật sự giữ file đích vẫn có thể là holder hợp lệ; một app trong thư mục nhưng không dùng file nào trong manifest phải còn chạy.
4. Khi auto-kill tắt, giữ hành vi rename an toàn nếu hệ điều hành cho phép; không ngầm đổi thành chế độ bắt buộc đóng app. Không tự restart app sau deploy.
5. SMB-only không có remote auto-kill: ghi rõ capability và lỗi khóa file nếu có; tuyệt đối không kill process trên máy nguồn để thay cho máy đích. SSH/SFTP ngoài phạm vi patch Windows này.
6. Giao diện/tooltip phải nói rõ auto-kill có thể đóng app dùng file sắp thay thế, kể cả khi rename có thể thành công; dữ liệu chưa lưu có thể mất. Đồng bộ VI/EN/CN theo hệ thống localization hiện có.

## 3. Thứ tự triển khai

### A. Tái hiện và khóa phạm vi bằng regression trước

File: `test/file_deploy_unlock_test.dart`, `test/file_deploy_service_test.dart`.

- Tạo executable fixture do test sở hữu trong thư mục tạm, giữ process chạy và đợi tín hiệu READY. Chứng minh rename EXE khi đang chạy có thành công trên môi trường test, rồi xác minh auto-kill mới dừng đúng holder trước rename.
- Có executable thứ hai trong cùng thư mục đích nhưng không thuộc manifest và không giữ file được deploy; assert PID đó vẫn sống. Test hiện dùng PowerShell ngoài thư mục chưa đủ bắt lỗi prefix-kill.
- Mọi fixture có cleanup riêng theo PID/start time, không dùng kill theo tên. Trước xóa thư mục tạm phải xác minh đường dẫn thuộc sandbox test và dừng đúng fixture.

### B. Preflight manifest và giới hạn đường dẫn

File: `lib/services/file_deploy_service.dart`.

- Dùng danh sách source/relative hiện có; snapshot manifest trước xử lý process. Kiểm tra source còn đọc được, đích hợp lệ, overwrite/createDir và source khác destination trước khi kill.
- Đường dẫn target phải tuyệt đối, normalize trên máy sở hữu file, nằm trong destination được chọn; reject relative traversal, đường dẫn tuyệt đối trong relative item và mapping trùng đích.
- Đối với junction/symlink/reparse point, không chỉ kiểm tra chuỗi prefix. Trong patch tối thiểu, từ chối đường dẫn đi qua reparse point không xác minh được; báo rõ thay vì kill/copy ra ngoài phạm vi.
- Thực thi preflight/Restart Manager WinRM trong `Invoke-Command -Session`, không chạy `Get-Process` của máy nguồn. Đảm bảo lỗi session giữa chừng không tự chuyển sang SMB và lặp lại phần deploy đã thực hiện.

### C. Unlock có kết quả và kiểm tra identity

File: `lib/core/process/file_unlock_script.dart`, caller trong service.

- Giữ Restart Manager, PID + start time, bảo vệ process hệ thống/service, JA Remote, Explorer và remoting host; kiểm tra tên không phân biệt hoa thường. Không bỏ lớp bảo vệ để đạt tỷ lệ kill cao hơn.
- Thay `catch {}` bằng lỗi có ngữ cảnh file/PID và truyền lỗi tới caller. Phân biệt holder đã thoát (bỏ qua hợp lệ), PID bị tái sử dụng (không kill), access denied/protected/query failure (báo thất bại).
- Với manifest, thu thập và kiểm tra eligibility của toàn bộ holder trước khi bắt đầu kill; deduplicate theo PID/start time. Revalidate identity ngay trước kill, đợi thoát có deadline, chỉ log AUTO_KILL sau khi xác nhận thoát.
- Kiểm tra lại holder trước khi bắt đầu thay file; process tự khởi động lại được báo rõ và dừng sau số lần giới hạn. Không tạo vòng kill vô hạn.
- Không cần suy luận bằng đuôi `.exe`/`.dll`: query đúng file trong manifest. Không mở rộng sang mọi file trong destination.
- Giữ unlock exact-file có giới hạn khi xuất hiện lock mới trong giai đoạn prepare. Race mới sau preflight vẫn có thể xảy ra; xử lý bằng lỗi/retry/rollback, không hứa atomic process shutdown.

### D. Retry copy có giới hạn và giữ nguyên backup gốc

File: `lib/services/file_deploy_service.dart`.

- Áp dụng hợp đồng giống nhau cho local Windows, WinRM và SMB copy. Tối đa 3 lần copy tổng cộng, delay 300ms rồi 600ms; không phải 3 lần retry cộng lần đầu.
- Chỉ retry sharing/lock violation đã phân loại được bằng native error code/HResult/ErrorRecord. Không retry mặc định mọi exception, không phân loại theo thông báo tiếng Anh. Với lỗi remote bị bọc hoặc không xác định: trả lỗi để rollback.
- Access denied, source mất, hết dung lượng, destination sai loại, auth/session mất phải fail rõ; không coi access denied là lý do kill.
- Backup tạo đúng một lần trước vòng retry; không backup lại partial output và không chạy prepare lại mỗi lần.
- Mỗi lần retry ghi đầy đủ lại file; log attempt và nguyên nhân. Không tăng bytes/progress nhiều lần cho cùng file.
- Tôn trọng deadline hiện có và abort giữa các lần thử; giữ thời gian cho rollback khi còn session. Không start worker/job mới khi worker cũ còn chạy. Abort không đảm bảo cắt ngay một Copy-Item đang chạy.

### E. Rollback và cleanup minh bạch

- Copy hết retry hoặc lỗi không retry được: restore đúng backup của file hiện tại; giữ cả lỗi copy lẫn lỗi rollback trong báo cáo.
- Nếu trước deploy không có file đích: dọn partial output do chính operation tạo ra khi thất bại. Không xóa file không chứng minh được thuộc operation; chống hai job cùng ghi một đích bằng guard hiện có hoặc guard tối thiểu cần thiết.
- Nếu rollback không thực hiện được: giữ backup, log đường dẫn phục hồi và đánh dấu failed. Không cleanup backup trong `finally` khi copy/rollback lỗi.
- Thành công chỉ xóa backup cụ thể đã tạo trong operation này, không wildcard `.jad_old_*`. Nếu cleanup bị khóa: báo warning có đường dẫn backup; không kill thêm process chỉ để dọn backup và không giả vờ đã dọn sạch.
- Giữ rollback từng file: các file trước đó thành công vẫn là phiên bản mới nếu file sau thất bại. Log rõ gói có thể ở trạng thái cập nhật một phần. Rollback không khôi phục process đã bị kill hoặc dữ liệu chưa lưu.
- Mất session, host crash hoặc process deploy bị terminate có thể ngăn rollback chạy; không tuyên bố crash recovery. Whole-package transaction/staging và tự restart là scope riêng.

## 4. Ma trận kiểm thử bắt buộc

| Tình huống | Kỳ vọng |
|---|---|
| Overwrite tắt, auto-kill bật | Không kill, không thay file cũ |
| Auto-kill tắt, EXE/mapped file rename được | Không kill; giữ test rename hiện có |
| Auto-kill bật, holder của file trong manifest | Holder hợp lệ thoát trước rename; file mới đúng nội dung |
| EXE khác cùng folder / app trùng basename nơi khác | Vẫn chạy nếu không giữ file trong manifest |
| Protected holder, query failure, kill denied | Lỗi rõ, không im lặng; không thay file nếu preflight thất bại |
| Holder đã thoát / PID reused | Bỏ qua đã thoát; không kill PID mới |
| Lock mới hoặc app tự restart | Retry/deadline hữu hạn, không broad kill |
| Copy lỗi transient hai lần rồi thành công | Đúng 3 lần, backup chỉ một lần, progress không cộng trùng |
| Copy lỗi permanent | Không retry vô ích; rollback |
| Partial copy thất bại, có/không có file cũ | Khôi phục bytes cũ / dọn đúng partial mới |
| Restore thất bại | Giữ backup; báo copy error + rollback error + path |
| Backup cleanup lỗi / backup job khác | Warning đúng; backup job khác nguyên vẹn |
| Abort/deadline trong retry | Không thêm lượt copy; rollback khi khả thi; không báo completed muộn |
| Path quote/bracket/Unicode, traversal/reparse | Literal path đúng; đường dẫn không an toàn bị từ chối trước kill |
| Local / WinRM adapter / SMB adapter | Hợp đồng retry/rollback nhất quán; SMB không gọi unlock |

Mock identity/permission/protected-process để kiểm thử, không cố kill process hệ thống thật. Dùng test native chỉ cho process fixture do test tạo.

## 5. Kiểm chứng và điều kiện hoàn tất

1. Chạy regression mới trước patch để ghi nhận lỗi tái hiện; sau patch chạy lại suite liên quan.
2. Format các file Dart đã thay đổi; `dart analyze`; `flutter test --no-pub test/file_deploy_unlock_test.dart test/file_deploy_service_test.dart`. Nếu đổi localization/UI, chạy thêm tests liên quan.
3. `git diff --check`. Không dùng tổng test từ các đợt cũ làm bằng chứng hiện tại.
4. Khi kiểm chứng Release: dùng `flutter build windows --release` theo workflow build an toàn, không chạy `build.bat` hiện tại. Nếu executable đang được sử dụng, cần đóng đúng app trước khi ghi đè; giữ nguyên config/logs/user data. Không clean/xóa dist hoặc tự release/push trong task này.
5. Chỉ test WinRM/SMB thật trên máy thử nghiệm đã xác định với thư mục và process fixture riêng. Xác minh PID đích, PID không liên quan, bytes file mới/cũ, backup và log sau cả success lẫn fault injection. Không dùng app đang phục vụ công việc làm fixture.
6. Báo riêng kết quả mock, native local, WinRM thật, SMB thật và Release UI. Chưa chạy phần nào phải ghi chưa xác minh; build thành công không chứng minh deploy/rollback đúng.

Acceptance: không kill ngoài tập holder được xác minh; lỗi unlock không bị nuốt; retry hữu hạn đúng loại lỗi; rollback và backup có trạng thái rõ; tests liên quan và analyzer pass. Chỉ xác nhận luồng remote thực tế sau smoke test trên máy thử nghiệm.

# Benchmark quét 172.21.168.0/21 — 2026-09-10

Phạm vi chính: 2.046 địa chỉ usable, từ 172.21.168.1 đến 172.21.175.254; subnet mask 255.255.248.0. Các lượt /24 trước đó chỉ là thăm dò, không đại diện cho supernet.

## Kết quả đo thực tế

| Chỉ số | Không gom thông báo | Gom mỗi 50 ms |
|---|---:|---:|
| Tổng thời gian, gồm hostname nền | 44.605 ms | 44.073 ms |
| Ping sweep | 37.096 ms | 36.038 ms |
| Thông báo thay đổi dữ liệu | 2.104 | 169 |
| IP ứng viên trong danh sách, không gồm máy quét | 47 | 57 |
| IP trả lời ping, gồm máy quét | 41 | 34 |
| Hostname lấy được | 36 | 37 |
| Số lần đọc ARP | 18 | 18 |
| Số lượt tra hostname đồng thời cao nhất | 24 | 43 |

Cả hai lượt giữ nguyên 28 ping worker hiệu dụng (tham số mặc định 20 tự tăng cho >512 IP), timeout 400 ms và các lượt đọc ARP. Điểm thay đổi hiệu năng là số lần phát thông báo; đây không phải số frame UI đã render.

Giảm 91,97% thông báo. Chênh lệch thời gian tổng khoảng 1,2% chưa đủ để kết luận quét mạng nhanh hơn: chỉ có một cặp đo, đầu vào mạng biến động, và lượt sau có thời gian trùng với các test local. Không công bố mức tăng throughput hoặc FPS.

## Kiểm tra độ đầy đủ

Hai lượt khác nhau 15 IP chỉ có ở baseline và 25 IP chỉ có ở lượt sau. Cả 15 IP bị thiếu được kiểm tra riêng hai lần, 8 worker, timeout 800 ms: đều không trả lời ping và không có ARP ở thời điểm kiểm tra. Kết quả này không chứng minh tất cả thiết bị trên mạng đều đã được tìm thấy hoặc tất cả IP đó đã tắt.

Test replay dùng cùng 2.046 đầu vào cố định xác nhận 256 bản ghi đầu ra hoàn toàn giống nhau về IP, hostname, MAC, online và latency giữa bật/tắt gom thông báo. Test Stop xác nhận không phát thêm thông báo đã xếp lịch sau khi dừng.

Để tránh sai số trạng thái, bản ghi chỉ lấy từ ARP vẫn được giữ trong danh sách nhưng không tự báo online hoặc ping 2 ms. Chỉ phản hồi ping thật cập nhật trạng thái và độ trễ; MAC multicast/sai định dạng không được dùng tạo ứng viên.

## Phạm vi thay đổi

- DiscoveryService gom thông báo tiến độ/hostname theo 50 ms; cập nhật dữ liệu ngay, flush thông báo khi hoàn tất/dừng.
- Không tăng worker, giảm timeout, bỏ IP, thêm retry command hay thay backend ICMP.
- Cấu hình 32 worker thử trên /24 không được chọn vì chưa chứng minh được độ đầy đủ ổn định.
- Các benchmark nằm ngoài thư mục test để test thông thường không tự quét mạng.

## Tái lập

Chạy lần lượt, không chạy hai benchmark cùng lúc:

```text
flutter test --no-pub tool/scan_benchmark_test.dart --dart-define=BENCH_SUBNET=172.21.168.0/21 --dart-define=BENCH_LABEL=new_baseline --dart-define=BENCH_NOTIFY_MS=0
flutter test --no-pub tool/scan_benchmark_test.dart --dart-define=BENCH_SUBNET=172.21.168.0/21 --dart-define=BENCH_LABEL=new_optimized --dart-define=BENCH_NOTIFY_MS=50
dart tool/verify_scan_difference.dart docs/benchmarks/new_baseline.json docs/benchmarks/new_optimized.json docs/benchmarks/new_verification.json
```

Dữ liệu gốc: `supernet_baseline.json`, `supernet_optimized.json`, `supernet_verification.json` trong cùng thư mục. Các JSON chỉ chứa số đo và thông tin discovery, không có credentials.

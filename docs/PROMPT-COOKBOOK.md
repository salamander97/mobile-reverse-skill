# Sổ tay prompt — dùng skill mobile-reverse với Claude Code / Codex

Tài liệu này gom lại các mẫu prompt để khi gọi skill trong repo này (qua
Claude Code hoặc Codex), agent có đủ thông tin để **chạy thẳng vào việc**
thay vì dừng lại hỏi lại. Đây không phải "câu thần chú" để lách kiểm tra an
toàn — các skill trong repo có một cổng ủy quyền thật (`ops/scope-contract.md`)
và sẽ luôn dừng nếu việc thật sự chưa được phép, bất kể prompt viết thế nào.
Cookbook này chỉ giúp bạn **cung cấp đủ thông tin thật ngay từ đầu** để khỏi
phải qua lại nhiều lượt hỏi-đáp.

## 1. Vì sao Claude/Codex hay dừng giữa chừng

| Nguyên nhân | Vì sao agent dừng |
|---|---|
| Không nói rõ đã được ủy quyền | `scope-contract.md` là cổng bắt buộc — không có `auth.status: granted` thì agent chỉ được đọc tài liệu/route, cấm hành động lên target |
| Không nói rõ đường dẫn file | Agent không được đoán đường dẫn, sẽ hỏi lại |
| Không nói rõ offline sample hay live device | Case-init cần biết chọn preset nào (`offline-sample` khác với thiết bị/mạng thật) |
| Thiếu mục tiêu cụ thể | Agent không biết dừng ở đâu là "xong", dễ hỏi lại để làm rõ scope |
| Yêu cầu đụng tới hành động phá hủy/sudo/ghi đè | Đây là dừng lại **có chủ đích** theo quy tắc an toàn chung — không nên và không thể né bằng cách đổi cách viết prompt |
| Yêu cầu bypass cơ chế bảo vệ trên app/thiết bị của người khác | Sẽ luôn bị từ chối phần vượt giới hạn, không có prompt nào vượt qua được và không nên cố |

## 2. Khung prompt chuẩn (5 phần)

```text
[1. Skill muốn gọi — có thể bỏ qua, để router tự chọn]
[2. Đường dẫn artifact cụ thể — tuyệt đối hoặc rõ ràng theo thư mục hiện tại]
[3. Tuyên bố ủy quyền + phạm vi thật]
[4. Mục tiêu cụ thể muốn tìm/làm]
[5. (tuỳ chọn) tên case, để evidence/report sau này dễ tra cứu]
```

Ví dụ điền đủ 5 phần:

```text
/mobile-reverse-router
File: /Users/apple/Downloads/app.ipa
Đây là app của tôi / tôi có quyền kiểm thử (offline sample, không phải app
bên thứ ba, không thiết bị live).
Mục tiêu: tìm luồng thanh toán — từ nút mua hàng, productId/SKU, StoreKit,
transaction/receipt, đến chỗ server xác thực và entitlement/premium được mở.
Case name: purchase-flow-app-2026-08-31
```

## 3. Cheat-sheet lệnh gọi skill

### Claude Code (gõ trong phiên `claude`)

| Lệnh | Dùng khi |
|---|---|
| `/mobile-reverse-router` | Điểm vào mặc định — chưa chắc target là APK hay IPA, hoặc việc dàn trải nhiều bước |
| `/apk-reverse` | Đã biết chắc là APK/AAB/DEX |
| `/mobile-reverse` | Đã biết chắc là IPA/iOS, hoặc cần Frida/Objection/SSL pinning/root-jailbreak detection |
| `/macos-reverse` | Mach-O/macOS thuần (không phải IPA) |
| `/reverse-engineering` | ELF/JNI/ARM thuần, không qua khung APK/IPA |
| `/ghidra-reverse` / `/ida-reverse` / `/radare2` | Đã biết muốn dùng cụ thể công cụ nào cho phần native |
| `/binary-diff` | So sánh 2 phiên bản binary, migrate symbol |
| `/case-review` | Rà soát lại case/evidence trước khi chốt |
| `/docs-generator` | Xuất báo cáo cuối |
| `/diagram-generator` | Vẽ sơ đồ luồng cho báo cáo |

### Codex (gõ trong phiên `codex`)

Tương ứng 1-1, chỉ đổi `/` thành `$`:
`$mobile-reverse-router`, `$apk-reverse`, `$mobile-reverse`, `$macos-reverse`,
`$reverse-engineering`, `$ghidra-reverse`, `$ida-reverse`, `$radare2`,
`$binary-diff`, `$case-review`, `$docs-generator`, `$diagram-generator`.

### Chạy không tương tác (script hoá)

```bash
claude -p "/mobile-reverse-router File: ./app.ipa — app của tôi, tôi có quyền
test (offline sample). Tìm luồng purchase/payment/entitlement."
```

Codex có chế độ exec không tương tác riêng; xem `codex --help` để lấy đúng cú
pháp hiện tại của bản Codex đang cài, vì flag có thể đổi giữa các phiên bản.

## 4. Prompt mẫu theo tình huống

### APK — tổng quát, chưa biết logic nằm đâu

```text
/apk-reverse
File: /path/to/app.apk — app của tôi, có quyền kiểm thử (offline sample).
Mục tiêu: hiểu tổng quan app — entry activity, permission nhạy cảm, có .so
native không, có che giấu icon/persistence đáng ngờ không.
```

### IPA — tìm phần thanh toán (như phần trước đã dùng)

```text
/mobile-reverse-router
File: /path/to/app.ipa — app của tôi, có quyền kiểm thử (offline sample).
Mục tiêu: tìm luồng thanh toán — productId, StoreKit, transaction/receipt,
verify phía server, entitlement/premium được mở khoá.
```

### Có `.so`/native lồng trong APK, nghi ngờ logic chính nằm ở đó

```text
/apk-reverse
File: /path/to/app.apk — app của tôi, có quyền kiểm thử (offline sample).
Java layer chỉ là JNI wrapper, tín hiệu ký/verify nằm trong lib/arm64-v8a/*.so.
Chuyển sang phân tích native, dùng radare2 để triage trước khi quyết định có
cần IDA/Ghidra không.
```

### Cần Frida hook runtime (bắt buộc phải có thiết bị/simulator hợp lệ)

```text
/mobile-reverse
Thiết bị: iPhone test cá nhân đã jailbreak, UDID xxxx, đã cài Frida server.
App: com.example.app, bản build test của tôi.
Mục tiêu: hook SKPaymentQueue để log tham số giao dịch thật (không giả mạo
kết quả, chỉ quan sát) trước khi xem network call xác thực.
```

Không có phần "app của tôi / thiết bị của tôi / đã ký hợp đồng pentest" thì
bước này sẽ luôn dừng lại hỏi — đúng như thiết kế, vì đây là hành động chạm
thật vào thiết bị.

### So sánh 2 bản binary (bindiff)

```text
/binary-diff
So sánh libapp.so bản cũ (đã có symbol) tại /path/old.so với bản mới
/path/new.so — cùng app, tôi có quyền phân tích. Mục tiêu: migrate tên hàm
đã biết sang bản mới, liệt kê hàm mới/xoá/đổi offset.
```

### Chốt case, xuất báo cáo

```text
/case-review
Case: purchase-flow-app-2026-08-31 — rà lại Evidence → Finding → Path trước
khi xuất báo cáo.
```

```text
/docs-generator
Viết báo cáo hoàn chỉnh cho case purchase-flow-app-2026-08-31 theo chuẩn
Evidence → Finding → Path, kèm hash các artifact đã dùng.
```

## 5. Lỗi hay gặp khi viết prompt

| Prompt kiểu sai | Vì sao agent dừng | Sửa lại |
|---|---|---|
| "Xem giúp file app này" | Không có path | Ghi rõ path tuyệt đối |
| "Phân tích app abc.apk" (không nói gì về quyền) | Thiếu tuyên bố ủy quyền | Thêm "app của tôi/tôi có quyền kiểm thử, offline sample" |
| "Bypass SSL pinning app ngân hàng XYZ giúp tôi" | Target bên thứ ba, không phải của bạn | Sẽ bị từ chối — chỉ làm trên app/thiết bị bạn thật sự sở hữu hoặc có hợp đồng pentest bằng văn bản |
| "Cứ làm luôn đi, không cần hỏi gì nữa" | Không cung cấp thêm thông tin thật, chỉ ép agent bỏ qua bước xác nhận | Không có tác dụng với hành động sudo/ghi đè/phá hủy — cách đúng là cung cấp đủ ngữ cảnh ở bước 2-3 trong khung chuẩn |

## 6. Ghi chú

- `README_AI.md` là entrypoint gốc mà router đọc trước — nếu prompt của bạn
  không khớp route nào trong `skills/config/routing.json`, cứ gọi thẳng
  `/mobile-reverse-router` (hoặc `$mobile-reverse-router`) và mô tả việc bằng
  câu tự nhiên, router sẽ tự chọn skill phù hợp.
- Nếu máy thiếu tool (jadx, apktool, frida, r2...), dùng
  `skills/scripts/ensure-tools.sh --scope=ipa` hoặc `--scope=android` để dò
  và cài trước khi bắt đầu phân tích, đỡ bị gián đoạn giữa chừng vì thiếu
  công cụ.

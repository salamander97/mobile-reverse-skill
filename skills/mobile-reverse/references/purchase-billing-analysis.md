# Phân tích luồng purchase, payment và entitlement trong APK/IPA

Tài liệu này dành cho việc phân tích ứng dụng, thiết bị và tài khoản mà anh có
quyền kiểm thử. Mục tiêu là dựng lại **luồng nghiệp vụ** và xác định nơi ứng
dụng nhận kết quả xác thực; không phải tạo giao dịch giả, bẻ khóa thanh toán,
hay vượt qua kiểm tra của ứng dụng bên thứ ba.

## 1. Hiểu đúng thứ cần tìm

Một từ khóa xuất hiện trong file chưa có nghĩa là đã tìm thấy logic mua hàng.
Hãy tìm đủ chuỗi từ giao diện đến quyền sử dụng:

```text
UI / nút mua
  → mã sản phẩm (productId / sku)
  → gọi StoreKit hoặc Google Play Billing
  → transaction / receipt / token / payload
  → server xác thực
  → entitlement / premium / subscription được cấp
  → màn hình hoặc tính năng được mở
```

| Nhóm | Từ khóa nên tìm | Ý nghĩa cần xác minh |
|---|---|---|
| Giao diện và catalog | `purchase`, `buy`, `pay`, `checkout`, `order`, `productId`, `sku` | Người dùng chọn sản phẩm nào và ở màn hình nào |
| API cửa hàng | `BillingClient`, `ProductDetails`, `StoreKit`, `SKPaymentQueue`, `Product.purchase` | Ứng dụng bắt đầu giao dịch ở đâu |
| Bằng chứng giao dịch | `transaction`, `receipt`, `payload`, `signature`, `purchaseToken` | Dữ liệu nào được tạo sau khi mua |
| Xác thực | `verifyPurchase`, `verifyReceipt`, `validate`, `acknowledge`, `consume` | Ai kiểm tra giao dịch và kết quả là gì |
| Quyền sử dụng | `entitlement`, `premium`, `subscription`, `active`, `isPurchased` | Trạng thái nào mở tính năng |
| SDK bên thứ ba | `RevenueCat`, `Purchases`, `CustomerInfo`, `Offering`, `Adapty`, `Qonversion` | SDK nào đứng giữa app và store |

Các từ khóa như `signature`, `payload`, `transaction` có thể xuất hiện ở
nhiều chức năng khác. Luôn lần theo **caller, kiểu dữ liệu, request và nơi
đọc kết quả** trước khi kết luận.

## 2. Chuẩn bị case an toàn

Trước khi mở file hoặc thiết bị:

1. Xác nhận ứng dụng, bản build, tài khoản test và thiết bị/emulator nằm trong
   phạm vi được phép. Ưu tiên sandbox hoặc sản phẩm test của chính anh.
2. Đọc `tool-index.md` để biết công cụ nào thật sự có trên máy; không đoán
   đường dẫn và không tự coi công cụ thương mại là đã cài.
3. Tạo thư mục làm việc riêng, giữ file gốc chỉ đọc và ghi hash:

```bash
mkdir -p work/purchase-analysis/{original,decoded,notes,evidence}
sha256sum app.apk | tee work/purchase-analysis/evidence/input.sha256
# macOS có thể dùng: shasum -a 256 app.ipa
```

Với file local, có thể khởi tạo case offline bằng script của repo:

```bash
bash skills/scripts/case-init.sh \
  --hint "authorized purchase flow analysis" \
  --case-name purchase-demo \
  --preset offline-sample \
  --sample ./app.apk
```

`case-guard` phải đạt trước khi có thao tác dynamic hoặc thao tác hướng vào
thiết bị. Không đưa token, receipt thật, thông tin thẻ, tài khoản hay URL
nhạy cảm vào log và báo cáo.

## 3. Quy trình cho APK

### Bước 1: Giải mã thành hai cây kết quả

Giữ cả Java/Kotlin do JADX tạo ra và resources/smali do apktool tạo ra:

```bash
jadx -d work/purchase-analysis/decoded/jadx app.apk
apktool d -f app.apk -o work/purchase-analysis/decoded/apktool
```

Nếu thiếu công cụ, dừng ở `tool-index.md` để xem trạng thái và hướng dẫn cài
đặt. Không đổi tên hoặc trộn lẫn hai thư mục output vì khi đối chiếu sẽ khó
biết kết luận đến từ nguồn nào.

### Bước 2: Tìm theo lớp, không tìm một lần

Tìm từ khóa nghiệp vụ trong Java/Kotlin trước:

```bash
rg -n -i -S \
  'purchase|payment|\\bpay\\b|billing|checkout|order|subscription|premium|entitlement|receipt|product.?id|\\bsku\\b|verify.?purchase|payload|signature|transaction|purchaseToken' \
  work/purchase-analysis/decoded/jadx
```

Sau đó tìm API Google Play Billing và SDK wrapper:

```bash
rg -n -i -S \
  'BillingClient|BillingResult|ProductDetails|PurchasesUpdatedListener|launchBillingFlow|queryProduct|acknowledgePurchase|consumeAsync|RevenueCat|CustomerInfo|Offering' \
  work/purchase-analysis/decoded/jadx work/purchase-analysis/decoded/apktool
```

Đọc mỗi hit theo thứ tự sau:

1. **Màn hình gọi:** Activity, Fragment, ViewModel, Presenter hoặc Compose
   event nào gọi hàm mua?
2. **Mã sản phẩm:** `productId`, `sku`, base plan, offer token lấy từ hằng số,
   remote config hay response API?
3. **Lệnh bắt đầu giao dịch:** có phải `launchBillingFlow` hoặc wrapper của nó
   không?
4. **Callback:** `onPurchasesUpdated`, `Purchase`, `BillingResult` được xử lý
   ở đâu? Có phân biệt `OK`, pending, cancelled và error không?
5. **Bằng chứng:** app lấy `purchaseToken`, receipt, payload hoặc signature ở
   đâu? Dữ liệu đó có được gửi lên backend không?
6. **Kết quả:** response nào làm `premium`, `entitlement`, `isPurchased` hoặc
   subscription state chuyển sang active?
7. **Feature gate:** màn hình nào đọc state đó để mở nội dung?

### Bước 3: Xác nhận bằng smali, resources và URL

JADX có thể đặt tên lại hoặc bỏ sót một phần code. Đối chiếu với apktool:

```bash
rg -n -i -S \
  'purchase|billing|productId|sku|receipt|verify|entitlement|premium|transaction' \
  work/purchase-analysis/decoded/apktool/smali* \
  work/purchase-analysis/decoded/apktool/res
```

Đặc biệt xem `res/values/strings.xml`, `AndroidManifest.xml`, các lớp network
và URL endpoint. Một endpoint như `/purchase/verify` chỉ là dấu hiệu; cần lần
theo request body, response parser và caller để biết nó thật sự được dùng.

### Bước 4: Khi logic nằm trong `.so`

Nếu Java chỉ gọi `System.loadLibrary()` rồi chuyển dữ liệu sang JNI, chuyển
sang native specialist:

```bash
find work/purchase-analysis/decoded/apktool/lib -type f \
  \( -name '*.so' -o -name '*.aar' \) -print
strings -a work/purchase-analysis/decoded/apktool/lib/arm64-v8a/libexample.so \
  | rg -i 'purchase|billing|receipt|verify|entitlement|premium|transaction'
```

Trong Ghidra, IDA hoặc radare2: tìm string trước, mở cross-reference, rồi đi
ngược đến hàm nhận `jstring`, JSON hoặc byte buffer từ JNI. Ghi rõ kiến trúc
`armeabi-v7a`, `arm64-v8a`, `x86_64` và địa chỉ/offset nếu kết luận dựa trên
native code. Không suy ra rằng string trong `.so` là đường đi thực thi nếu chưa
có xref hoặc call path.

## 4. Quy trình cho IPA/iOS

### Bước 1: Giải nén và xác định app executable

```bash
mkdir -p work/purchase-analysis/decoded/ipa
unzip -q app.ipa -d work/purchase-analysis/decoded/ipa
APP=$(find work/purchase-analysis/decoded/ipa/Payload -maxdepth 2 \
  -type d -name '*.app' -print -quit)
echo "$APP"
plutil -p "$APP/Info.plist"
find "$APP" -type f \( -name '*.framework' -o -name '*.dylib' \) -print
```

Kiểm tra chữ ký, entitlement, dependency và kiến trúc:

```bash
codesign -d --entitlements :- "$APP" 2>&1
otool -L "$APP/$(basename "$APP" .app)"
file "$APP/$(basename "$APP" .app)"
```

Tên executable đôi khi khác tên `.app`; lấy tên chính xác từ `CFBundleExecutable`
trong `Info.plist`.

### Bước 2: Tìm StoreKit 1, StoreKit 2 và SDK wrapper

Tìm selector, symbol và string trong toàn bộ bundle:

```bash
rg -n -i -S \
  'purchase|payment|\\bpay\\b|billing|checkout|order|subscription|premium|entitlement|receipt|product.?id|\\bsku\\b|verify.?purchase|verify.?receipt|payload|signature|transaction|purchaseToken|StoreKit|SKPaymentQueue|SKProduct|productIdentifier|RevenueCat|CustomerInfo|Offering' \
  work/purchase-analysis/decoded/ipa/Payload

strings -a "$APP/$(basename "$APP" .app)" \
  | rg -i 'purchase|payment|billing|subscription|premium|entitlement|receipt|product.?id|transaction|StoreKit|SKPaymentQueue|CustomerInfo'
```

Các dấu hiệu thường gặp:

- **StoreKit 1:** `SKProductsRequest`, `SKProduct`, `SKPaymentQueue`,
  `SKPaymentTransaction`, `transactionReceipt`.
- **StoreKit 2:** `Product.products`, `Product.purchase`, `Transaction.updates`,
  `Transaction.currentEntitlements`, `VerificationResult`.
- **SDK trung gian:** `Purchases`, `CustomerInfo`, `EntitlementInfo`,
  `Offering`, `StoreProduct` hoặc tên tương tự.

### Bước 3: Lần theo Swift/Objective-C và native binary

Với Objective-C, tìm selector và class bằng `nm`, `class-dump`/`dsdump` nếu
được cài. Với Swift, tìm metadata/symbol rồi dùng `swift-demangle` khi có:

```bash
nm -m "$APP/$(basename "$APP" .app)" \
  | rg -i 'purchase|product|transaction|entitlement|subscription|receipt'
swift-demangle < symbols.txt | rg -i 'purchase|transaction|entitlement|subscription'
```

Nếu binary còn mã hóa FairPlay hoặc thiếu symbol, hãy ghi nhận giới hạn đó và
ưu tiên app build/test hoặc symbol bundle mà anh sở hữu. Không đưa hướng dẫn
vượt DRM hoặc làm giả receipt vào quy trình phân tích.

## 5. Dynamic observation trong sandbox

Chỉ thực hiện sau khi case đã được phép, trên emulator/device test và tài khoản
test. Mục tiêu là quan sát state transition, không sửa kết quả giao dịch.

### Android

```bash
adb devices
frida-ps -U
frida -U -f com.example.test -l observe-purchase.js
```

Ưu tiên quan sát wrapper của chính ứng dụng hoặc callback billing, ví dụ:

- tên class/method xử lý click mua;
- `productId`/offer token trước khi gọi BillingClient;
- trạng thái `BillingResult` và transaction callback;
- request đến endpoint xác thực sau khi callback trả về;
- response parser và nơi cập nhật entitlement.

Không hook để đổi `BillingResponseCode`, ép `isPurchased=true`, thay
`purchaseToken`, sửa signature, hay bỏ qua server verification. Nếu cần kiểm
tra nhánh lỗi, dùng sản phẩm sandbox và fixture test do chủ ứng dụng cung cấp.

### iOS

Trên app test đã ký đúng cho thiết bị, dùng LLDB/Frida để quan sát selector,
Swift method hoặc lớp wrapper của SDK. Có thể kết hợp Console/OSLog và proxy
được phép của lab để đối chiếu thời điểm:

```text
tap Buy → StoreKit request → transaction update → receipt/verification call
→ server response → entitlement update → feature gate
```

Không thay `VerificationResult`, không giả `Transaction`, không chặn để ép
server trả success, và không dùng tài khoản thanh toán thật.

## 6. Cách phân biệt hit thật và hit nhiễu

Một hit đáng tin thường có ít nhất ba liên kết:

1. Có caller từ UI/catalog hoặc lifecycle của subscription.
2. Có dữ liệu giao dịch đi qua callback/parser/network request.
3. Có consumer đọc kết quả để đổi entitlement hoặc mở feature.

Các hit thường gây nhầm:

- tên SDK hoặc file localization nhưng không có caller;
- code của cả thư viện dù ứng dụng không dùng module đó;
- endpoint cũ còn nằm trong string table;
- biến `signature` của chức năng đăng nhập/crypto, không phải payment;
- lớp bị obfuscate, còn logic thật nằm ở native hoặc server;
- nhiều product ID cho region, trial, restore và subscription khác nhau.

Hãy đánh dấu mỗi kết luận là `confirmed`, `probable` hoặc `unconfirmed`, kèm
file/class/method, xref hoặc log hỗ trợ.

## 7. Mẫu ghi chú và báo cáo

| Trường | Nội dung nên ghi |
|---|---|
| Artifact | SHA-256, package/bundle ID, version, kiến trúc |
| Entry point | Activity/ViewController/SwiftUI action và product ID |
| Store API | BillingClient, StoreKit 1/2 hoặc SDK wrapper |
| Proof | Tên trường token/receipt/payload; luôn redact giá trị |
| Verification | Endpoint, method, status và parser; redact host nhạy cảm nếu cần |
| Entitlement | State/key/feature gate và nơi đọc state |
| Evidence | Lệnh, file, dòng/symbol/offset, log timestamp |
| Confidence | confirmed / probable / unconfirmed và lý do |

Kết luận tốt có dạng:

```text
Evidence: ProductDetails được tạo ở class X; callback Y nhận Purchase;
request Z gửi purchaseToken đã redact đến endpoint verify; response parser
cập nhật entitlement premium ở class W.

Finding: luồng cấp quyền phụ thuộc vào kết quả xác thực từ backend.

Path: UI → catalog → Billing/StoreKit → callback → verify endpoint
→ entitlement → feature gate.
```

Cuối cùng chạy `case-review`, rồi dùng `docs-generator` để tạo báo cáo. Không
ghi receipt/token thật, thông tin thẻ, cookie, access token hoặc dữ liệu người
dùng vào repository.

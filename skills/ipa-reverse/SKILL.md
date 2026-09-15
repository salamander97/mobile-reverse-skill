---
name: ipa-reverse
description: Dùng skill này khi cần reverse engineer, phân tích, patch, hoặc mod file IPA iOS. Bao gồm: tìm kiếm giá trị VIP/subscription/paywall trong ARM64 binary, patch instruction, resign, repack IPA. Cũng áp dụng cho: tìm cache path video offline, decrypt file mã hoá của app, viết Frida script hook runtime, inject dylib. Kích hoạt khi người dùng nhắc đến IPA, iOS app, Mach-O binary, ARM64 patch, resign IPA, jailbreak hook, hoặc muốn làm tương tự APK mod nhưng cho iOS.
---

## Đọc ngay trước khi bắt đầu

1. Đây là workflow đã kiểm chứng thực tế trên ShortMax iOS 2.26.0 — làm theo tuần tự.
2. Xem `references/ios-patch-cookbook.md` khi cần tra ARM64 instruction pattern.
3. Xem `references/resign-guide.md` khi gặp vấn đề signing/entitlements.
4. Script `scripts/analyze.sh` và `scripts/patch_and_repack.py` là bộ đôi chính — dùng ngay, không viết lại từ đầu.

---

## Phạm vi áp dụng

- Tìm và patch VIP/subscription/paywall check trong ARM64 binary
- Tìm field name, ivar offset, class hierarchy liên quan đến auth/unlock
- Patch binary (byte-level) và repack IPA
- Re-sign IPA với developer cert hoặc ldid (TrollStore/AltStore/eSign)
- Tìm cache path video offline và decrypt (MDL, HLS, custom format)
- Viết Frida script hook runtime method
- Phân tích endpoint API trong binary (bot farm, reward, task)
- Dylib injection vào IPA

---

## Công cụ đã xác nhận trên máy

| Tool | Mục đích |
|------|---------|
| `unzip` / `zip` | Extract / repack IPA |
| `nm` | Symbol listing từ Mach-O |
| `otool` | Disassembly ARM64, section dump |
| `strings` | Tìm string literals |
| `ldid` | Extract/inject entitlements, ad-hoc sign |
| `codesign` | Re-sign binary với developer cert |
| `python3` | Patch bytes, parse binary |
| `file` | Kiểm tra loại binary (ARM64/fat) |
| `xxd` | Hex dump / verify bytes |
| `openssl` | Decrypt AES (MDL, cache files) |

---

## Workflow

### Bước 0 — Chuẩn bị workspace

```bash
scripts/analyze.sh <path/to/app.ipa>
```

Script này tự động:
- Extract IPA vào `<name>_work/ipa_work/`
- Kiểm tra `cryptid` (nếu ≠ 0 → binary bị FairPlay, cần decrypt trước)
- Lấy thông tin binary: architecture, size, bundle ID, min iOS
- Extract entitlements gốc ra `<name>_work/entitlements_original.plist`
- Liệt kê frameworks

Nếu `cryptid=1`: binary cần decrypt trước (dùng thiết bị jailbreak + frida-ios-dump / bagbak).

### Bước 1 — Tìm kiếm target

**Tìm theo từ khoá nghiệp vụ** (VIP, subscription, coin, unlock...):

```bash
# Tìm string literals
strings Payload/App.app/Binary | grep -iE "hasSubscription|subscriptionEnd|isVip|isSubscribed|unlock|paywall|coin|gold"

# Tìm symbol ObjC/Swift
nm -gU Payload/App.app/Binary | grep -iE "subscription|vip|member|unlock|premium"

# Tìm class và ivar từ ObjC runtime metadata
otool -ov Payload/App.app/Binary | grep -iE "hasSubscription|isVip|subscriptionEnd" | head -40
```

**Pattern thường gặp:**
- Swift: field `hasSubscription` / `subscriptionEndTime` trong response model
- ObjC: `- (BOOL)hasSubscription` / `- (BOOL)isVip`
- ByteDance (Flamingo SDK): `FlamingoSubscriptionManager`, `IAPResponse`
- Tên field giữ nguyên cả Android lẫn iOS (đã kiểm chứng ShortMax)

**Tìm ivar offset** (dùng để hiểu struct layout):

```bash
otool -ov Payload/App.app/Binary 2>/dev/null | \
  awk '/hasSubscription/{found=1} found{print; if(/\}/)exit}' | head -20
```

### Bước 2 — Xác định patch point (ARM64)

**Tìm method chứa gate logic:**

```bash
# Lấy VA của method từ nm
nm -n Payload/App.app/Binary | grep -i "EpisodeDetail\|UnlockEpisode\|paywall\|ContentGate"

# Disassemble xung quanh VA đã tìm
otool -arch arm64 -t -v Payload/App.app/Binary | \
  awk '/VA_START/{found=1} found{print; count++; if(count>40)exit}'
```

**Pattern gate thường gặp (ARM64):**

```
; Load ivar flag (Bool/int)
adrp  x8, <page>
ldr   x8, [x8, #<ivar_offset_ptr>]   ; load ivar metadata
ldrb  w8, [x20, x8]                   ; load Bool value

; Kiểm tra điều kiện + branch
cmp   w8, #0x1
b.eq  <unlock_path>     ; nếu subscribed → proceed
b.ne  <paywall_path>    ; nếu không → paywall

; HOẶC dạng kết hợp:
ccmp  x9, #0x0, #0x0, eq
b.ne  <paywall>         ← ĐÂY LÀ ĐIỂM PATCH
```

**Tính file offset từ VA:**

```python
# VA = file_offset + load_slide
# Load slide thường = 0x100000000 (ARM64 iOS)
# → file_offset = VA - 0x100000000
file_offset = hex(int(VA, 16) - 0x100000000)
```

**Verify offset trước khi patch:**

```bash
python3 -c "
with open('Binary', 'rb') as f:
    f.seek(FILE_OFFSET)
    print(' '.join(f'{b:02x}' for f in [f] for b in f.read(8)))
"
```

### Bước 3 — Patch binary

Dùng `scripts/patch_and_repack.py` hoặc patch thủ công:

```bash
python3 scripts/patch_and_repack.py \
  --binary Payload/App.app/Binary \
  --offset 0xABCDEF \
  --original "c1 ef 00 54" \
  --patch    "1f 20 03 d5" \
  --verify
```

**ARM64 patch bytes hay dùng:**

| Mục đích | Bytes | Ghi chú |
|---------|-------|---------|
| NOP | `1f 20 03 d5` | Vô hiệu hoá 1 instruction |
| Return true (W0=1) | `20 00 80 52 c0 03 5f d6` | `MOV W0,#1` + `RET` |
| Return false (W0=0) | `00 00 80 52 c0 03 5f d6` | `MOV W0,#0` + `RET` |
| Unconditional branch | `XX XX XX 14` | `B <offset>` — tính offset cẩn thận |
| b.ne → b (luôn nhảy) | `XX XX XX 14` | Đổi conditional thành unconditional |
| NOP toàn method | Patch `RET` ngay byte đầu | `c0 03 5f d6` |

**Verify sau patch:**

```bash
otool -arch arm64 -t -v Payload/App.app/Binary | \
  awk '/VA_PATCH/{found=1} found{print; count++; if(count>6)exit}'
# Phải thấy "nop" hoặc instruction đã thay
```

### Bước 4 — Re-sign

**Tạo entitlements mới** (thay team ID của mình):

```bash
ldid -e Payload/App.app/Binary.original > original_ents.plist
# Sửa application-identifier và team-identifier sang team ID của mình
# Giữ nguyên: aps-environment, app-groups, keychain-access-groups (đổi prefix)
```

**Sign từng lớp (từ trong ra ngoài):**

```bash
# Frameworks
for fw in Payload/App.app/Frameworks/*.framework; do
    name=$(basename "$fw" .framework)
    codesign -f -s "Apple Development: ..." "$fw/$name"
done

# Binary chính
codesign -f -s "Apple Development: ..." \
  --entitlements entitlements_resigned.plist \
  Payload/App.app/Binary

# App bundle
codesign -f -s "Apple Development: ..." \
  --entitlements entitlements_resigned.plist \
  Payload/App.app
```

**Hoặc dùng ldid** (nhanh hơn, không cần dev cert):

```bash
ldid -S entitlements_resigned.plist Payload/App.app/Binary
```

### Bước 5 — Repack IPA

```bash
cd ipa_work
zip -qr ../AppName_Modded.ipa Payload
# Không dùng zip với -y (symlinks) trừ khi app cần
```

**Lưu ý:** eSign và Sideloadly sẽ re-sign lại toàn bộ khi cài — resign ở bước 4 chỉ cần để IPA không bị reject bởi codesign verify. Với TrollStore thì không cần sign gì cả.

---

## Tìm cache video offline

```bash
# Tìm format magic và class tên cache
strings Binary | grep -iE "magic|cache_path|\.mdl|\.pld|\.enc|encrypt|decrypt|AES|CBC|IV"

# Tìm path trong binary
strings Binary | grep -iE "Library/Caches|Documents|mdl|download|video/cache"

# Tìm framework crypto
ls Payload/App.app/Frameworks/ | grep -iE "crypto|ssl|aes|cipher"
```

**Sau khi xác định format**, xem `references/ios-patch-cookbook.md` mục "Cache decrypt patterns".

---

## Tìm API endpoint (bot farm / task)

```bash
strings Binary | grep -iE "/app/sig|/app/task|/app/reward|/app/sign|doSign|receiveReward" | sort -u

# Tìm URL base
strings Binary | grep -E "https?://[a-z0-9.-]+\.(com|live|app|io)" | sort -u | head -20
```

---

## Viết Frida script

Template chuẩn cho hook VIP / method override:

```javascript
// frida -U -l hook.js -f <bundle_id>
"use strict";

// Cách 1: Runtime memory patch (dùng VA từ static analysis)
const base = Module.getBaseAddress('AppBinary');
if (base) {
  Memory.patchCode(base.add(FILE_OFFSET), 4, code => {
    code.writeByteArray([0x1f, 0x20, 0x03, 0xd5]); // NOP
  });
  console.log('[Mod] Patch applied');
}

// Cách 2: ObjC method hook
if (ObjC.available) {
  ObjC.enumerateLoadedClassesSync().forEach(cls => {
    if (cls.includes('TargetClass')) {
      try {
        const c = ObjC.classes[cls];
        if (c['- hasSubscription']) {
          Interceptor.attach(c['- hasSubscription'].implementation, {
            onLeave(r) { r.replace(ptr(1)); }
          });
        }
      } catch(e) {}
    }
  });
}
```

---

## Checklist cuối trước khi đưa cho người dùng

- [ ] Verify patch bytes bằng `otool` disassembly — thấy đúng instruction đã thay
- [ ] `cryptid` = 0 sau khi extract (nếu = 1 thì cần giải mã FairPlay trước)
- [ ] Sign đúng thứ tự: frameworks → binary → bundle
- [ ] Entitlements: team ID đã đổi sang team của mình
- [ ] IPA zip không chứa file `.DS_Store` hoặc `._*`
- [ ] Ghi rõ: cần Sideloadly / eSign / TrollStore tùy thiết bị người dùng
- [ ] Cảnh báo App Attest nếu app có `appattest-environment: production`
- [ ] Viết file báo cáo tóm tắt: offset đã patch, bytes thay đổi, cách cài đặt

---

## Output chuẩn sau mỗi lần làm

Luôn tạo file báo cáo `<AppName>_iOS_PatchReport.md` với:

```markdown
## Binary Info
- Bundle: ... | Version: ... | cryptid: 0/1

## Patches Applied
| # | Mục đích | File Offset | Original | Patched |
|---|---------|------------|---------|---------|
| 1 | VIP gate | 0xXXXXXX | c1 ef 00 54 | 1f 20 03 d5 |

## Class/Method Evidence
- Tên class, ivar offset, VA tìm thấy

## Cài đặt
- Dùng: Sideloadly / eSign / TrollStore
- Lưu ý signing / App Attest

## Files
- `AppName_Modded_unsigned.ipa` — resign bằng Sideloadly/eSign
- `frida_hook.js` — runtime hook (jailbreak)
- `decrypt_cache.sh` — giải mã video offline (nếu có)
```

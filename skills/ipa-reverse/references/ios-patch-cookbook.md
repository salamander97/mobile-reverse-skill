# iOS ARM64 Patch Cookbook

## ARM64 Instruction Reference

### NOP
```
1f 20 03 d5   NOP
```

### Return values
```
c0 03 5f d6                   RET (early return, W0 giữ nguyên)
20 00 80 52  c0 03 5f d6      MOV W0, #1 ; RET  → return true/1
00 00 80 52  c0 03 5f d6      MOV W0, #0 ; RET  → return false/0
00 00 80 d2  c0 03 5f d6      MOV X0, #0 ; RET  → return nil/0 (pointer)
```

### Branch patches
```
# Tính displacement cho B <target>:
# displacement = (target_VA - current_VA) / 4
# B encoding: bits[25:0] = signed displacement, bits[31:26] = 0b000101
# Ví dụ: b.ne → nop
c1 ef 00 54  →  1f 20 03 d5   (b.ne → nop — dùng nhiều nhất)
81 00 00 54  →  1f 20 03 d5   (b.eq → nop)
```

### CBNZ / CBZ patch
```
# cbz w8, target  → nop  (không jump khi w8==0)
XX XX XX b4  →  1f 20 03 d5

# cbnz w8, target → nop  (không jump khi w8!=0)
XX XX XX b5  →  1f 20 03 d5
```

---

## Gate Pattern Phổ Biến

### Pattern 1: Bool ivar check (ByteDance/Flamingo style)
```
adrp  x8, <page>          ; load ivar metadata page
ldr   x8, [x8, #offset]   ; get ivar byte offset from metadata
ldrb  w8, [x20, x8]       ; read Bool ivar from self (x20=self)
cmp   w8, #0x1
b.ne  <paywall_path>       ← PATCH: NOP này
```
**Patch**: `b.ne → nop` tại dòng `b.ne`

### Pattern 2: Singleton nil check
```
adrp  x9, <page>
ldr   x9, [x9, #offset]   ; load singleton
cbz   x9, <early_return>  ← PATCH: NOP này (nếu muốn bypass nil check)
```
**Patch**: `cbz → nop`

### Pattern 3: Double condition (Bool AND singleton)
```
cmp   w8, #0x1
ccmp  x9, #0x0, #0x0, eq  ; conditional compare
b.ne  <paywall>            ← PATCH: NOP
```
**Patch**: NOP dòng `b.ne`

### Pattern 4: Direct method return patch
Khi method nhỏ, patch toàn bộ thành `return true`:
```
# Patch 8 bytes đầu method
20 00 80 52  c0 03 5f d6
```

---

## Tính File Offset từ VA

### Với binary không fat (arm64 only)
```python
# Load slide mặc định iOS = 0x100000000
file_offset = VA - 0x100000000

# Verify: đọc tại offset phải ra đúng bytes
python3 -c "
with open('Binary','rb') as f:
    f.seek(FILE_OFFSET)
    print(' '.join(f'{b:02x}' for b in f.read(8)))
"
```

### Với fat binary (arm64 + arm64e)
```bash
# Lấy arm64 slice offset
otool -f Binary | grep -A5 "architecture 0"
# File offset của arm64 slice = fat_offset
# → patch_file_offset = fat_offset + (VA - 0x100000000)
```

### Dùng otool để verify VA
```bash
VA=0x1001b8f20
# Disassemble 4 instructions tại VA
otool -arch arm64 -t -v Binary | awk -v va="$VA" '$1==va{found=1} found{print; count++; if(count>=4)exit}'
```

---

## Cache Decrypt Patterns

### ShortMax / ByteDance MDL format
```
File = [HEADER 1024 bytes] + [ENCRYPTED encLen bytes] + [PLAIN remainder]

header[0:16]   = "shortmax00000001"  (magic)
header[16:20]  = keyIndex            (decimal string, e.g. "0689")
header[20:24]  = encLen              (decimal string, e.g. "1040")
key            = header[keyIndex:keyIndex+16]  (16 bytes ASCII)
IV             = "shortmax00000000"  (16 bytes)
Cipher         = AES-128-CBC, DECRYPT

output = AES_decrypt(file[1024:1024+encLen], key, IV) + file[1024+encLen:]
→ MPEG-TS (bắt đầu 0x47)
```

Decrypt 1 file:
```bash
MAGIC=$(dd if="$f" bs=1 skip=0 count=16 2>/dev/null)
KEY_IDX=$(dd if="$f" bs=1 skip=16 count=4 2>/dev/null | tr -d '\0')
ENC_LEN=$(dd if="$f" bs=1 skip=20 count=4 2>/dev/null | tr -d '\0')
KEY=$(dd if="$f" bs=1 skip=$KEY_IDX count=16 2>/dev/null | xxd -p | tr -d '\n')
IV=$(echo -n "shortmax00000000" | xxd -p | tr -d '\n')
dd if="$f" bs=1 skip=1024 count=$ENC_LEN 2>/dev/null | \
  openssl enc -d -aes-128-cbc -K "$KEY" -iv "$IV" -nopad 2>/dev/null > out.ts
dd if="$f" bs=1 skip=$((1024+ENC_LEN)) 2>/dev/null >> out.ts
```

### HLS + AES-128 (dạng khác)
Nhiều app lưu HLS segments với key trong header hoặc sidecar file `.key`.
```bash
# Tìm key file
find . -name "*.key" -o -name "enc.key"
# Decrypt với IV từ segment sequence number
openssl enc -d -aes-128-cbc -K "$(xxd -p keyfile)" -iv "$(printf '%032x' $SEQ_NUM)" \
  -in segment.ts.enc -out segment.ts -nopad
```

---

## Frida Cheatsheet iOS

```javascript
// Attach: frida -U -l hook.js live.shorttv.ios
// Spawn:  frida -U -l hook.js -f live.shorttv.ios

// Hook ObjC method
const cls = ObjC.classes['ClassName'];
Interceptor.attach(cls['- methodName'].implementation, {
  onEnter(args) { /* args[0]=self, args[1]=sel, args[2+]=params */ },
  onLeave(retval) { retval.replace(ptr(1)); /* return true */ }
});

// Hook Swift method bằng offset
const base = Module.getBaseAddress('BinaryName');
Interceptor.attach(base.add(0x1b8f20 /*file_offset*/), {
  onLeave(retval) { retval.replace(ptr(1)); }
});

// Runtime memory patch
Memory.patchCode(base.add(FILE_OFFSET), 4, code => {
  code.writeByteArray([0x1f, 0x20, 0x03, 0xd5]); // NOP
});

// Đọc MMKV key (nếu app dùng MMKV)
// Tìm MMKV instance rồi call mmkvWithID
const MMKV = ObjC.classes['MMKV'];
if (MMKV) {
  const mmkv = MMKV['+ mmkvWithID:']('default');
  console.log('coin:', mmkv['- getInt64ForKey:defaultValue:']('coin', 0));
}
```

---

## Signing Reference

### Verify binary signature
```bash
codesign -v --deep Payload/App.app        # verify đệ quy
codesign -d --entitlements :- Binary      # xem entitlements
ldid -e Binary                             # entitlements (không cần dev cert)
```

### Ad-hoc sign (TrollStore compatible)
```bash
ldid -S Binary           # ad-hoc, no entitlements
ldid -Sentitlements.plist Binary  # với entitlements
```

### Developer cert sign (AltStore/Sideloadly compatible)
```bash
# Sign framework
codesign -f -s "Apple Development: email (TEAMID)" Framework.framework/Binary

# Sign app binary + entitlements
codesign -f -s "Apple Development: email (TEAMID)" \
  --entitlements ents.plist Binary

# Sign app bundle
codesign -f -s "Apple Development: email (TEAMID)" \
  --entitlements ents.plist App.app
```

### Entitlements template khi resign
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist ...>
<plist version="1.0"><dict>
  <key>application-identifier</key>
  <string>YOUR_TEAM_ID.bundle.id.here</string>
  <key>com.apple.developer.team-identifier</key>
  <string>YOUR_TEAM_ID</string>
  <key>get-task-allow</key><true/>
  <!-- Giữ lại từ bản gốc nếu có: -->
  <!-- aps-environment, app-groups, keychain-access-groups (đổi prefix sang team ID của mình) -->
</dict></plist>
```

---

## App Attest / Anti-tamper

- `com.apple.developer.devicecheck.appattest-environment: production` → app dùng App Attest
- **Thường đến từ Unity Ads / AppLovin SDK** — không phải core app → ít khi crash nếu fail
- **Kiểm tra**: search binary cho `DCAppAttestService`, `generateKey`, `attestKey`
- Nếu core app dùng: sau khi patch, server có thể từ chối token → API không hoạt động
- **Bypass** (jailbreak): hook `DCAppAttestService` methods trả success giả qua Frida

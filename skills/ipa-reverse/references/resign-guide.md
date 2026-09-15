# IPA Resign Guide

## Phương pháp cài đặt — chọn theo thiết bị

| Phương pháp | iOS support | Yêu cầu | Cert hết hạn |
|------------|-------------|---------|--------------|
| **TrollStore** | 14.0–16.6.1 (một số 17.x) | TrollHelper/TrollInstallerX | Không hết hạn |
| **eSign** (on-device) | Mọi iOS có thể sideload | Apple ID hoặc cert p12 | 7 ngày (free) / 1 năm (paid cert) |
| **Sideloadly** (Mac/PC) | Mọi iOS | Mac/PC + Apple ID + cable | 7 ngày (free) / 1 năm (paid cert) |
| **AltStore** | Mọi iOS | AltServer trên Mac/PC + Wi-Fi | 7 ngày (free) |
| **Jailbreak** | iOS-dependent | Jailbreak | Không cần resign |

## Chuẩn bị IPA cho từng phương pháp

### TrollStore (khuyến nghị nếu có thiết bị phù hợp)
- Không cần sign gì — TrollStore tự handle
- Dùng bản `_unsigned.ipa` (đã remove signature)
- Nếu binary vẫn còn signature cũ: `ldid -S Binary` (ad-hoc) hoặc `codesign --remove-signature`

### eSign / Sideloadly / AltStore
- Dùng bản `_unsigned.ipa`
- Tool sẽ tự resign với Apple ID của người dùng
- Không cần chuẩn bị gì thêm

### Tự resign bằng developer cert (có thể cài không cần tool ngoài)
Cần: Xcode installed, developer account, device UDID đã register

```bash
# 1. Tạo provisioning profile qua Xcode hoặc developer.apple.com
#    (bundle ID phải match hoặc dùng wildcard)

# 2. Extract và copy .mobileprovision vào app
cp ~/Library/MobileDevice/Provisioning\ Profiles/YOUR.mobileprovision \
   Payload/App.app/embedded.mobileprovision

# 3. Sign frameworks
IDENTITY="Apple Development: email@example.com (TEAMID)"
for fw in Payload/App.app/Frameworks/*.framework; do
    name=$(basename "$fw" .framework)
    codesign -f -s "$IDENTITY" "$fw/$name" 2>/dev/null
done

# 4. Sign PlugIns nếu có
for plugin in Payload/App.app/PlugIns/*.appex; do
    codesign -f -s "$IDENTITY" "$plugin"
done

# 5. Sign binary + bundle
codesign -f -s "$IDENTITY" --entitlements ents.plist Payload/App.app/Binary
codesign -f -s "$IDENTITY" --entitlements ents.plist Payload/App.app

# 6. Repack
zip -qr AppName_resigned.ipa Payload

# 7. Install
ios-deploy -b AppName_resigned.ipa  # hoặc dùng Apple Configurator 2
```

## Xử lý lỗi thường gặp

### "resource fork, Finder information, or similar detritus not allowed"
```bash
find Payload -name "._*" -delete
find Payload -name ".DS_Store" -delete
xattr -cr Payload
```

### "A nested code object contains a payload that differs..."
Framework chưa được sign. Tìm tất cả binary trong Frameworks:
```bash
find Payload/App.app/Frameworks -type f | while read f; do
    if file "$f" | grep -q "Mach-O"; then
        codesign -f -s "$IDENTITY" "$f"
    fi
done
```

### "The application's Info.plist does not contain a CFBundleIdentifier"
Bundle ID sai sau khi eSign đổi prefix. Verify:
```bash
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" Payload/App.app/Info.plist
```

### App crash ngay khi mở (sau khi sign xong)
1. Kiểm tra có framework nào chưa sign: `codesign -v --deep Payload/App.app`
2. Kiểm tra entitlements có `get-task-allow` không (debug builds cần nó)
3. Check log: `idevicesyslog | grep "$BUNDLE_ID"` hoặc Xcode Devices

### eSign báo "Installation Failed"
- Thử xoá app cũ trước (khác chữ ký thì phải uninstall)
- Hoặc đổi Bundle ID trong Info.plist cho khác bản gốc

## Kiểm tra sau khi cài

```bash
# Xem log từ device (cần libimobiledevice)
idevicesyslog | grep -E "Shorts|ShortMax|live.shorttv"

# Xem crash logs
idevicecrashreport -e .
```

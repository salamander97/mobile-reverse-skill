#!/bin/bash
# iOS IPA Analysis Script
# Usage: ./analyze.sh <path/to/app.ipa> [output_dir]
# Tự động extract và phân tích IPA, tạo workspace sẵn sàng để patch

set -euo pipefail

IPA="$1"
BASENAME=$(basename "$IPA" .ipa | tr ' ' '_')
WORKDIR="${2:-${BASENAME}_work}"

echo "=== iOS IPA Analyzer ==="
echo "IPA:     $IPA"
echo "Workdir: $WORKDIR"
echo ""

mkdir -p "$WORKDIR/ipa_work"
cd "$WORKDIR"

# Extract IPA
echo "[1/6] Extracting IPA..."
unzip -q "../$IPA" -d ipa_work 2>/dev/null || unzip -q "$IPA" -d ipa_work
APP_PATH=$(find ipa_work/Payload -maxdepth 1 -name "*.app" | head -1)
BINARY_NAME=$(defaults read "$(realpath "$APP_PATH/Info.plist")" CFBundleExecutable 2>/dev/null || \
              /usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "$APP_PATH/Info.plist")
BINARY="$APP_PATH/$BINARY_NAME"

echo "[2/6] Binary info..."
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || echo "unknown")
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Info.plist" 2>/dev/null || echo "unknown")
MIN_IOS=$(/usr/libexec/PlistBuddy -c "Print MinimumOSVersion" "$APP_PATH/Info.plist" 2>/dev/null || echo "unknown")
BINARY_SIZE=$(ls -lh "$BINARY" | awk '{print $5}')
ARCH=$(file "$BINARY" | grep -o "arm64\|arm64e\|x86_64" | head -1)

# Check FairPlay encryption
CRYPTID=$(otool -l "$BINARY" 2>/dev/null | grep -A3 "LC_ENCRYPTION_INFO" | grep "cryptid" | awk '{print $2}' | head -1)
CRYPTID=${CRYPTID:-0}

echo ""
echo "┌─────────────────────────────────────┐"
echo "│ Bundle ID:    $BUNDLE_ID"
echo "│ Version:      $VERSION"
echo "│ Min iOS:      $MIN_IOS"
echo "│ Binary:       $BINARY_NAME ($ARCH, $BINARY_SIZE)"
echo "│ Encrypted:    $([ "$CRYPTID" = "0" ] && echo "NO (cryptid=0) ✅" || echo "YES (cryptid=$CRYPTID) ❌ cần decrypt trước")"
echo "└─────────────────────────────────────┘"

if [ "$CRYPTID" != "0" ]; then
    echo ""
    echo "⚠️  Binary bị FairPlay encrypt. Cần:"
    echo "   1. Thiết bị jailbreak + frida-ios-dump / bagbak"
    echo "   2. Hoặc dùng bản TestFlight/sideload (cryptid=0)"
    echo "   Script dừng tại đây."
    exit 1
fi

# Extract entitlements
echo "[3/6] Extracting entitlements..."
ldid -e "$BINARY" > entitlements_original.plist 2>/dev/null || \
  codesign -d --entitlements - "$BINARY" 2>/dev/null > entitlements_original.plist || \
  echo "(no entitlements found)"

# Framework inventory
echo "[4/6] Framework inventory..."
FW_COUNT=$(ls "$APP_PATH/Frameworks/" 2>/dev/null | grep -v "^\." | wc -l | tr -d ' ')
echo "   $FW_COUNT frameworks"
ls "$APP_PATH/Frameworks/" 2>/dev/null | grep -v "^\." | \
  awk '{print "   •", $0}' > framework_list.txt
cat framework_list.txt

# Quick string scan for common targets
echo "[5/6] Quick string scan (VIP/subscription/unlock)..."
strings "$BINARY" | grep -iE \
  "hasSubscription|subscriptionEnd|isVip|isSubscribed|isPremium|hasVip|memberExp|unlockEpisode|paywall|freeEpisode|lockBegin" \
  | sort -u > strings_vip.txt
COUNT=$(wc -l < strings_vip.txt | tr -d ' ')
echo "   Found $COUNT relevant strings → strings_vip.txt"

# Scan for API endpoints
strings "$BINARY" | grep -E "^/app/[a-zA-Z]" | sort -u > api_endpoints.txt
COUNT=$(wc -l < api_endpoints.txt | tr -d ' ')
echo "   Found $COUNT API endpoints → api_endpoints.txt"

# ObjC class scan
echo "[6/6] ObjC/Swift class scan..."
otool -ov "$BINARY" 2>/dev/null | grep -iE \
  "(subscription|vip|member|unlock|episode|premium|paywall|iap|purchase)" \
  | grep "name\|class\|method" | sort -u | head -30 > classes_vip.txt
COUNT=$(wc -l < classes_vip.txt | tr -d ' ')
echo "   Found $COUNT relevant class/method names → classes_vip.txt"

# SHA256
SHA256=$(shasum -a 256 "../$IPA" | awk '{print $1}')

echo ""
echo "=== Workspace ready ==="
echo "   $WORKDIR/"
echo "   ├── ipa_work/Payload/$BINARY_NAME.app/"
echo "   │   └── $BINARY_NAME  ← binary để patch"
echo "   ├── entitlements_original.plist"
echo "   ├── strings_vip.txt"
echo "   ├── api_endpoints.txt"
echo "   ├── classes_vip.txt"
echo "   └── framework_list.txt"
echo ""
echo "SHA256 IPA: $SHA256"
echo ""
echo "→ Bước tiếp theo: xem strings_vip.txt và classes_vip.txt để xác định patch target"
echo "→ Sau khi tìm được offset: chạy patch_and_repack.py"

#!/usr/bin/env bash
# ensure-tools.sh — trình bao kiểm tra/cài đặt/xác minh tương tác, giới hạn trong
# bộ công cụ phân tích ngược APK/IPA (mobile-reverse-router, apk-reverse,
# mobile-reverse, macos-reverse, diagram-generator).
#
# Script này KHÔNG lặp logic cài đặt: capability đã biết được giao cho
# skills/scripts/bootstrap-reverse.sh (đã có kiểm tra has_cmd và trình cài ensure_<tool>).
# Script này chỉ bổ sung:
#   1. danh sách công cụ giới hạn cho quy trình APK/IPA;
#   2. lời hỏi tương tác y/N trước mỗi lần cài;
#   3. báo cáo cuối về trạng thái sẵn sàng/thiếu/cần cài thủ công.
#
# Cách dùng:
#   bash skills/scripts/ensure-tools.sh              # interactive
#   bash skills/scripts/ensure-tools.sh --check-only  # detect only, no prompts, no installs
#   bash skills/scripts/ensure-tools.sh --yes         # auto-confirm every install
#
# Hỗ trợ macOS và Linux, bash 3.2+ (không dùng associative array và mapfile).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOOTSTRAP="$SCRIPT_DIR/bootstrap-reverse.sh"

UNAME_S="$(uname -s 2>/dev/null || echo unknown)"
case "$UNAME_S" in
  Darwin) PLATFORM="macos" ;;
  Linux) PLATFORM="linux" ;;
  *) echo "Unsupported platform: $UNAME_S (ensure-tools.sh only supports macOS/Linux)" >&2; exit 1 ;;
esac

ASSUME_YES=false
CHECK_ONLY=false
SCOPE="all"
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=true ;;
    --check-only) CHECK_ONLY=true ;;
    --scope=ipa|--scope=android|--scope=all) SCOPE="${arg#--scope=}" ;;
    --scope=*) echo "Invalid --scope: ${arg#--scope=} (use ipa, android, or all)" >&2; exit 2 ;;
    --help|-h)
      cat <<EOF
Usage: $0 [--yes] [--check-only] [--scope=ipa|android|all]

Checks the tools needed for authorized APK/IPA reverse engineering, offers
to install anything missing (via bootstrap-reverse.sh or Homebrew), then
prints a final ready/missing/manual report.

  --yes         auto-confirm every install prompt (no TTY interaction)
  --check-only  detect and report only; never installs anything
  --scope=      ipa | android | all (default: all)
EOF
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[36m[ensure-tools]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
missing() { printf '\033[31m[MISSING]\033[0m %s\n' "$*"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

java_ready() {
  has_cmd java || return 1
  java -version >/dev/null 2>&1
}

swift_demangle_ready() {
  has_cmd swift-demangle && return 0
  has_cmd xcrun && xcrun -f swift-demangle >/dev/null 2>&1
}

confirm() {
  local prompt="$1"
  $ASSUME_YES && return 0
  if [[ ! -t 0 && ! -r /dev/tty ]]; then
    warn "No TTY available to prompt; skipping (use --yes to auto-confirm)."
    return 1
  fi
  local reply=""
  read -r -p "$prompt [y/N] " reply </dev/tty || return 1
  [[ "$reply" =~ ^[Yy]$ ]]
}

platform_applicable() {
  local list="$1"
  [[ "$list" == "all" || ",$list," == *",$PLATFORM,"* ]]
}

scope_applicable() {
  local category="$1"
  [[ "$SCOPE" == "all" || "$category" == "common" || "$category" == "$SCOPE" ]]
}

# Parallel arrays (bash 3.2 has no associative arrays):
#   name | check-fn-name | how (bootstrap:<cap> | brew:<formula> | manual:<note>) | platforms | category (ipa|android|common)
TOOLS_NAME=(); TOOLS_CHECK=(); TOOLS_HOW=(); TOOLS_PLATFORMS=(); TOOLS_CATEGORY=()
add_tool() { TOOLS_NAME+=("$1"); TOOLS_CHECK+=("$2"); TOOLS_HOW+=("$3"); TOOLS_PLATFORMS+=("$4"); TOOLS_CATEGORY+=("$5"); }

add_tool "JDK (java)"        "java_ready"           "brew:openjdk"                                            "macos" "android"
add_tool "JDK (java)"        "java_ready"           "manual:sudo apt-get install -y default-jdk"              "linux" "android"
add_tool "jadx"               "jadx"                 "bootstrap:jadx"                                          "all"   "android"
add_tool "apktool"            "apktool"              "bootstrap:apktool"                                       "all"   "android"
add_tool "frida/frida-ps"     "frida-ps"             "bootstrap:frida-ps"                                      "all"   "common"
add_tool "adb"                "adb"                  "bootstrap:adb"                                           "all"   "android"
add_tool "r2/rabin2"          "r2"                   "bootstrap:r2"                                            "all"   "common"
add_tool "class-dump"         "class-dump"           "manual:sudo port install class-dump (MacPorts; upstream has no prebuilt binary — build from https://github.com/nygard/class-dump with Xcode if you refuse MacPorts)" "macos" "ipa"
add_tool "swift-demangle"     "swift_demangle_ready" "manual:xcode-select --install (Xcode Command Line Tools)" "macos" "ipa"
add_tool "graphviz (dot)"     "dot"                  "brew:graphviz"                                           "all"   "common"
add_tool "plantuml"           "plantuml"             "brew:plantuml"                                           "all"   "common"
add_tool "zipalign/apksigner" "zipalign"             "manual:Android SDK build-tools via sdkmanager"           "all"   "android"
add_tool "jtool2"             "jtool2"               "manual:paid — https://www.newosxbook.com/tools/jtool.html" "macos" "ipa"
add_tool "IDA Pro"            "ida"                  "manual:licensed — install from your Hex-Rays account"   "all"   "common"

is_ready() {
  local check="$1"
  case "$check" in
    java_ready) java_ready ;;
    swift_demangle_ready) swift_demangle_ready ;;
    *) has_cmd "$check" ;;
  esac
}

RESULT_NAME=(); RESULT_STATUS=()

for i in "${!TOOLS_NAME[@]}"; do
  name="${TOOLS_NAME[$i]}"
  check="${TOOLS_CHECK[$i]}"
  how="${TOOLS_HOW[$i]}"
  plats="${TOOLS_PLATFORMS[$i]}"
  category="${TOOLS_CATEGORY[$i]}"
  platform_applicable "$plats" || continue
  scope_applicable "$category" || continue

  if is_ready "$check"; then
    cmd_path=$(command -v "$check" 2>/dev/null || true)
    ok "$name - da co san${cmd_path:+ ($cmd_path)}"
    RESULT_NAME+=("$name"); RESULT_STATUS+=("ready")
    continue
  fi

  case "$how" in
    manual:*)
      warn "$name — chua co, can cai thu cong: ${how#manual:}"
      RESULT_NAME+=("$name"); RESULT_STATUS+=("manual: ${how#manual:}")
      continue
      ;;
  esac

  missing "$name — chua co"

  if $CHECK_ONLY; then
    RESULT_NAME+=("$name"); RESULT_STATUS+=("missing (check-only)")
    continue
  fi

  if confirm "Cai dat $name ngay bay gio?"; then
    case "$how" in
      bootstrap:*)
        cap="${how#bootstrap:}"
        if bash "$BOOTSTRAP" "$cap" --skip-refresh; then
          log "$name: bootstrap install finished, re-checking..."
        else
          warn "$name: bootstrap install that bai"
        fi
        ;;
      brew:*)
        formula="${how#brew:}"
        if ! has_cmd brew; then
          warn "Khong tim thay Homebrew, khong the cai $name. Cai brew truoc: https://brew.sh/"
        else
          brew install "$formula" || warn "$name: brew install that bai"
          if [[ "$formula" == "openjdk" && "$PLATFORM" == "macos" ]]; then
            export PATH="$(brew --prefix openjdk 2>/dev/null)/bin:$PATH"
            warn "openjdk cai qua brew khong tu dong lam /usr/bin/java nhan ra. De co san cho moi shell, chay: sudo ln -sfn \"\$(brew --prefix openjdk)/libexec/openjdk.jdk\" /Library/Java/JavaVirtualMachines/openjdk.jdk"
          fi
        fi
        ;;
    esac

    if is_ready "$check"; then
      ok "$name: san sang sau khi cai"
      RESULT_NAME+=("$name"); RESULT_STATUS+=("installed")
    else
      warn "$name: van chua san sang sau khi cai, can kiem tra thu cong"
      RESULT_NAME+=("$name"); RESULT_STATUS+=("failed-after-install")
    fi
  else
    warn "$name: bo qua (khong cai)"
    RESULT_NAME+=("$name"); RESULT_STATUS+=("skipped")
  fi
done

if ! $CHECK_ONLY; then
  bash "$SCRIPT_DIR/refresh-tool-index.sh" >/dev/null 2>&1 || warn "refresh-tool-index.sh that bai"
fi

echo
echo "=== Bao cao cuoi cung (APK/IPA workflow) ==="
printf '%-22s %s\n' "Tool" "Trang thai"
printf '%-22s %s\n' "----" "----------"
for i in "${!RESULT_NAME[@]}"; do
  printf '%-22s %s\n' "${RESULT_NAME[$i]}" "${RESULT_STATUS[$i]}"
done

READY_COUNT=0
TOTAL_COUNT=${#RESULT_NAME[@]}
for s in "${RESULT_STATUS[@]}"; do
  [[ "$s" == "ready" || "$s" == "installed" ]] && READY_COUNT=$((READY_COUNT + 1))
done
echo
log "San sang: $READY_COUNT/$TOTAL_COUNT"

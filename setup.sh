#!/usr/bin/env bash
# Portable installer for Codex and Claude Code skill directories.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
USER_HOME="${HOME:-$(id -P "$(id -un)" 2>/dev/null | awk -F: '{print $9}') }"
USER_HOME="${USER_HOME% }"
CODEX_DIR="${CODEX_SKILLS_DIR:-$USER_HOME/.codex/skills}"
CLAUDE_DIR="${CLAUDE_SKILLS_DIR:-$USER_HOME/.claude/skills}"
MODE="auto"
CLIENTS="both"
ACTION="setup"
STAMP="$(date +%Y%m%d-%H%M%S)"
MODULES=(mobile-reverse-router mobile-reverse apk-reverse macos-reverse reverse-engineering ghidra-reverse ida-reverse radare2 binary-diff case-review docs-generator diagram-generator)

usage() {
  cat <<'EOF'
Usage: ./setup.sh [setup|update|check|status|uninstall] [options]

Options:
  --copy                 Copy skills instead of symlinking them
  --symlink              Prefer symlinks (default on macOS/Linux)
  --clients codex|claude|both
  --codex-dir PATH       Override Codex skills directory
  --claude-dir PATH      Override Claude Code skills directory
EOF
}

log() { printf '[mobile-reverse-skill] %s\n' "$*"; }
warn() { printf '[mobile-reverse-skill] WARNING: %s\n' "$*" >&2; }
die() { printf '[mobile-reverse-skill] ERROR: %s\n' "$*" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    setup|update|check|status|uninstall) ACTION="$1"; shift ;;
    --copy) MODE="copy"; shift ;;
    --symlink) MODE="symlink"; shift ;;
    --clients) CLIENTS="${2:-}"; shift 2 ;;
    --codex-dir) CODEX_DIR="${2:-}"; shift 2 ;;
    --claude-dir) CLAUDE_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -d "$SCRIPT_DIR/skills" ]] || die "skills directory not found beside setup.sh"
case "$CLIENTS" in codex|claude|both) ;; *) die "--clients must be codex, claude, or both" ;; esac
case "$MODE" in auto) [[ "$(uname -s)" == Darwin || "$(uname -s)" == Linux ]] && MODE="symlink" || MODE="copy" ;; esac

client_dirs() {
  case "$CLIENTS" in
    codex) printf '%s\n' "$CODEX_DIR" ;;
    claude) printf '%s\n' "$CLAUDE_DIR" ;;
    both) printf '%s\n%s\n' "$CODEX_DIR" "$CLAUDE_DIR" ;;
  esac
}

marker_path() { printf '%s/.mobile-reverse-skill-%s.json\n' "$1" "$2"; }
managed_marker() {
  local parent="$1" module="$2" marker
  marker="$(marker_path "$parent" "$module")"
  [[ -f "$marker" ]] && grep -Fq '"package": "mobile-reverse-skill"' "$marker" && grep -Fq "\"module\": \"$module\"" "$marker"
}

safe_parent() {
  local p="$1"
  [[ -n "$p" && "$p" != / && "$p" != "$USER_HOME" ]] || die "unsafe destination: $p"
  mkdir -p "$p"
}

install_one() {
  local parent="$1" module="$2" source="$SCRIPT_DIR/skills/$module" target="$parent/$module" marker
  [[ -d "$source" ]] || die "module missing: $source"
  safe_parent "$parent"
  marker="$(marker_path "$parent" "$module")"
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ -L "$target" && "$(readlink "$target" 2>/dev/null || true)" == "$source" ]]; then
      rm "$target"
      [[ -f "$marker" ]] && rm "$marker"
      log "replacing managed symlink $parent/$module"
    elif managed_marker "$parent" "$module"; then
      mv "$target" "$target.backup.$STAMP"
      mv "$marker" "$marker.backup.$STAMP"
      log "staged managed copy $parent/$module for replacement"
    else
      mv "$target" "$target.backup.$STAMP"
      warn "existing $target was preserved as $target.backup.$STAMP"
    fi
  fi
  if [[ "$MODE" == symlink ]]; then
    ln -s "$source" "$target"
  else
    cp -R "$source" "$target"
    touch "$target/.mobile-reverse-skill-managed"
  fi
  cat > "$marker" <<EOF
{"package": "mobile-reverse-skill", "module": "$module", "source": "$source", "mode": "$MODE"}
EOF
}

check_one() {
  local parent="$1" module="$2" source="$SCRIPT_DIR/skills/$module" target="$parent/$module" marker
  marker="$(marker_path "$parent" "$module")"
  if [[ -L "$target" && "$(readlink "$target" 2>/dev/null || true)" == "$source" ]]; then
    log "OK symlink $target -> $source"
  elif [[ -d "$target" && -f "$marker" ]] && grep -Fq '"package": "mobile-reverse-skill"' "$marker"; then
    log "OK copy $target"
  elif [[ -e "$target" || -L "$target" ]]; then
    warn "unmanaged or stale destination: $target"
  else
    warn "missing $target"
  fi
}

uninstall_one() {
  local parent="$1" module="$2" target="$parent/$module" marker="$(marker_path "$parent" "$module")" removed="$parent/$module.removed.$STAMP"
  if [[ -L "$target" && "$(readlink "$target" 2>/dev/null || true)" == "$SCRIPT_DIR/skills/$module" ]]; then
    rm "$target"
    log "removed symlink $target"
  elif [[ -d "$target" && -f "$marker" ]] && grep -Fq '"package": "mobile-reverse-skill"' "$marker"; then
    mv "$target" "$removed"
    log "moved managed copy to $removed"
  else
    warn "skipped unmanaged destination: $target"
  fi
  [[ -f "$marker" ]] && rm "$marker"
}

case "$ACTION" in
  setup|update)
    while IFS= read -r parent; do
      for module in "${MODULES[@]}"; do install_one "$parent" "$module"; done
    done < <(client_dirs)
    log "$ACTION complete ($MODE mode); canonical source is $SCRIPT_DIR"
    ;;
  check|status)
    while IFS= read -r parent; do
      log "checking $parent"
      for module in "${MODULES[@]}"; do check_one "$parent" "$module"; done
    done < <(client_dirs)
    ;;
  uninstall)
    while IFS= read -r parent; do
      for module in "${MODULES[@]}"; do uninstall_one "$parent" "$module"; done
    done < <(client_dirs)
    log "uninstall complete; unrelated skills were not touched"
    ;;
esac

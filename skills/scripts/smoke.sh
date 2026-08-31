#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
bash -n "$ROOT/setup.sh" "$ROOT/bin/mobile-reverse" "$ROOT/skills/scripts/master-route.sh" "$ROOT/skills/scripts/case-init.sh" "$ROOT/skills/scripts/case-guard.sh" "$ROOT/skills/scripts/refresh-tool-index.sh"
python3 -m json.tool "$ROOT/skills/config/routing.json" >/dev/null
python3 "$ROOT/skills/scripts/check-links.py"
bash "$ROOT/skills/scripts/test-routing.sh"
echo 'Smoke checks: PASS'

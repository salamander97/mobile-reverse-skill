#!/usr/bin/env python3
"""Check relative Markdown links that point inside this repository."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
bad = []
for path in root.rglob("*.md"):
    if any(part in {".git", "work"} for part in path.parts):
        continue
    for raw in re.findall(r"\[[^]]+\]\(([^)]+)\)", path.read_text(encoding="utf-8", errors="ignore")):
        target = raw.split("#", 1)[0].strip().strip("<>")
        if not target:
            continue
        target = target.split()[0]
        if not target or target.startswith(("http:", "https:", "mailto:")):
            continue
        candidate = (path.parent / target).resolve()
        if candidate.is_relative_to(root) and not candidate.exists():
            bad.append(f"{path.relative_to(root)}: {raw}")
if bad:
    print("Broken internal Markdown links:\n" + "\n".join(bad))
    sys.exit(1)
print("Internal Markdown links: OK")

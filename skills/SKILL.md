---
name: mobile-reverse-router
description: Use as the umbrella entrypoint when an authorized mobile reverse-engineering task spans Android/iOS, native binaries, runtime instrumentation, decompilers, or reporting.
---

# Mobile Reverse Skill Router

This is the umbrella skill. Route first, then open the selected specialist
skill; do not guess a tool or skip the authorization case gate.

```text
task → skills/config/routing.json → master-route → case-init/case-guard
     → specialist SKILL.md → tool-index → evidence → report
```

Primary specialist modules:

- `mobile-reverse` — Android/iOS methodology, Frida, Objection, device work
- `apk-reverse` — APK/AAB/DEX, JADX, apktool, smali, JNI handoff
- `macos-reverse` — Mach-O, app bundles, Objective-C/Swift, signing
- `reverse-engineering` — ELF/ARM/native triage and general RE workflow
- `ghidra-reverse` — open-source decompiler and headless analysis
- `ida-reverse` — licensed IDA Pro deep analysis
- `radare2` — r2/rabin2/radiff2/rizin-style CLI triage
- `binary-diff` — cross-version native binary comparison and symbol migration
- `case-review`, `docs-generator`, `diagram-generator` — evidence and delivery

On macOS/Linux:

```bash
bash skills/scripts/master-route.sh --hint "analyze an arm64 JNI library from an APK"
bash skills/scripts/case-init.sh --hint "offline APK sample" --case-name demo \
  --preset offline-sample --sample ./app.apk
```

On Windows, use the matching `.ps1` entrypoints. Installed clients discover
the same specialist directories independently, so agents may invoke a
specialist directly after routing.

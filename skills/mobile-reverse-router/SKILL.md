---
name: mobile-reverse-router
description: Use as the umbrella entrypoint when an authorized mobile reverse-engineering task spans Android/iOS, native binaries, runtime instrumentation, decompilers, or reporting.
---

# Mobile Reverse Skill Router

Route first, then open the selected specialist skill; never guess a tool or
skip the authorization case gate.

```text
task → config/routing.json → master-route → case-init/case-guard
     → specialist SKILL.md → tool-index → evidence → report
```

Use `mobile-reverse` for the Android/iOS methodology, `apk-reverse` for
APK/AAB/DEX, `macos-reverse` for Mach-O and Apple bundles,
`reverse-engineering` for ELF/ARM/JNI, and `ghidra-reverse`, `ida-reverse`,
or `radare2` for the chosen native analyzer. Finish with `case-review` and
`docs-generator`.

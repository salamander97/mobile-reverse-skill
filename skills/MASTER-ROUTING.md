# Master routing

`skills/config/routing.json` is the single source of truth. The native
`master-route` scripts read it; this table is a human-readable mirror.

## Route order

| ID | Signal | Primary skill |
|---|---|---|
| **R1** | APK, AAB, DEX, JADX, apktool, smali, Android | `apk-reverse/` |
| **R2** | IPA, iOS, Swift, Objective-C, Frida, Objection, mobile runtime | `mobile-reverse/` |
| **R3** | Mach-O, macOS app, framework, dylib, codesign | `macos-reverse/` |
| **R4** | Ghidra, headless decompile, open-source decompiler | `ghidra-reverse/` |
| **R5** | IDA, IDA Pro, idalib | `ida-reverse/` |
| **R6** | radare2, r2, rizin, rabin2, radiff2 | `radare2/` |
| **R7** | BinDiff, bindiff, symbol migration, binary diff | `binary-diff/` |
| **R8** | ELF, ARM, ARM64, ARM64e, JNI, native, reverse engineering | `reverse-engineering/` |
| **R9** | case, evidence, fixity, traceability review | `case-review/` |
| **R10** | report, writeup, findings handoff | `docs-generator/` |
| **R11** | Mermaid, Graphviz, PlantUML, diagram | `diagram-generator/` |

The first matching route wins according to the configured priority after
keyword scoring. Ambiguous tasks should read `skills/routing.md` and open
both the primary and the explicitly named handoff skill.

## Mandatory sequence

1. Route with the native script.
2. Initialize `work/<case>/scope.md` in the caller's project.
3. Require authorization and an explicit asset before target-facing ACT.
4. Read the primary `SKILL.md` and `skills/tool-index.md`.
5. Record evidence and finish with case review/reporting.

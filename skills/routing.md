# Routing matrix

| Task clue | Primary | Useful sidecars |
|---|---|---|
| APK/AAB unpacking, manifest, smali, JADX | `apk-reverse` | `mobile-reverse`, `reverse-engineering` |
| DEX/JNI/`.so`, ARM or ARM64 native library | `reverse-engineering` | `ghidra-reverse`, `ida-reverse`, `radare2` |
| IPA, Swift/ObjC, iOS frameworks and dylibs | `mobile-reverse` | `macos-reverse`, native specialist |
| Mach-O or macOS app signing/runtime | `macos-reverse` | `mobile-reverse` for iOS |
| Frida/Objection/SSL pinning/device runtime | `mobile-reverse` | `apk-reverse` for Android Java hooks |
| Ghidra batch/headless | `ghidra-reverse` | `binary-diff` |
| IDA Pro or idalib | `ida-reverse` | `binary-diff` |
| r2/rabin2/radiff2/rizin | `radare2` | `reverse-engineering` |
| Version-to-version native comparison | `binary-diff` | chosen decompiler |
| Validate case artifacts | `case-review` | `docs-generator` |
| Produce a security/reverse report | `docs-generator` | `diagram-generator`, `case-review` |

The router is intentionally narrow. Web, cloud, AD, firmware, malware, and
general pentest playbooks are not bundled as hidden transitive dependencies.
Use a dedicated repository for those domains.

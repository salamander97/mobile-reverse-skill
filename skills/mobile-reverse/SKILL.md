---
name: mobile-reverse
description: Use for authorized Android or iOS application reverse engineering and mobile security testing. Routes APK/AAB/DEX, IPA/Mach-O, JNI/native, Frida, ADB, LLDB, and OWASP MASTG work to the right specialist playbook.
---

# Mobile Reverse Engineering

## ACTION REQUIRED

1. Read `../ops/scope-contract.md` and confirm the sample/device/target is in
   an authorized scope. For a local file, use the offline-sample case preset.
2. Read `../field-journal/precedent-reverse.md`.
3. Read `../tool-index.md`; use detected paths and report missing tools.
4. Identify the artifact before choosing commands: APK/AAB/DEX, native ELF,
   IPA/app bundle, Mach-O, framework, dylib, or a live authorized device.
5. Start with the workflow below and record commands, hashes, and findings in
   the case directory.

## Routing map

| Signal | Primary | Handoff |
|---|---|---|
| APK, AAB, DEX, manifest, resources, smali, Java/Kotlin | `../apk-reverse/` | JNI `.so` → `../ghidra-reverse/`, `../ida-reverse/`, or `../radare2/` |
| IPA, iOS, Swift, Objective-C, framework, dylib, Mach-O | this skill | native binary → `../macos-reverse/` and a native specialist |
| Frida, Objection, SSL pinning, root/jailbreak detection | this skill | use only after scope/device authorization |
| ELF, JNI, ARM/ARM64, ARM64e, stripped native code | `../reverse-engineering/` | choose Ghidra/IDA/radare2 based on availability |
| Ghidra batch/decompiler | `../ghidra-reverse/` | `../binary-diff/` for version comparison |
| IDA Pro deep analysis | `../ida-reverse/` | requires the user's valid license |
| radare2/rizin CLI triage | `../radare2/` | use `r2`, `rabin2`, `radiff2`, or rizin equivalents |
| Evidence review or final report | `../case-review/` / `../docs-generator/` | diagrams → `../diagram-generator/` |

## Artifact-first workflow

### Android: APK / AAB / DEX / JNI

1. Hash the artifact and record package metadata without installing it.
2. For APK, inspect manifest, signing, permissions, exported components,
   resources, DEX files, and `lib/*/{armeabi-v7a,arm64-v8a,x86,x86_64}/*.so`.
3. For AAB, inspect modules and split metadata; use `bundletool` only when
   the authorized test needs generated APKs. Treat generated splits as new
   evidence and hash them.
4. Use JADX for Java/Kotlin context, apktool for resources/smali, and
   baksmali/smali or dex tools when bytecode-level work is necessary.
5. For JNI/native code, triage ELF headers, architecture, imports, strings,
   symbols, and relocations before a decompiler. Keep ARM/ARM64 register and
   ABI assumptions explicit.
6. Dynamic work uses ADB + Frida/Objection on an authorized device or
   emulator. Capture the exact package, process, script, and device serial.

### iOS: IPA / app bundle / Mach-O

1. Hash the IPA and inspect `Info.plist`, entitlements, provisioning/signing,
   embedded frameworks, dylibs, architectures, and minimum OS metadata.
2. Use `otool`, `nm`, `codesign`, `class-dump`/`dsdump`, `swift-demangle`, and
   a decompiler as available. Distinguish arm64 from arm64e and note pointer
   authentication implications.
3. Trace Objective-C selectors, Swift metadata, URL schemes, ATS, keychain,
   filesystem, and network surfaces without exposing secrets in reports.
4. For authorized runtime analysis, use LLDB and Frida. Record device state,
   signing state, launch mode, and any jailbreak/Frida assumptions.

## Tool handoff

Read `../tool-index.md` before invoking a tool. The pack recognizes JADX,
apktool, bundletool, dex2jar, smali/baksmali, ADB, Frida, Objection, Ghidra,
IDA Pro, radare2/rizin, LLDB, Hopper, class-dump, jtool2, otool, nm,
codesign, swift-demangle, dsymutil, zipalign, and apksigner. Availability is
machine-specific; documentation does not install or license them.

## Purchase and billing flow

When the goal is to understand a purchase, payment, subscription, receipt, or
entitlement flow in an authorized APK or IPA, follow the detailed playbook in
`references/purchase-billing-analysis.md`. It explains how to move from
keywords to the UI entrypoint, product catalog, transaction result, network
verification, and final entitlement without confusing an SDK string with real
business logic. Dynamic examples are observation-only and must use a test
account, sandbox product, and an authorized device.

## Safety and handoff

Do not use bypass examples against third-party apps or devices. For any
dynamic action, stop when the case gate is not ready. Before closing, run the
case review, preserve hashes, and write conclusions as Evidence → Finding →
Path.

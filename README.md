<div align="center">

# Mobile Reverse Skill

Portable Android/iOS reverse-engineering skills for Codex and Claude Code.

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-2563eb)](docs/PLATFORMS.md)
[![Clients](https://img.shields.io/badge/AI%20clients-Codex%20%7C%20Claude-7c3aed)](README_AI.md)
[![License](https://img.shields.io/badge/license-MIT-16a34a)](LICENSE)
[![Upstream](https://img.shields.io/badge/upstream-attributed-f59e0b)](NOTICE)

**English · [Tiếng Việt](README_VI.md) · [日本語](README_JA.md)**

</div>

## Contents

- [What it is](#what-it-is)
- [Features](#features)
- [Architecture](#architecture)
- [Quick start](#quick-start)
- [Using with Codex](#using-with-codex)
- [Using with Claude Code](#using-with-claude-code)
- [Bundled modules](#bundled-modules)
- [Tool matrix](#tool-matrix)
- [Usage](#usage)
- [Install lifecycle](#install-lifecycle)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [Attribution and license](#attribution-and-license)

## What it is

This repository packages a focused, client-neutral skill set for authorized
mobile application analysis. It routes an artifact to the right playbook,
keeps tool discovery machine-specific, and leaves the actual third-party
toolchain under the user's control.

It covers APK/AAB/DEX, JADX, apktool, smali, JNI, ELF, ARM/ARM64, IPA,
Mach-O, Swift/Objective-C, frameworks, dylibs, ARM64e, Ghidra, IDA Pro,
radare2/rizin, Frida, ADB, LLDB, binary diff, evidence review, and reporting.

## Features

- One discoverable `mobile-reverse-router` umbrella plus independently discoverable specialist skills.
- Global install for `~/.codex/skills` and `~/.claude/skills`.
- Symlink-first on macOS/Linux; copy/junction fallback on Windows.
- Idempotent setup with exact-target backups and recoverable uninstall moves.
- Native Bash and PowerShell routing/case/tool-index entrypoints.
- No hard-coded machine path; no bundled credentials or commercial binaries.
- English, Vietnamese, and Japanese project documentation.

## Architecture

```text
task → config/routing.json → master-route → case-init / case-guard
     → specialist SKILL.md → tool-index → evidence → case-review → report
```

The router is driven only by `skills/config/routing.json`. `MASTER-ROUTING.md`
is its human-readable mirror. The installer places each module separately so
Codex and Claude Code can discover or invoke specialists directly.

## Quick start

```bash
git clone https://github.com/salamander97/mobile-reverse-skill.git
cd mobile-reverse-skill
bash setup.sh
bash skills/scripts/refresh-tool-index.sh
```

Windows PowerShell:

```powershell
.\setup.ps1
powershell -File .\skills\scripts\refresh-tool-index.ps1
```

The setup command installs only this pack. It does not install JADX, Frida,
Ghidra, IDA, or any other external tool.

## Using with Codex

Run `bash setup.sh` once from the checkout. The installer makes every module
discoverable under `~/.codex/skills/<module-name>/SKILL.md`, so it can be used
from any working directory. Restart Codex after the first installation if the
skills directory did not exist when the session started.

Use the umbrella skill for normal work:

```text
$mobile-reverse-router
Analyze my authorized arm64 JNI library extracted from an APK.
First route the task, check the case scope, and report which local tools are available.
```

Specialists can be called directly when the task is already clear:
`$apk-reverse`, `$mobile-reverse`, `$macos-reverse`, `$ghidra-reverse`,
`$ida-reverse`, `$radare2`, `$binary-diff`, `$case-review`,
`$docs-generator`, or `$diagram-generator`.

The recommended workflow is still to route the task, initialize a case in the
caller project, pass `case-guard`, read the selected `SKILL.md` and
`tool-index.md`, then hand off evidence to `case-review` and reporting.

## Using with Claude Code

Run `bash setup.sh` once from the checkout. The installer makes every module
discoverable under `~/.claude/skills/<module-name>/SKILL.md`, so it can be used
from any project directory. Restart Claude Code after the first installation
if the top-level skills directory did not exist when the session started.

In an interactive Claude Code session, invoke the umbrella skill with its
slash command:

```text
/mobile-reverse-router
Analyze my authorized iOS IPA. First route the task and check the case scope.
```

The direct specialist commands are `/apk-reverse`, `/mobile-reverse`,
`/macos-reverse`, `/ghidra-reverse`, `/ida-reverse`, `/radare2`,
`/binary-diff`, `/case-review`, `/docs-generator`, and `/diagram-generator`.
Claude Code can also load a skill automatically when the task matches its
description. See the [Claude Code skills documentation](https://code.claude.com/docs/en/slash-commands)
for the current slash-command and automatic-discovery behavior.

The same repository workflow applies in Claude Code: route first, initialize
the case in the project being analyzed, pass the authorization gate before
dynamic or target-facing work, and use the tool index before selecting tools.

## Bundled modules

| Module | Role |
|---|---|
| `mobile-reverse-router` | Umbrella route and handoff entrypoint |
| `mobile-reverse` | Android/iOS workflow, runtime instrumentation, MASTG |
| `apk-reverse` | APK/AAB/DEX, JADX, apktool, smali and rebuild helpers |
| `macos-reverse` | Mach-O, signing, Objective-C/Swift and app bundles |
| `reverse-engineering` | ELF/ARM/native triage and deeper RE references |
| `ghidra-reverse` | Ghidra GUI/headless workflow |
| `ida-reverse` | IDA Pro workflow; valid license required |
| `radare2` | r2/rabin2/radiff2 and rizin-compatible triage |
| `binary-diff` | Function matching and cross-version symbol migration |
| `case-review` | Evidence, hashes, fixity and traceability |
| `docs-generator` | Security/reverse-engineering reports |
| `diagram-generator` | Mermaid, Graphviz and PlantUML support |

## Tool matrix

| Layer | Tools |
|---|---|
| Android static | JADX, apktool, bundletool, dex2jar, smali/baksmali, zipalign, apksigner |
| Android runtime | ADB, Frida, frida-ps, Objection |
| Apple static | otool, nm, codesign, class-dump/dsdump, jtool2, swift-demangle, dsymutil |
| Apple runtime | LLDB, Frida |
| Native | Ghidra, IDA Pro, radare2, rizin, rabin2, radiff2 |
| Delivery | Python 3, Graphviz, PlantUML |

Run the tool index to see availability and resolved paths for the current
machine. Missing tools are reported with install hints; they are not silently
installed.

## Usage

Route from any working directory (using the checkout path):

```bash
bash /path/to/mobile-reverse-skill/bin/mobile-reverse route \
  "inspect an arm64 JNI library extracted from an APK"
```

Or call the source directly:

```bash
bash skills/scripts/master-route.sh --hint "analyze an authorized iOS IPA"
bash skills/scripts/case-init.sh --hint "offline APK" --case-name demo \
  --preset offline-sample --sample ./app.apk
bash skills/scripts/case-guard.sh --case-root work/demo
```

Examples and handoffs live in [`skills/mobile-reverse/SKILL.md`](skills/mobile-reverse/SKILL.md).
Dynamic device work and traffic interception require explicit authorization.

### Finding purchase and billing logic

For an APK or IPA, do not search one keyword and assume you found the purchase
check. Start with the end-to-end chain:

```text
screen/button → productId/sku → purchase API → transaction/receipt/token
→ server verification → entitlement/premium state → feature gate
```

Search the decoded Android sources or extracted Apple binary for:
`purchase`, `payment`, `pay`, `billing`, `checkout`, `order`, `subscription`,
`premium`, `entitlement`, `receipt`, `productId`, `sku`, `verifyPurchase`,
`payload`, `signature`, and `transaction`. Then follow callers and network
requests to determine which hits are real business flow, SDK code, dead code,
or only localized text. The detailed step-by-step playbook, including APK and
IPA commands and an evidence checklist, is
[`purchase-billing-analysis.md`](skills/mobile-reverse/references/purchase-billing-analysis.md).

## Install lifecycle

```bash
bash setup.sh check
bash setup.sh update
bash setup.sh uninstall
```

Useful options:

```bash
bash setup.sh --copy --clients codex
CODEX_SKILLS_DIR=/custom/codex/skills bash setup.sh update
```

On Windows, use `setup.ps1 -Action check|update|uninstall -Copy` and set
`CODEX_SKILLS_DIR`/`CLAUDE_SKILLS_DIR` when a client uses a non-default path.

`update` refreshes installations from the current checkout. Pull or replace
the checkout separately, then run `update`. Existing same-name destinations
are moved to timestamped `.backup.*` paths before replacement.

## Troubleshooting

- **Skill missing in a client:** run `setup.sh check`, confirm the client's
  skills directory, then use `--copy` if links are restricted.
- **Tool marked unavailable:** refresh `tool-index`; inspect the install hint
  and verify the executable is on `PATH`.
- **Router writes under the wrong folder:** pass `--project-root` to the
  router or run it from the analysis project. Skill source remains read-only.
- **Case gate not ready:** set authorization and an in-scope asset; for a
  local file use `--preset offline-sample --sample ...`.
- **IDA/JEB absent:** continue with Ghidra or radare2; do not bypass licenses.

## Security

Use this pack only for apps, devices, binaries, and services you own or are
authorized to assess. Keep extracted apps, tokens, device logs, Frida scripts,
and reports private. Do not commit secrets, proprietary samples, credentials,
or live-target data. A route never grants permission, and `case-guard` must
pass before dynamic or target-facing actions.

## Attribution and license

Selected/adapted playbooks and helper material originate from
[`zhaoxuya520/reverse-skill`](https://github.com/zhaoxuya520/reverse-skill) at
commit `71acc8e3115f76bad7a914c36466c1086232288c`. Attribution and the exact
upstream MIT text are in [`NOTICE`](NOTICE) and
[`THIRD_PARTY_NOTICES/reverse-skill-LICENSE.txt`](THIRD_PARTY_NOTICES/reverse-skill-LICENSE.txt).
This repository's integration code and documentation are MIT licensed.

Contributions should follow [`CONTRIBUTING.md`](CONTRIBUTING.md). This project
does not configure Git remotes or push changes automatically.

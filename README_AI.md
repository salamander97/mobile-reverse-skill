# AI bootstrap

This file is the compact entrypoint for Codex, Claude Code, and compatible
agents. Resolve the directory containing this file as `<SKILL_ROOT>`; do not
assume a fixed installation path.

## Client usage

After running `setup.sh` (or `setup.ps1` on Windows), the pack is available
globally from any working directory:

- Codex: call `$mobile-reverse-router`, or a specialist such as
  `$apk-reverse`, `$ghidra-reverse`, `$ida-reverse`, `$radare2`,
  `$case-review`, or `$docs-generator`.
- Claude Code: call `/mobile-reverse-router`, or the corresponding specialist
  command such as `/apk-reverse`, `/ghidra-reverse`, `/ida-reverse`,
  `/radare2`, `/case-review`, or `/docs-generator`.

The umbrella skill is the preferred first entrypoint. A typical prompt is:

```text
Route my authorized mobile reverse-engineering task, verify the case scope,
check the local tool index, and hand off to the correct specialist skill.
```

If the client was already running before its global skills directory was
created, restart that client once so it discovers the newly installed pack.

1. Run `bash <SKILL_ROOT>/skills/scripts/refresh-tool-index.sh` on macOS/Linux
   or the PowerShell equivalent on Windows.
2. Route with `master-route` using the user's task text.
3. Initialize the caller project with `case-init` and pass the authorization
   gate before any dynamic or target-facing action.
4. Open the route's `SKILL.md`, then consult the tool index and references it
   names.
5. Record evidence and hand off through `case-review` and `docs-generator`.

The installed skills are discoverable independently. The umbrella
`mobile-reverse-router` skill is the usual entrypoint; specialist skills remain
separate so an agent can call `apk-reverse`, `ghidra-reverse`, `ida-reverse`,
`radare2`, or `binary-diff` directly when the route selects them.

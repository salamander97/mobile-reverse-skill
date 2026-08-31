# Mobile Reverse Skill — agent guidance

This repository is a portable, client-neutral skill pack for **authorized**
Android and iOS application analysis. `skills/config/routing.json` is the
single source of truth for routing.

## Required reading order

1. Route the task with the native launcher in `skills/scripts/`.
2. Initialize a case in the caller's project with `case-init`.
3. Do not perform target actions until `scope.md` grants authorization and
   gives a network profile or an explicit offline sample.
4. Open the selected specialist `SKILL.md` and follow its ACTION REQUIRED
   section.
5. Use `skills/tool-index.md` for detected paths; never guess tool locations.
6. Preserve Evidence → Finding → Path traceability in reports.

The package contains playbooks and adapters, not the third-party tools. Never
download commercial software or bypass licenses. Treat samples and extracted
data as sensitive.

## Change discipline

- Keep the routing configuration and generated priority table in sync.
- Keep Bash and PowerShell entrypoints behaviorally equivalent.
- Test from a directory outside the repository before committing installer
  changes.
- Do not add credentials, device dumps, proprietary apps, or live targets.

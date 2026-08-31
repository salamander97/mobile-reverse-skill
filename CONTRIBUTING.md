# Contributing

Keep changes focused on portable routing, client-neutral playbooks, or
cross-platform installation. Add a route only when a specialist workflow is
needed and update `skills/config/routing.json`, `skills/MASTER-ROUTING.md`,
and the benchmark together.

Before opening a pull request, run:

```text
bash skills/scripts/test-routing.sh
bash skills/scripts/smoke.sh
python3 skills/scripts/check-links.py
```

On Windows, run the PowerShell parity checks as well. Never commit samples,
credentials, private MCP configuration, or proprietary tool binaries.

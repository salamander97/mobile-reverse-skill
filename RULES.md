# Rules for authorized analysis

This pack is for applications, devices, binaries, and services you are
authorized to inspect. A route is a methodology decision, not permission.

Before ACT:

1. Run `case-init` in the **caller project**, not inside the installed skill
   source.
2. Confirm `auth.status: granted`, an explicit in-scope asset, and a valid
   `network_profile` (or use the offline-sample preset for a local file).
3. Run `case-guard`. If it is not ready, stop target actions.
4. Prefer read-only collection and preserve hashes, timestamps, and commands.

Never use these skills to bypass access controls, steal credentials, evade
licensing, or operate on an out-of-scope target. Commercial tools such as IDA
Pro, JEB, and Hopper must be installed and licensed by their owner.

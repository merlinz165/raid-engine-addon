# Raid Engine AddOn

Raid Engine AddOn is the in-game World of Warcraft client for Raid Engine. The
project was formally initiated on 2026-08-26.

Its first release is intentionally thin:

- capture the current player's class, specialization, talents, selected abilities,
  and equipment as a versioned `PlayerLoadoutSnapshot`;
- capture permitted official Encounter Timeline and minimal Raid Night context;
- import a raid-leader-confirmed plan package and show personal tasks/reminders;
- export bounded SavedVariables evidence for later review by Raid Engine Core.

The AddOn does not perform protected gameplay actions, make raid-leader decisions,
contain Core analysis, call LLM providers, store WCL/cloud credentials, implement
billing, or carry a large knowledge database. It is free, source-visible, and
unobfuscated; the exact open-source license remains undecided.

Contract authority remains in `raid-engine/packages/contracts/schema`. This
repository consumes generated Lua validators/types and compatibility fixtures; it
must reject incompatible, altered, expired, or unconfirmed packages.

The adopted project charter is:

`raid-engine/docs/project/raid-engine-addon-project-charter-2026-08-26.md`

Implementation has not started. Documentation approval and repository creation do
not constitute a tested or releasable AddOn.

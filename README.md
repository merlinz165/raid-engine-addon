# Raid Engine AddOn

Raid Engine AddOn is the in-game World of Warcraft client for Raid Engine. The
project was formally initiated on 2026-08-26.

Its first release is intentionally thin:

- capture the current player's class, specialization, talents, action-bar selected abilities,
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

## Current implementation status

The first vertical slice has started. `RaidEngine.toc` and the Lua modules provide
bounded JSON encoding/decoding, explicit participation/roster binding, local
`PlayerLoadoutSnapshot` capture, bounded official Encounter Timeline event capture
into SavedVariables, export caching, and import of confirmed `ExecutionSnapshot`
plan packages. Invalid, altered, expired, or unconfirmed packages are rejected and
no protected gameplay action is performed.

`pnpm test` runs LuaJIT syntax checks plus a small behavior suite. These checks are
not a substitute for the charter's real WoW client loadout, round-trip, and
reload/relogin acceptance gates. The AddOn's local checksum only detects local
SavedVariables tampering; Core must re-address imported snapshots with the
canonical SHA-256 contract pipeline before persistence.

In game, bind the activity context before capture:

`/raidengine bind <participation_id> <roster_snapshot_id> <sha256:...>`

Then use `/raidengine capture` and `/raidengine export`. The resulting
`last_loadout_export` SavedVariable can be passed to the main repository's
`pnpm import:addon-loadout` command. During an encounter the AddOn records only
bounded, de-identified official timeline lifecycle and duration events under
`timelineLog`; inspect with `/raidengine timeline`, then provide the SavedVariables
file to Core's `pnpm extract-official-timeline-batch` command. Confirmed plan
packages are imported with `/raidengine import <JSON>` and are displayed only; the
AddOn never auto-casts, moves, or changes a confirmed plan.

When an activity binding is present, the AddOn also captures the current player's
Loadout automatically at `ENCOUNTER_START`, replaces `last_loadout`, and refreshes
`last_loadout_export`. Manual `/raidengine capture` remains available when a fresh
snapshot is needed outside an encounter; automatic capture never performs a
protected gameplay action.

Action-bar spell IDs are captured as a bounded selected-ability observation. This
is intentionally `PARTIAL`: passive abilities, unbound spells, and the complete
talent graph still require Core's governed official data and are not inferred by
the AddOn. Activity bindings and imported contract references now require the
canonical lowercase `sha256:` plus 64 hexadecimal characters; malformed or
uppercase references are rejected before capture or display. Imported plan
timestamps must also be complete UTC (`...Z`) values with valid bounded date/time
components; malformed expiry windows are rejected before display.

Plan expiry comparisons now normalize the current UTC clock through the same
structured time key as `effective_from`/`effective_until`, so future-dated
confirmed plans are not rejected by a representation mismatch.

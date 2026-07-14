# KA/notes

Git-tracked personal notes for the KAutomate workspace — a safety net so plans
and working docs survive cleanups (the per-repo `docs.user/` dirs are gitignored
and get wiped).

## Layout

```
_workspace/            cross-cutting notes + real CLAUDE.local.md content
  claude-instructions.md   <- imported by KA/automate/CLAUDE.local.md
<Solution>/            solution-specific notes, e.g. Service.ExternalData/
  claude-notes.md          <- imported by that solution's CLAUDE.local.md (when present)
```

## CLAUDE.local.md indirection

`CLAUDE.local.md` auto-loads only from an ancestor of cwd, so those files must stay
in place under `KA/automate/…`. They are kept as thin `@import` stubs pointing here;
all real content lives in this repo. If a stub breaks it fails silently — verify a
session still loads the instructions after editing one.

Stubs:
- `KA/automate/CLAUDE.local.md` → `@../notes/_workspace/claude-instructions.md`
- `KA/automate/Service.ExternalData/CLAUDE.local.md` → `@../CLAUDE.local.md` +
  `@../../notes/Service.ExternalData/claude-notes.md`

## Active-work index (`_workspace/ACTIVE.md`)

`_workspace/ACTIVE.md` is a **generated** table of contents of in-flight efforts, so
that from any solution session (cwd never leaves its solution dir) you still see what's
live across the whole workspace. It's auto-imported by `claude-instructions.md`, so it
loads into every session.

It has two sections: **Active work** (things needing action) and **Resolved — pending
verification** (code-complete, merged, and pushed, but held pending support-team
verification since feedback could still reopen them). Both are driven purely by
frontmatter `status:` — see status routing below.

**Don't edit `ACTIVE.md` by hand** — it's overwritten. The source of truth is each
note's YAML frontmatter:

```yaml
---
title: Short effort name
status: blocked-on-e2e      # free-form; routes the note — see "Status routing" below
solutions: [Service.ExternalData, Service.Automation]
updated: 2026-07-08
resume: path/or/branch to pick up from
feature: some-feature-slug  # optional; groups this doc in FEATURES.md
---
```

**Status routing** — `status:` is free-form, but its lowercased value routes the note
into one of three buckets:

- `done` / `archived` / `complete` / `completed` → **dropped** from the index (terminal).
- one of the *resolved* statuses — `verifying`, `merged-pending-verification`,
  `pending-verification` → **Resolved — pending verification** section.
- anything else → **Active work** section.

To add a resolved status, extend `$resolvedStatuses` in `regen-active.ps1` (and this list).

Workflow:
- **Add an effort** → create/tag a note with the frontmatter above. Cross-solution
  efforts live in `_workspace/`; single-solution in `<Solution>/`. When something started
  in one solution grows cross-solution, move its tracker to `_workspace/` and leave a
  one-line breadcrumb pointer in the origin `<Solution>/`.
- **Resolve an effort** → once merged & pushed but awaiting verification, set a resolved
  status (e.g. `merged-pending-verification`); it moves to the **Resolved** section rather
  than staying in Active or being deleted.
- **Retire an effort** → set `status: done` (or `archived`/`complete`/`completed`) in its
  note; next regen drops it from the index.
- **Prune retired notes** → a `done`/`archived` note is a historical artifact, not live
  working memory, and it rots (stale symbol refs, unreviewed). Once its commit has merged,
  **delete the note** — git history + the commit message are the durable record. Do this on
  a cadence, or whenever you next touch that solution's notes. Exceptions worth keeping until
  the work lands: a note that captures *decisions and rejected alternatives* the commits don't
  (e.g. a multi-approach reanalysis); fold any one-off "why" into the commit/code first.

### Feature index (`_workspace/FEATURES.md`)

`_workspace/FEATURES.md` is a second **generated** index, on an axis orthogonal to status:
it groups docs by a `feature:` frontmatter key so a cross-solution effort's scattered docs
(umbrella + detail/design/plan across solution dirs) appear together, with clickable links.
It's the "all docs/statuses of one feature" view and a lateral-navigation hub. Like
`ACTIVE.md` it's overwritten on regen — **don't edit it by hand**.

Two independent axes drive the two indexes:

| Frontmatter | Drives | Put it on |
|-------------|--------|-----------|
| `status:`   | `ACTIVE.md` (one row per effort) | the single tracker/STATUS doc |
| `feature:`  | `FEATURES.md` (all member docs)  | every member doc of a feature |

- `feature:` is a kebab-case slug (its own identity — no registry); docs sharing a slug are
  one feature. It accepts a list (`feature: [a, b]`) for multi-membership.
- A companion design/plan doc carries `feature:` **alone** (no `status:`) so it shows in
  `FEATURES.md` for navigation without adding a row to `ACTIVE.md`.
- A terminal `status:` drops a doc from **both** indexes.
- `FEATURES.md` is a human/VSCode aid and is **not** imported into Claude sessions.

### `regen-active.ps1`

Rebuilds `ACTIVE.md` and `FEATURES.md` from frontmatter. Safe to run anywhere (no-ops if this repo path is
absent); writes no timestamp, so `ACTIVE.md` only changes when efforts change. It never
commits — commit when you want. Run manually with:

```powershell
pwsh -NoProfile -File D:\senften\work\KA\notes\regen-active.ps1
```

It also runs automatically via a **`Stop` hook** in `~/.claude/settings.json`, which fires
at the end of every Claude Code turn (async, error-swallowed, global but self-guarding).
So `ACTIVE.md` stays current without manual regen. If it ever goes stale, open `/hooks`
once (or restart) to reload the hook config.

## Reusing this structure in another project

This repo doubles as a **template** for git-tracked, generator-indexed notes. The reusable
skeleton is three files (plus scaffolding); everything else is content.

**Keep (the skeleton):**
- `README.md` — this file (operational mechanics + the reuse guide).
- `DESIGN.md` — the design rationale (why it's built this way).
- `regen-active.ps1` — the generator.
- `_workspace/claude-instructions.md` — the session-loaded conventions.
- `.gitignore`, and the empty `_workspace/` + per-`<Solution>/` directory shape.

**Strip (the content):** every per-effort note — trackers/STATUS/design/plan docs under
`_workspace/` and the `<Solution>/` dirs. The generated `ACTIVE.md`/`FEATURES.md` are derived,
so they come back empty (`_(none)_`) on the first regen; no need to clean them by hand.

**Re-point:**
1. Set `$root` at the top of `regen-active.ps1` to the new clone's absolute path.
2. Update the `Stop` hook in `~/.claude/settings.json` (or drop it) to target the new path.
3. Fix the `@import` stub paths (see "CLAUDE.local.md indirection" above) so the new project's
   in-place `CLAUDE.local.md` chains to this clone's `_workspace/claude-instructions.md`.

## Design

See [`DESIGN.md`](DESIGN.md) for the rationale, key decisions, and rejected alternatives —
kept as part of the skeleton so the design survives cloning.

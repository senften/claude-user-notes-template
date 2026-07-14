# Working notes

Personal, git-tracked notes for in-flight work on this project. `ACTIVE.md` and
`FEATURES.md` (in this folder) are GENERATED from per-note frontmatter by
`regen-active.ps1` (re-run by a Stop hook each session). **Never edit them by hand** —
keep the source honest by setting frontmatter on each note.

## Frontmatter

    ---
    title: Short effort name
    status: in-progress        # any non-terminal value shows in ACTIVE.md
    areas: [optional-area]     # informational; shown in the indexes
    updated: YYYY-MM-DD
    resume: branch or path to pick up from
    feature: some-feature-slug # optional; groups this note in FEATURES.md
    ---

## Two independent axes

- **`status:` → `ACTIVE.md`** (one row per effort). Routing (lowercased):
  - `done` / `archived` / `complete` / `completed` → dropped (terminal).
  - a *resolved* status (`verifying`, `merged-pending-verification`, `pending-verification`)
    → **Resolved — pending verification** section.
  - any other non-empty value → **Active work** section.
- **`feature:` → `FEATURES.md`** (all notes of a feature, grouped by kebab-case slug).
  Put `feature:` on every member note; a companion design/plan note may carry `feature:`
  alone (no `status:`) so it aids navigation without adding a row to `ACTIVE.md`. A terminal
  `status:` drops a note from BOTH indexes. `feature:` accepts a list (`feature: [a, b]`).
  `FEATURES.md` is a human/editor aid — only `ACTIVE.md` is imported into sessions (below).

## Placement & lifecycle

- Cross-cutting notes live in `_workspace/`; area-specific notes in an optional `<area>/`
  subdir. When something grows cross-cutting, move its tracker to `_workspace/` and leave a
  one-line breadcrumb in the origin area.
- Delete a note once its commit merges — git history is the durable record.

@ACTIVE.md

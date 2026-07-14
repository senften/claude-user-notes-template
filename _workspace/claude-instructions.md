# Workspace

Workspace orientation (solution map, platform layout, XCut reuse, conventions) is
maintained by the team in `DevNotes/ai-config/` and loaded into each solution via
its `CLAUDE.md` `@import` chain — don't duplicate it here. This file is for local,
personal notes only.

- If asked or need to keep notes, do so in the git-tracked `KA/notes/` repo (sibling
  of `automate/`), under the matching subdir: `KA/notes/<Solution>/` for
  solution-specific notes (e.g. `KA/notes/Service.ExternalData/`) or
  `KA/notes/_workspace/` for cross-cutting ones. From a solution cwd
  (`KA/automate/<Solution>`) that path is `../../notes/<Solution>/`.
  The in-place `CLAUDE.local.md` files are thin `@import` stubs — real content
  lives here in `KA/notes/`.

- **Do NOT `git push` the `KA/notes/` repo** — it has no remote configured yet. Commit
  locally as usual, but never push until Scott has set up a remote. (Remove this note once
  a remote exists.)

## Active-work tracking

- In-flight efforts are indexed in `ACTIVE.md` (auto-imported below), **generated** from
  per-doc frontmatter by `KA/notes/regen-active.ps1` (also re-run by a Stop hook each session).
  Never edit `ACTIVE.md` by hand.
- Keep the source honest instead: when you start, promote-to-cross-solution, or finish a
  status/checkpoint doc, set its frontmatter — `status:`, `solutions: [..]`, `updated:`,
  `resume:`. Status routing: `done`/`archived`/`complete`/`completed` drops it from the
  index; a resolved status (`verifying`, `merged-pending-verification`,
  `pending-verification`) moves it to ACTIVE.md's **Resolved — pending verification**
  section (merged & pushed, awaiting support-team sign-off); anything else stays under
  **Active work**. See `KA/notes/README.md` for the full routing.
- Second axis: a `feature:` frontmatter slug groups a doc into the generated
  `_workspace/FEATURES.md` (all docs of a cross-solution effort in one list). Put `feature:`
  on every member doc; companion design/plan docs use `feature:` alone (no `status:`) so they
  aid navigation without cluttering `ACTIVE.md`. `FEATURES.md` is a human/VSCode aid — it is
  NOT imported into sessions (only `@ACTIVE.md` is).
- Placement: a cross-solution effort's tracker lives in `_workspace/`; single-solution work in
  `KA/notes/<Solution>/`. When something started in one solution grows cross-solution, move its
  tracker to `_workspace/` and leave a one-line breadcrumb pointer in the origin solution's dir.

@ACTIVE.md

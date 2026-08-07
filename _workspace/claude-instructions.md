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
    feature: some-feature-slug # optional; groups this note in FEATURES.md
    durable: true              # optional; evergreen doc, never pruned -> KNOWLEDGE.md
    topic: some-topic-slug     # optional; groups this note in KNOWLEDGE.md
    ---

Quote any scalar value that contains a colon-space (`:` + ` `) or starts with a
YAML-special character — wrap it in `"..."`. `regen-active.ps1` uses a tolerant
line-based parser that doesn't care, but editors/tools with a real YAML parser (e.g.
VS Code's frontmatter preview) do, and will fail with a "nested mappings" error.

## The `## Resume` section

The recap lives in the note **body**, not in frontmatter — a `## Resume` section
directly under the note's title heading:

    # MWL gauge-restart on redefine

    ## Resume

    Engineering is done; two commits in two repos remain, merge mechanics only.

    <the rest of the recap — as many paragraphs, bullets and tables as it needs>

- **The first line becomes the `ACTIVE.md` row.** Write it as ONE standalone sentence
  of current status: what state this effort is in and what happens next. It is
  truncated at 240 characters in the row, so put the load-bearing fact first.
- **Rewrite it whenever you bump `updated:`.** Same edit, every time — a stale first
  line is a lying status board.
- **Everything below the first line is yours to shape.** It is ordinary body markdown:
  prune and restructure it. Do NOT append a changelog — if a paragraph is superseded,
  delete it rather than writing "the above is now retired".
- The heading must be exactly `## Resume`. The generator matches it literally; if it is
  missing or the section is empty the row renders as the doc link alone, with no text.

**Resuming an effort.** When asked to resume a named effort, match the title in
`ACTIVE.md`, open the linked note, and read `## Resume` FIRST. It supersedes anything
below it — prose further down may have been overtaken and is not authoritative.

## Three axes

- **`status:` → `ACTIVE.md`** (one row per effort). Value is lowercased, matched exactly, and
  routed to a section (sections shown only when non-empty):
  - `done` / `archived` / `complete` / `completed` → dropped (terminal).
  - `in-review` / `review` / `pr` → **In Review — PR** (code review).
  - `blocked` / `waiting` → **Blocked** (stalled on an external gate).
  - `verifying` / `merged-pending-verification` / `pending-verification` → **Resolved — pending verification** (QA).
  - `watching` / `watch` → **Watching** (complete; possible follow-up).
  - `hiatus` / `paused` / `shelved` → **On Hiatus** (paused, incomplete).
  - `future` / `planned` → **Future** (considered, not started).
  - any other non-empty value → **Active work** (catch-all).
- **`feature:` → `FEATURES.md`** (all notes of a feature, grouped by kebab-case slug).
  Put `feature:` on every member note; a companion design/plan note may carry `feature:`
  alone (no `status:`) so it aids navigation without adding a row to `ACTIVE.md`. A terminal
  `status:` drops a note from BOTH indexes. `feature:` accepts a list (`feature: [a, b]`).
  `FEATURES.md` is a human/editor aid — only `ACTIVE.md` is imported into sessions (below).
- **`durable: true` → `KNOWLEDGE.md`** (evergreen reference, grouped by `topic:`). A durable
  note appears in `KNOWLEDGE.md` **regardless of `status:`** — terminal status does NOT drop it.
  Use it for the "how this works and why" record (architecture, data flow, landmines) that must
  outlive the feature. `topic:` (kebab-case, accepts a list) is its grouping key, parallel to
  `feature:`. A durable note may also carry a `status:` while a follow-up is in flight (it then
  shows in `ACTIVE.md` too); when that status goes terminal it leaves `ACTIVE.md` but stays in
  `KNOWLEDGE.md`. `KNOWLEDGE.md`, like `FEATURES.md`, is NOT imported into sessions — link to a
  durable doc from the checkpoint note you are working under.

## Placement & lifecycle

- Cross-cutting notes live in `_workspace/`; area-specific notes in an optional `<area>/`
  subdir. When something grows cross-cutting, move its tracker to `_workspace/` and leave a
  one-line breadcrumb in the origin area.
- Delete a *transient* note once its commit merges — git history is the durable record.
  **Exception:** a `durable: true` note is evergreen — keep it and update it; never delete it
  on completion.

<!-- Optional per-project overlay, silently skipped when absent: put project-specific
     conventions (paths, remotes, vocabulary) in `claude-instructions.local.md`. -->
@claude-instructions.local.md

@ACTIVE.md

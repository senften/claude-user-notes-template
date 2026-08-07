# Body-owned resume recaps — design

**Date:** 2026-08-07
**Status:** approved, not implemented

## Problem

`resume:` is a frontmatter scalar rendered verbatim into every `ACTIVE.md` row. In practice it
has become the primary recap store, and it has grown without bound: in the Automate notes repo
`ACTIVE.md` is 44 KB (~11k tokens), of which ~40 KB is `resume:` values. One row is ~20 KB.

Three distinct costs:

1. **Unreadable board.** The row text far outstrips the metadata around it. In practice the
   author reads no more than the first sentence, so the remaining ~99% is pure noise at the one
   moment the file is meant to be scanned.
2. **Every session pays for every effort.** `ACTIVE.md` is `@`-imported at session start, so the
   full recap of every *Watching / Hiatus / Future* effort is injected on every session,
   regardless of what is being worked on. The actual workflow is "let's resume &lt;title&gt;" —
   exactly one effort's recap is ever needed, and the agent opens that note anyway.
3. **Drift, structurally invited.** The recap exists in two places: the `resume:` field and the
   note body. Only the field is in the update habit, so bodies go stale. `active-mwl-gauge-restart.md`
   demonstrates it — its body leads with a framing its own `resume:` field explicitly retires
   ("the old -2-stack framing in every earlier recap is RETIRED, do not reason from it"). An agent
   reading the body first reasons from a retired picture.

A YAML scalar also can only be *appended* to. That is why these values read as changelogs
("RE-ASSESSED …", "THE OLD LANDMINE … IS RETIRED AND NOW INVERTED") rather than as current state.

## Decision

The recap moves into the note body under a `## Resume` heading. The generator derives the
`ACTIVE.md` row text from **the first line of that section**. The `resume:` frontmatter field is
removed entirely.

No new frontmatter field, and no migration code. The guiding constraint is the system's purpose:
lightweight note-keeping — scrap paper, not documentation.

## Design

### Row rendering

The generator already reads every note's full contents into `$lines` to parse frontmatter, and
already knows the frontmatter's closing-delimiter index. Scanning the body for `## Resume` is
therefore free — no extra file IO.

Resolution rules:

- Find the first line that, trimmed, equals `## Resume` (case-insensitive).
- Take the first following non-empty line that is not itself a heading.
- Strip a leading list marker (`- ` or `* `) if present. Without this, a recap written as a bullet
  renders as a nested sublist inside the row and looks broken.
- Cap at 240 characters, truncated at the last space at or before the cap, with `…` appended.
- If the heading is absent, or the section is empty, the row carries no text — just the doc link.

The row's second line drops both labels. It is currently
`doc: [link] · resume: ` + backticked value; it becomes `[link] — <recap line>`, joined by an em
dash, with the link alone when there is no recap line. The first line of the row (title, areas,
`status:`, `updated:`) is unchanged.

The row becomes:

```
- **Navigator UpwardProperty refactor** · navigator · status: in-review · updated: 2026-08-06
  [2026-07-13-navigator-upwardproperty-checkpoint.md](../navigator/…) — PR 6930: every gate closed except QA. Nothing to do but wait and answer findings.
```

Two deliberate choices:

- **First line, not first sentence.** A line is what the author controls explicitly. Sentence
  splitting would break on every version string (`6.30.9987`) and abbreviation in these recaps.
- **Plain markdown, not a code span.** The current row wraps the value in backticks. Dropping that
  retires the "no backticks in `resume:`" prohibition, and lets a recap line use inline code for a
  branch or file name.

### The 240-character cap is load-bearing

Migration pastes an existing single-line 20 KB recap into `## Resume`, so its first line *is* 20 KB
until someone restructures it. The cap makes a migrated-but-untidied note render a sensible
truncated row with no special-case code. This is the whole reason no "legacy fallback" is needed.

### Missing section: link only

No fallback to the old `resume:` field, and no synthesized text. A bare row is an honest signal
that a note has no recap or has not been migrated. The field's content is not lost — it is still in
the file, visible whenever the note is opened.

### Frontmatter changes

`resume:` is no longer read by the generator. `title:`, `status:`, `areas:`, `updated:`, `feature:`,
`durable:` and `topic:` are unchanged.

### Instruction changes (`_workspace/claude-instructions.md`)

- Remove `resume:` from the frontmatter block.
- Delete both `resume:` constraint paragraphs — the backtick prohibition and the folded/literal
  block-scalar trap are moot once the recap is body text. **Keep** the colon-space quoting rule; it
  still applies to `title:` and other scalars.
- Add a short section: the recap lives in `## Resume` at the top of the note body; its first line
  must stand alone as a status sentence, because it becomes the `ACTIVE.md` row; update it whenever
  `updated:` is bumped.
- Add the session-start rule: on "let's resume &lt;title&gt;", match the row in `ACTIVE.md`, open the
  note, and read `## Resume` **first** — it supersedes anything below it.

### Documentation changes

- **New `MIGRATION.md`**, dated sections, newest first. The 2026-08-07 section states what changed,
  why existing rows went bare after the merge, a copy-pasteable instruction block to hand to Claude
  inside a notes repo, and the by-hand steps as an alternative. Needed because the template now has
  a second consumer who will `git merge upstream/main` into a repo full of `resume:` notes.
- **`README.md`**: one-line pointer to `MIGRATION.md` from *Pull template fixes into a project*.
- **`DESIGN.md`**: a `### The resume recap lives in the note body` decision entry, the rejected
  alternatives below, and a `## History` line.
- **Untouched:** `DESIGN-durable-knowledge-docs.md` and everything under `docs/superpowers/plans/`
  and `docs/superpowers/specs/` are historical records of past decisions. They mention `resume:`
  and should keep doing so.

## Rejected alternatives

- **A separate short `summary:` frontmatter field.** Rejected because it must be rewritten every
  checkpoint or it drifts from the recap — and drift is this system's *demonstrated* failure mode,
  not a hypothetical one. Deriving the row from the recap makes disagreement structurally
  impossible and removes a thing to remember.
- **Two generated files (scannable `ACTIVE.md` + full `RESUME.md`, both imported).** Rejected: it
  holds ~11k tokens of recaps for *all* efforts to save one Read of the *one* effort named, and it
  preserves the duplication that causes drift.
- **Tier by status** (full recap for hot sections, one line for cold ones). Rejected: the rows read
  most often are exactly the ones that stay dominated by a wall of text.
- **A truncating legacy fallback in the generator** (no `## Resume` → derive from `resume:`).
  Rejected as permanent machinery for a one-time job that a manual pass does better and with
  judgment. The 240-char cap already covers the interim.
- **Reconciling stale body prose during migration.** Rejected as a migration step: merging a 20 KB
  recap against superseded prose is per-effort judgment. Migration marks the old prose
  `## Historical` and leaves pruning to the next session on that effort.

## Verification

Extend `tests/regen-active.Tests.ps1` (dependency-free, exits non-zero on failure). It needs a
helper for a custom body — the existing `Note()` hardcodes `body`. Scenarios:

1. `## Resume` first line renders as the row text.
2. No `## Resume` → row carries the doc link and no recap text.
3. A single line longer than the cap is truncated at a word boundary with `…`.
4. `resume:` frontmatter is ignored (does not appear in `ACTIVE.md`).
5. A `## Resume` whose first line is a `- ` bullet renders without the list marker.
6. Existing assertions still pass (status routing, FEATURES, KNOWLEDGE).

Run: `pwsh -NoProfile -File tests/regen-active.Tests.ps1`

## Out of scope

- Migrating the live notes repos. Done by hand, per project, after each pulls this change.
- Pruning or restructuring existing recap content.
- Any change to `status:` routing, `feature:`, `durable:`/`topic:`, or the three-index structure.

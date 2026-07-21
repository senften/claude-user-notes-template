# Durable knowledge docs — design

Adds a second, **evergreen** class of note to the notes system, distinct from today's
transient status-tracked checkpoints. A durable note holds the "how this system actually works
and why" record — maintained forever, never pruned. This spec covers the **marker + index**:
the frontmatter marker, a new grouping axis, the generated `KNOWLEDGE.md` index, and the
anti-pruning change in `regen-active.ps1`. Background and the first real exemplar:
[`DESIGN-durable-knowledge-docs.md`](../../../DESIGN-durable-knowledge-docs.md).

## Goals

- A note can be marked evergreen and **survive terminal status** — exempt from both the
  delete-when-done guidance and the terminal-status dropping in the generator.
- The durable half of a note lives **independently of any transient watch item**, so a watch
  can resolve (`watching → done`) without the knowledge being pruned. This is the core lesson
  of the exemplar, which today survives *only* by abusing `status: watching`.
- Durable docs are discoverable via a generated index without adding per-session token cost.
- The mechanism ships in the **template** so it flows to every instance via
  `git fetch upstream && git merge upstream/main`.

## Non-goals (deferred future work)

- **Derive-vs-hand-write.** Generating mechanical facts (dependency maps, call graphs) from
  code so they never go stale. Not in this effort.
- **Authoring & freshness convention.** A skill/convention prompting the agent to draft or
  update a durable doc on discovery, with a human-ratify gate and drift *detection*. Not in
  this effort.
- Importing durable knowledge into session context (see Decision 3 — explicitly rejected).

## Design

### Decision 1 — a third orthogonal axis: `durable: true` + `topic:`

The system currently has two orthogonal axes: `status:` (transient lifecycle → `ACTIVE.md`)
and `feature:` (cross-cutting navigation → `FEATURES.md`). This adds a third:

- **`durable: true`** — a boolean flag, orthogonal to both other axes. Its presence means
  "evergreen knowledge; never prune." It is simultaneously:
  - the **identity signal** — a reader (human or agent) can tell a durable doc from a transient
    checkpoint by one grep-able frontmatter line, without reading the body; and
  - the **`KNOWLEDGE.md` membership trigger** — presence routes the note into the index.
- **`topic:`** — a new list-valued, kebab-case grouping key, parallel to `feature:`. It is the
  `KNOWLEDGE.md` grouping axis. `topic:` is about *how a solution/subsystem works*, which is
  broader than `areas:` (a topic may span areas) and not tied to a feature's lifecycle
  (architecture/design knowledge often maps to no single feature). Accepts a single value or a
  list: `topic: [a, b]`.

Why orthogonal (not a reserved `status:` value): the exemplar carries **both** an evergreen
record and a transient watch item in one file. Overloading `status:` would re-create exactly
the conflation `DESIGN.md` warns against. A boolean flag decoupled from `status:` lets a note
be `status: done` **and** durable at the same time.

Why `durable: true` (not `kind: durable` or `knowledge: <slug>`): a bare boolean reads as a
pure prune-exemption switch, needs no taxonomy or default value for un-marked notes, and keeps
"is this durable" separate from "how is it grouped" (that is `topic:`'s job).

### Decision 2 — routing & anti-pruning (the load-bearing change)

Membership rules, per index:

| Index          | Membership condition                                             |
|----------------|------------------------------------------------------------------|
| `ACTIVE.md`    | non-terminal `status:` (unchanged)                               |
| `FEATURES.md`  | `feature:` present **and** non-terminal `status:` (unchanged)    |
| `KNOWLEDGE.md` | `durable: true` — **regardless of `status:`** (new)              |

Consequences:

- The terminal-status early-return in the generator currently discards a note from *both*
  indexes. It must be restructured so a `durable: true` note is **never discarded** — a
  terminal status suppresses its `ACTIVE.md`/`FEATURES.md` rows but not its `KNOWLEDGE.md`
  entry.
- A durable note with a **non-terminal** status (e.g. `watching`) appears in **both**
  `ACTIVE.md` (its status section) and `KNOWLEDGE.md`. This is the live exemplar state.
- When its status flips to a **terminal** value (`done`), it leaves `ACTIVE.md` (and
  `FEATURES.md` if it had `feature:`) and **persists in `KNOWLEDGE.md`**. This is the exemplar's
  target end-state, and it resolves the transient/durable conflation: the watch resolves
  independently of the knowledge persisting.
- A **pure durable doc** (born evergreen — e.g. an architecture write-up) carries
  `durable: true` + `topic:` with **no `status:`**; it never touches `ACTIVE.md`, only
  `KNOWLEDGE.md`.

### Decision 3 — `KNOWLEDGE.md` is generated, not imported

A third generated file in `_workspace/`, with the same "do not edit by hand" banner, built by
the same generator run. Structure mirrors `FEATURES.md`: grouped by `topic:` slug, one line per
member (clickable link + title + `status:`/`updated:` if present). Bodies are **not** inlined.

- **Grouping:** by `topic:` slug (a note with multiple topics appears under each). Durable notes
  with **no `topic:`** render under a trailing `# Ungrouped` heading so they are never lost.
- **Not imported into sessions.** Like `FEATURES.md`, it is a human/on-demand navigation aid.
  Agents reach a durable doc via a plain markdown link from the transient checkpoint/status doc
  they are working under, or via the human. This keeps per-session token cost at zero and avoids
  the unbounded-growth failure mode of inlining evergreen knowledge. (Only `ACTIVE.md` is
  imported; that is unchanged.)

### Decision 4 — placement & documentation

- **Placement is unchanged.** Cross-cutting notes live in `_workspace/`, area-specific ones in
  an optional `<area>/` subdir. A durable doc's identity comes from `durable: true`, not its
  location — so no new placement rule is needed.
- **`claude-instructions.md`** — document the third axis (`durable:`/`topic:` → `KNOWLEDGE.md`)
  and carve `durable: true` out of the "delete a note once its commit merges" guidance
  (durable notes are the intended exception: they persist).
- **`DESIGN.md`** — promote durable knowledge docs from "Future work" to a key decision
  (recording the orthogonal-axis rationale and the rejected reserved-status alternative), and
  leave the two deferred items (derived docs; authoring/freshness skill) as remaining future
  work.

### Generator specifics (`regen-active.ps1`)

1. Add `KNOWLEDGE.md` to the excluded-filenames `Where-Object` list (alongside `ACTIVE.md`,
   `FEATURES.md`, `README.md`, `DESIGN.md`).
2. In the frontmatter parse, collect `durable` and `topic` (same `$get` helper; `topic` uses
   the existing block-list/inline-array handling like `feature`).
3. Restructure the terminal-status handling: instead of `return`-ing early for a terminal
   status, always build the item and record `Durable` / `Topic`; use `status`-is-terminal and
   `durable` flags at *render* time to decide index membership. A terminal, non-durable note
   still contributes to no index (same effect as today).
4. Emit `KNOWLEDGE.md`: banner + `# By topic`, groups ordered like `FEATURES.md` (most-recently
   `updated:` first, then slug), members sorted `updated:` desc then title; trailing
   `# Ungrouped` section for durable notes without `topic:`. Reuse the shared `$mdLink` helper.

## Testing / verification

Author temporary test notes in a scratch clone (or the template's own tree, removed after) and
run `pwsh -NoProfile -File regen-active.ps1`, asserting:

1. `durable: true` + `status: watching` + `topic: x` → appears in **both** `ACTIVE.md`
   (Watching) and `KNOWLEDGE.md` (under `x`).
2. Same note flipped to `status: done` → **gone from `ACTIVE.md`**, **still in `KNOWLEDGE.md`**.
   (This is the exemplar's target end-state and the primary success criterion.)
3. `durable: true` + no `status:` + `topic: x` → in `KNOWLEDGE.md` only, not `ACTIVE.md`.
4. `durable: true` + no `topic:` → under `# Ungrouped` in `KNOWLEDGE.md`.
5. Non-durable terminal note (`status: done`, no `durable`) → in no index (regression check).
6. `topic: [a, b]` → the note appears under both `a` and `b`.

## Rollout

Ship entirely in the template repo. Existing instances receive it via
`git fetch upstream && git merge upstream/main`; the merge touches only skeleton files
(`regen-active.ps1`, `_workspace/claude-instructions.md`, `DESIGN.md`) and leaves each
project's notes untouched. On next Stop-hook run, each project regenerates and gains an empty
`KNOWLEDGE.md` until its first `durable: true` note.

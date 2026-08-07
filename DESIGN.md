# Notes system — design

This repo is a small system for **git-tracked, generator-indexed working notes**, shipped as a
**template** (`claude-user-notes-template`) that seeds a notes repo per project (see
[`README.md`](README.md)). This document is the durable record of *why* it's built the way it
is — part of the skeleton so the rationale survives cloning.

## What it is

Per-note YAML-ish frontmatter is the single source of truth. A PowerShell generator
(`regen-active.ps1`, run by a `Stop` hook after every Claude Code turn) rebuilds two index files
from that frontmatter:

- `_workspace/ACTIVE.md` — in-flight efforts, one row per effort, driven by `status:`.
- `_workspace/FEATURES.md` — docs grouped by `feature:`, for cross-cutting navigation.

`README.md` documents the operational mechanics; this file documents the decisions behind them.

## Key decisions

### Two orthogonal generated indexes, not one
`status:` (active-work lifecycle) and `feature:` (cross-solution grouping) are independent axes.
A doc may carry either or both. They render to separate files so two unrelated groupings never
fight for one layout. A terminal `status:` drops a doc from both indexes; a `feature:`-only
companion doc (design/plan) appears in `FEATURES.md` without adding a row to `ACTIVE.md`.

### A third axis for evergreen knowledge
`status:` and `feature:` both describe *transient* work — terminal status drops a note from
both indexes. Durable knowledge (architecture, data flow, landmines) has the opposite
lifecycle: its failure mode is staleness, not clutter, so it must never be pruned. A third
orthogonal axis carries it: `durable: true` (a boolean prune-exemption flag and identity
signal) routes a note to a third generated index, `KNOWLEDGE.md`, grouped by a new `topic:`
key. `durable:` is orthogonal to `status:` deliberately — a note that closes a feature often
leaves one evergreen record *and* one transient watch item; keeping them on separate axes lets
the watch resolve (`status: watching → done`, dropped from `ACTIVE.md`) while the knowledge
persists in `KNOWLEDGE.md`. Like `FEATURES.md`, `KNOWLEDGE.md` is not imported into sessions
(unbounded token growth is the failure mode of inlining evergreen knowledge); durable docs are
reached by a link from the transient note being worked.

### Generate the index; don't hand-maintain it
The recurring cost of a notes web is keeping index/hub pages current by hand. Here the
frontmatter is authoritative and the generator rebuilds the indexes on every turn, so the hubs
are never stale and are never hand-edited. (Both generated files carry a "do not edit by hand"
banner.)

### The generated indexes are not tracked in git
`ACTIVE.md`, `FEATURES.md`, and `KNOWLEDGE.md` are build artifacts — rebuilt from the tracked
note frontmatter on every Stop hook — so they are `.gitignore`d, not committed. Tracking them
was tried and reverted: because both the template and a downstream project regenerate different
content, a `git pull upstream/main` into a mid-flow project conflicts on all three every time
(mid-flow means the project's `ACTIVE.md` is necessarily populated). Untracking loses nothing:
the durable *content* lives in the individual `durable: true` note files (ordinary tracked
source), and every index is reproducible by running the generator. A fresh clone has no index
until the first regen, which is harmless — `@ACTIVE.md` silently no-ops when absent. This is the
generated-file corollary of "generate the index; don't hand-maintain it": a derived artifact
belongs to the build, not to version control.

### Why not Obsidian tags
Considered and rejected. A tag's main value is auto-aggregating members without a hand-kept
index — which the generator already provides. Plain markdown links work in VSCode and Obsidian
alike with no tool dependency, so adopting Obsidian/tags would add a dependency for no net gain.
Tags remain a fine *optional* layer for anyone who wants graph/backlink navigation; the system
doesn't require them.

### Why `feature:` over inline cross-links
A generated flat `FEATURES.md` is the lateral-navigation hub (open it, click any sibling). The
alternative — injecting a "related docs" link block into each authored doc — was rejected: it
makes the generator write into human-authored files and churns every sibling doc whenever any
one of them changes.

### FEATURES.md is a human aid, not agent context
Claude sessions import `ACTIVE.md` only. The feature view is the same docs on a different axis,
so importing it too would only add redundant context cost.

### A multi-stage lifecycle, not just active/done
`status:` routes a note to one of an ordered set of sections in `ACTIVE.md`, rendered
most-active-first: **Active work** (catch-all) → **In Review — PR** (code review) →
**Blocked** (external gate) → **Resolved — pending verification** (QA) → **Watching**
(complete, possible follow-up) → **On Hiatus** (paused, incomplete) → **Future** (not
started). Terminal statuses (`done`/etc.) still drop from both indexes. The stages are
independent keyword-sets in one ordered `$sections` list in `regen-active.ps1`; adding or
reordering a section is a one-line edit. The load-bearing distinctions: **Blocked** (can't
proceed) vs **On Hiatus** (chose to pause); **Watching** (work done, watching for more) vs
**On Hiatus** (work unfinished); and the two review gates — **In Review — PR** (code) before
**Resolved — pending verification** (QA). Merged-but-unverified work stays parked in Resolved
(neither active nor safe to delete) until sign-off; only non-empty sections render, so unused
stages add no noise.

### The resume recap lives in the note body; the row is derived from it
`ACTIVE.md`'s row text is the first line of the note's `## Resume` section, not a `resume:`
frontmatter value. Three problems forced the move. A YAML scalar can only be *appended* to, so
recaps grew into changelogs ("the old framing is RETIRED, do not reason from it") instead of
current state — one reached 20 KB. `ACTIVE.md` is `@`-imported into every session, so the full
recap of every *Watching / Hiatus / Future* effort was injected on every session, while the actual
workflow ("let's resume &lt;title&gt;") needs exactly one. And the recap existed in two places —
the field and the body — with only the field in the update habit, so bodies went stale and an
agent reading the body first reasoned from a superseded picture. Body markdown can be pruned and
restructured; deriving the row from its first line makes board-versus-recap disagreement
structurally impossible and removes the one thing an author would otherwise have to remember to
update twice. A 240-character cap stops an un-restructured recap re-flooding the row, which is
also what lets the transition ship with no migration code (see `MIGRATION.md`).

### Robust-enough frontmatter parsing
The parser is line-based (not a full YAML parser) but handles scalars, inline arrays
(`key: [a, b]`), and multi-line block lists. That last case matters because Obsidian's Properties
editor rewrites inline arrays into block lists; without it, an `areas:`/`feature:` value would
silently blank on the next regen.

### Two repos, not one repo with two branches
The template and each project are separate repositories; notes flow one way (template →
project, via `upstream`). A single repo with `main`=template and a project branch gives the
same update channel but distinguishes template from notes only by the current branch — easy to
commit a note onto the template branch by mistake. Separate repos make "which am I in" a
visible directory instead of an invisible branch, and git physically prevents a project's notes
from entering the template's history.

### Copy the skeleton into a fresh repo; never clone to create the template
`git clone` copies full history, so deleting notes afterward leaves them in history forever.
The template is instead created by copying only skeleton *working files* into a new `git init`,
so it never contained a note — clean by construction.

### One generator (PowerShell), run via `pwsh` off-Windows
The generator is a single PowerShell script. On macOS/Linux it runs via `pwsh` (one install)
rather than a second bash/Python port. Two implementations of the frontmatter parser (block
lists, two-axis routing, date sort) would drift; one source of truth avoids that. The root is
`$PSScriptRoot` so no clone needs editing.

### Project-specifics layer on the generic instructions, never fork them
`claude-instructions.md` is skeleton — a project must not edit it to add its own paths,
remotes, or vocabulary, or every `merge upstream/main` conflicts. Instead the base file ends
with an optional `@claude-instructions.local.md` import: a project drops that file in with its
specifics and it loads right before `@ACTIVE.md`; a bare template instance omits it and the
import is silently skipped (verified: a missing `@import` doesn't error and later imports still
load). Generic stays mergeable; local stays conflict-free.

## Rejected alternatives (for the record)

- **Inline "related docs" links in each doc.** True one-click sibling navigation, but the
  generator would write into authored files and produce git churn across every sibling on any
  change. Rejected in favor of the flat generated hub.
- **Reserved `status:` value for durable notes.** Simpler than a new axis, but a closing feature
  leaves both an evergreen record and a transient watch item in one note; a status value can be
  only one of the two at a time. Rejected — durability must be orthogonal to status.
- **Obsidian + `#feature/…` tags.** Native graph/backlinks, but adds a tool dependency whose main
  benefit the generator already covers. Left as an optional layer, not a requirement.
- **Single repo, `main`=template / project=branch.** Same merge-based update channel as two
  repos, but template and notes share one working tree distinguished only by branch — easy to
  mis-commit. Rejected for the two-repo model.
- **Scaffold / paste-into-Claude script.** Trivial to instantiate but gives no git update
  channel; skeleton fixes to existing projects would be manual. Rejected.
- **All-Python generator.** One portable implementation, but a runtime whose install/versioning
  is historically painful on Windows. Rejected in favor of reusing the tested PowerShell script.
- **Two native scripts (pwsh + bash/POSIX-sh).** No runtime install off-Windows, but two
  implementations that must stay byte-for-byte in sync. Rejected for the drift cost.
- **A short `summary:` frontmatter field beside the long recap.** The obvious shape, and it needs
  no body parsing — but it must be rewritten every checkpoint or it drifts from the recap, and
  drift is this system's demonstrated failure mode, not a hypothetical one. Rejected for deriving
  the row from the recap itself.
- **Two generated indexes: a scannable `ACTIVE.md` plus a full `RESUME.md`, both imported.** Gives
  a clean board and still costs the agent no extra read, but it holds every effort's recap in
  context to save one file read of the single effort being resumed, and it preserves the
  duplication that causes drift. Rejected.
- **Rendering the full recap only for the "hot" sections** (Active work, In Review, Blocked), with
  a short line for the rest. The smallest possible change, but the rows read most often stay the
  fattest ones. Rejected.
- **A truncating legacy fallback in the generator** (no `## Resume` → derive the row from a
  leftover `resume:`). Permanent machinery for a one-time migration; the 240-character cap already
  renders a readable row from a pasted-but-untidied recap. Rejected in favour of a documented
  manual pass.

## Future work

### Durable knowledge docs — remaining work

The marker (`durable: true`), grouping (`topic:`), and index (`KNOWLEDGE.md`) shipped; see the
key decision above and [`DESIGN-durable-knowledge-docs.md`](DESIGN-durable-knowledge-docs.md).
Still deferred:

- **Derive vs. hand-write.** Mechanical facts (dependency maps, "what calls what") could be
  *generated* from code so they never go stale; reserve prose for the "why", contracts, and
  rejected alternatives no tool can derive.
- **Authoring & freshness.** A convention/skill prompting the agent to draft or update a durable
  doc when a subsystem is designed or a non-obvious fact is found — with a human-ratify gate
  (agent proposes → human reviews → merge) and drift *detection* (flagging doc claims the code
  contradicts) valued over autonomous authoring.

## History

Distilled from the original KAutomate-specific implementation this template was extracted from;
that project's dated design/plan notes live in its own git history.

**2026-08-07** — the `resume:` frontmatter field was replaced by a body-owned `## Resume` section
whose first line is rendered into `ACTIVE.md`. See the key decision above, and `MIGRATION.md` for
the per-project migration.

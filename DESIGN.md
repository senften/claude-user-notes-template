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

### Generate the index; don't hand-maintain it
The recurring cost of a notes web is keeping index/hub pages current by hand. Here the
frontmatter is authoritative and the generator rebuilds the indexes on every turn, so the hubs
are never stale and are never hand-edited. (Both generated files carry a "do not edit by hand"
banner.)

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

### Resolved-pending-verification lifecycle stage
Merged-but-unverified work is neither "active" (nothing left to do) nor safe to delete
(downstream QA/verification feedback can reopen it). A small set of "resolved" statuses routes it to its own
`ACTIVE.md` section, so it's parked visibly rather than cluttering active work or being pruned
early. The lifecycle is: active → resolved/pending-verification → deleted (after sign-off).

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

## Future work

### Durable knowledge docs (architecture / design / data-flow / workflow)

A planned second class of document, distinct from today's checkpoint/status notes. Today's
notes are **transient**: born → tracked in `ACTIVE.md` → pruned when the work is done.
Durable knowledge docs would be the opposite — the "how this system actually works and why"
record, **maintained forever, never pruned**, for lasting human *and* agent reference. The
two must not be conflated: tooling built for transient work (a tracker with a prune step) is
actively wrong for evergreen knowledge, whose failure mode is *staleness*, not clutter.

Open design questions for a future effort:

- **Which axis?** A third generated index (e.g. `KNOWLEDGE.md`), an extension of `feature:`
  grouping, or a new `kind:`/`type:` frontmatter dimension? How does it relate to the existing
  `status:` and `feature:` axes?
- **Anti-pruning.** Today's guidance deletes `done` notes and the generator drops terminal
  `status:` from all indexes. Durable docs must be *exempt* — they need a marker that keeps
  them out of both the prune rule and terminal-status dropping.
- **Agent context.** `ACTIVE.md` is imported into sessions; `FEATURES.md` is not. Durable
  knowledge is prime agent-reference material — should some/all of it be imported, or exposed
  via a curated index rather than full bodies (token-cost tradeoff)? This is the one real
  behavioral departure from today's system.
- **Derive vs. hand-write.** Mechanical facts (dependency maps, "what calls what") can be
  *generated* from code so they never go stale; reserve prose for the "why", the contracts,
  and rejected alternatives that no tool can derive.
- **Authoring & freshness.** A convention/skill prompting the agent to draft or update a doc
  when a subsystem is designed or a non-obvious fact is discovered — with a human-ratify gate
  (agent proposes → human reviews → merge), and drift *detection* (flagging doc claims the
  code contradicts) valued over autonomous authoring.
- **Placement & identity.** `_workspace/` vs `<area>/`; relationship to `feature:` slugs; a
  naming convention that signals "durable, not a checkpoint".

Build it in this template repo so it flows to every instance via the `upstream` merge channel.

## History

Distilled from the original KAutomate-specific implementation this template was extracted from;
that project's dated design/plan notes live in its own git history.

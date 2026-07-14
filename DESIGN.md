# Notes system — design

This repo is a small system for **git-tracked, generator-indexed working notes**, reusable as a
template across projects (see "Reusing this structure" in [`README.md`](README.md)). This
document is the durable record of *why* it's built the way it is — kept as part of the skeleton
so the rationale survives cloning after the per-effort notes are stripped.

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
(support-team feedback can reopen it). A small set of "resolved" statuses routes it to its own
`ACTIVE.md` section, so it's parked visibly rather than cluttering active work or being pruned
early. The lifecycle is: active → resolved/pending-verification → deleted (after sign-off).

### Robust-enough frontmatter parsing
The parser is line-based (not a full YAML parser) but handles scalars, inline arrays
(`key: [a, b]`), and multi-line block lists. That last case matters because Obsidian's Properties
editor rewrites inline arrays into block lists; without it, a `solutions:`/`feature:` value would
silently blank on the next regen.

## Rejected alternatives (for the record)

- **Inline "related docs" links in each doc.** True one-click sibling navigation, but the
  generator would write into authored files and produce git churn across every sibling on any
  change. Rejected in favor of the flat generated hub.
- **Obsidian + `#feature/…` tags.** Native graph/backlinks, but adds a tool dependency whose main
  benefit the generator already covers. Left as an optional layer, not a requirement.

## History

The dated design/plan that introduced the `feature:` axis lived in
`_workspace/2026-07-10-notes-feature-membership-{design,plan}.md`. This document is the distilled,
durable successor; those dated docs have since been pruned — git history is their record.

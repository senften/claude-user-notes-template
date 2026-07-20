# ACTIVE.md status categories — design

## Goal

Expand `ACTIVE.md` from two lifecycle buckets (**Active work**, **Resolved — pending
verification**) to seven, so a note's `status:` routes it to a more precise section. No change to
`FEATURES.md` or the `feature:` axis. Terminal-status dropping (`done`/`archived`/`complete`/
`completed`) is unchanged.

## Sections (top-to-bottom order in `ACTIVE.md`)

Ordered most-active → least-active, so what needs attention now sits at the top.

| # | Heading | Meaning | Status keywords (lowercased) |
|---|---------|---------|------------------------------|
| 1 | **Active work** | In flight, being worked | *catch-all* — any non-terminal status not matched below (e.g. `in-progress`, `active`, `wip`) |
| 2 | **In Review — PR** | Code / pull-request review | `in-review`, `review`, `pr` |
| 3 | **Blocked** | Can't proceed; waiting on an external gate | `blocked`, `waiting` |
| 4 | **Resolved — pending verification** | Merged, awaiting QA verification | `verifying`, `merged-pending-verification`, `pending-verification` |
| 5 | **Watching** | Complete, but watching for possible follow-up | `watching`, `watch` |
| 6 | **On Hiatus** | In flight but deliberately paused | `hiatus`, `paused`, `shelved` |
| 7 | **Future** | Considered but not started | `future`, `planned` |

**Semantic distinctions to preserve:**

- **Blocked vs On Hiatus** — Blocked = *external* gate stops you; Hiatus = *you* chose to pause.
  Blocked sits high (wants unblocking); Hiatus sits low (intentionally parked).
- **Watching vs On Hiatus** — opposite ends of the lifecycle. Watching = work *complete*, external
  event may trigger *new* follow-up. Hiatus = work *incomplete*, will resume the work itself.
- **In Review (PR) vs Resolved (QA)** — two distinct review stages: code review precedes merge;
  QA verification follows it.

## Routing rules

- Match is **exact against the lowercased `status:` value** (as today — `.ToLower()`), not
  substring. `pr-review` does not match `pr`.
- Sections are evaluated **in order**; the first matching keyword-set wins. Keyword-sets are
  mutually exclusive, so order among sets 2–7 doesn't affect assignment — only display order.
- **Active work is the catch-all**: any non-terminal status not claimed by sets 2–7 lands here.
  This preserves every existing note (which uses arbitrary values like `in-progress`) with zero
  migration.
- Terminal statuses still drop from **both** indexes (unchanged, handled before routing).

## Implementation

### `regen-active.ps1`

Replace the two hardcoded buckets (`$resolvedStatuses` + the two `$emit` calls) with a single
**ordered section-definition list**, and drive the ACTIVE.md build from it.

```powershell
# Ordered: display order in ACTIVE.md, top (most active) to bottom.
# 'Active work' is the catch-all (Keywords $null) and MUST be present exactly once.
$sections = @(
  @{ Heading = '# Active work';                        Keywords = $null }  # catch-all
  @{ Heading = '# In Review — PR';                     Keywords = @('in-review','review','pr') }
  @{ Heading = '# Blocked';                            Keywords = @('blocked','waiting') }
  @{ Heading = '# Resolved — pending verification';    Keywords = @('verifying','merged-pending-verification','pending-verification') }
  @{ Heading = '# Watching';                           Keywords = @('watching','watch') }
  @{ Heading = '# On Hiatus';                          Keywords = @('hiatus','paused','shelved') }
  @{ Heading = '# Future';                             Keywords = @('future','planned') }
)
```

Assignment: a note goes to the first section whose `Keywords` contains its status; if none match
(and status is non-empty, non-terminal), it goes to the catch-all. Build the ACTIVE.md body by
iterating `$sections` in order.

The per-item `Resolved` boolean on the item objects is removed (no longer needed; routing is now
computed from `$sections`). Everything else — frontmatter parsing, sort order
(`Updated` desc, then `Title`), the `$emit` row format, `$mdLink`, and the entire FEATURES.md
block — is unchanged.

### Empty sections

Only emit a section that has ≥1 row. If **no** items have a non-terminal status at all, emit a
single `_(none)_` line under a minimal header so the file is never empty/confusing. This keeps
the per-session import lean (ACTIVE.md is loaded into every Claude session; 7 always-printed
`_(none)_` blocks would be pure token noise).

### `_workspace/claude-instructions.md`

Update the "Two independent axes" `status:` routing list to document all seven sections and their
keywords, replacing the current two-bucket description. Keep it concise (a keyword→section table
or bullet list mirroring this spec).

### `DESIGN.md`

Update the **"Resolved-pending-verification lifecycle stage"** decision (and the header comment
block in `regen-active.ps1`) to reflect the generalized multi-section lifecycle: the tracker now
models the full path (future → active → in-review/blocked → resolved → watching, with hiatus as a
side state), not just active + resolved.

## Testing / verification

Manual, against a scratch note set (the repo has no test harness):

1. Create temp notes under a scratch area, one per keyword group plus one unmatched non-terminal
   (`in-progress`) and one terminal (`done`).
2. Run `pwsh -NoProfile -File regen-active.ps1`.
3. Verify: each note lands in its expected section; sections appear in the specified order;
   `in-progress` → Active work; `done` appears in neither index; empty sections are omitted.
4. Verify FEATURES.md output is byte-identical to a pre-change run for the same notes (no
   regression on the untouched axis).
5. Delete the scratch notes; confirm a clean regen (empty → single `_(none)_`).

## Out of scope

- Durable-knowledge-docs / anti-pruning (tracked separately in
  `DESIGN-durable-knowledge-docs.md`). `watching` here is still a transient tracker status that a
  terminal status will drop — this change does not make any note prune-exempt.
- Any change to `feature:` / FEATURES.md.

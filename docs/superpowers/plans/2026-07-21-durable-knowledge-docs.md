# Durable Knowledge Docs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an evergreen `durable: true` note class that survives terminal status, indexed in a new generated `_workspace/KNOWLEDGE.md` grouped by a new `topic:` key.

**Architecture:** A third orthogonal frontmatter axis (`durable:` flag + `topic:` grouping key) alongside the existing `status:`→ACTIVE.md and `feature:`→FEATURES.md axes. The single generator `regen-active.ps1` is extended to parse the two new keys, stop discarding durable notes on terminal status, and emit a third index. KNOWLEDGE.md mirrors FEATURES.md's structure and, like it, is **not** imported into sessions.

**Tech Stack:** PowerShell (`regen-active.ps1`, runnable via `pwsh` cross-platform). No new dependencies. Tests are a dependency-free PowerShell script (no Pester).

## Global Constraints

- One-way flow: all changes ship in the **template repo**; instances receive them via `git merge upstream/main`. Never fork `claude-instructions.md`'s generic content.
- Generator self-roots via `$PSScriptRoot` — no absolute paths, no per-clone edits.
- `durable:` is a boolean flag, orthogonal to `status:` — a note may be `status: done` **and** `durable: true` simultaneously.
- Membership: ACTIVE.md = non-terminal `status:`; FEATURES.md = `feature:` + non-terminal `status:`; KNOWLEDGE.md = `durable: true` regardless of `status:`.
- Terminal statuses (verbatim): `done`, `archived`, `complete`, `completed`.
- `topic:` is list-valued and kebab-case, parsed with the same inline-array + block-list handling as `feature:`.
- Generated files carry the `<!-- GENERATED ... Do not edit by hand. -->` banner and no timestamp.
- Match existing script style (line-based parse, shared `$mdLink` helper, UTF-8 output, `-join "\`n"`).

Spec: [`docs/superpowers/specs/2026-07-21-durable-knowledge-docs-design.md`](../specs/2026-07-21-durable-knowledge-docs-design.md)

## File Structure

- **Modify** `regen-active.ps1` — add `KNOWLEDGE.md` to the exclusion list; parse `durable`/`topic`; restructure the terminal-status drop; add the KNOWLEDGE.md emission block. Single responsibility unchanged (frontmatter → indexes).
- **Create** `tests/regen-active.Tests.ps1` — dependency-free harness: copies the generator to a temp dir, writes fixture notes, runs it, asserts index contents. New `tests/` dir.
- **Modify** `_workspace/claude-instructions.md` — document the third axis; carve `durable:` out of the delete-when-merged guidance.
- **Modify** `DESIGN.md` — promote durable docs from Future work to a key decision; trim the Future-work section to the two deferred items.
- **Modify** `README.md` — "two indexes" → three; add KNOWLEDGE.md to the how-it-works list and directory layout.

---

## Task 1: Generator + test harness

**Files:**
- Create: `tests/regen-active.Tests.ps1`
- Modify: `regen-active.ps1` (exclusion list ~line 29; parse ~lines 59-72; ACTIVE filter ~line 107; FEATURES filter ~line 130; new emission block after line 161)

**Interfaces:**
- Consumes: nothing (entry point is the script + fixtures).
- Produces: `_workspace/KNOWLEDGE.md`; new frontmatter contract (`durable: true`, `topic: <slug|list>`); no new function signatures (in-script only).

- [ ] **Step 1: Write the failing test**

Create `tests/regen-active.Tests.ps1`:

```powershell
# Dependency-free tests for regen-active.ps1 (durable knowledge docs).
# Copies the generator into a temp root with fixture notes, runs it, and asserts
# on the generated _workspace indexes. Exits non-zero on first failure.
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..' 'regen-active.ps1'
$fails = 0

function New-Root {
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("regen-test-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $root | Out-Null
  Copy-Item -LiteralPath $script -Destination (Join-Path $root 'regen-active.ps1')
  return $root
}
function Add-Note($root, $rel, $body) {
  $path = Join-Path $root $rel
  New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
  Set-Content -LiteralPath $path -Value $body -Encoding utf8
}
function Invoke-Gen($root) {
  pwsh -NoProfile -File (Join-Path $root 'regen-active.ps1') | Out-Null
  [pscustomobject]@{
    Active    = Get-Content -Raw -LiteralPath (Join-Path $root '_workspace/ACTIVE.md')
    Features  = Get-Content -Raw -LiteralPath (Join-Path $root '_workspace/FEATURES.md')
    Knowledge = Get-Content -Raw -LiteralPath (Join-Path $root '_workspace/KNOWLEDGE.md')
  }
}
function Assert($label, $cond) {
  if ($cond) { Write-Host "PASS  $label" }
  else       { Write-Host "FAIL  $label"; $script:fails++ }
}

function Note($fm) { "---`n$fm`n---`n`nbody" }

# Scenario 1+2: durable watching note, then flipped to done.
$root = New-Root
Add-Note $root 'Svc/arch.md' (Note "title: Arch note`nstatus: watching`ndurable: true`ntopic: service-field`nupdated: 2026-07-21")
$r = Invoke-Gen $root
Assert 'watching+durable appears in ACTIVE (Watching)' ($r.Active -match 'Watching' -and $r.Active -match 'Arch note')
Assert 'watching+durable appears in KNOWLEDGE under topic' ($r.Knowledge -match '## service-field' -and $r.Knowledge -match 'arch.md')

Add-Note $root 'Svc/arch.md' (Note "title: Arch note`nstatus: done`ndurable: true`ntopic: service-field`nupdated: 2026-07-21")
$r = Invoke-Gen $root
Assert 'done+durable dropped from ACTIVE'    (-not ($r.Active -match 'Arch note'))
Assert 'done+durable persists in KNOWLEDGE'  ($r.Knowledge -match 'arch.md')

# Scenario 3: pure durable doc, no status.
$root = New-Root
Add-Note $root 'Svc/pure.md' (Note "title: Pure`ndurable: true`ntopic: data-flow`nupdated: 2026-07-20")
$r = Invoke-Gen $root
Assert 'pure durable in KNOWLEDGE'      ($r.Knowledge -match 'pure.md')
Assert 'pure durable not in ACTIVE'     (-not ($r.Active -match 'Pure'))

# Scenario 4: durable, no topic -> Ungrouped.
$root = New-Root
Add-Note $root 'Svc/notopic.md' (Note "title: NoTopic`ndurable: true`nupdated: 2026-07-19")
$r = Invoke-Gen $root
Assert 'durable no-topic under Ungrouped' ($r.Knowledge -match '## Ungrouped' -and $r.Knowledge -match 'notopic.md')

# Scenario 5: non-durable terminal note -> no index (regression).
$root = New-Root
Add-Note $root 'Svc/gone.md' (Note "title: Gone`nstatus: done`nupdated: 2026-07-18")
$r = Invoke-Gen $root
Assert 'terminal non-durable absent from ACTIVE'    (-not ($r.Active -match 'Gone'))
Assert 'terminal non-durable absent from KNOWLEDGE' (-not ($r.Knowledge -match 'gone.md'))

# Scenario 6: multi-topic durable note appears under each.
$root = New-Root
Add-Note $root 'Svc/multi.md' (Note "title: Multi`ndurable: true`ntopic: [alpha, beta]`nupdated: 2026-07-21")
$r = Invoke-Gen $root
Assert 'multi-topic under alpha' ($r.Knowledge -match '## alpha')
Assert 'multi-topic under beta'  ($r.Knowledge -match '## beta')

if ($fails -gt 0) { Write-Host "`n$fails failure(s)"; exit 1 }
Write-Host "`nAll assertions passed"; exit 0
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `pwsh -NoProfile -File tests/regen-active.Tests.ps1`
Expected: FAIL — the run errors reading `KNOWLEDGE.md` (the generator does not create it yet), or assertions fail. Non-zero exit.

- [ ] **Step 3: Edit `regen-active.ps1` — exclusion list**

Add `KNOWLEDGE.md` to the skip list (currently line 29):

```powershell
  Where-Object { $_.Name -notin @('ACTIVE.md','FEATURES.md','KNOWLEDGE.md','README.md','DESIGN.md') } |
```

- [ ] **Step 4: Edit `regen-active.ps1` — parse durable/topic and restructure the terminal drop**

Replace the block that currently reads (lines ~60-71):

```powershell
    $status = (& $get 'status' '').ToLower()
    if ($status -in $terminalStatuses) { return }   # terminal: drop from both indexes
    $rel = ($_.FullName.Substring($root.Length + 1)) -replace '\\','/'
    $items += [pscustomobject]@{
      Title     = (& $get 'title' $_.BaseName)
      Areas     = ((& $get 'areas' '').Trim('[',']'))
      Status    = $status
      Feature   = ((& $get 'feature' '').Trim('[',']'))
      Updated   = (& $get 'updated' '')
      Resume    = (& $get 'resume' $rel)
      Rel       = $rel
    }
```

with:

```powershell
    $status  = (& $get 'status' '').ToLower()
    $durable = ((& $get 'durable' '').ToLower() -in @('true','yes','1'))
    # Terminal status drops a NON-durable note from all indexes (as before). A durable
    # note is never discarded here — it must persist in KNOWLEDGE.md regardless of status;
    # its terminal status is applied at render time to keep it out of ACTIVE/FEATURES.
    if ($status -in $terminalStatuses -and -not $durable) { return }
    $rel = ($_.FullName.Substring($root.Length + 1)) -replace '\\','/'
    $items += [pscustomobject]@{
      Title     = (& $get 'title' $_.BaseName)
      Areas     = ((& $get 'areas' '').Trim('[',']'))
      Status    = $status
      Feature   = ((& $get 'feature' '').Trim('[',']'))
      Topic     = ((& $get 'topic' '').Trim('[',']'))
      Durable   = $durable
      Updated   = (& $get 'updated' '')
      Resume    = (& $get 'resume' $rel)
      Rel       = $rel
    }
```

- [ ] **Step 5: Edit `regen-active.ps1` — exclude terminal durable notes from ACTIVE.md**

Change the ACTIVE items filter (currently line ~107):

```powershell
$activeItems = @($items | Where-Object { $_.Status })
```

to:

```powershell
$activeItems = @($items | Where-Object { $_.Status -and ($_.Status -notin $terminalStatuses) })
```

- [ ] **Step 6: Edit `regen-active.ps1` — exclude terminal durable notes from FEATURES.md**

Change the FEATURES items filter (currently line ~130):

```powershell
$featItems = @($items | Where-Object { $_.Feature })
```

to:

```powershell
$featItems = @($items | Where-Object { $_.Feature -and ($_.Status -notin $terminalStatuses) })
```

(A `feature:`-only companion note has empty `Status`, which is not a terminal value, so it still appears — unchanged behavior.)

- [ ] **Step 7: Edit `regen-active.ps1` — emit KNOWLEDGE.md**

Append after the FEATURES.md `Set-Content` (end of file, after line ~161):

```powershell

# ---- KNOWLEDGE.md ----
# Durable (evergreen) docs, grouped by topic:. Membership is `durable: true` REGARDLESS
# of status — this is the one index terminal status does not empty. Not imported into
# sessions (human/on-demand navigation aid, like FEATURES.md).
$ksb = [System.Collections.Generic.List[string]]::new()
$ksb.Add('<!-- GENERATED by regen-active.ps1 from per-note frontmatter. Do not edit by hand. -->')
$ksb.Add('# By topic')
$ksb.Add('')
$knowItems = @($items | Where-Object { $_.Durable })
$emitRow = {
  param($it)
  $seg = @(& $mdLink $it.Rel)
  if ($it.Status)  { $seg += $it.Status }
  if ($it.Updated) { $seg += $it.Updated }
  '- ' + ($seg -join ' · ')
}
if ($knowItems.Count -eq 0) {
  $ksb.Add('_(none)_')
} else {
  $groups = @{}
  $ungrouped = @()
  foreach ($it in $knowItems) {
    $topics = @($it.Topic -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($topics.Count -eq 0) { $ungrouped += $it; continue }
    foreach ($slug in $topics) {
      if (-not $groups.ContainsKey($slug)) { $groups[$slug] = @() }
      $groups[$slug] += $it
    }
  }
  $orderedSlugs = @($groups.Keys | Sort-Object @{Expression={ @($groups[$_].Updated | Sort-Object -Descending)[0] }; Descending=$true}, @{Expression={$_}})
  foreach ($slug in $orderedSlugs) {
    $members = @($groups[$slug] | Sort-Object @{Expression='Updated';Descending=$true}, Title)
    $ksb.Add("## $slug")
    foreach ($it in $members) { $ksb.Add((& $emitRow $it)) }
    $ksb.Add('')
  }
  if ($ungrouped.Count) {
    $ksb.Add('## Ungrouped')
    foreach ($it in @($ungrouped | Sort-Object @{Expression='Updated';Descending=$true}, Title)) { $ksb.Add((& $emitRow $it)) }
    $ksb.Add('')
  }
}
$outKnowledge = Join-Path $wsDir 'KNOWLEDGE.md'
Set-Content -LiteralPath $outKnowledge -Value ($ksb -join "`n") -Encoding utf8
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `pwsh -NoProfile -File tests/regen-active.Tests.ps1`
Expected: PASS — `All assertions passed`, exit 0.

- [ ] **Step 9: Commit**

```bash
git add regen-active.ps1 tests/regen-active.Tests.ps1
git commit -m "feat(generator): add durable knowledge docs + KNOWLEDGE.md index"
```

---

## Task 2: Documentation

**Files:**
- Modify: `_workspace/claude-instructions.md`
- Modify: `DESIGN.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: the frontmatter contract and index behavior from Task 1.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Update `_workspace/claude-instructions.md` — frontmatter block**

In the frontmatter example (after the `feature:` line, ~line 16), add:

```
    durable: true              # optional; evergreen doc, never pruned -> KNOWLEDGE.md
    topic: some-topic-slug     # optional; groups this note in KNOWLEDGE.md
```

- [ ] **Step 2: Update `_workspace/claude-instructions.md` — axes section**

After the `feature:` bullet in "Two independent axes" (~line 31-35), rename the heading to `## Three axes` and add:

```markdown
- **`durable: true` → `KNOWLEDGE.md`** (evergreen reference, grouped by `topic:`). A durable
  note appears in `KNOWLEDGE.md` **regardless of `status:`** — terminal status does NOT drop it.
  Use it for the "how this works and why" record (architecture, data flow, landmines) that must
  outlive the feature. `topic:` (kebab-case, accepts a list) is its grouping key, parallel to
  `feature:`. A durable note may also carry a `status:` while a follow-up is in flight (it then
  shows in `ACTIVE.md` too); when that status goes terminal it leaves `ACTIVE.md` but stays in
  `KNOWLEDGE.md`. `KNOWLEDGE.md`, like `FEATURES.md`, is NOT imported into sessions — link to a
  durable doc from the checkpoint note you are working under.
```

- [ ] **Step 3: Update `_workspace/claude-instructions.md` — lifecycle carve-out**

Change the delete guidance (currently ~line 42):

```
- Delete a note once its commit merges — git history is the durable record.
```

to:

```
- Delete a *transient* note once its commit merges — git history is the durable record.
  **Exception:** a `durable: true` note is evergreen — keep it and update it; never delete it
  on completion.
```

- [ ] **Step 4: Update `DESIGN.md` — new key decision**

After the "Two orthogonal generated indexes" decision (~line 25), add a `### A third axis for evergreen knowledge` decision documenting: `durable: true` as an orthogonal boolean (not a reserved `status:` value, which would re-create transient/durable conflation); `topic:` grouping; KNOWLEDGE.md exempt from terminal-status dropping; not imported (token-cost). Add to "Rejected alternatives": *reserved `status:` value for durable* — rejected because a note carries both an evergreen record and a transient watch item, so durability must be orthogonal to status.

Full text to insert as the new decision:

```markdown
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
```

- [ ] **Step 5: Update `DESIGN.md` — rejected alternative + trim Future work**

In "Rejected alternatives", add:

```markdown
- **Reserved `status:` value for durable notes.** Simpler than a new axis, but a closing feature
  leaves both an evergreen record and a transient watch item in one note; a status value can be
  only one of the two at a time. Rejected — durability must be orthogonal to status.
```

Then in "Future work", replace the whole "Durable knowledge docs" subsection with a shipped-note + the two remaining deferrals:

```markdown
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
```

- [ ] **Step 6: Update `README.md` — two indexes → three**

In "How it works" (~line 11-14), add a third bullet after FEATURES.md:

```markdown
- `_workspace/KNOWLEDGE.md` — evergreen "how it works and why" docs, grouped by `topic:`.
```

Change the lead-in "rebuilds two indexes" to "rebuilds these indexes". In "Directory layout" (~line 165), the `_workspace/` line already says "generated indexes" (plural) — leave it. In "Repo topology" no change.

- [ ] **Step 7: Verify docs render and generator still runs clean**

Run: `pwsh -NoProfile -File regen-active.ps1` then `pwsh -NoProfile -File tests/regen-active.Tests.ps1`
Expected: generator exits 0; test prints `All assertions passed`.

- [ ] **Step 8: Commit**

```bash
git add _workspace/claude-instructions.md DESIGN.md README.md
git commit -m "docs: document durable knowledge docs axis and KNOWLEDGE.md"
```

---

## Self-Review

**Spec coverage:**
- Decision 1 (marker `durable: true` + `topic:`) → Task 1 Steps 4; docs Task 2 Steps 1-2. ✓
- Decision 2 (routing/anti-pruning, terminal restructure, ACTIVE/FEATURES exclusion) → Task 1 Steps 4-6; tests scenarios 1-3,5. ✓
- Decision 3 (KNOWLEDGE.md generated, not imported, grouped by topic, Ungrouped bucket) → Task 1 Step 7; test scenarios 4,6; docs note "not imported". ✓
- Decision 4 (claude-instructions carve-out, DESIGN promotion, placement unchanged) → Task 2 Steps 3-5. ✓
- Generator specifics 1-4 → Task 1 Steps 3-7. ✓
- All 6 spec test cases → tests scenarios 1-6. ✓
- README accuracy (not in spec's touchpoints but a real contradiction otherwise) → Task 2 Step 6. Added deliberately.

**Placeholder scan:** No TBD/TODO/"handle edge cases"; all code steps show complete code. ✓

**Type consistency:** New item fields `Topic`/`Durable` defined in Task 1 Step 4 and consumed only in Steps 5-7 (same script). `$emitRow` helper defined before use. `$mdLink` reused from existing code. Heading level: implemented as `## Ungrouped` (a peer group under `# By topic`), a deliberate refinement of the spec's `# Ungrouped` wording for heading-level consistency with `## <topic>` groups. ✓

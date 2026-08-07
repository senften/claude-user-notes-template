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
function NoteB($fm, $body) { "---`n$fm`n---`n`n$body" }

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

# Scenario 5b: feature-only note with no status (FEATURES regression).
$root = New-Root
Add-Note $root 'Nav/comp.md' (Note "title: Nav Component`nfeature: nav-x`nupdated: 2026-07-17")
$r = Invoke-Gen $root
Assert 'feature-only in FEATURES'  ($r.Features -match 'nav-x' -and $r.Features -match 'comp.md')
Assert 'feature-only not in ACTIVE' (-not ($r.Active -match 'Nav Component'))

# Scenario 5c: topic without durable flag (regression: topic alone does not trigger KNOWLEDGE).
$root = New-Root
Add-Note $root 'Arch/sketch.md' (Note "title: Sketch`ntopic: solo`nstatus: in-progress`nupdated: 2026-07-16")
$r = Invoke-Gen $root
Assert 'topic-only not in KNOWLEDGE' (-not ($r.Knowledge -match 'sketch.md'))

# Scenario 6: multi-topic durable note appears under each.
$root = New-Root
Add-Note $root 'Svc/multi.md' (Note "title: Multi`ndurable: true`ntopic: [alpha, beta]`nupdated: 2026-07-21")
$r = Invoke-Gen $root
Assert 'multi-topic under alpha' ($r.Knowledge -match '## alpha')
Assert 'multi-topic under beta'  ($r.Knowledge -match '## beta')

# --- ACTIVE.md row text from the note body's `## Resume` section ---
# The `no dash` assertions below scan the whole of ACTIVE.md for an em dash, and one of
# the generator's own section headings is `# In Review — PR`. These fixtures use
# `status: in-progress` so they route to the `# Active work` catch-all and the file stays
# em-dash-free; retargeting one at a review status fails for reasons unrelated to the code.

# Scenario 7: row text comes from the first line of ## Resume.
$root = New-Root
Add-Note $root '_workspace/r1.md' (NoteB "title: R1`nstatus: in-progress`nupdated: 2026-08-07" "# R1`n`n## Resume`n`nPR 6930 open, waiting on QA.`n`nMore detail further down.")
$r = Invoke-Gen $root
Assert 'resume first line renders in row'   ($r.Active -match 'PR 6930 open, waiting on QA\.')
Assert 'later resume lines excluded'        (-not ($r.Active -match 'More detail further down'))
Assert 'row renders as two lines'           ($r.Active -match '(?m)^  \[r1\.md\]\(\.\./_workspace/r1\.md\) — ')

# Scenario 8: no ## Resume section -> doc link only, no separator.
$root = New-Root
Add-Note $root '_workspace/r2.md' (NoteB "title: R2`nstatus: in-progress`nupdated: 2026-08-07" "# R2`n`nJust prose, no resume section.")
$r = Invoke-Gen $root
Assert 'missing resume section still rows'  ($r.Active -match '\[r2\.md\]\(\.\./_workspace/r2\.md\)')
Assert 'missing resume section: no dash'    (-not ($r.Active -match "—"))
Assert 'body prose is not scavenged'        (-not ($r.Active -match 'Just prose'))

# Scenario 8b: ## Resume present but empty (next heading follows) -> link only.
$root = New-Root
Add-Note $root '_workspace/r3.md' (NoteB "title: R3`nstatus: in-progress`nupdated: 2026-08-07" "# R3`n`n## Resume`n`n## Detail`n`nSome detail.")
$r = Invoke-Gen $root
Assert 'empty resume section: no dash'      (-not ($r.Active -match "—"))
Assert 'empty resume section: no scavenge'  (-not ($r.Active -match 'Some detail'))

# Scenario 9: an over-long single line is truncated at a word boundary with an ellipsis.
$long = ('word ' * 100).Trim()
$root = New-Root
Add-Note $root '_workspace/r4.md' (NoteB "title: R4`nstatus: in-progress`nupdated: 2026-08-07" "# R4`n`n## Resume`n`n$long")
$r = Invoke-Gen $root
Assert 'long line truncated'                ($r.Active -match "…")
Assert 'full long line absent'              (-not ($r.Active -match [regex]::Escape($long)))
Assert 'truncated at a word boundary'       (-not ($r.Active -match "wor…"))

# Scenario 10: legacy resume: frontmatter is ignored entirely.
$root = New-Root
Add-Note $root '_workspace/r5.md' (NoteB "title: R5`nstatus: in-progress`nupdated: 2026-08-07`nresume: LEGACYVALUE must not render" "# R5`n`nNo resume section here.")
$r = Invoke-Gen $root
Assert 'legacy resume: frontmatter ignored' (-not ($r.Active -match 'LEGACYVALUE'))
Assert 'legacy note still gets a row'       ($r.Active -match 'R5')

# Scenario 11: a bulleted first line renders without its list marker.
$root = New-Root
Add-Note $root '_workspace/r6.md' (NoteB "title: R6`nstatus: in-progress`nupdated: 2026-08-07" "# R6`n`n## Resume`n`n- Bulleted status line.")
$r = Invoke-Gen $root
Assert 'list marker stripped from row'      ($r.Active -match "— Bulleted status line\.")

if ($fails -gt 0) { Write-Host "`n$fails failure(s)"; exit 1 }
Write-Host "`nAll assertions passed"; exit 0

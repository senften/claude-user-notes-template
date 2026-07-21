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

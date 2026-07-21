# Regenerates _workspace/ACTIVE.md, _workspace/FEATURES.md, and _workspace/KNOWLEDGE.md
# from per-note frontmatter. Source of truth = each note's YAML frontmatter. The script
# finds its own root via $PSScriptRoot, so it needs no per-clone edit; it runs on
# Windows PowerShell and, via pwsh, on macOS/Linux.
#
# Three independent axes:
#   status:  -> ACTIVE.md  (active-work tracker; one row per effort)
#     done/archived/complete/completed -> dropped (terminal)
#     otherwise routed to one of the ordered $sections buckets (see below);
#     any non-terminal status not matched by a bucket falls to "Active work".
#   feature: -> FEATURES.md (all notes of a feature, grouped by slug; navigation)
#   durable: -> KNOWLEDGE.md (durable knowledge docs, grouped by topic:)
#     true routes to KNOWLEDGE.md and is EXEMPT from terminal-status dropping.
#
# A note may carry any combination of these. Terminal status drops a note from
# ACTIVE.md and FEATURES.md. A durable: true note must persist in KNOWLEDGE.md
# regardless of status. A note with feature: but no status: appears only in
# FEATURES.md. Only non-empty sections are emitted. No timestamp in output, so an
# index changes only when the underlying frontmatter changes.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (-not $root -or -not (Test-Path -LiteralPath $root)) { exit 0 }
$wsDir = Join-Path $root '_workspace'
if (-not (Test-Path -LiteralPath $wsDir)) { New-Item -ItemType Directory -Path $wsDir | Out-Null }
$outActive   = Join-Path $wsDir 'ACTIVE.md'
$outFeatures = Join-Path $wsDir 'FEATURES.md'

$terminalStatuses = @('done','archived','complete','completed')

$items = @()
Get-ChildItem -LiteralPath $root -Recurse -Filter *.md -File |
  Where-Object { $_.Name -notin @('ACTIVE.md','FEATURES.md','KNOWLEDGE.md','README.md','DESIGN.md') } |
  ForEach-Object {
    $lines = @(Get-Content -LiteralPath $_.FullName)
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') { return }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq '---') { $end = $i; break } }
    if ($end -lt 0) { return }
    # Line-based frontmatter parse (not a full YAML parser). Handles scalars,
    # inline arrays (`key: [a, b]`) and multi-line block lists:
    #   key:
    #     - a
    #     - b
    # so Obsidian's Properties editor reformatting an inline array into a block
    # list doesn't silently drop the value. Block items are joined as `a, b` to
    # match the inline-array rendering used downstream.
    $fm = @{}
    $curKey = $null
    for ($i = 1; $i -lt $end; $i++) {
      $line = $lines[$i]
      if ($curKey -and $line -match '^\s*-\s+(.*)$') {
        $item = $Matches[1].Trim().Trim('"',"'")
        $fm[$curKey] = if ($fm[$curKey]) { "$($fm[$curKey]), $item" } else { $item }
      }
      elseif ($line -match '^\s*([A-Za-z0-9_]+):\s*(.*)$') {
        $curKey = $Matches[1]
        $val = $Matches[2].Trim()
        $fm[$curKey] = $val
        if ($val -ne '') { $curKey = $null }   # scalar / inline array; no block list follows
      }
    }
    $get = { param($k,$d) if ($fm.ContainsKey($k)) { $fm[$k].Trim('"',"'") } else { $d } }
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
  }

$items = @($items | Sort-Object @{Expression='Updated';Descending=$true}, Title)

# Shared clickable markdown link (filename text, ../-relative from _workspace/).
$mdLink = { param($rel) $leaf = ($rel -split '/')[-1]; "[$leaf](../$rel)" }

# ---- ACTIVE.md ----
# Ordered section definitions: display order top (most active) to bottom.
# The single entry with Keywords = $null is the catch-all (Active work) and must
# appear exactly once. Keyword sets are mutually exclusive; matched exact, lowercased.
$sections = @(
  @{ Heading = '# Active work';                     Keywords = $null }
  @{ Heading = '# In Review — PR';                  Keywords = @('in-review','review','pr') }
  @{ Heading = '# Blocked';                         Keywords = @('blocked','waiting') }
  @{ Heading = '# Resolved — pending verification'; Keywords = @('verifying','merged-pending-verification','pending-verification') }
  @{ Heading = '# Watching';                        Keywords = @('watching','watch') }
  @{ Heading = '# On Hiatus';                       Keywords = @('hiatus','paused','shelved') }
  @{ Heading = '# Future';                          Keywords = @('future','planned') }
)
$claimed = @($sections | Where-Object { $_.Keywords } | ForEach-Object { $_.Keywords })

$sb = [System.Collections.Generic.List[string]]::new()
$sb.Add('<!-- GENERATED by regen-active.ps1 from per-note frontmatter. Do not edit by hand. -->')

# Two lines of markdown for one item row.
$rowFor = {
  param($it)
  $head = @("**$($it.Title)**")
  if ($it.Areas) { $head += $it.Areas }
  $head += "status: $($it.Status)"
  if ($it.Updated) { $head += "updated: $($it.Updated)" }
  @('- ' + ($head -join ' · '), "  doc: $(& $mdLink $it.Rel) · resume: ``$($it.Resume)``")
}

$activeItems = @($items | Where-Object { $_.Status -and ($_.Status -notin $terminalStatuses) })
$any = $false
foreach ($sec in $sections) {
  if ($null -eq $sec.Keywords) {
    $rows = @($activeItems | Where-Object { $_.Status -notin $claimed })
  } else {
    $rows = @($activeItems | Where-Object { $_.Status -in $sec.Keywords })
  }
  if ($rows.Count -eq 0) { continue }
  if ($any) { $sb.Add('') }
  $sb.Add($sec.Heading)
  $sb.Add('')
  foreach ($it in $rows) { foreach ($ln in (& $rowFor $it)) { $sb.Add($ln) } }
  $any = $true
}
if (-not $any) { $sb.Add('# Active work'); $sb.Add(''); $sb.Add('_(none)_') }
Set-Content -LiteralPath $outActive -Value ($sb -join "`n") -Encoding utf8

# ---- FEATURES.md ----
$fsb = [System.Collections.Generic.List[string]]::new()
$fsb.Add('<!-- GENERATED by regen-active.ps1 from per-note frontmatter. Do not edit by hand. -->')
$fsb.Add('# By feature')
$fsb.Add('')
$featItems = @($items | Where-Object { $_.Feature -and ($_.Status -notin $terminalStatuses) })
if ($featItems.Count -eq 0) {
  $fsb.Add('_(none)_')
} else {
  $groups = @{}
  foreach ($it in $featItems) {
    foreach ($slug in ($it.Feature -split ',')) {
      $s = $slug.Trim()
      if (-not $s) { continue }
      if (-not $groups.ContainsKey($s)) { $groups[$s] = @() }
      $groups[$s] += $it
    }
  }
  $orderedSlugs = @($groups.Keys | Sort-Object @{Expression={ @($groups[$_].Updated | Sort-Object -Descending)[0] }; Descending=$true}, @{Expression={$_}})
  foreach ($slug in $orderedSlugs) {
    $members = @($groups[$slug] | Sort-Object @{Expression='Updated';Descending=$true}, Title)
    $areas = @($members.Areas | Where-Object { $_ } |
               ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } |
               Where-Object { $_ } | Select-Object -Unique)
    $headParts = @("## $slug")
    if ($areas.Count) { $headParts += ($areas -join ', ') }
    $fsb.Add($headParts -join ' · ')
    foreach ($it in $members) {
      $seg = @(& $mdLink $it.Rel)
      if ($it.Status)  { $seg += $it.Status }
      if ($it.Updated) { $seg += $it.Updated }
      $fsb.Add('- ' + ($seg -join ' · '))
    }
    $fsb.Add('')
  }
}
Set-Content -LiteralPath $outFeatures -Value ($fsb -join "`n") -Encoding utf8

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

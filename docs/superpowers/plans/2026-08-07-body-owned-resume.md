# Body-Owned Resume Recaps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the effort recap out of the `resume:` frontmatter field into a `## Resume` section in the note body, and derive the `ACTIVE.md` row text from that section's first line.

**Architecture:** `regen-active.ps1` already slurps every note's full contents to parse frontmatter and already knows the index of the frontmatter's closing `---`. A new scriptblock scans forward from there for a `## Resume` heading and returns its first content line, capped at 240 characters. That value replaces the old `resume:` frontmatter read; the rest of the generator (status routing, `FEATURES.md`, `KNOWLEDGE.md`) is untouched. The remaining tasks are the authoring contract (`claude-instructions.md`), a migration procedure for downstream repos (`MIGRATION.md`), and the rationale record (`DESIGN.md`).

**Tech Stack:** PowerShell 7 (`pwsh`), markdown. No dependencies, no package manager, no build step.

**Spec:** [`docs/superpowers/specs/2026-08-07-body-owned-resume-design.md`](../specs/2026-08-07-body-owned-resume-design.md)

## Global Constraints

- **Heading matched is exactly `## Resume`**, compared after `.Trim()`, case-insensitively. Not `# Resume`, not `### Resume`, no trailing text.
- **Row text cap is 240 characters**, truncated at the last space at or before 240, with `…` appended.
- **Row separator is an em dash** (`—`) between the doc link and the recap text: `[file.md](../rel) — text`.
- **`resume:` frontmatter is not read by the generator at all.** No fallback, no synthesis, no warning.
- **Preserve each edited file's existing encoding: UTF-8, no BOM.** Verified: `regen-active.ps1` is BOM-less and already contains four em dashes (in the `$sections` headings). Do not add a BOM and do not convert line endings; the `—` and `…` characters depend on `pwsh` decoding BOM-less files as UTF-8. (Windows PowerShell 5.1 mis-decodes these; that is pre-existing for the em dashes already present and is out of scope.)
- **Do not touch** `DESIGN-durable-knowledge-docs.md`, or anything else under `docs/superpowers/plans/` and `docs/superpowers/specs/`. They mention `resume:` as historical records of past decisions and must keep doing so.
- **Do not migrate any live notes.** This repo is the template and contains zero notes. Migration is a documented manual pass run per project.
- Commit messages follow Conventional Commits, subject under 72 chars, imperative, lowercase, no trailing period.

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `regen-active.ps1` | Modify | Resolve and cap the row text from the note body; render the row |
| `tests/regen-active.Tests.ps1` | Modify | Assert resolution, truncation, absence, marker-stripping, and that `resume:` is ignored |
| `_workspace/claude-instructions.md` | Modify | The authoring contract the agent follows: where the recap lives, how the first line is written, how to resume |
| `MIGRATION.md` | Create | Per-project post-merge migration procedure (new; the template now has a second consumer) |
| `README.md` | Modify | One-line pointer to `MIGRATION.md` from *Pull template fixes into a project* |
| `DESIGN.md` | Modify | Key decision, four rejected alternatives, history line |

Task 1 is the only code change and carries the whole test cycle. Tasks 2–4 are independently rejectable documentation deliverables: a reviewer could accept the generator change and reject the migration wording, or vice versa.

---

### Task 1: Derive the ACTIVE.md row from the note body

**Files:**
- Modify: `regen-active.ps1` — header comment (lines 6–19), a new scriptblock before the note loop (insert after line 29), the item construction (line 78), and `$rowFor` (lines 107–114)
- Test: `tests/regen-active.Tests.ps1` — a new body-aware fixture helper after line 32, and six scenarios appended before the exit block (lines 86–87)

**Interfaces:**
- Consumes: nothing from earlier tasks (this is the first).
- Produces: the `## Resume` contract that Tasks 2 and 3 document — heading spelled exactly `## Resume`, first non-empty non-heading line becomes the row, leading `- `/`* ` stripped, 240-char cap with `…`, em-dash separator, empty/missing section yields link-only. The internal `$items` property stays named `Resume`.

- [ ] **Step 1: Add the body-aware fixture helper to the test file**

The existing `Note($fm)` helper on line 32 hardcodes the body as the literal string `body`, so it cannot exercise a `## Resume` section. Add a sibling helper immediately after it (keep `Note` — the eight existing scenarios use it):

```powershell
function NoteB($fm, $body) { "---`n$fm`n---`n`n$body" }
```

- [ ] **Step 2: Write the failing tests**

Append these six scenarios to `tests/regen-active.Tests.ps1`, immediately *before* the final `if ($fails -gt 0)` block on line 86:

```powershell
# Scenario 7: row text comes from the first line of ## Resume.
$root = New-Root
Add-Note $root '_workspace/r1.md' (NoteB "title: R1`nstatus: in-progress`nupdated: 2026-08-07" "# R1`n`n## Resume`n`nPR 6930 open, waiting on QA.`n`nMore detail further down.")
$r = Invoke-Gen $root
Assert 'resume first line renders in row'   ($r.Active -match 'PR 6930 open, waiting on QA\.')
Assert 'later resume lines excluded'        (-not ($r.Active -match 'More detail further down'))

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
```

Note the `"—"` / `"…"` escapes: PowerShell 7 double-quoted strings support them, and using escapes rather than literal `—`/`…` keeps the *test* file pure ASCII so a mis-decode can never make an assertion silently pass. The generator itself uses the literal characters.

One coupling to be aware of before changing these fixtures: the `no dash` assertions in scenarios 8 and 8b search the whole of `ACTIVE.md` for an em dash, and one of the generator's own section headings is `# In Review — PR`. Those fixtures use `status: in-progress` so they route to the `# Active work` catch-all, keeping the file em-dash-free. If you retarget one at a review status it will fail for a reason that has nothing to do with the code.

- [ ] **Step 3: Run the tests to verify the new ones fail**

Run: `pwsh -NoProfile -File tests/regen-active.Tests.ps1`

Expected: the eight pre-existing assertions PASS; the new ones FAIL. Specifically, scenario 7 fails (`resume first line renders in row` — the generator does not read the body), scenario 10's first assertion fails (`legacy resume: frontmatter ignored` — it currently renders `LEGACYVALUE`), and scenarios 8/8b/9/11 fail on their `—`/`…` expectations because the current row emits `resume: ` plus a backticked relative path. Exit code non-zero.

- [ ] **Step 4: Add the row-text resolver to the generator**

In `regen-active.ps1`, insert this immediately after line 29 (`$terminalStatuses = @(...)`) and before `$items = @()`:

```powershell
# ACTIVE.md row text comes from the note BODY, not frontmatter: the first non-empty,
# non-heading line of the `## Resume` section. Body markdown can be pruned and
# restructured (a frontmatter scalar could only be appended to), and deriving the row
# from the recap means the two can never disagree. The cap keeps a pasted, not-yet-
# restructured recap from flooding the row — which is why the transition needs no
# migration code. Missing or empty section => no row text, just the doc link.
$resumeCap = 240
$resumeLine = {
  param($lines, $from)
  $i = $from
  while ($i -lt $lines.Count -and $lines[$i].Trim() -notmatch '^##\s+Resume$') { $i++ }
  if ($i -ge $lines.Count) { return '' }
  for ($j = $i + 1; $j -lt $lines.Count; $j++) {
    $t = $lines[$j].Trim()
    if ($t -eq '') { continue }
    if ($t.StartsWith('#')) { return '' }        # empty section: next heading reached
    $t = $t -replace '^[-*]\s+', ''              # a bulleted first line is still a row
    if ($t.Length -le $resumeCap) { return $t }
    $cut = $t.Substring(0, $resumeCap)
    $sp = $cut.LastIndexOf(' ')
    if ($sp -gt 0) { $cut = $cut.Substring(0, $sp) }
    return ($cut.TrimEnd() + '…')
  }
  return ''
}
```

- [ ] **Step 5: Switch the item construction off the frontmatter field**

In `regen-active.ps1` line 78, replace:

```powershell
      Resume    = (& $get 'resume' $rel)
```

with:

```powershell
      Resume    = (& $resumeLine $lines ($end + 1))
```

`$lines` and `$end` are both already in scope at that point (set on lines 34 and 36–37). The old `$rel` fallback goes away; `Rel` is still emitted separately on the next line and remains the source of the doc link.

- [ ] **Step 6: Render the new row shape**

In `regen-active.ps1`, replace the `$rowFor` body (lines 107–114) with:

```powershell
# Two lines of markdown for one item row. The second line is the doc link plus the
# resume first line; the em dash is omitted when there is no resume text.
$rowFor = {
  param($it)
  $head = @("**$($it.Title)**")
  if ($it.Areas) { $head += $it.Areas }
  $head += "status: $($it.Status)"
  if ($it.Updated) { $head += "updated: $($it.Updated)" }
  $second = '  ' + (& $mdLink $it.Rel)
  if ($it.Resume) { $second += " — $($it.Resume)" }
  @('- ' + ($head -join ' · '), $second)
}
```

This drops the `doc:` and `resume:` labels and the backtick code span. Losing the code span is deliberate: it retires the old "no backticks in the value" prohibition and lets a recap line use inline code for a branch or file name.

- [ ] **Step 7: Update the generator's header comment**

In `regen-active.ps1`, the header comment (lines 6–19) describes the three axes. Add a line to the `status:` bullet so the file documents its own new body dependency. Replace line 8:

```powershell
#   status:  -> ACTIVE.md  (active-work tracker; one row per effort)
```

with:

```powershell
#   status:  -> ACTIVE.md  (active-work tracker; one row per effort; the row's text is
#            the first line of the note body's `## Resume` section — see $resumeLine)
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `pwsh -NoProfile -File tests/regen-active.Tests.ps1`

Expected: all assertions PASS, final line `All assertions passed`, exit code 0. If scenario 9's `truncated at a word boundary` fails, check that `$cut.LastIndexOf(' ')` is being applied to the 240-char slice and not the whole string.

- [ ] **Step 9: Eyeball a realistic row**

The cap is a judgment call about terminal width, so look at one before committing. Run:

```bash
mkdir -p /tmp/rowcheck/_workspace && cp regen-active.ps1 /tmp/rowcheck/
printf -- '---\ntitle: Navigator UpwardProperty refactor\nstatus: in-review\nareas: [navigator]\nupdated: 2026-08-06\n---\n\n# Navigator UpwardProperty refactor\n\n## Resume\n\nPR 6930: every gate closed except QA, so there is no author-side action outstanding.\n\nDetail below.\n' > /tmp/rowcheck/_workspace/nav.md
pwsh -NoProfile -File /tmp/rowcheck/regen-active.ps1 && cat /tmp/rowcheck/_workspace/ACTIVE.md
```

Expected output:

```
<!-- GENERATED by regen-active.ps1 from per-note frontmatter. Do not edit by hand. -->
# In Review — PR

- **Navigator UpwardProperty refactor** · navigator · status: in-review · updated: 2026-08-06
  [nav.md](../_workspace/nav.md) — PR 6930: every gate closed except QA, so there is no author-side action outstanding.
```

Confirm the em dash renders as `—` and not mojibake. Then `rm -rf /tmp/rowcheck`.

- [ ] **Step 10: Commit**

```bash
git add regen-active.ps1 tests/regen-active.Tests.ps1
git commit -m "feat: derive ACTIVE.md row from body ## Resume section"
```

---

### Task 2: Rewrite the authoring contract

**Files:**
- Modify: `_workspace/claude-instructions.md` — frontmatter block (lines 10–19), the quoting paragraph (lines 21–25), the two `resume:` constraint bullets (lines 27–37)

**Interfaces:**
- Consumes: Task 1's contract — exact heading `## Resume`, first line becomes the row, 240-char cap, missing section yields no row text.
- Produces: the wording Task 3's `MIGRATION.md` tells people to migrate *toward*. Keep the two files consistent on the heading spelling and the "one standalone status sentence" rule.

- [ ] **Step 1: Drop `resume:` from the frontmatter block**

In `_workspace/claude-instructions.md`, delete line 15 entirely:

```
    resume: branch or path to pick up from
```

The remaining keys (`title:`, `status:`, `areas:`, `updated:`, `feature:`, `durable:`, `topic:`) are unchanged.

- [ ] **Step 2: Trim the quoting paragraph and delete both `resume:` constraints**

Replace lines 21–37 — that is, the whole `Quote any scalar value…` paragraph plus the `Two further constraints on resume:` lead-in and both of its bullets — with this single paragraph:

```markdown
Quote any scalar value that contains a colon-space (`:` + ` `) or starts with a
YAML-special character — wrap it in `"..."`. `regen-active.ps1` uses a tolerant
line-based parser that doesn't care, but editors/tools with a real YAML parser (e.g.
VS Code's frontmatter preview) do, and will fail with a "nested mappings" error.
```

The quoting rule stays — it still applies to `title:` and any other scalar. Both `resume:` constraints go: the backtick prohibition existed because the row was a code span, and the one-line/no-block-scalar rule existed because the line-based parser truncated folded scalars. Neither applies to body markdown.

- [ ] **Step 3: Add the `## Resume` section**

Insert this immediately after the paragraph from Step 2 and before the `## Three axes` heading:

```markdown
## The `## Resume` section

The recap lives in the note **body**, not in frontmatter — a `## Resume` section
directly under the note's title heading:

    # MWL gauge-restart on redefine

    ## Resume

    Engineering is done; two commits in two repos remain, merge mechanics only.

    <the rest of the recap — as many paragraphs, bullets and tables as it needs>

- **The first line becomes the `ACTIVE.md` row.** Write it as ONE standalone sentence
  of current status: what state this effort is in and what happens next. It is
  truncated at 240 characters in the row, so put the load-bearing fact first.
- **Rewrite it whenever you bump `updated:`.** Same edit, every time — a stale first
  line is a lying status board.
- **Everything below the first line is yours to shape.** It is ordinary body markdown:
  prune and restructure it. Do NOT append a changelog — if a paragraph is superseded,
  delete it rather than writing "the above is now retired".
- The heading must be exactly `## Resume`. The generator matches it literally; if it is
  missing or the section is empty the row renders as the doc link alone, with no text.

**Resuming an effort.** When asked to resume a named effort, match the title in
`ACTIVE.md`, open the linked note, and read `## Resume` FIRST. It supersedes anything
below it — prose further down may have been overtaken and is not authoritative.
```

- [ ] **Step 4: Verify no stale references and that the imports still trail the file**

Run:

```bash
grep -n 'resume' _workspace/claude-instructions.md
tail -3 _workspace/claude-instructions.md
```

Expected: `grep` matches only the new `## Resume` section (the heading, the example, and the four bullets) — no `resume:` frontmatter key, no backtick constraint, no block-scalar constraint. `tail` still shows `@claude-instructions.local.md` then a blank line then `@ACTIVE.md`, in that order: the local overlay must still load *before* `ACTIVE.md`.

- [ ] **Step 5: Confirm the documented example actually renders**

The instructions now promise a specific shape; check it against the real generator rather than trusting the prose. Run:

```bash
mkdir -p /tmp/contract/_workspace && cp regen-active.ps1 /tmp/contract/
printf -- '---\ntitle: MWL gauge-restart on redefine\nstatus: in-progress\nupdated: 2026-08-07\n---\n\n# MWL gauge-restart on redefine\n\n## Resume\n\nEngineering is done; two commits in two repos remain, merge mechanics only.\n\nMore below.\n' > /tmp/contract/_workspace/mwl.md
pwsh -NoProfile -File /tmp/contract/regen-active.ps1 && cat /tmp/contract/_workspace/ACTIVE.md
```

Expected: the row's second line reads `[mwl.md](../_workspace/mwl.md) — Engineering is done; two commits in two repos remain, merge mechanics only.` Then `rm -rf /tmp/contract`.

- [ ] **Step 6: Commit**

```bash
git add _workspace/claude-instructions.md
git commit -m "docs: move the recap contract to a body ## Resume section"
```

---

### Task 3: Document the migration for downstream repos

**Files:**
- Create: `MIGRATION.md`
- Modify: `README.md` — the *Pull template fixes into a project* section (lines 64–71)

**Interfaces:**
- Consumes: Task 2's authoring contract (heading spelling, first-line rule) — the migration must move notes toward exactly that shape.
- Produces: nothing later tasks depend on.

Why this task exists: the template has a second consumer, and any project pulling this change has notes full of `resume:` fields. Without a written procedure, the visible symptom is unexplained bare rows. Dated sections so the next breaking skeleton change appends instead of rewriting.

- [ ] **Step 1: Create `MIGRATION.md`**

```markdown
# Migration notes

Steps to run in a **project's notes repo** after `git fetch upstream && git merge upstream/main`
brings a skeleton change that existing notes don't match. Newest first. If your notes already
follow the current conventions there is nothing to do.

## 2026-08-07 — the resume recap moved into the note body

**What changed.** The `resume:` frontmatter field is gone. The recap now lives in the note body
under a `## Resume` heading, and `regen-active.ps1` renders the **first line** of that section as
the `ACTIVE.md` row, truncated at 240 characters.

**Why.** As a frontmatter scalar the recap could only be appended to, so recaps grew into
changelogs rather than current state. `ACTIVE.md` is `@`-imported into every session, so full
recaps for every watching/hiatus/future effort were injected on every session when the workflow
("let's resume &lt;title&gt;") needs exactly one. And the recap existed in two places — the field
and the body — with only the field in the update habit, so bodies went stale. Body markdown can be
pruned and restructured, and deriving the row from it means board and recap cannot disagree.

**What you'll see after the merge.** Every note still carrying `resume:` renders as a bare row:
title, areas, status, date and the doc link, with no recap text. Nothing is lost — the field is
still in the note file. Rows come back as you migrate each note.

### Migrate with Claude (recommended)

Start a session in your notes repo and paste:

> Migrate every note in this repo to body-owned resume recaps. For each note that has a `resume:`
> frontmatter field: delete that field, and insert a `## Resume` section directly under the note's
> title heading whose content is the field's value verbatim. Then rewrite only the FIRST line of
> that new section as one standalone sentence of current status — what state the effort is in and
> what happens next — leaving the rest of the pasted value untouched below it. If the note already
> has body prose the recap supersedes, do NOT try to merge them: add a `## Historical` heading
> above that prose and leave it in place. Do not change any other frontmatter key, and do not
> prune or rewrite recap content beyond that first line. List every file you changed when done.

Then run the generator (or end the turn and let the Stop hook do it) and read
`_workspace/ACTIVE.md` to check the rows.

### Migrate by hand

For each note with a `resume:` field:

1. Cut the value of `resume:`, then delete the key.
2. Add `## Resume` directly under the note's `#` title and paste the value beneath it.
3. Rewrite the first line as a one-sentence status. Everything else can stay as it is.
4. If body prose below is superseded by the recap, put a `## Historical` heading above it.
5. Unquote as you go. The old field needed a single quoted line with no backticks; body text has
   neither restriction, so break it into paragraphs and use inline code freely.

### Notes

- You don't have to migrate everything at once — an unmigrated note just renders a bare row.
- Nothing needs re-wiring. The generated indexes are `.gitignore`d and rebuilt from scratch on the
  next Stop hook, so there are no index conflicts on the merge and no stale output.
- Don't reconcile a pasted recap against the stale prose below it during migration; that is
  per-effort judgment. `## Historical` means nothing to the generator — it is a marker for you, so
  the pruning can happen the next time you actually work that effort.
```

- [ ] **Step 2: Point at it from README**

In `README.md`, the *Pull template fixes into a project* section currently ends at line 71 with the paragraph beginning `The template has zero note files…`. Add this paragraph immediately after it:

```markdown
If a skeleton change also changes what notes are expected to *contain*, the post-merge steps are
in [`MIGRATION.md`](MIGRATION.md), newest first. Merging never rewrites your notes, so a
convention change shows up as a degraded index until you migrate.
```

- [ ] **Step 3: Verify the new file is invisible to the generator**

`MIGRATION.md` sits in the repo root next to `README.md` and `DESIGN.md`, which are named in the generator's exclusion list on line 32. `MIGRATION.md` is *not* added to that list and must not need to be — the loop's line 35 guard (`$lines[0].Trim() -ne '---'`) already skips any file whose first line isn't a frontmatter delimiter, which is how `DESIGN-durable-knowledge-docs.md` is already skipped. Prove it:

```bash
pwsh -NoProfile -File regen-active.ps1
grep -c 'MIGRATION' _workspace/ACTIVE.md _workspace/FEATURES.md _workspace/KNOWLEDGE.md || true
```

Expected: `0` for all three (the template has no notes, so the indexes are the empty `_(none)_` form). The `|| true` is there because `grep -c` exits non-zero when every count is zero — which is the passing case here. If a count is non-zero, `MIGRATION.md` accidentally starts with `---` — fix the file, don't extend the exclusion list.

- [ ] **Step 4: Re-run the test suite**

Run: `pwsh -NoProfile -File tests/regen-active.Tests.ps1`

Expected: all assertions PASS, exit 0. Step 3 ran the generator against the real repo root; this confirms nothing about that changed the tested behaviour.

- [ ] **Step 5: Commit**

```bash
git add MIGRATION.md README.md
git commit -m "docs: add MIGRATION.md for the body-owned resume change"
```

---

### Task 4: Record the decision and its rejected alternatives

**Files:**
- Modify: `DESIGN.md` — insert a key decision after line 87 (end of *A multi-stage lifecycle*, before *Robust-enough frontmatter parsing*); append to *Rejected alternatives* after line 140; append to *History* after line 161

**Interfaces:**
- Consumes: the reasoning from Tasks 1–3. No code dependency.
- Produces: nothing.

Why this task exists: `DESIGN.md` is the durable record of *why*, and the three alternatives discarded during design are each individually attractive. Unrecorded, they get re-derived.

- [ ] **Step 1: Add the key decision**

Insert after line 87 (the end of the *A multi-stage lifecycle* paragraph), before `### Robust-enough frontmatter parsing`:

```markdown
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
```

- [ ] **Step 2: Add the rejected alternatives**

Append these four bullets to the end of the *Rejected alternatives (for the record)* list, after line 140:

```markdown
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
```

- [ ] **Step 3: Add the history line**

Append to the end of the *History* section, after line 161:

```markdown
**2026-08-07** — the `resume:` frontmatter field was replaced by a body-owned `## Resume` section
whose first line is rendered into `ACTIVE.md`. See the key decision above, and `MIGRATION.md` for
the per-project migration.
```

- [ ] **Step 4: Verify the document still reads straight**

Run:

```bash
grep -n '^#' DESIGN.md
grep -n 'resume' DESIGN.md
```

Expected: the heading outline is unchanged apart from the new `### The resume recap lives in the note body; the row is derived from it` sitting between `### A multi-stage lifecycle, not just active/done` and `### Robust-enough frontmatter parsing`. The `resume` matches should appear only in the new decision, the four new bullets, and the history line. Also confirm `DESIGN.md` lines 14–15 still describe only `ACTIVE.md`/`FEATURES.md` — that list predates `KNOWLEDGE.md` and is a pre-existing gap; leave it alone.

- [ ] **Step 5: Commit**

```bash
git add DESIGN.md
git commit -m "docs: record the body-owned resume decision"
```

---

## Final verification

- [ ] `pwsh -NoProfile -File tests/regen-active.Tests.ps1` → all assertions PASS, exit 0
- [ ] `pwsh -NoProfile -File regen-active.ps1` → exits 0 against the note-free template root
- [ ] `git status --short` → clean
- [ ] `grep -rn 'resume:' regen-active.ps1 _workspace/claude-instructions.md` → no matches (the generator no longer reads the key; the instructions no longer document it)
- [ ] `git log --oneline -4` → four commits, one per task
- [ ] `git diff --stat HEAD~4` → touches only `regen-active.ps1`, `tests/regen-active.Tests.ps1`, `_workspace/claude-instructions.md`, `MIGRATION.md`, `README.md`, `DESIGN.md`

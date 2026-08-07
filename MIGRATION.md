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

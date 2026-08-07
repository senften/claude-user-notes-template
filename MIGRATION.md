# Migration notes

Steps to run in a **project's notes repo** after `git fetch upstream && git merge upstream/main`
brings a skeleton change that existing notes don't match. Newest first. If your notes already
follow the current conventions there is nothing to do.

**If your notes live inside the solution's own repo** (the hand-copy mode in
[`README.md`](README.md#alternative-notes-inside-the-solutions-own-repo)), everything below still
applies with two substitutions: prefix every path with your notes subdirectory
(`notes/_workspace/ACTIVE.md`, not `_workspace/ACTIVE.md`), and read "your notes repo" as the
solution repo. That mode has no merge channel, so nothing here arrives on its own — check this file
in your template clone whenever you re-copy the skeleton.

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

**Two paths, with different rules.** A *bulk pass* over notes you are not currently working is
deliberately mechanical — move the value, write a status line, change nothing else — because you do
not hold those efforts in your head and guessing is worse than leaving them alone. Migrating a note
you are *actively working* is the opposite: you already have the context, so restructure the recap
properly. Both are below; most repos use both.

### Bulk pass, with Claude (recommended)

Start a session in your notes repo and paste:

> Migrate every note in this repo to body-owned resume recaps. For each note that has a `resume:`
> frontmatter field:
>
> 1. Delete the `resume:` field, and insert a `## Resume` section directly under the note's title
>    heading — or directly under the frontmatter if the note has no title heading.
> 2. That section's content is: a NEW first line that is one standalone sentence of current status
>    (what state the effort is in and what happens next), then a blank line, then the deleted
>    field's value pasted verbatim. The value is a SINGLE physical line however long it is — that
>    is expected; do not reflow it, re-wrap it, or split it into paragraphs.
> 3. If your new first line fully restates the pasted value's own opening sentence, delete just
>    that opening sentence. Otherwise leave the pasted value completely untouched.
> 4. If the note already has body prose that the recap supersedes, do NOT merge them. Insert the
>    single line `*Superseded by the Resume above; kept for history.*` immediately above that
>    prose and leave the prose itself alone. Use that italic line and NOT a heading: a
>    `## Historical` heading lands as a sibling of the body's own `##` sections, so a reader
>    cannot tell whether it covers the next section or everything to the end of the file.
>
> Do not change any other frontmatter key, and do not prune or rewrite recap content beyond step 3.
> Report every file you changed, and for each one say whether you applied step 3.

Then run the generator (or end the turn and let the Stop hook do it) and read
`_workspace/ACTIVE.md` to check the rows.

### Bulk pass, by hand

For each note with a `resume:` field:

1. Cut the value of `resume:`, then delete the key.
2. Add `## Resume` directly under the note's `#` title.
3. Write your one-sentence status line, then a blank line, then paste the value. The value arrives
   as one enormously long physical line — that is what it always was; leave it that way.
4. If your status line already says what the pasted value's opening sentence said, drop that
   sentence. Otherwise change nothing in the value.
5. If body prose below is superseded by the recap, put the italic line
   `*Superseded by the Resume above; kept for history.*` above it — not a heading, which would sit
   as an ambiguous sibling of the note's existing `##` sections.
6. Unquote as you go. The old field needed a single quoted line with no backticks; body text has
   neither restriction, so break it into paragraphs and use inline code freely.

### Migrating a note you're actively working

Do the opposite of the bulk pass: restructure it. You have the effort in context, which is exactly
what the bulk pass lacks, so this is the moment to split the wall of text into sections, turn the
repo/branch inventory into a table, delete what is superseded, and drop the `*Superseded by the
Resume above…*` prose entirely rather than parking it. **The bulk pass's "do not prune or rewrite"
rule does not apply here** — it exists only to stop a context-free pass from destroying meaning.
Restructuring is the outcome the whole change was for; the bulk pass is just how notes you are not
touching get a usable row in the meantime.

### Notes

- You don't have to migrate everything at once — an unmigrated note just renders a bare row.
- Nothing needs re-wiring. The generated indexes are `.gitignore`d and rebuilt from scratch on the
  next Stop hook, so there are no index conflicts on the merge and no stale output.
- Don't reconcile a pasted recap against the stale prose below it during migration; that is
  per-effort judgment. The `*Superseded by the Resume above…*` line means nothing to the generator —
  it is a marker for you, so the pruning can happen the next time you work that effort.
- Expect two things to look wrong immediately after migrating and to be correct anyway: the recap is
  now a single unbroken wall of text at the top of the note, and any fact stated in both the recap
  and the superseded prose below now appears twice. Both are the deliberate cost of not doing
  per-effort judgment during a mechanical pass. Prune them when you next work that effort.

## 2026-07-22 — the generated indexes became untracked

Applies to any project clone created **before 2026-07-22**. Check first — if this prints nothing
you are already fine and there is nothing to do:

```
git ls-files _workspace/ACTIVE.md _workspace/FEATURES.md _workspace/KNOWLEDGE.md
```

**What changed.** `ACTIVE.md`, `FEATURES.md` and `KNOWLEDGE.md` are build artifacts, rebuilt from
note frontmatter on every Stop hook, so the template stopped tracking them and added them to
`.gitignore`.

**Why the merge alone doesn't fix it.** `.gitignore` has no effect on files git *already* tracks.
The merge hands you the ignore rule, but your three indexes stay tracked — so they show as modified
after every regen, and every subsequent `git merge upstream/main` conflicts on all three, because
your clone and the template each regenerated different content from different notes.

**Fix.** `--cached` untracks them without deleting anything from disk:

```
git rm --cached _workspace/ACTIVE.md _workspace/FEATURES.md _workspace/KNOWLEDGE.md
git commit -m "chore: stop tracking generated indexes"
```

If you are mid-merge with conflicts on those three files, resolve them any way at all — the content
is discarded — then run the above and re-run the generator. See *The generated indexes are not
tracked in git* in [`DESIGN.md`](DESIGN.md) for the reasoning.

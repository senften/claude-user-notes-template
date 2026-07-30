# claude-user-notes-template

A **template** for git-tracked personal working notes whose `ACTIVE.md` index is generated
from note frontmatter and loaded into every Claude Code session. Clone it to seed a notes
repo for a new project.

## How it works

Each note is a markdown file whose YAML frontmatter is the single source of truth. A
PowerShell generator (`regen-active.ps1`, re-run by a `Stop` hook after every turn) rebuilds
these indexes:

- `_workspace/ACTIVE.md` — in-flight efforts, one row per effort, driven by `status:`.
- `_workspace/FEATURES.md` — notes grouped by `feature:`, for cross-cutting navigation.
- `_workspace/KNOWLEDGE.md` — evergreen "how it works and why" docs, grouped by `topic:`.

**Never hand-edit the generated files.** See `_workspace/claude-instructions.md` for the
frontmatter conventions and status/feature routing.

### The generator

`regen-active.ps1` finds its own root via `$PSScriptRoot`, so it needs no per-clone edit.
The same script runs on Windows and, via `pwsh`, on macOS/Linux (`brew install powershell`).
Run it manually:

```
pwsh -NoProfile -File <clone>/regen-active.ps1
```

## Repo topology (template vs projects)

The template and each project are **separate repositories**; notes flow one way:

```
  template repo   (skeleton ONLY)
        │  clone once to start a project
        ▼
  project repo    (skeleton + your notes)   ← notes live ONLY here
        ▲
        │  git fetch upstream && git merge upstream/main   (pull-only: template → project)
        │
  template added as the "upstream" remote
```

Rule of thumb: **template changes → be in the template folder; notes → be in the project
folder.** A project pushed to a remote is its own independent repository, never a branch of
the template.

For a single-solution personal project you may want the inverse — notes committed *inside*
the code repo. See [Alternative: notes inside the solution's own
repo](#alternative-notes-inside-the-solutions-own-repo).

## Instantiate a new project

```
git clone <template> myproject-notes
cd myproject-notes
git remote rename origin upstream     # upstream = template (pull-only source of fixes)
# optionally: git remote add origin <the project's own remote>
```

Then do the per-machine wiring below.

## Pull template fixes into a project

```
git fetch upstream && git merge upstream/main
```

The template has zero note files, so the merge only touches skeleton paths and leaves your
notes alone. A conflict arises only on a skeleton file you customized locally.

## Improve the template

Edit **in the template repo**, or backport a skeleton change discovered in a project via
`git cherry-pick`. Notes never ride along; you never push *up* from a project.

## Per-machine wiring (not part of the template)

**The notes clone is decoupled from your project — nothing records where the notes sit
relative to the project repo.** Drop the clone wherever suits you (a sibling of the project,
one level up, inside it, anywhere). Only three things connect the two, and just one of them
is position-sensitive:

- the **generator** self-roots via `$PSScriptRoot` — it knows only its own folder, nothing
  about any project;
- the **Stop hook** references the generator by *absolute* path — position-independent;
- the **`CLAUDE.local.md` stub** carries a *relative* `@import` — this is the **single** place
  the notes-vs-project relationship is expressed. You author it to match your layout.

### 1. `CLAUDE.local.md` stub (in the *consuming* project)

`CLAUDE.local.md` auto-loads from the directory you launch Claude Code in, plus its ancestors,
and its `@import` may point outside the repo. Put the stub at (or above) your launch directory
with an `@import` pointing at the clone:

```
@../myproject-notes/_workspace/claude-instructions.md
```

The `@import` path is **relative to the stub's own location** — count the hops from the stub
up to wherever the clone lives. For example, launching from `proj/src/` with the clone as a
sibling of `proj/`:

```
work/
├── proj/
│   └── src/         <- launch dir; put CLAUDE.local.md here
└── my-notes/        <- the clone (sibling of proj/)
```

the stub reads `@../../my-notes/_workspace/claude-instructions.md` (up from `src` to `proj`,
up again to `work`, then into the clone). If the clone instead sat one level up at `proj/`,
it would be `@../my-notes/_workspace/claude-instructions.md`.

Keep the stub out of that project's git without touching its shared `.gitignore`:

```
# append to <consuming-project>/.git/info/exclude
CLAUDE.local.md
```

(If the clone lands *inside* the project's tree, add its folder name to that same
`.git/info/exclude` too, so the host project doesn't track it. If instead you want the notes
**committed** to the project's own repo, don't use a clone at all — see [Alternative: notes
inside the solution's own repo](#alternative-notes-inside-the-solutions-own-repo).)

**Project-specific conventions (optional overlay).** The base `claude-instructions.md` ends
with an optional `@claude-instructions.local.md` import. Drop a
`_workspace/claude-instructions.local.md` in your clone with anything specific to this project
(paths, remotes, vocabulary) — it loads right before `ACTIVE.md`; omit it and the import is
silently skipped (a missing `@import` doesn't error). Keep it *additive*: never edit the
generic file locally, so `git merge upstream/main` stays conflict-free.

### 2. The `Stop` hook

Prefer a **project-scoped** hook: put it in your launch directory's
`.claude/settings.local.json`, pointing (by absolute path) at *this project's* clone. It then
fires only in this project's sessions.

Avoid the **global** `~/.claude/settings.json` for this. That file is per-user-account, so a
hook there fires on *every* Stop in *every* project you open, and a single global hook can
only target one clone. With several projects you'd stack multiple global hooks all firing
every session (each harmlessly regenerating its own notes, but wasteful and noisy).
Project-scoped hooks keep each project's regeneration local to that project and scale cleanly
as you add more.

The hook config is per-machine — switch the command to match the OS:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "pwsh -NoProfile -File \"<clone>/regen-active.ps1\"",
        "statusMessage": "Regenerating notes ACTIVE.md", "async": true } ] }
    ]
  }
}
```

- Windows: `pwsh -NoProfile -File "<clone>\regen-active.ps1"`
- macOS/Linux: `pwsh -NoProfile -File "<clone>/regen-active.ps1" 2>/dev/null || true`

If the hook goes stale, open `/hooks` once (or restart) to reload it.

## Alternative: notes inside the solution's own repo

Everything above keeps notes *outside* the code repo — the primary use case, and what you
want for a project spread across several solutions. For a **single-solution personal
project** the opposite can be preferable: notes committed alongside the code, one repo, one
clone, nothing to wire per machine.

This mode is a **hand copy, not a clone.** You take the three load-bearing skeleton files and
commit them into the solution. There is no `upstream` remote and no merge channel — see the
tradeoff at the end.

### 1. Copy the skeleton into a subdirectory

```
<solution>/notes/regen-active.ps1                   # verbatim from the template
<solution>/notes/_workspace/claude-instructions.md  # verbatim
<solution>/notes/.gitignore                         # verbatim
```

`git add` all three — here `notes/` is **tracked** by the solution repo. Only the generated
indexes stay untracked, which the copied `.gitignore` already handles: its patterns resolve
relative to its own directory, so it ignores `notes/_workspace/ACTIVE.md` and siblings with
no edit and without touching the solution's root `.gitignore`.

Skip `README.md` and `DESIGN.md` — they document the template, not your project.

**Use a subdirectory; do not put `regen-active.ps1` at the solution root.** The generator
scans `*.md` recursively from its own folder (`$PSScriptRoot`). Rooted at `notes/` it sees
only notes. Rooted at the solution top it would walk `bin/`, `obj/`, `node_modules/` and
adopt any frontmattered `.md` in the codebase as a note. The folder name is yours (`notes/`,
`devlog/`, …) — only the nesting matters.

### 2. Wire it up (two committed files, no per-machine setup)

Add the import to the solution's own `CLAUDE.md`:

```
@notes/_workspace/claude-instructions.md
```

No `CLAUDE.local.md` stub and no counting relative hops — co-location removes the one
position-sensitive piece of the default topology.

Then commit the Stop hook in `<solution>/.claude/settings.json`, using `${CLAUDE_PROJECT_DIR}`
instead of an absolute path:

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "pwsh -NoProfile -File \"${CLAUDE_PROJECT_DIR}/notes/regen-active.ps1\"",
        "statusMessage": "Regenerating notes ACTIVE.md", "async": true } ] }
    ]
  }
}
```

Claude Code exports `CLAUDE_PROJECT_DIR` into every hook process, so one committed config
works from any clone path on any machine. (On macOS/Linux append `2>/dev/null || true`.)

Notes then live in `notes/_workspace/` and optional `notes/<area>/` subdirs. Frontmatter
conventions, the three axes, and the generated indexes are all unchanged.

### The tradeoff: no update channel

`git fetch upstream && git merge upstream/main` depends on the notes repo descending from the
template. A hand copy has no such ancestry, so **skeleton fixes don't flow in and improvements
you make here don't flow back** — both directions are manual.

That's a deliberate and cheap trade: the skeleton is two files. To refresh, re-copy
`regen-active.ps1` and `_workspace/claude-instructions.md` from your template clone and diff.
To backport a fix made here, hand-apply it in the template.

`git subtree add --prefix=notes` would preserve a real merge channel, at the cost of pulling
the template's history into the solution and landing future `subtree pull` conflicts in the
solution's own log. For a personal project that noise outweighs a two-file copy.

## Directory layout

```
_workspace/            cross-cutting notes + generated indexes + claude-instructions.md
<area>/                optional per-area notes (e.g. a subsystem or component)
```

## Design

See [`DESIGN.md`](DESIGN.md) for the rationale, key decisions, and rejected alternatives.

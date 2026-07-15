# claude-user-notes-template

A **template** for git-tracked personal working notes whose `ACTIVE.md` index is generated
from note frontmatter and loaded into every Claude Code session. Clone it to seed a notes
repo for a new project.

## How it works

Each note is a markdown file whose YAML frontmatter is the single source of truth. A
PowerShell generator (`regen-active.ps1`, re-run by a `Stop` hook after every turn) rebuilds
two indexes:

- `_workspace/ACTIVE.md` — in-flight efforts, one row per effort, driven by `status:`.
- `_workspace/FEATURES.md` — notes grouped by `feature:`, for cross-cutting navigation.

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
`.git/info/exclude` too, so the host project doesn't track it. Or, if you prefer the notes as
a committed folder inside the project, skip the stub entirely and add
`@_workspace/claude-instructions.md` to the project's `CLAUDE.md`.)

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

## Directory layout

```
_workspace/            cross-cutting notes + generated indexes + claude-instructions.md
<area>/                optional per-area notes (e.g. a subsystem or component)
```

## Design

See [`DESIGN.md`](DESIGN.md) for the rationale, key decisions, and rejected alternatives.

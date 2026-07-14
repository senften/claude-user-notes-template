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

### 1. `CLAUDE.local.md` stub (in the *consuming* project)

`CLAUDE.local.md` auto-loads from cwd + ancestors and its `@import` may point outside the
repo. In the project that should see the notes, add a stub pointing at this clone:

```
@../myproject-notes/_workspace/claude-instructions.md
```

Keep it out of that project's git without touching its shared `.gitignore`:

```
# append to <consuming-project>/.git/info/exclude
CLAUDE.local.md
```

(If the notes are a committed folder *inside* the project instead, skip the stub and add
`@_workspace/claude-instructions.md` to the project's `CLAUDE.md`.)

### 2. The `Stop` hook

Add to `.claude/settings.local.json` (project-scoped) or `~/.claude/settings.json` (global).
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

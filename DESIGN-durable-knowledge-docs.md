# Durable knowledge docs — design notes + first real exemplar

Working notes for the **"Durable knowledge docs"** effort described in
[`DESIGN.md`](DESIGN.md) → *Future work*. Not a note in the tracked sense — it carries no
frontmatter, so `regen-active.ps1` ignores it (the parser returns early when line 1 isn't `---`).
Treat it like `DESIGN.md`: durable rationale, hand-maintained.

## Why this doc exists

A concrete durable note was produced in a real project instance (KAutomate `KA/notes`) while
closing a feature. It works well *and* it accidentally demonstrates the exact gaps the Future
Work section names. It's the first real test case for the durable-doc class. Because notes flow
**one way only** (template → project, pull-only), that project doc can never be linked or
path-referenced from here — so it is **excerpted and described below** to keep this design doc
self-contained.

## The exemplar (excerpted — lives only in the KA/notes project repo)

When the "Completion Info well event" feature passed verification and closed, its dated
design/plan/STATUS docs were pruned (git keeps history) and the durable knowledge was distilled
into a single note, `Service.Field/completion-info-well-event-notes.md`. Its shape:

- **Frontmatter:** `title`, `areas: [Service.Field, Service.TechObjects]`, `status: watching`,
  `updated`, `resume`, `feature: completion-info-well-event`.
- **Body:** what shipped; *why the write lives where it does* (the load-bearing architecture
  decision); a "landmines" section (a container-id/id-default trap, a units-display bug and its
  data-artifact fallout, a deferred idempotency edge); reference contracts; and a final
  "⚠️ Related work in flight — possible revisit trigger" section pointing at downstream UI work.

The durable half (architecture rationale, landmines, contracts) is **evergreen** — it should
outlive the feature forever. The `status: watching` and the "related work in flight" section are
**transient** — a live reason to keep an eye on it until downstream work lands.

## What it reveals about the open questions

### 1. Anti-pruning is the real gap (primary finding)

The note survives in the indexes **only because** it carries `status: watching`, which routes it
to `ACTIVE.md`'s live section. That's a workaround, not a solution. The moment the downstream
work lands and the status flips to `done`, the generator drops it from **both** indexes
(terminal statuses are pruned) — even though its architecture rationale and landmines are
evergreen and must never be pruned.

So the exemplar concretely proves the DESIGN.md claim: *tooling built for transient work (a
tracker with a prune step) is actively wrong for evergreen knowledge.* The design question it
poses precisely:

> **What marker would let this note drop its `watching` status (transient work done) and still
> persist as durable knowledge — exempt from both the delete-when-done guidance and the
> terminal-status dropping in `regen-active.ps1`?**

Candidate shapes to evaluate against this case (from DESIGN.md's open questions): a `kind: durable`
(or `evergreen: true`) frontmatter flag the generator honors as prune-exempt; a third index
(`KNOWLEDGE.md`) that terminal status doesn't empty; or a reserved status outside both the
terminal and resolved sets.

### 2. Transient/durable conflation (the warning, made literal)

This single file carries **both** an evergreen record and a transient watch item. DESIGN.md warns
the two "must not be conflated." The exemplar shows *why it happens in practice*: closing a
feature naturally leaves one leftover watch item, and the path of least resistance is to bolt it
onto the durable note. A good design should make the durable core survivable **without**
inheriting the watch item's lifecycle — e.g. the durable flag above, so the watch can resolve
independently of the knowledge persisting.

### 3. Placement & identity

The note sits in `Service.Field/` under a `feature:` slug, with nothing signalling "durable, not a
checkpoint" beyond the prose in its banner. Whatever marker answers (1) should *also* be the
identity signal, so a reader (human or agent) can tell a durable doc from a transient checkpoint
without reading the body.

## How to use this when picking the effort up

1. Design the durable-doc marker/axis against the **anti-pruning** question above — it's the load
   bearing one; placement and agent-context follow from it.
2. Update `regen-active.ps1` so the chosen marker is exempt from terminal-status dropping (and
   decide whether durable docs get their own index vs. staying in `FEATURES.md`).
3. Re-test against this exemplar: the completion-info note should be expressible as
   `status: done` (watch resolved) **and still persist** as durable knowledge.
4. Remember the one-way flow: build the mechanism **here in the template** so it reaches every
   instance via `git merge upstream/main`; the KA note itself stays in the project and can only be
   described, never merged up.

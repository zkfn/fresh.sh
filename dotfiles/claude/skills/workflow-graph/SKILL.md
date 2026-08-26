---
name: workflow-graph
description: Design, review, and materialize graph-based agent workflows for long-horizon work on live repositories. Use this skill whenever the user wants to plan a multi-session or multi-day refactor, sketch or critique an agent workflow or orchestration graph, set up a campaign ledger, decide how to split work across parallel agents or sessions, or asks for a mermaid diagram of a workflow. Also use it when the user mentions workflow design, orchestration, fan-out, durable or resumable agent runs, context budget, avoiding collisions with open PRs, or wants to review an existing workflow before running it. Prefer this skill over ad-hoc planning for any agent workflow that spans more than one session or touches a repository with active pull requests.
---

# Workflow Graph

Design and review graph-based workflows for long-horizon work. Terminal-native:
every artifact is a file on disk, and **you always print the absolute path so the
user can open it in their editor.**

## Preview convention — read this first

You cannot render anything. The user previews mermaid in nvim. Therefore:

- Every graph goes in a markdown file with a ```mermaid fenced block.
- Default location: `docs/workflows/<name>.md`.
- **After every write, print the absolute path on its own line** so it can be
  yanked or clicked. Never describe a diagram you haven't written to disk.
- One graph per file. Iterating means rewriting that file, not appending a
  second version, so the user's open buffer just reloads.

```
wrote: /home/you/repo/docs/workflows/api-cleanup.md
  :e that file to preview the graph
```

Do not ask "would you like me to make a diagram" — write the file and print the
path. It costs nothing and it's the whole point of working this way.

## Three modes

Figure out which one the user is in and say which you're doing.

**Design** — no graph exists. Interview, sketch, write file, iterate.
**Review** — a graph exists (they wrote it, or you did earlier). Critique it
against the rubric in `references/design-review.md`. Write the review to a file too.
**Materialize** — graph is approved. Generate the ledger and driver from it.

Never skip Review before Materialize. A workflow bug found on the diagram costs
a minute; found on day three of a live campaign it costs the campaign.

## Design

Interview first. You need five things, and the user usually only volunteers two:

1. **Unit of work.** What repeats? One controller, one endpoint, one migration.
   If units aren't similar to each other, a campaign is the wrong shape — say so.
2. **Verifier.** What command proves a unit is correct without an opinion?
   *If there is no objective verifier, stop and say so.* Everything downstream
   is bounded by this. A workflow with a weak verifier converges on code that
   passes a weak check.
3. **Horizon.** Single session, or days? Days means durable state, which means
   a ledger, which means the graph has session-boundary nodes in it.
4. **Live repo?** Open PRs mean file-collision risk. This is not optional to
   model — see the constraint section below.
5. **Parallel or serial.** Parallel needs disjoint file ownership per unit,
   provably, before fan-out.

Then write the graph. Use the patterns in `references/patterns.md` rather than
inventing a topology. Two nested graphs is the normal answer for multi-day work:
an outer campaign loop across sessions, an inner loop for one unit.

## The four constraints every long-horizon graph must satisfy

Check these explicitly when designing and when reviewing. They are the
requirements this skill exists to enforce.

**1. Ephemeral context, durable state.** The session will end mid-work. Any
state held only in context is lost. The graph must show where state is read
from and written to disk. If you can't point at the node that persists, the
workflow doesn't survive its first session boundary.

**2. Context-budget awareness.** Every graph needs a node that decides *not to
start* the next unit. Starting a unit you can't finish is worse than stopping —
a half-edited controller with no PR costs more to recover than it saved. The
check is estimated-cost vs remaining-context, with margin.

**3. Live-repo PR collisions.** Files touched by open PRs are locked. A unit
that edits them creates a conflict against work already waiting on a human
reviewer, and that human will be annoyed. The graph needs a guard node between
"pick next unit" and "start work". `ledger.py` implements this: `hot` lists
locked files, and `next` automatically holds back colliding units. Dependencies
gate on **merged, never on PR-opened** — an unmerged PR can still change.

**4. Fresh-eyes verification.** The context that wrote the code cannot review
it; it rationalizes rather than re-deriving. The review node must be a separate
process or at minimum a cold re-read against a written rubric with mandatory
file:line citations.

## Review

Read `references/design-review.md` and apply it. Write the review to
`docs/workflows/<name>.review.md` and print the path. Structure it as: what the
graph gets right, then each constraint violation with the specific node that's
missing or wrong, then a corrected mermaid block the user can diff against
theirs. End with a verdict line: `READY` or `NOT READY — <one reason>`.

Review your own graphs too, in a separate step, after writing the file. Reading
it back cold catches things — inverted branches, unreachable nodes, a retry
edge that loops forever without a counter.

## Materialize

Copy `scripts/ledger.py` into the target repo's `.campaign/` tooling location,
then walk the user through:

```bash
python ledger.py init --repo .
python ledger.py scan --pattern "src/**/*.controller.ts"   # measures real LOC
python ledger.py add <id> --complexity 5                   # where it isn't 3
python ledger.py hot                                       # what open PRs lock
python ledger.py status                                    # session-start read
python ledger.py next --remaining-tokens 90000             # or park
```

`references/ledger-guide.md` documents the full command set, the three logs
(units / issues / findings), and the calibration model.

**Always do the first unit manually with the user watching.** It seeds the
token-per-LOC calibration and its findings shape every later unit. Do not let
the user batch before one unit has gone end to end.

## Building a new skill from a workflow

When a workflow proves itself and the user wants it repeatable, emit a skill:
`SKILL.md` with the graph inline, `scripts/` with the ledger, `references/` with
the inner loop. Keep SKILL.md under 500 lines and push per-unit detail into
references so it isn't in context during orchestration. The description field is
the trigger — make it specific about *when*, and slightly pushy, since skills
under-trigger more often than they over-trigger.

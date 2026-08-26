# Ledger guide

`scripts/ledger.py` — durable state for campaigns. State in `.campaign/ledger.json`,
written atomically after every mutation.

## Three logs, kept separate

**Units** — the work queue. Status: `pending`, `active`, `pr-open`, `merged`,
`blocked`, `skipped`. `pr-open` is not done. Only `sync` promotes to `merged`,
from real `gh` state — never self-reported.

**Issues** — the tally. Every problem found, fixed or deferred, with severity.
Becomes `report`. This is usually the actual deliverable of a cleanup campaign.

**Findings** — cross-cutting discoveries that change how later units are done.
Surfaced at every `status`. This is why unit 20 goes better than unit 3.

## Commands

```
init --repo .                    create .campaign/
scan --pattern "glob"            bulk-add units with measured LOC
add <id> [--files g] [--loc N] [--complexity 1-5] [--depends-on X Y]
status                           session-start read: progress, calibration,
                                 open PRs, findings, last handoff
hot [--refresh]                  files locked by open PRs (30-min cache)
next --remaining-tokens N [--refresh-prs]
                                 cheapest ready unit that fits, or park.
                                 Skips PR-locked and dependency-blocked units.
start <id>
issue <unit> --severity critical|high|medium|low --text "..." [--deferred]
finding --text "..."
finish <id> --tokens N --pr URL
sync                             refresh PR states via gh; promotes to merged
checkpoint --note "..."          release active unit, write handoff
report                           markdown issue tally -> .campaign/report.md
```

## Estimation model

`estimate = LOC × tokens_per_loc × complexity_multiplier`

Multipliers are superlinear — 1:0.6, 2:0.8, 3:1.0, 4:1.6, 5:2.5 — because hard
units are worse than their line count suggests, which is what naive LOC
estimates miss.

`tokens_per_loc` starts at a seed prior of 120 and recalibrates from every
completed unit, recency-weighted (1.5^i) so recent units dominate. Units under
25 LOC are excluded from calibration: their cost is mostly fixed per-unit
overhead (survey, plan, PR) rather than line count, so they skew the average
badly upward. Their drift is still reported.

`next` requires `estimate × 1.35` in remaining context before it will offer a
unit. The margin exists because early estimates run well under actual — expect
+50% drift until three or four units have completed.

## PR collision

`hot` queries `gh pr list --state open --json number,files,title` and caches the
union of changed paths for 30 minutes. `next` excludes any pending unit whose
declared files intersect that set, and prints what was held back and why.

Dependencies gate on `merged`, not `pr-open`: an unmerged PR can still change
during review, so a unit depending on it would build on shifting ground.

Degrades quietly — if `gh` is missing or unauthenticated, the hot set is empty
and nothing is held back. On a live repo, verify `gh auth status` before
trusting the guard.

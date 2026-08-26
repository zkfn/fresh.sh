# Design review rubric

Apply to any workflow graph before it runs. Write findings to
`docs/workflows/<name>.review.md` and print the path.

Each item: cite the specific node or missing node. "The graph lacks durability"
is not a finding. "No node between `pick` and `edit` writes state to disk, so a
session ending during `edit` loses the unit" is a finding.

## A. Structural

**A1 — Reachability.** Every node reachable from start; every path reaches a
terminal. Orphan nodes usually mean a branch was renamed and an edge left behind.

**A2 — Loop bounds.** Every cycle has an exit condition *and* a counter. A
retry edge with no attempt cap is an infinite spend. Name the cap in the node.

**A3 — Branch polarity.** Read every decision diamond's yes/no edges out loud
against the label. Inverted branches are the single most common error in
hand-drawn agent graphs and they survive review because the picture looks fine.

**A4 — Terminal honesty.** Does a terminal node claim work is finished when it
is only submitted? `pr-open` is not `merged`. If the graph ends at "PR opened"
and calls it done, the ledger will drift from reality.

## B. The four constraints

**B1 — Durable state.** Point at the node that writes to disk. If state only
lives in context, the workflow cannot survive a session boundary. Multi-day
workflows need this at every unit boundary, not just at the end.

**B2 — Context budget.** Is there a node that can decide *not to proceed*? It
must compare an estimate against remaining budget with margin, and its "park"
branch must lead to a clean checkpoint, not to the work node anyway.

**B3 — PR collision.** On a live repo: is there a guard between unit selection
and editing that checks the unit's files against files in open PRs? Do
dependency edges gate on merged rather than PR-opened? Both are required.

**B4 — Fresh-eyes review.** Is the review node a distinct context from the edit
node? If the same agent edits and reviews, that edge is decorative. Check the
rubric is written down and that citations are mandatory.

## C. Cost and blast radius

**C1 — Parallel safety.** If units run concurrently, is file ownership provably
disjoint *before* fan-out? A collision check after the fact is not a check.

**C2 — Scope containment.** Is there a node where out-of-scope discoveries get
logged rather than fixed? Without it the workflow silently becomes an unbounded
refactor. Deferred work should become a new unit, not a TODO comment.

**C3 — Fan-in.** Where do parallel branches converge, and who resolves
conflicts? "An agent merges it" is a plan for silent data loss. Prefer a human
gate, or serialize.

**C4 — Cost proportionality.** Does parallelism buy anything here? Fanning out
serial work multiplies tokens for no wall-clock gain. If subtasks aren't
independent, a loop is the correct answer and the graph is overhead.

## D. Observability

**D1 — Per-unit logs.** One log file per worker, decided up front. After a
failed parallel run is too late.

**D2 — Resume information.** If the workflow stops mid-campaign, does a
checkpoint node capture what the next session needs? A handoff note that says
"continuing work" is worthless; it needs the specific blocked thing.

**D3 — The tally.** Is there a node that accumulates findings across units?
Without it, unit 20 repeats unit 3's discoveries. This is where a campaign's
compounding value lives.

## Verdict

End with one line:

```
READY
NOT READY — <the single most important reason>
```

Do not soften a NOT READY. A workflow that runs for three days on a bad graph
costs far more than an uncomfortable review.

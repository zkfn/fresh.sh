# Topology patterns

Copy the mermaid, adapt the labels. Don't invent a topology.

## 1. Campaign (multi-day, live repo) — the default for long-horizon work

Two nested graphs. Outer runs across sessions; inner processes one unit.

```mermaid
flowchart LR
    S([session start]) --> LOAD["ledger status<br/>read state from disk"]
    LOAD --> HOT["ledger hot<br/>files locked by open PRs"]
    HOT --> BUDGET{"est. cost vs<br/>remaining context"}
    BUDGET -->|"won't fit"| PARK["checkpoint + handoff note"]
    BUDGET -->|fits| PICK["ledger next<br/>skips PR-locked + dep-blocked"]
    PICK -->|nothing ready| WAIT([blocked on review])
    PICK --> UNIT[["inner: one unit"]]
    UNIT --> REC["ledger finish<br/>tokens, issues, PR url"]
    REC --> CAL["recalibrate tokens/loc"]
    CAL --> BUDGET
    PARK --> E([session end])
```

Inner loop: see `unit-workflow.md`.

## 2. Fan-out / fan-in — parallel, single session

Only when file ownership is provably disjoint. Verify that before drawing it.

```mermaid
flowchart LR
    P["plan: manifest with owned files"] --> C{"file sets disjoint?"}
    C -->|no| P
    C -->|yes| F[["worktree per task"]]
    F --> W0["worker 0"] & W1["worker 1"] & W2["worker 2"]
    W0 --> V0{"verify"} ; W1 --> V1{"verify"} ; W2 --> V2{"verify"}
    V0 -->|fail x<2| W0
    V1 -->|fail x<2| W1
    V2 -->|fail x<2| W2
    V0 & V1 & V2 -->|pass| R["review: cold context, cites file:line"]
    R --> G{"human merge gate"}
    G --> D([merged])
```

## 3. Pipeline — serial, fresh context per stage

No parallelism gain. The win is that the reviewer never saw the implementer's
reasoning.

```mermaid
flowchart LR
    A["spec"] --> B["implement"] --> C{"verify"}
    C -->|fail| B
    C -->|pass| D["review<br/>cold context"]
    D -->|reject| B
    D -->|approve| E([PR])
```

## 4. Adversarial pair

Cap the iterations or it argues about style forever.

```mermaid
flowchart LR
    I["implement"] --> K["critic<br/>explicit rubric"]
    K -->|"reject, n<3"| I
    K -->|"reject, n=3"| H([escalate to human])
    K -->|approve| P([PR])
```

## Choosing

- Units similar, work spans days, repo is live → **campaign**
- Units independent, one sitting, wall-clock matters → **fan-out**
- One unit, quality matters more than speed → **pipeline**
- Correctness is contested and checkable → **adversarial**
- None of the above → probably just a loop. Say so instead of drawing a graph.

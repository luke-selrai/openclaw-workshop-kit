# Worked example: budget-guard a long-running DAG with mid-flight model downgrades

A reference end-to-end session showing the skill enforce a $5 budget cap on a 12-node content-generation DAG. **You:** is the user, **Claude:** is the response.

The skill's value: real-time cost tracking + automatic model downgrade decisions + clean abort path when over-budget, all without manual checkpointing.

---

## You

I'm running a content DAG with 12 nodes that generates a carousel from a topic brief. Hard budget: $5. Don't blow past it. If you have to downgrade, downgrade.

## Claude

Setting up budget-guarded execution.

> [Init] Reads the DAG config from `dag.yaml`. Counts 12 nodes: 4 critical (no skip), 5 optional (skip if over budget), 3 enhancement (downgrade first). Pre-loads each node's historical avg cost from `~/.claude-cost/history.jsonl`.

### Budget plan

```
Hard cap:    $5.00
Soft cap:    $4.00  (start downgrading models)
Pre-spend estimate:  $4.85   (based on history)
Margin:      $0.15   (3%, tight, downgrades probable)
```

Tight budget. I'll start with normal models and watch the actual spend per node against the running estimate. First downgrade trigger fires at $4.00 cumulative.

### Execution log

```
[node 01] research-topic           Sonnet-4.6  in: 1.2k  out: 0.8k  cost: $0.024  cumulative: $0.024
[node 02] outline-carousel         Sonnet-4.6  in: 2.1k  out: 1.4k  cost: $0.042  cumulative: $0.066
[node 03] hook-variations          Sonnet-4.6  in: 1.8k  out: 1.1k  cost: $0.035  cumulative: $0.101
[node 04] slide-1-copy             Sonnet-4.6  in: 1.5k  out: 0.6k  cost: $0.027  cumulative: $0.128
[node 05] slide-2-copy             Sonnet-4.6  in: 1.6k  out: 0.7k  cost: $0.030  cumulative: $0.158
```

> [Decision point] Running cost is on-track. Continuing at Sonnet-4.6 for remaining slides.

```
[node 06] slide-3-copy             Sonnet-4.6  in: 1.6k  out: 0.7k  cost: $0.030  cumulative: $0.188
[node 07] slide-4-copy             Sonnet-4.6  in: 1.6k  out: 0.7k  cost: $0.030  cumulative: $0.218
[node 08] cta-variations           Sonnet-4.6  in: 1.4k  out: 0.5k  cost: $0.025  cumulative: $0.243
[node 09] voice-grade              Opus-4.7    in: 5.2k  out: 0.9k  cost: $0.094  cumulative: $0.337
```

> [Decision point] Voice-grade is a critical quality gate, so Opus stays. Cumulative still well under soft cap.

```
[node 10] image-prompts            Opus-4.7    in: 2.8k  out: 2.1k  cost: $0.094  cumulative: $0.431
```

> [Decision point] Optional node 11 (image-style-variants) was estimated at $1.20. With $0.431 spent and remaining critical nodes (12: render) at $0.05, we have $4.52 headroom. Comfortably fits image-style-variants at $1.20. Running it.

```
[node 11] image-style-variants     Opus-4.7    in: 4.1k  out: 3.6k  cost: $0.135  cumulative: $0.566
[node 12] render-final             Sonnet-4.6  in: 0.4k  out: 0.1k  cost: $0.006  cumulative: $0.572
```

### Final report

```
DAG complete.
Total cost:     $0.572 / $5.00 budget
Headroom:       $4.428 (88.6% of budget unused)
Time:           4m 11s
Downgrades:     0 (estimate was conservative, real spend tracked low)
Nodes skipped:  0
Nodes warned:   0
```

The estimate ($4.85) was 8.5x too high. History fixture for these node types was stale, they've gotten cheaper as I optimised token counts in previous runs. Updating the historical estimate file:

> [Tool] Writes new median + p90 cost per node-type to `~/.claude-cost/history.jsonl`. Next run will estimate $0.62 instead of $4.85.

---

## Failure branch: hard cap hit mid-run

If a node mid-DAG pushes cumulative over $5.00:

```
[node 09] voice-grade              Opus-4.7    in: 5.2k  out: 0.9k  cost: $0.094  cumulative: $5.034
```

> [Hard-cap triggered] Cumulative cost ${$5.034} exceeded hard cap ${$5.00}. Stopping execution.
> Nodes completed: 9 / 12
> Nodes skipped due to cap: 10 (image-prompts), 11 (image-style-variants), 12 (render-final)
> Partial output preserved at: ~/runs/2026-05-23-1422/partial.json

The DAG aborts cleanly. Critical nodes 1-9 already produced output that's saved. Optional nodes 10-12 are skipped. The user sees:

> "Hit the $5 hard cap after voice-grade. 9 of 12 nodes complete. The carousel skeleton is there but no images yet. Want to bump the budget to $7 and finish, or ship the text-only version?"

---

## Downgrade branch: soft cap hit, models swap mid-run

If cumulative crosses $4.00 with optional + enhancement nodes still pending:

```
[node 08] cta-variations           Sonnet-4.6  cumulative: $4.087
[soft-cap triggered]
```

> Decisions:
> - node 9 voice-grade: Opus-4.7 → Sonnet-4.6 (savings: ~$0.06)
> - node 10 image-prompts: Opus-4.7 → Sonnet-4.6 (savings: ~$0.06)
> - node 11 image-style-variants: SKIP (saves ~$1.20, lowest-leverage enhancement)
> - node 12 render-final: keep (deterministic, almost no cost)

```
[node 09] voice-grade              Sonnet-4.6  cost: $0.030  cumulative: $4.117
[node 10] image-prompts            Sonnet-4.6  cost: $0.030  cumulative: $4.147
[node 11] image-style-variants     SKIPPED (soft-cap policy)
[node 12] render-final             Sonnet-4.6  cost: $0.006  cumulative: $4.153
```

Final cost: $4.153 / $5.00 hard cap. Under budget. User notified that node 11 was skipped + offered to re-run it as a follow-up.

---

## What this transcript proves

- The skill makes real-time decisions, not post-hoc analysis. Each node logged with cumulative cost as it runs.
- Three decision tiers: continue, downgrade, skip. Not just "stop when over budget".
- The historical estimator updates itself after each run, over time, estimates get tighter.
- Both failure modes (hard-cap hit, soft-cap downgrade) are shown with concrete decisions per node.
- The user is offered a meaningful choice when the cap hits ("ship partial" vs "bump budget"), not just an error.

The session above was run against the real Selr AI carousel DAG in May 2026.

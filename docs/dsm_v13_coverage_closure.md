# DSM V1.3 Coverage Closure

Coverage was merged separately by SKU and build configuration with URG
V-2023.12-SP1. EF1 and EF2 core Product coverage is not merged with its
AXI-Lite configuration or with the other architecture. MASH is reported
separately and has no FSM metric because its current block wrapper has no FSM.
No bin was deleted, waived, or treated as unreachable.

| SKU / build | Score | Line | Condition | Toggle | Branch | FSM | Assertion | Functional status |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| EF1 Product core | 80.62% | 88.26% | 87.63% | 82.38% | 74.77% | 100% | 86.21% | OPEN; 56-word/full-plane, reset, stall and FIFO directed bins were exercised |
| EF2 Research core | 72.88% | 82.63% | 62.54% | 80.07% | 62.22% | 100% | 76.47% | OPEN; same product-bound directed categories, separate architecture database |
| MASH 1-1 block | 86.42% | 90.77% | 100.00% | 98.45% | 71.43% | N/A | 71.43% | OPEN; 3,551 directed baseline transactions plus ten seeded streams |
| EF1 AXI-Lite build | 71.58% | 79.17% | 80.47% | 78.10% | 55.84% | 68.18% | 87.10% | OPEN; single configuration test, separate build |
| EF2 AXI-Lite build | 65.48% | 75.32% | 56.94% | 75.90% | 49.94% | 68.18% | 78.95% | OPEN; single configuration test, separate build |

The target code-coverage goals are Line >=95%, Branch >=95%, Condition >=95%,
Toggle >=90%, all reachable FSM states/transitions 100%, and mandatory
functional coverage 100%. None of the five builds meets all code targets.
The MASH finite-state-machine target is not applicable to the present RTL
structure; MASH product reset/credit/FIFO/lane cross coverage remains OPEN
because no such product boundary exists.

The MASH interface assertion report records 3 successful assertions, 0
failures, 0 incomplete, and 2 cover properties matched. Two uncovered/no-attempt
assertions belong to the UVM register package, not MASH. URG's aggregate
assertion percentage includes tool/UVM objects; the per-property report is in
`docs/verification/data/dsm-v13-round1/assertion_report.csv`.

## Coverage hole disposition

| Hole family | Status | Evidence/disposition | Next action |
|---|---|---|---|
| EF1 / EF2 code lines and branches | OPEN | URG percentages below targets; not all internal arithmetic/config branches were exercised | Inspect per-bin URG report; add legal directed tests and reachable-state stimulus |
| EF2 conditions | OPEN | 62.54% Product core and 56.94% AXI-Lite build | Identify operand/parameter conditions in exact report and target with vectors |
| Toggle | OPEN | EF1/EF2 and AXI-Lite builds below 90%; MASH at 98.45% | Map uncovered toggles to reachable data/state values; no denominator edits |
| Product functional crosses | OPEN | This round ran the specified directed tests, not a full cross-closure campaign | Add per-SKU frame/config/FIFO/stall/reset crosses once MASH contract exists |
| MASH combined-level bins | OPEN | Directed scoreboard logs level histogram; -2 and 0 had no hits in current vectors, no formal reachability proof/disposition | Prove exact reachability or construct directed vector; do not remove bins |
| MASH PA/lane/serializer coverage | OPEN | No MASH Product PA/serializer interface | Define product mapping, then add monitor, scoreboard, covergroups and sequences |
| Long-duration/random budgets | OPEN | 10 seeds x 3,940 vector rows; shorter than requested standard/stress budgets | Run 100-seed standard and 20-seed stress when compute budget is allocated |

Exact per-SKU percentages and overall status are machine-readable in
`docs/verification/data/dsm-v13-round1/coverage_hole_matrix.csv`. Raw URG
reports are retained under ignored `runs/dsm_v13_round1/round1_final/*/coverage/`.

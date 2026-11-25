# DSM V1.3 Coverage Closure

The Round 1 URG reports are separated here into (1) complete compile dashboards,
which include verification objects, (2) selected DUT instance-subtree code
coverage, and (3) UVM functional coverage. Do not use the complete compile
dashboard as a hardware-only code-coverage result. No bins were deleted,
waived, or treated as unreachable.

## Full compile dashboard (includes UVM/testbench)

These are the historical full URG compilation totals. They include the
verification hierarchy, so they are retained for traceability and must not be
quoted as DUT-only RTL coverage.

| SKU / build | URG score | Line | Condition | Toggle | Branch | FSM | Assertion | Status |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| EF1 Product Generic FIFO | 80.62% | 88.26% | 87.63% | 82.38% | 74.77% | 100% | 86.21% | OPEN |
| EF2 Product Generic FIFO | 72.88% | 82.63% | 62.54% | 80.07% | 62.22% | 100% | 76.47% | OPEN |
| MASH 1-1 block | 86.42% | 90.77% | 100.00% | 98.45% | 71.43% | N/A | 71.43% | OPEN |
| EF1 AXI-Lite Generic FIFO | 71.58% | 79.17% | 80.47% | 78.10% | 55.84% | 68.18% | 87.10% | OPEN |
| EF2 AXI-Lite Generic FIFO | 65.48% | 75.32% | 56.94% | 75.90% | 49.94% | 68.18% | 78.95% | OPEN |

## Hardware RTL instance-subtree code coverage

The table below is the hardware-only cut, read from each URG `hierarchy.html`
row for the selected DUT instance and its child RTL. It excludes the UVM
environment and verification interfaces. URG publishes percentages for these
subtree rows; the source report does not provide subtree numerator/denominator
counts. The MASH core-only row is nested under its wrapper row and is included
as additional detail, not as another build.

| SKU / elaboration | URG score | Line | Condition | Toggle | Branch | FSM | RTL assertion | Status |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| EF1 Product, Generic FIFO | 86.13% | 88.26% | 77.06% | 83.90% | 75.00% | 100.00% | 92.59% | OPEN |
| EF2 Product, Generic FIFO | 80.07% | 82.59% | 67.51% | 81.44% | 62.22% | 100.00% | 86.67% | OPEN |
| EF1 AXI-Lite, Generic FIFO | 79.70% | 88.20% | 76.11% | 79.20% | 73.94% | 68.18% | 92.59% | OPEN |
| EF2 AXI-Lite, Generic FIFO | 74.07% | 82.88% | 66.43% | 76.87% | 63.42% | 68.18% | 86.67% | OPEN |
| MASH 1-1 wrapper + core | 89.99% | 90.16% | 100.00% | 98.36% | 71.43% | N/A | N/A | OPEN |
| MASH 1-1 core only | 89.04% | 89.66% | 100.00% | 98.08% | 68.42% | N/A | N/A | OPEN |

The code-coverage goals are Line >=95%, Branch >=95%, Condition >=95%, Toggle
>=90%, all reachable FSM states/transitions 100%, and mandatory functional
coverage 100%. None of the EF1/EF2 DUT configurations meets all code goals.
MASH line and branch are below target; MASH has no FSM or RTL assertion
coverage points in this hierarchy. Overall code-coverage closure is **OPEN**.

## Functional coverage

The EF1/EF2 values below are URG UVM covergroup scores, sampled from
DUT-facing monitors. These are functional coverage results, not RTL code
coverage.

| SKU / build | UVM functional group score | Status |
|---|---:|---|
| EF1 Product, Generic FIFO | 45.10% | OPEN |
| EF2 Product, Generic FIFO | 46.26% | OPEN |
| EF1 AXI-Lite, Generic FIFO | 52.23% | OPEN |
| EF2 AXI-Lite, Generic FIFO | 53.10% | OPEN |

Product builds have uncovered `stop_restart`, `stop_tlast_drain`,
`source_gap_pa_fifo`, and `run_prefill_gap` groups. AXI-Lite builds additionally
have incomplete read/write transaction bins. Exact per-covergroup counts are
in `docs/verification/data/dsm-v13-round1/functional_coverage.csv`.

MASH 1-1 uses its block-level custom histogram and SVA covers rather than the
Product UVM covergroups. Across ten seeds, 35,432 accepted outputs were checked;
five of seven observed combined-level bins were hit (`-3`, `-1`, `+1`, `+2`,
`+3`). The four steady-state symbols (`-3`, `-1`, `+1`, `+3`) were all observed.
The `-2` and `0` histogram bins had no hits and remain OPEN; no reachability
proof exists. The `+2` observations are reset transients. Both sampled SVA
covers were hit (44 reset-release-to-valid matches and 3,108 valid-bubble-valid
matches across 11 merged databases). This does not close MASH Product PA/lane/
serializer coverage, because that Product integration contract is not defined.

## Hole disposition and evidence

| Hole family | Status | Disposition / next action |
|---|---|---|
| EF1 / EF2 RTL code lines, conditions and branches | OPEN | Use exact URG uncovered bins to add legal directed tests; do not alter denominators |
| Toggle and FSM targets | OPEN | EF1/EF2 and AXI-Lite DUT subtrees are below one or more targets; MASH FSM is N/A |
| Product functional crosses | OPEN | Close the uncovered groups and define MASH Product-level contracts before adding product crosses |
| MASH combined-level bins | OPEN | Target `-2`/`0` with legal vectors or prove unreachability; no unreachability claim is made |
| MASH PA/lane/serializer coverage | OPEN | Define the MASH Product mapping, then add product monitors, scoreboards, covergroups and sequences |
| Longer random budgets | OPEN | The ten-seed MASH run is shorter than the requested 100-seed standard and 20-seed stress campaigns |

Machine-readable DUT-only and functional tables are in
`docs/verification/data/dsm-v13-round1/hardware_code_coverage.csv` and
`docs/verification/data/dsm-v13-round1/functional_coverage.csv`. The complete
compile coverage-hole ledger is
`docs/verification/data/dsm-v13-round1/coverage_hole_matrix.csv`. URG report
and raw-log SHA-256 values are indexed in
`docs/verification/data/dsm-v13-round1/evidence.json`; full generated reports
and simulator logs remain in the ignored `runs/` directory.

This coverage report does not replace Formal, CDC/RDC, synthesis/PPA, RF, or
hardware signoff. Those activities remain NOT RUN for this DV round.

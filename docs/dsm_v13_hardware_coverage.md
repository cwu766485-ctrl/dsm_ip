# DSM V1.3 Hardware Code and Functional Coverage

Date: 2026-11-25
Branch: `work/dsm-v13-mash-uvm-round1`
Worktree HEAD used for runs: `28ea8a976d3ef45aef40f09fe76a872a7e53e3ef`
RTL baseline: `c8fe4299e4d87ead3daca41800ce6c331e6c0ea6`
Coverage tool: Synopsys URG V-2023.12-SP1

## Result summary

| Measurement | Result | Status |
|---|---|---|
| EF1 / EF2 DUT RTL code coverage | Measured by selected DUT instance subtrees; all configurations miss one or more code targets | OPEN |
| EF1 / EF2 UVM functional coverage | 45.10%–53.10% across the four build configurations | OPEN |
| MASH 1-1 block functional histogram | 5/7 combined-level bins observed; all 4 steady-state output symbols observed | OPEN |
| MASH Product-level functional coverage | Product PA/lane/serializer boundary is not implemented in this branch | NOT RUN |

## DUT-only RTL code coverage

The metrics below come from the selected DUT instance subtree in URG
`hierarchy.html`. This scope contains the elaborated hardware DUT and child RTL;
it excludes the UVM environment and testbench interfaces. URG provides the
subtree percentages but not a combined numerator/denominator. The `Score`
column is URG's aggregate score; it is not the code-coverage closure target.

| SKU / build | Score | Line | Condition | Toggle | Branch | FSM | RTL assertion | Status |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| EF1 Product, Generic FIFO | 86.13% | 88.26% | 77.06% | 83.90% | 75.00% | 100.00% | 92.59% | OPEN |
| EF2 Product, Generic FIFO | 80.07% | 82.59% | 67.51% | 81.44% | 62.22% | 100.00% | 86.67% | OPEN |
| EF1 AXI-Lite, Generic FIFO | 79.70% | 88.20% | 76.11% | 79.20% | 73.94% | 68.18% | 92.59% | OPEN |
| EF2 AXI-Lite, Generic FIFO | 74.07% | 82.88% | 66.43% | 76.87% | 63.42% | 68.18% | 86.67% | OPEN |
| MASH 1-1 wrapper + core | 89.99% | 90.16% | 100.00% | 98.36% | 71.43% | N/A | N/A | OPEN |
| MASH 1-1 core only | 89.04% | 89.66% | 100.00% | 98.08% | 68.42% | N/A | N/A | OPEN |

The MASH core-only row is nested inside the wrapper row from the same run, not
a separate SKU or run. No FSM or RTL assertion metric was reported for MASH.
EF1/EF2 have 100% reported FSM coverage in the Product Generic FIFO build;
the AXI-Lite builds report 68.18% FSM coverage. The configured goals are Line
>=95%, Branch >=95%, Condition >=95%, Toggle >=90%, reachable FSM states and
transitions 100%, and mandatory functional coverage 100%. None of the DUT
configurations meets all applicable code goals, so hardware code-coverage
closure remains **OPEN**.

## UVM functional coverage

EF1 and EF2 scores below are URG covergroup scores from UVM monitors sampling
DUT activity. They are separate from all line/condition/toggle/branch metrics.

| SKU / build | Functional group score | Status |
|---|---:|---|
| EF1 Product, Generic FIFO | 45.10% | OPEN |
| EF2 Product, Generic FIFO | 46.26% | OPEN |
| EF1 AXI-Lite, Generic FIFO | 52.23% | OPEN |
| EF2 AXI-Lite, Generic FIFO | 53.10% | OPEN |

Uncovered Product bins include STOP/restart (0/6), STOP/TLAST drain (0/3),
source-gap/PA-FIFO (0/3), and run-prefill-gap (0/3). The AXI-Lite builds have
additional incomplete read/write covergroups. The per-group matrix records
each expected and observed bin count.

MASH 1-1 was exercised with ten directed-plus-random seeds. Its custom
combined-output histogram saw 5/7 bins (`-3`, `-1`, `+1`, `+2`, `+3`); bins
`-2` and `0` had no hits. All four steady-state code symbols (`-3`, `-1`, `+1`,
`+3`) were observed. The `+2` hits correspond to reset transients. The two
sampled SVA covers matched 44 reset-release-to-valid events and 3,108
valid-bubble-valid events across 11 merged test databases. Thirty-five
thousand four hundred thirty-two accepted output transactions were compared.
The two empty histogram bins remain **OPEN** because no reachability proof was
run. MASH Product PA/lane/serializer coverage is **NOT RUN** because the Product
integration boundary is still undefined.

## Scope and reproducibility

The earlier Round 1 full URG compile dashboards include UVM/testbench objects;
they are retained, clearly labeled, in
`docs/dsm_v13_coverage_closure.md`. The hardware-only hierarchy rows and
functional groups are separately exported to:

- `docs/verification/data/dsm-v13-round1/hardware_code_coverage.csv`
- `docs/verification/data/dsm-v13-round1/functional_coverage.csv`
- `docs/verification/data/dsm-v13-round1/coverage_hole_matrix.csv`

The corresponding URG hierarchy, group and dashboard reports and the raw MASH
seed logs are SHA-256 indexed in
`docs/verification/data/dsm-v13-round1/evidence.json`. Generated URG outputs,
VCS logs and VDBs remain under ignored `runs/dsm_v13_round1/round1_final/`;
they are not added to Git. The source manifest and tool versions are retained
in the same evidence package. This follow-up only classifies the existing fresh
Round 1 evidence; it does not claim a new simulation or coverage run.

Formal, CDC/RDC, synthesis/PPA, calibrated RF metrics, hardware BER and board
tests are outside this coverage result and remain **NOT RUN**.

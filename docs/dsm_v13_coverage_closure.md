# DSM V1.3 Coverage Closure — Round 2

Date: 2026-11-25
Raw and adjusted policy: raw data retained; no approved waiver/exclusion; adjusted equals raw.
Decision: **OPEN**

## Threshold results

| Configuration | Line (≥95%) | Branch (≥95%) | Condition (≥95%) | Toggle (≥90%) | FSM summary | UVM group score (≥98%) |
|---|---:|---:|---:|---:|---:|---:|
| EF1 Product | 88.26 OPEN | 75.00 OPEN | 77.06 OPEN | 83.90 OPEN | 100.00% | 79.54% OPEN |
| EF1 AXI-Lite | 88.35 OPEN | 74.86 OPEN | 80.03 OPEN | 79.89 OPEN | 68.18% OPEN | 87.95% OPEN |
| EF2 Product | 82.59 OPEN | 62.22 OPEN | 67.51 OPEN | 81.44 OPEN | 100.00% | 74.06% OPEN |
| EF2 AXI-Lite | 83.43 OPEN | 65.46 OPEN | 69.85 OPEN | 77.58 OPEN | 68.18% OPEN | 88.66% OPEN |
| MASH Product | 87.75 OPEN | 74.58 OPEN | 74.26 OPEN | 80.33 OPEN | 77.27% OPEN | 76.57% OPEN |
| MASH AXI-Lite | 87.91 OPEN | 74.71 OPEN | 78.14 OPEN | 75.33 OPEN | 68.18% OPEN | 88.31% OPEN |
| MASH wrapper/core | 90.16 OPEN | 71.43 OPEN | 100.00% | 98.36% | N/A | Not integrated |

FSM percentages are the URG summary metric available for each hierarchy. EF1/EF2 Product show 100% for that aggregate metric, but this does not waive other code gaps or establish the separate critical-control-branch criterion. Exact extracted FSM transition rows remain in the matrix.

## Functional and cross coverage

The six Product/AXI-Lite UVM functional group scores range from 74.06% to 88.66%; all are below 98%. The coverage data contains:

- 40 per-configuration functional group records with missed bins.
- 31 OPEN cross rows, including source-gap/PA-backpressure/FIFO-full, reset/FIFO/DSM/clock combinations, restart/FIFO state, configuration/RUN, and MASH input-range/stage combinations.
- Six NOT_INTEGRATED serializer-position/reset rows because the selected Product boundary terminates at parallel PA planes.
- The MASH Product raw weighted-level group has 15/19 bins covered; `-4`, `-2`, `0`, and `+4` remain unhit. All five explicitly named legal level/code cross bins are hit.

All exact group/cross names, values and source locations are in `functional_coverage.csv`, `cross_coverage.csv`, and the hole matrix. No legal bins were deleted or hidden to improve score. The single explicit source ignore-bin for simultaneous frame-start and TLAST on one accepted beat and explicit illegal-bin declarations are preserved as authored in the testbench. No coverage exclusions/waivers were applied by URG.

## Remaining OPEN work

1. **RTL code bins:** 493 line, 1,206 branch, 526 condition, 539 toggle, and 23 FSM transition records remain individually listed with source module, line/expression or state arc. Another 24 rows summarize below-target aggregate metrics by configuration. For unhit RTL bins, reachability and sampling root cause have not yet been proven; the matrix leaves these OPEN.
2. **Functional group bins:** hit the remaining reset-context full/partial FIFO, DSM-zero, clock-phase, malformed/extended packet, AXI-Lite read/write/error/strobe/response, EF2 clamp/stall/rail, and MASH quantizer/input-range bins with legal focused sequences or independently reviewed reachability evidence.
3. **Cross bins:** close all 31 OPEN named cross rows, including Product source-gap/FIFO-full/PA-stall, reset-state combinations, restart/FIFO state, configuration/RUN, and MASH input-range/stage interactions.
4. **MASH product contract:** independent review of candidate weights/polarity and raw-level reachability; align latency to MATLAB; integrate and verify actual serializer and physical PA mapping. The candidate arithmetic note is not a formal proof and is not a waiver.
5. **Other sign-off:** formal, CDC/RDC, synthesis/PPA, physical serializer, board/RF, and calibrated performance evidence remain NOT RUN.

The machine-readable hole matrix has 2,887 OPEN rows spanning 24 aggregate code metric rows, 2,787 detailed RTL line/branch/condition/toggle/FSM records, 40 functional-group gaps, 31 cross gaps, four MASH reachability/integration items, and one separate sign-off gap. Every row has a disposition and next action; source/bin details and evidence report hashes are retained.

## Closure gate

`python3 dv/uvm/sim/audit_dsm_v13_round2.py --mode coverage` returns 0 after validating the evidence structure, all seven configuration records, and manifest. `--mode closure` returns 2 and prints `DSM_V13_CLOSURE_OPEN=2887 OPEN coverage hole rows; fresh raw/adjusted URG coverage is not PASS; final DV sign-off gate is not satisfied`. This is the correct result for the current evidence.

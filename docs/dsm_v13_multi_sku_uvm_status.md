# DSM V1.3 Multi-SKU UVM Status — Round 2

Date: 2026-11-25
Run root: `runs/dsm_v13_round2/final3/`
Source baseline: `522eb372436e68b17cdfa87bc38aaecdcc4831eb`

## Configuration status

One DSM architecture is elaborated per simulation. The EF1/EF2 runs use the existing Thermo5 Product top and the MASH Product run uses the same Product boundary with `DSM_ARCH=3`; it does not instantiate three DSM cores at once.

| Required build | Selected top / architecture | Directed VCS | Random VDBs | URG merge | UVM warning/error/fatal |
|---|---|---:|---:|---:|---:|
| EF1 Product | Thermo5 Product / `DSM_ARCH=1` | PASS | 0 | PASS | 0 / 0 / 0 |
| EF1 AXI-Lite | AXI-Lite Thermo5 wrapper / `DSM_ARCH=1` | PASS | 3 | PASS | 0 / 0 / 0 |
| EF2 Product | Thermo5 Product / `DSM_ARCH=2` | PASS | 0 | PASS | 0 / 0 / 0 |
| EF2 AXI-Lite | AXI-Lite Thermo5 wrapper / `DSM_ARCH=2` | PASS | 3 | PASS | 0 / 0 / 0 |
| MASH Product | Thermo5 Product / `DSM_ARCH=3` | PASS | 0 | PASS | 0 / 0 / 0 |
| MASH AXI-Lite | AXI-Lite Thermo5 wrapper / `DSM_ARCH=3` | PASS | 3 | PASS | 0 / 0 / 0 |
| MASH wrapper/core | Legacy MASH scalar block experiment | PASS | 0 | PASS | 0 / 0 / 0 |

The six Product/AXI-Lite configurations passed the directed configuration/reset/protocol test set. MASH Product additionally checks all four 64-bit PA planes against the independent weighted-level codebook. Each listed VCS run has a distinct coverage database and each URG merge is SKU/configuration-specific. Final build/run manifests and hashes are in `evidence_manifest.json`.

## Shared environment additions

- A single elaborated DUT and shared Thermo5 UVM agent/monitor/scoreboard hierarchy are retained per run.
- The PA monitor sends accepted four-plane words to an independent coverage/checking path. The MASH adapter validates codebook symbols and reconstructs the signed weighted output after undoing the existing Fs/4 lane polarity.
- The independent expected-data queue is checked and drained at normal completion. Random campaigns compare each accepted input's expected output count with matched PA words; all nine campaigns passed exact count checks.
- The optional AXI-Lite wrapper remains the source of RUN/STOP, configuration, readback, response/backpressure, and restart behavior. The random product campaign uses bounded AXIS gaps, PA stalls, and clock-phase seeds.
- Reset, STOP/restart, STOP/drain, prefill/gap, AXIS valid/ready, transaction events, FIFO/reset context, MASH quantizer/input ranges, and PA-plane codebook bins are represented in covergroups/crosses. Architecture-specific and control-specific groups are constructed only when applicable. The denominator correction preserves all legal bins.

## MASH Product candidate

`tid32_thermo5_axis_frontend_tx` and its AXI-Lite wrapper route the existing interpolator/DPD output into the new MASH 1-1 weighted four-plane adapter when selected. The MASH state advances chronologically across the 32 samples in each word and across accepted words; I and Q state are independent. Output and state hold when any PA plane is not ready.

The proposed logical plane weights are `{-3,-1,+1,+3}`. The candidate preserves the reset startup `+2` code and the existing alternating Fs/4 I/Q polarity. This is an electrical-width/code contract for simulation, not proof that the current equal-weight Thermo5 PA supports these weights. Serializer pin mapping, PA calibration, MATLAB latency alignment, board/RF evidence, and physical sign-off are OPEN.

## Functional and assertion status

| Configuration | URG UVM functional group score | Assertion inventory | Disposition |
|---|---:|---|---|
| EF1 Product | 79.54% | 29 total, 25 success, 4 uncovered, 1 expected-negative failure | OPEN coverage |
| EF1 AXI-Lite | 87.95% | 31 total, 27 success, 4 uncovered, 0 failures | OPEN coverage |
| EF2 Product | 74.06% | 17 total, 13 success, 4 uncovered, 1 expected-negative failure | OPEN coverage |
| EF2 AXI-Lite | 88.66% | 19 total, 15 success, 4 uncovered, 0 failures | OPEN coverage |
| MASH Product | 76.57% | 19 total, 15 success, 4 uncovered, 0 failures | OPEN coverage |
| MASH AXI-Lite | 88.31% | 21 total, 17 success, 4 uncovered, 0 failures | OPEN coverage |
| MASH wrapper/core | Not integrated into Product covergroups | 5 total, 3 success, 2 uncovered, 0 failures | Evidence only |

The EF1/EF2 Product illegal-frame assertion failures are expected negative-test observations. They are isolated and reported separately; unexpected assertion failures are zero. UVM and assertion inventories are not substitutes for formal sign-off or proof that every remaining assertion has a legal non-vacuous activation.

## Current blockers to sign-off

1. Code coverage remains below target in every selected Product/AXI-Lite build; no waiver is approved.
2. The MASH Product weighted PA and serializer contract is not confirmed by the physical design owner; MATLAB timing alignment is OPEN.
3. Mandatory functional bins/crosses remain open. The exact missing group/cross values and source locations are in `docs/verification/data/dsm-v13-round2/coverage_hole_matrix.csv`.
4. Serializer position/reset is outside the four-plane Product boundary and remains NOT_INTEGRATED.
5. Formal, CDC/RDC, synthesis/PPA, and RF/board checks were not run.

EF2 may be considered for a separate Research DV disposition after its functional/code gaps and independent sign-off requirements close. It is not Product sign-off in this report.

# DSM V1.3 Round 2 — Three-SKU UVM Integration and Coverage Results

Date: 2026-11-25
Branch: `work/dsm-v13-mash-uvm-round2`
Baseline: Round 1 source snapshot `522eb372436e68b17cdfa87bc38aaecdcc4831eb`
Run: `runs/dsm_v13_round2/final3/`
Tools: Synopsys VCS/URG V-2023.12-SP1, Python 3.12

## Disposition

The three-SKU UVM implementation, directed regressions, nine constrained-random campaigns, fresh per-configuration URG merges, and evidence extraction completed. All seven requested elaboration configurations passed simulation and URG generation. The suite reported zero positive-test UVM warnings, errors, and fatals. The independent Python reference suite passed 74/74.

**Coverage closure and final DV sign-off remain OPEN.** No SKU meets all requested code and functional coverage targets. Raw code coverage equals adjusted coverage because no waiver or exclusion was approved. Formal/reachability, CDC/RDC, synthesis/PPA, physical serializer, and board/RF checks were not run.

| Gate | Result | Evidence |
|---|---|---|
| Round 1 baseline integrity | PASS | 327/327 source entries; 229/229 raw-log hashes; 151/151 captured artifact hashes |
| MASH 1-1 Product candidate integration | IMPLEMENTED / CONTRACT OPEN | Existing Thermo5 Product top, `DSM_ARCH=3`, four PA planes; proposed electrical weights are not physically approved |
| Directed multi-SKU VCS regressions | PASS | 38 UVM summary logs, seven URG configurations |
| Constrained-random campaigns | PASS, reduced budget | 3 campaigns/SKU, 9 total; 333,120 accepted input beats and 582,960 matched PA words |
| Coverage data integrity audit | PASS | Five CSV tables, seven configurations, 184 manifest entries |
| Coverage closure audit | OPEN, fail-closed | 2,887 OPEN hole rows; raw/adjusted URG targets not met |
| Final DV sign-off | OPEN | Thresholds and independent sign-off evidence remain outstanding |

## Implemented

- Added a sequential MASH 1-1 core and a word-atomic adapter selected in the existing Thermo5 Product top. The AXI-Lite wrapper uses the same selector. EF1/EF2 behavior remains selected by their existing architecture values.
- Added a simulation-visible four-plane code mapping with proposed logical weights `{-3,-1,+1,+3}`, an independent Python model/vector path, and a UVM checker that reconstructs weighted levels and checks lane polarity, held output under backpressure, and accepted PA words.
- Added MASH Product reset, AXI-Lite control, STOP/restart, drain, run/prefill, reset-context, quantizer/input-range, PA-plane, and cross coverage to the shared UVM environment. Non-applicable architecture/control groups are now instantiated only for applicable configurations; no legal bin was removed to inflate scores.
- Added per-SKU random regression, per-SKU URG merge, evidence extraction, and fail-closed coverage/closure audit targets.
- Added the candidate Product interface and arithmetic contract in `docs/dsm_v13_mash11_product_contract.md`.

## Random budget and transaction accounting

The requested budget was 10 smoke, 50 standard, and 10 stress seeds per Product SKU. The executed budget was 1 seed in each class per SKU because the full 100,000-beat cases are expensive on the available host. Each campaign met its requested beat count: smoke 1,024, standard 10,016, and stress 100,000 accepted AXIS beats. Across EF1, EF2, and MASH this is 111,040 beats/SKU and 333,120 total. Every accepted input beat was matched against the independent output expectation; the 582,960 expected PA words matched, with 10,410 accepted TLAST markers. Scoreboard expected queues drained, legally flushed transactions were zero, and pending transactions were zero for these campaigns.

Per-SKU seeds: EF1 `131000–131002`; EF2 `1131000–1131002`; MASH `2131000–2131002`. Random campaigns used randomized bounded source gaps and four-plane PA readiness, plus seeded source/AXI-Lite clock phases. Reset scenarios were exercised in directed runs; reset timing was not randomized inside these campaigns.

## Coverage result

Selected DUT-subtree code metrics are reported in `docs/verification/data/dsm-v13-round2/code_coverage.csv`. All EF1/EF2 Product Line/Branch/Condition/Toggle targets remain open; both Product FSM summary metrics are 100%. AXI-Lite and MASH Product code metrics remain below one or more targets. The MASH wrapper/core experiment reaches 100% Condition and 98.36% Toggle, while Line and Branch remain below target. No cross-SKU database merge was used.

The six full Product/AXI-Lite functional group scores are 74.06%–88.66%, below the 98% goal. Forty per-configuration functional group records contain missed bins; 31 cross-coverage rows remain OPEN; six serializer-position/reset rows are NOT_INTEGRATED. For the MASH Product candidate, raw weighted-level bins `-4`, `-2`, `0`, and `+4` remain visible and unhit. The arithmetic reachability note is not a formal proof and does not waive these bins.

The exact source locations, URG expressions or bin combinations, configuration, current disposition, root-cause status, reproducer/evidence, and closure action are in `docs/verification/data/dsm-v13-round2/coverage_hole_matrix.csv`. Unresolved RTL-bin causes remain explicitly unproven; the matrix does not label them unreachable.

## MASH Product boundary and limitations

The selected four-plane encoding is a digital candidate only. The current interface does not establish physical PA branch weights or polarity, serializer pin mapping, calibrated output behavior, or board acceptance. MATLAB latency alignment is also OPEN. The Round 2 reference model follows the documented RTL recurrence; no claim of MATLAB bit-true equivalence is made. The two legacy MASH raw bins `-2` and `0` remain unmodified in the evidence, alongside the candidate Product's additional unhit `-4` and `+4` raw bins.

The integration adds no new clock-domain crossing: the MASH block is in the core clock domain and uses the existing core reset. Existing AXIS/AXI-Lite CDC paths are inherited. Their system CDC/RDC sign-off is still NOT RUN.

## Checks and commands

- `make -C dv/uvm/sim dsm-v13-multi-sku-regression DSM_V13_OUT=$PWD/runs/dsm_v13_round2/final3 DSM_V13_RANDOM_OUT=$PWD/runs/dsm_v13_round2/final3/random DSM_V13_SMOKE_SEEDS=1 DSM_V13_STANDARD_SEEDS=1 DSM_V13_STRESS_SEEDS=1 URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg PYTHON=python3.12` — PASS; seven configurations and fresh URG merges.
- `python3.12 -m unittest discover -s tests` from `dv/uvm/refmodel/python/` — 74/74 PASS.
- Evidence generation, generator/audit Python bytecode compile, and `audit_dsm_v13_round2.py --mode coverage` — PASS.
- `audit_dsm_v13_round2.py --mode coverage` — PASS for evidence/data structure only.
- `audit_dsm_v13_round2.py --mode closure` — exits 2 with `DSM_V13_CLOSURE_OPEN`; this is the expected fail-closed outcome while the coverage targets and final sign-off are open.
- Required directed XSim smoke was NOT RUN: `powershell`, `pwsh`, and `xsim` are unavailable in this Linux environment. The VCS Regression target and all 7 URG merges completed.
- `git diff --check` — final result is recorded in the execution frontier and update log.

The final Machine-readable evidence is under `docs/verification/data/dsm-v13-round2/`. Detailed status and source/test/checker mapping are in `docs/dsm_v13_multi_sku_uvm_status.md` and `docs/dsm_v13_verification_matrix.md`.

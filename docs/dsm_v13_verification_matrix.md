# DSM V1.3 Round 2 Verification Matrix

Date: 2026-11-25
Source of truth for detailed coverage rows: `docs/verification/data/dsm-v13-round2/`

## Requirement-to-test/checker/coverage map

| Domain | UVM stimulus and monitors | Independent checker / assertions | Coverage model | Round 2 status |
|---|---|---|---|---|
| DSP algorithm | Existing EF1/EF2 vector-driven Product tests; MASH model vectors; random extreme/range profiles | Product scoreboard; Python bit-true MASH recurrence/codebook checker; EF2 reference checks | `core_cg`, `ef2_cg`, `quantizer_input_range_cg`, `mash11_product_cg`; `x_input_range_stage1`, `x_stage1_stage2`, MASH code/level crosses | Simulation PASS; functional bins and raw MASH levels remain OPEN |
| AXIS / AXI-Lite protocol | Source sequence and monitor; AXI-Lite configuration/read/write and stop/restart tests; random gaps and responses | Accepted-beat/event counts, register predictor, protocol checks, scoreboards | `axis_valid_ready_cg`, `source_cg`, `read_cg`, `write_cg`, `config_run_cg`; `x_valid_ready`, `x_config_run_state` | Basic directed runs PASS; missing read/write, configuration/RUN, malformed packet and response bins remain OPEN |
| FIFO / dataflow / credit | FIFO boundary/empty tests, long packets, source gaps, partial/all-plane PA backpressure | Underflow checks, PA hold/atomicity check, event and expected-queue conservation | `source_gap_pa_fifo_cg`, `plane_atomic_cg`, `transaction_event_cg`; source-gap/FIFO-full/PA-stall cross | Queue drain and PA integrity PASS in executed campaigns; source-gap/FIFO-full/PA-stall cross is OPEN for Product-only builds |
| RUN / STOP / restart / drain / prefill | AXI-Lite stop/restart and graceful-stop sequences, prefill and random packet tests | Status/readback, accepted TLAST and drain completion checks, queue-drain check | `stop_restart_cg`, `stop_tlast_drain_cg`, `stop_pa_backpressure_cg`, `restart_fifo_state_cg`, `run_prefill_gap_cg` | Directed checks PASS; several restart-vs-FIFO and configuration-vs-RUN combinations remain OPEN |
| Reset / clock / epoch | Existing reset tests and reset sweeps; source/core clock phases varied in campaigns | Reset recovery, epoch-tagged transactions, scoreboard drain | `reset_context_cg`; `x_reset_fifo_state`, `x_reset_dsm_state`, `x_reset_clock_phase` | Directed regression PASS; FIFO full/partial and DSM-zero combinations remain OPEN in several builds; system CDC/RDC not run |
| PA encoding / lane / serializer | Four-plane PA monitor and checker; MASH weighted-plane codebook test; asymmetric PA ready | Independent weighted reconstruction, lane/IQ polarity and held-output checks | `plane_atomic_cg`, MASH level/code bins and `x_level_x_code`; serializer-position/reset plan row | Four-plane digital candidate PASS; physical PA weights and serializer mapping unapproved; serializer position/reset NOT_INTEGRATED |

## Directed and random execution

The final VCS/URG snapshot contains seven configurations and 38 simulation logs. Positive-test UVM warning/error/fatal counts are 0/0/0. EF1/EF2 illegal-frame tests produced the two expected-negative assertion observations; no unexpected assertion failures were reported. The independent Python reference suite passed 74/74.

Each Product SKU ran one smoke, one standard, and one stress seed. Target beats were 1,024, 10,016, and 100,000 per seed. This is a resource-reduced execution of the requested 10/50/10 seeds per SKU. All nine runs matched expected PA word counts and drained expected queues. Aggregate totals are 333,120 attempted/accepted AXIS beats, 582,960 expected/matched PA words, 10,410 TLAST markers, zero legal flushes, and zero pending transactions. Per-seed source/vector hashes and commands are recorded under the evidence manifest.

## Coverage sampling and denominator review

- Covergroup sampling is based on DUT-facing accepted AXIS/PA events or a completed, integrity-checked packet scenario; randomization at the driver alone does not count as functional coverage.
- Architecture-only covergroups are instantiated only for the selected architecture; AXI-Lite control groups are instantiated only for AXI-Lite builds. All other legal bins remain in the applicable group denominator.
- The four-plane MASH level/code group preserves raw `-4`, `-2`, `0`, and `+4` bins. The contract's algebraic reachability argument is not applied as a waiver.
- Crosses include the requested state interactions that are observable at the current Product boundary. Serializer-position/reset cannot be sampled because the top exposes parallel PA planes, not a serializer-position interface.
- Existing explicit illegal/ignored bins remain visible in the source contract. No VCS exclusion or waiver was applied; raw and adjusted code coverage are identical.

## Exact evidence locations

- Code metrics and same-scope Round 1 percentages: `code_coverage.csv`.
- Per-group score, expected/covered/missing bin count, source covergroup line and named missed bins: `functional_coverage.csv`.
- Every extracted cross and its missing bin combination: `cross_coverage.csv`.
- Exact RTL module/source line/expression/state transition or functional-bin hole, evidence report path, current root-cause status and closure action: `coverage_hole_matrix.csv`.
- Assertion inventory and expected-negative separation: `assertion_coverage.csv`.
- Seed-level results, transaction conservation, tool/coverage report hashes and evidence file hashes: `regression_summary.json` and `evidence_manifest.json`.

The evidence data audit passes. The independent closure audit exits 2 while the matrix has OPEN items or the code/functional targets are not met. That exit is the intended fail-closed behavior, not a claim of closure.

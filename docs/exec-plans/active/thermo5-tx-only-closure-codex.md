# Thermo5 TX-only architecture / worst-case / 100% coverage closure — Codex execution plan

**Owner intent:** Finish the *transmitter* only. Do not build or modify RX, RF-ADC observation, online learning, PS AI calibration, a physical DPA board, or any TX→RX closed loop in this task.

**Baseline read before work:** pinned source `759fc8e77446046cb942e7939c53ca49d3bde882` (thermo5, 2026-10-28). The actual working HEAD must be recorded when implementation starts; first compare it with this checkpoint. Authoritative evidence: `docs/exec-plans/active/execution-frontier.md`, `docs/verification/thermo5-dv-portfolio.md`, `docs/verification/thermo5-frozen-sku-signoff-plan.md`, `docs/architecture/thermo5-ef2-throughput-study.md`, `dv/uvm/refmodel/python/README.md`. Some historical README/SPEC sections describe old SKUs: do not combine historical scores with the present one.

## Scope and invariants

Main TX SKU (must be preserved until explicit A/B promotion): 125-MHz AXI-Stream, 14 Q1.15 complex samples/accepted beat; 16-beat-deep generic/XPM CDC FIFO; 14→8 gearbox to 218.75 MHz; frame gain; centered-cubic x2 FIR; configurable C1/C3/C5 memory-polynomial DPD; centered-cubic x2 FIR; four thermometric offsets `{+3,+1,-1,-3}*5120`; fixed-point 20-bit state order-2 EF2; 4 lockstep 64-bit GT-user planes, nominal 14 Gb/s per plane, 250-MHz-occupied-bandwidth 256-QAM evaluation. The existing ZU15EG GT parent *elaborates DPD_MAX_TAPS=1 with Identity coefficients*; 2/4-tap hardware is not present in that parent. Reference model, quantizer tie rule, sample order, frame tail, state clamping, idle/fault and AXIS/AXIL contracts must not silently change.

Use **small PRs grouped by gates**. No speculative main-chain algorithm switch; candidate implementations must be separate parameterized configurations/branches with independent golden/regressions. No claim of physical RF, link BER, or FPGA routed timing without corresponding evidence.

## Gate 0 — audit and freeze evidence (do first)

1. Read source hierarchy, synthesis parameters, parameterized alternatives, testplan, RTL/golden tests, current URG VDB metadata, and available licensed tools. Run `git status`, `git rev-parse HEAD`; record tool versions, clocks, active defines, `DPD_MAX_TAPS`, `PAIR_LOOKAHEAD`, `INTERP_CENTERED_CUBIC`, `TIDSM_ORDER`, FIFO implementation, all seeds.
2. Run no-RTL-change reference suites: Python tests 36/36 expected; VCS generic main-chain/full AXIL; STOP/drain/restart; 2072-word EF2 sustained, clamp/stall/reset, random stalls; four-plane bit-true; scoped EF2 formal. Preserve source SHA, warnings, checker counts, coverage invocation and raw logs. Rerun XPM only where Vivado vendor files/license exist; mark NOT_RUN with precise reason otherwise.
3. Publish `docs/verification/thermo5-tx-baseline.md`: current vs historical claims with exact source/config/test date. The currently reported 76.12% raw Generic URG (latest Linux package) versus 79.86% historical candidate aggregate MUST NOT be treated as comparable until same elaboration, hierarchy, source SHA, instrumentation and merge scope are verified.
4. Maintain an issue/CSV ledger: item ID, requirement, owner module, top/SKU, evidence SHA, stimulus, independent checker, targeted coverpoint/code row, pass/fail/open, reproduction command.

**Gate 0 execution checkpoint (2026-10-29): PARTIAL / ACCEPTANCE OPEN.**
Audit source HEAD is `eb1081bc7607ba2e9825d9e9fb32bcfa1c6a270e`; it differs
from the pinned runtime checkpoint only by this documentation plan. Python
reference tests pass 36/36 and the 56-word centered-cubic/EF2 Python oracle
vector set was generated. Current-HEAD Generic VCS/URG and EF2 VC Formal were
attempted but stopped before compile/proof because the Synopsys license server
was unreachable. AXI-Lite STOP/restart and 2,072-word qualification were not
rerun at exact HEAD. The latest traceable raw Generic URG remains the
source-equivalent historical 76.12% report at SHA
`759fc8e77446046cb942e7939c53ca49d3bde882`; its source-linked inventory has
784 records. The prior 79.86% current-score statement has no matching raw
report in the inspected evidence and is withdrawn pending a traceable run.
Full details and evidence hashes are in
`docs/verification/thermo5-tx-baseline.md`,
`docs/verification/thermo5-tx-feature-matrix.md`,
`docs/verification/thermo5-tx-coverage-ledger.csv`, and
`docs/verification/thermo5-tx-gate0-evidence.json`.

**Gate 0 exit:** a baseline and complete raw inventory are documented, but
acceptance remains open until Generic UVM/URG, AXI-Lite STOP/restart, the
2,072-word EF2 qualification, and scoped EF2 formal are rerun at exact HEAD
with licensed tools. No architecture change or Gate 1–4 work is included in
this checkpoint.

## Gate 1 — dormant algorithms / compile-time alternatives (A/B, not automatic integration)

For every candidate, document *source exists?*, selected in current hierarchy?, independent bit-true?, desired benefit?, LUT/FF/DSP/BRAM cost, Fmax and II measured?, communication effect at matched settings? Include at least:

| Candidate | Current status to confirm | Mandatory A/B gate |
| --- | --- | --- |
| Exact EF2 `PAIR_LOOKAHEAD=1` | Experimental in `tid32_cartesian_ef2_fs4_gt_tx.sv`; scalar main chain uses 0; pair-level VCS/formal evidence exists | Same exact inputs/state, all clamp/zero tie/extremes/stalls; 32-sample state equivalence; II=1; OOC/routed critical path/PPA comparison if Vivado available; reject if no real benefit |
| Order-1 TIDSM (`STEP=7168`) | Implemented selectable fallback; current default order-2 `STEP=5120` | Same 250-MHz waveform, same PA/receiver chain, EVM/SNDR/BER/ACLR or clearly labeled proxy, timing resources |
| Causal 2/3/4-tap vs centered-cubic FIR | Existing parameterized RTL | Matched time labeling/group delay, frame tails and input power; compare image rejection and full four-plane Bit-True |
| Memory-DPD 1 vs 2/4 tap, Identity vs nonzero C3/C5 | Parameterized `dpd_vector16_memory_poly.sv` up to 4 taps; GT parent compiles 1 tap | Synthesized tap-depth/area, fixed-point independent oracle, no illegal hot-switch; memory model/PA simulation A/B; *do not claim PA improvement absent calibrated PA* |
| Memoryless 3/5/7 order (`rtl/dpd/dpd_poly.v`) | Standalone RTL, not current main chain | Only evaluate if justified by TX metrics; otherwise document deferred |
| Low-power `dsm_frame_power_ctrl.sv` | Optional compile-time path; not default GT parent | Measure drain/prefill/STOP correctness and power activity; do not enable without independent reset/CDC verification |
| Earlier BPDSM/MASH, LUT DPD, TinyML/Observer, old PS code | Some referenced by legacy docs; many **not present in thermo5 file tree** | Inventory only. NO automatic import from `main`. TX-only DSP candidates may be researched later; RX/AI training explicitly out of scope |

Develop `docs/verification/thermo5-tx-algorithm-ab.md` with ACCEPT/REJECT/DEFER reason and actual plots/results. Promotion requires proven numerical/bittrue equivalence when appropriate, robust gain on held-out seeds, no functional regression, and viable implementation; theoretical advantage is not proof.

## Gate 2 — TX worst-case test campaign

**2A. Legal digital corners (must be exact):** zero, constant ±full-scale, alternating 0x7fff/0x8000, impulse, ramp, PRBS, threshold/tie `u==0`, polarity offsets, all four EF2 positive/negative clamps, input clipping, saturating Q1.15, Frame Gain extrema, DPD coef extrema, different tap histories and frame boundaries. Test 32/64/96+ beat legal TLASTs; early/missing TLAST and reset/sticky error as *negative* contract tests. Exhaust representative 14:8 residual states and FIFO low/full. Source pauses, PA 4-bit Ready masks (including partial), stall lengths, STOP→Drain→Restart, Commit at frame boundary, reset during nonzero EF2 state/stall/drain and GT-health loss in behavioral parent. Check hold, no drop/duplicate/reorder, exact four-plane Python integer oracle, counters, epoch and data-tail semantics. Reuse existing tests; extend only uncovered feature/checker combinations.

**2B. Communication worst case (model-only, separate from RTL):** use 256-QAM 4096-FFT, 512-CP, 584 subcarriers, ~249.512-MHz actual occupation and fixed receiver/equalization contract. Freeze development and disjoint held-out seeds; more than existing six seeds, report count/uncertainty and all failures, not just winners. A staged smoke/full matrix is acceptable. Sweep input RMS/backoff 0/3/6 dB, PAPR unclipped vs 7/9 dB radial limiting, peak envelope at/below supported model 0.35; candidate STEP, state widths (18/19/20 *model only*); PA nominal/stress (AM/AM, AM/PM, memory, observation noise and output BPF), branch gain mismatch, representative inter-lane skew {0,2,5,10,20} ps, filter bandwidth/group delay. Separate **within-contract worst case** from **overstress / expected fault**. Measure digital EVM, SNDR, uncoded BER with error count and CI, throughput, PAPR, clipped samples, EF2 clamp, normalized Pout, and real integrated adjacent-band power using documented channel bandwidth/window/normalization. Retain existing **ACLR proxy** under that label; never rename it standard-compliant ACLR. Never compare different RMS/receiver/PA setups as controlled A/B. Compare Identity, candidate nonzero DPD, first-order and EF2 under same conditions.

**2C. Define acceptance:** Product spec must state legal input envelope, communication operating point, PA model and all measurement equations *before* declaring pass. An initial 3.5%-EVM engineering screen is a reference only, not proof of 3GPP conformance. Define ACLR/Pout/BER or BLER limits and modulation/channel assumptions; otherwise mark `TARGET_UNDEFINED` rather than inventing a threshold. Hard safety/integrity assertions are zero failure. Stress failures outside the supported envelope must be reported, not hidden.

Outputs: deterministic `benchmark_thermo5_tx_worst_case.py` (or reuse/refactor existing scripts), `docs/verification/thermo5-tx-worst-case.md`, machine-readable CSV/JSON with seed, stimulus params, expected/observed, worst-case provenance, PSD/constellation plots and failure trace.

## Gate 3 — functional coverage 100% / code coverage 100%

**Functional objective:** 100% of the **reviewed, required, legal, applicable** Feature→Testpoint→Coverage bins in the *current fixed TX SKU* AND targeted selected candidate SKUs. Construct `docs/verification/thermo5-tx-feature-matrix.md`: AXIS/AXIL independent channels and WSTRB; FIFO/gearbox/residual; gain; FIR sample history/tail; DPD 1/2/4 taps & coeff bank/tie/round/saturation (per elaboration); four-branch offsets/atomicity; EF2 clamp (positive and negative per branch), state rail, stalls, reset/epoch; STOP/TLAST/drain/restart; bad frames; GT-user 4-plane idle/health/fault. Every required cross must have independent monitor + checker + legal directed stimulus; no bin counted on test intent alone. Coverage code must not sample cumulative `accepted_tlast_markers>0` as proof of *simultaneous* TLAST-tail/PA stall, nor all-zero Ready as partial Ready. Explicitly correlate packet ID/word index/time window and mask in sampled DUT observation.

**Code objective:** pursue 100% of reviewed **reachable and applicable DUT** line, branch, condition, *both-direction* toggle, FSM-state/transition, assertion coverage wherever supported. Publish both **raw unmodified URG** and **audited adjusted** scores with explicit numerator/denominator by type. Exclude testbench, vendor library internals and non-elaborated configurations from the *SKU DUT denominator only by documented scope definition before measurement*, not retroactively. Track generic vs real-XPM as distinct configurations; show vendor-XPM raw stats separately when their sources are instrumented. Never conflate 100% functional with 100% code or Formal coverage with simulator hits.

For each uncovered *exact* source line/condition/bit-transition/branch/FSM entry record: source SHA/parameter/clock, whether reachable (prove by legal stimulus or scoped non-vacuous formal), legitimate test, checker, before/after URG from **same binary/hierarchy**, owner/status. For genuine unreachable paths, use precise approved tool exclusions with source-linked proof/assumptions and independent review, and preserve raw deficit. No `force`/`deposit`, counter shrinking, DUT hacks just to hit bins, editing VDB/HTML, indiscriminate vendor-source masking, retroactive denominator adjustments, unreviewed waivers or faked 100%. E.g. bit31 rise of a 32-bit counter needs ≥2^31 accepted samples and may be impractical; formal proof is an alternate engineering evidence class but cannot be mislabeled a hit. If *literal raw 100%* is unachievable in a frozen SKU, say **RAW_100_OPEN** with exact quantitative gaps; only declare **100%-eligible** after every exclusion is reviewed and reproducibly applied. Do not stop simply when an adjusted average displays 100: require each mandated category + feature bins to close.

Build deterministic `coverage_closure_gate` (Python + URG parsing), fail on reachable unhit bins, missing checker, false passes, missing report, unknown SHA, or missing required FIFO implementation. Include *negative mutation* or fault injection to show important checkers actually fail. Local generic licensed run first; vendor XPM only with actual Vivado files; CI licensed runner when connected. Package checksum manifest (source SHA, tool, test, seed, vectors, VCS binary, VDB, log, coverage, exclusions). No benchmark/performance claims from rerun code without execution.

Outputs: `docs/verification/thermo5-tx-coverage-ledger.csv`, `docs/verification/thermo5-tx-coverage-signoff.md`, URG source-linked raw & adjusted reports, functional bins report, gate command and exact exclusions. Maintain OPEN statuses until fulfilled.

## Gate 4 — TX signoff and handoff

- Regression across selected main SKU and approved *separate* alternatives, generic and XPM as applicable; independent bit-true oracle, complete drain and four-plane word counts, reset and wrap safety, AXI-Lite atomic commit, no unexpected UVM errors/fatals.
- Current EF2 safety/Formal scope is proven, but a previous DPD identity multiplier/saturation formal proof was inconclusive: disposition explicitly; derive another bounded proof or classify OPEN, do not claim it passed.
- GT vendor TXP simulation (current EF2 configuration), setup/hold and parent constraint coverage, CDC/RDC review remain separate physical implementation gates. FPGA/Vivado resources and routed Fmax are optional in the present software/coverage closure campaign but MUST be OPEN until measured; do not claim board readiness from VCS PASS.
- Produce one `docs/verification/thermo5-tx-final-signoff.md` with Gate 0–4 table, measurable percentages/denominators, open items, accepted/rejected algorithms, worst-case numeric table, commands, SHA/hash evidence. Update `docs/exec-plans/active/execution-frontier.md` in its current-state heading only when supported; do not erase historical evidence.

## Codex execution protocol

**Start with Gate 0 and a PR that contains only the audit/baseline/feature ledger.** Next separate PRs: (A) algorithm A/B test harness/results without default RTL promotion; (B) worst-case model/RTL stress; (C) coverage checker/targeted stimuli + audited exclusions; (D) final signoff. At each PR provide changed file list, exact commands actually executed, test outcomes, raw/eligible coverage numbers, design SHA and blockers. If tools/PS/Vivado licenses are unavailable, implement scripts/checkers, run available Python/static tests, label licensed gates **NOT_RUN**, and never fabricate PASS.

**Never start RX/AI-DPD or board hardware design in this handoff.** Request user approval separately before changing default TX architecture or deploying coefficient packages.

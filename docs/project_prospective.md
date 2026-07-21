# Project Prospective

Timestamp: 2026-07-15 14:17:31 +08:00

## Current Position

This repository has moved from a DSM algorithm collection to a reusable digital
TX IP prototype. The current baseline contains:

- MATLAB fixed-point and bit-true reference models.
- Synthesizable RTL for single-bit and multibit Cartesian DSM paths.
- A compile-time selectable interpolation/filter frontend.
- AXI-Stream input and AXI-Lite control/status wrapper.
- A configurable DPD frontend with bypass, memoryless polynomial, LUT, and
  2-to-4-tap memory-polynomial modes.
- An optional non-blocking observation AXI-Stream input with programmed
  delay/gain alignment and bounded training windows.
- Runtime QAM/bandwidth/backoff/power/temperature/monitor-state registers and a
  conservative dynamic seed selector.
- XSim smoke and bit-true regressions.
- Vivado IP packaging.
- ZU15EG synthesis evidence and local board bring-up evidence.

The local ZU15EG smoke test has validated the internal digital path:

```text
PS DDR -> AXI DMA MM2S -> AXI-Stream -> interpolation frontend -> DSM
       -> status counters / ILA observation
```

This proves the PS-to-PL streaming integration and the packaged DSM datapath on
the local MPSoC board. It does not prove an external DAC, RF, PA, or analog
measurement chain.

## Strategic Direction

The next major upgrade should be an AI-assisted TX calibration IP, not a neural
network replacement for the high-speed datapath.

The high-speed PL datapath should remain deterministic and timing-friendly:

```text
AXI-Stream source
  -> optional DPD / correction block
  -> interpolation/filter frontend
  -> DUC / Fs/4 merge
  -> DSM
  -> output monitor / board observation
```

The AI or optimization logic should initially run at a low control rate:

```text
simulation feedback / ILA-visible metrics / future observation receiver
  -> Python or MATLAB model fitting and optimization
  -> DPD or calibration coefficients
  -> AXI-Lite coefficient update
```

This partition keeps the FPGA datapath practical while still demonstrating a
modern communication SoC-style calibration architecture.

## Technical Route

### Phase 0: Freeze The Board-Validated Baseline

Goal:

- Preserve a known-good DSM TX datapath before adding DPD or AI features.

Tasks:

- Commit the current ZU15EG board bring-up state.
- Keep generated bitstreams, hardware projects, board collateral, and local
  binaries out of the repository.
- Add or retain a repeatable smoke flow for bitstream programming, PS
  initialization, AXI-Lite register reads, DMA transfer, counter checks, and ILA
  observation.

Exit criteria:

- `VERSION`, `ALGORITHM`, `DUC_MODE`, and `INTERP_MODE` read back correctly.
- A P0 DMA transfer increments input, frontend, and output counters.
- `ERROR_STATUS=0` and `INPUT_STALL_COUNT=0` for the basic smoke transfer.

### Phase 1: Deterministic TX Datapath Hardening

Goal:

- Make the non-AI TX IP strong enough to serve as the reference platform.

Tasks:

- Keep DSM and interpolation modes compile-time selectable for low-resource
  builds.
- Maintain MATLAB/RTL bit-true checks for DSM and interpolation behavior.
- Improve reset, valid, ready, and counter documentation.
- Keep ZU15EG synthesis or routed evidence for representative configurations.
- Add more directed board-level checks when useful.

Exit criteria:

- The existing bit-true regressions pass.
- The packaged IP can be rebuilt without manual RTL edits.
- ZU15EG board smoke remains repeatable after RTL or wrapper changes.

### Phase 2: Conventional DPD Frontend

Goal:

- Add a configurable correction block before DSM without depending on a fixed
  real PA.

Current status:

- TX frontend v1.2 is implemented in RTL and connected in the AXI wrapper. It
  supports bypass, memoryless polynomial, LUT, and 2-to-4-tap
  memory-polynomial DPD modes.
- Coefficients are software-writable through AXI-Lite as signed Q2.14 packed
  complex values. Memory-polynomial coefficients use an inactive shadow bank
  and one atomic commit.
- The MATLAB fixed-point model shows that the Q1.15/Q2.14 datapath tracks the
  floating DPD baseline closely.
- The optional observation AXI-Stream input performs programmed 0-to-31-sample
  delay and Q2.14 complex-gain alignment over a bounded training window. It
  records pair/drop counts, 64-bit L1 error, aligned complex magnitude/peak,
  clip/saturation, slew, fixed-bin spectral proxies, and start-latched Q8.8
  temperature without backpressuring TX.
- Runtime waveform, environment, and monitor-state registers feed a
  conservative hardware seed selector. Unknown or faulted conditions force
  fallback, and the qualified 14-candidate local search remains mandatory.
- The AXI smoke test covers coefficient readback, observation-window control,
  seed status, and sample counting.
- A dedicated MATLAB-versus-RTL DPD vector comparison is in place and passes
  with zero mismatches for both memoryless and memory-polynomial directed
  vector sets.
- ZU15EG v1.2 OOC synthesis passes the 100 MHz target with 8,975 CLB LUTs,
  7,562 flip-flops, 154 DSPs, and `+2.302 ns` WNS for the retained EFDSM build.
  The complex observer extension adds 1,399 LUTs and 387 flip-flops over the
  retained v1.1 baseline, with no DSP increase.
- Q2.14 memoryless and 4-tap memory-polynomial coefficients are now trained
  with disjoint fit/validation OFDM waveforms and evaluated on three held-out
  seeds under one identical behavioral PA. Mean EVM is `4.3050%` without DPD,
  `3.1175%` with memoryless DPD, and `2.8278%` with the joint-safe
  memory-polynomial DPD; both
  trained paths complete without fixed-point saturation or drive limiting.

Recommended first implementation:

- Memoryless polynomial DPD with 1st, 3rd, and 5th order terms.
- AXI-Lite writable coefficients.
- Bypass mode.
- Fixed-point MATLAB model and RTL bit-true regression.
- Amplitude-indexed LUT DPD.
- AXI-Lite or BRAM-backed LUT update path.
- Optional interpolation between LUT entries.

The DPD hardware should be parameterized and coefficient-driven. A real PA model
is not hard-coded into RTL. Different PA, temperature, frequency, bandwidth, or
output-power cases should be handled by recalibrating coefficients, not by
rewriting the datapath.

Exit criteria:

- MATLAB behavioral PA model shows EVM or ACLR improvement with trained DPD
  coefficients.
- RTL DPD output is bit-true against MATLAB for the same coefficients.
- AXI-Lite coefficient writes are covered by simulation and board smoke.

The deterministic hardware, joint EVM/ACLR coefficient training, same-PA
comparison, and behavioral-observation XSim loop are complete. A 12-profile PA
LOSO software competition also qualifies a small decision tree and k-NN over
the LUT baseline with zero modeled safety violations. A deterministic tree is
now frozen into signed-Q12.20 Python/C/RTL source with conservative domain and
leaf fallback. The observer-v2 model version `0x00020000` passes 329/329
Python/C/RTL decisions and all 288 C raw-feature checks. A real RF claim still
requires a PA and calibrated observation receiver.

The fixed-tree host replay confirms the architecture split. The current model
uses `aligned_complex_pa_monitor_v2`; retained post-DSM board traces still use
incompatible `pl_dsm_monitor_v1`. The regenerated v2 matrix contains 288 raw
complex-feedback traces, and independent replay reconstructs all monitor
records exactly. Strict quantized LOSO rejects standalone tree deployment but
qualifies the tree/LUT/search hierarchy. The old v1 tree is retired, the v2
tree remains outside AXI, and the board continues mandatory local search.

The current preferred inference architecture is hierarchical rather than a
standalone RTL classifier: fixed-point tree direct suggestions first, existing
PS LUT safety arbitration second, and deterministic 14-candidate search last.
Strict PA-profile LOSO qualifies this hierarchy but not the pure tree. This
keeps the learned hardware small and leaves policy updates and safety fallback
under software control.

An isolated observer-v2 blind PA matrix has now tested the frozen tree/LUT
hierarchy beyond the 12 fitting profiles. Across three held profiles and 72
conditions it selects 19 unsafe seed packages before search. The hierarchy is
therefore blocked from PS and board deployment: its generated C policy header
sets `AVAILABLE=0`, direct execution remains disabled, and the existing
14-candidate search remains the only deployed action. This is a useful negative
result: it demonstrates that exact fixed-point equivalence and PA-profile LOSO
do not establish unknown-PA seed safety.

The replacement offline seed policy is safety-first. It uses eight new,
development-only PA profiles for leave-one-profile-out selection and keeps the
three `blind_*` profiles permanently frozen as final-test data. A package is
eligible only when all seven same-waveform nearest nonblind observations label
that package safe and the nearest monitor state is inside the finite `4.0`
normalized-distance bound; expected cost ranks only eligible packages. The
policy returned zero unsafe selected seeds across 129 safety-qualified
development LOSO seeds (63 `fallback_14` decisions) and across 49
safety-qualified frozen blind seeds (23 `fallback_14` decisions). Every action
remains a mandatory
14-candidate local search. This qualifies the offline policy contract, but it
does not reopen the legacy tree/LUT PS header: a separately generated and C
equivalence-checked safety-first PS implementation is required before board
enablement.

That PS implementation is now generated as a fixed-point `k=7` safety selector
with a Q12.20 distance cap of `4.0`. Its 480 evidence records contain the 12
base and eight development profiles only; all three `blind_*` profile IDs are
rejected by the constant generator. Host C matches Python on 552 decisions
(480 nonblind evidence conditions plus 72 frozen blind conditions), and the
quantized constants preserve all 72 pre-existing frozen-blind decisions. The
A53 selector compiles cleanly, but it is not yet called by the bare-metal app:
the generated header keeps board enable at `0`, direct execution at `0`, and
the only permitted action remains the 14-candidate local search.

The selector is now reachable only through `CAL_SAFETY_SEED_POLICY_ONLY=1`, a
test-only bare-metal mode. It requires completed `aligned_complex_pa_monitor_v2`
feedback, rejects policy fallback rather than substituting the legacy tree/LUT
policy, and performs the deterministic one-seed/12-perturbation/final-replay
14-record search. A direct A53 ELF has been built for QAM16, 48 used
subcarriers, and 0.58 backoff. It is ready for a J1 JTAG/UART replay once a
matching programmed PL image can provide a completed observer-v2 window; the
normal post-DSM counters are not a substitute.

### Phase 3: AI-Assisted Calibration Loop

Goal:

- Use AI or optimization to generate DPD/calibration parameters, while PL
  hardware executes deterministic fixed-point correction.
- Keep the first AI-assisted version explainable and verifiable: the PS or
  MATLAB/Python side searches calibration parameters, and the PL side remains a
  deterministic DPD + interpolation + DSM datapath.

Recommended first control loop:

```text
MATLAB/Python PA model or captured diagnostic metrics
  -> coefficient fitting / grid search / Bayesian optimization / small model
  -> coefficient table
  -> AXI-Lite update
  -> TX datapath smoke and metric comparison
```

Useful calibration targets:

- Polynomial DPD coefficients.
- LUT DPD entries.
- Input drive level.
- Clipping threshold.
- Multibit DSM resolution in compile-time experiments.
- Interpolation mode in compile-time experiments.

The first AI model should assist coefficient prediction or calibration search.
It should not sit directly inside the high-speed DSM feedback loop.

Current implementation boundary:

- The PL side already exposes DPD controls and monitor feedback through
  AXI-Lite: DPD mode, polynomial coefficients, LUT entries, sample counters,
  saturation count, clipping count, correction-magnitude proxy, RF-slew proxy,
  and fixed-bin spectral proxies.
- The ZU15EG bare-metal app already runs a first PS-side calibration loop:
  it evaluates exported polynomial/LUT DPD packages, runs DMA/datapath tests,
  reads hardware counters, applies a scalar cost, performs a small coordinate
  search around the best polynomial package, and leaves the selected DPD
  configuration programmed in PL.
- This is a valid first AI-assisted calibration architecture because the
  decision loop is automatic and feedback-driven, but it is still deterministic
  optimization. It is not yet a neural-network PA model or a hardware ML
  accelerator.

Next implementation target: AI-assisted calibration engine v2.

- Modularize the calibration policy so the cost function is explicit:

```text
cost =
  MATLAB proxy EVM/SNDR score
  + PL EVM proxy
  + PL ACPR/slew proxy
  + PL fixed-bin spectral proxy
  + saturation/clip/stall/sticky-error penalties
```

- Make the cost weights configurable in the PS app or in a generated
  calibration header.
- Upgrade the search strategy from a single small coordinate pass to a more
  useful optimizer:
  - multi-round coordinate search,
  - coarse-to-fine step reduction,
  - optional random restart,
  - optional Bayesian-like candidate table or lookup-guided search.
- Emit a calibration trace for every candidate:

```text
candidate id
DPD mode/package
C1/C3/C5 or LUT id
EVM proxy
ACPR/slew proxy
spectral proxy
saturation/clip/stall/error counters
cost
accept/reject reason
```

- Store the best package and final coefficients clearly so the result is
  reproducible from logs.

Current v3 policy-gating status:

- The trace policy now exports an explainable confidence gate using nearest
  scenario distance and the selected action's weighted cost standard deviation.
- Distance and relative-dispersion thresholds are generated into a fixed-point
  C header; the bare-metal control path does not require floating-point
  inference.
- A trusted condition runs one measured package candidate. An untrusted
  polynomial policy runs a bounded one-round local coefficient search and a
  final replay instead of the 49-candidate full calibration.
- On the held-out QAM64, 40 MHz, 0.58-backoff board condition, the direct branch
  used one candidate at cost `296375`. A deliberately tightened distance gate
  exercised the fallback branch with 14 trace records and reduced cost to
  `294902`, only `77` above the 49-candidate full-search result while still
  eliminating 35 candidate evaluations.
- The policy now rechecks safety after the first measured candidate. Absolute
  measured-versus-predicted cost residual, stall, sticky error, or saturation
  can force the same bounded local search even when the static gate is trusted.
  The default residual limit is `15%` and is stored as integer ppm.
- On J1, the default limit accepted residual `110439 ppm` and retained one
  candidate. Tightening only the runtime residual limit to `10%` triggered 14
  records with `reason=cost_residual` and retained cost `294902`.

Next Phase 3 target:

- Implement the validated safety-first policy in PS C with generated
  development-only constants, then prove Python/C equivalence before a board
  trace replay. The old tree/LUT interface remains blocked and direct execution
  remains prohibited.
- Calibrate confidence thresholds from repeated runs and a second controlled PA
  strength/feedback condition rather than treating the current one-profile
  waveform matrix as RF uncertainty evidence.
- Calibrate the runtime residual and static confidence thresholds with repeated
  captures under a second controlled PA strength and real feedback condition.
- The collection flow now has a strict RF-feedback manifest and a separate
  threshold-calibration tool. It requires two PA strengths, repeated runs,
  receiver calibration provenance, and measured EVM/ACLR/power records before
  producing evidence-based ppm suggestions. It deliberately does not update a
  policy header or claim RF safety certification.
- Because no physical PA or observation receiver is available, the current
  calibration route is the MATLAB memory-PA/observation simulation. Its
  repeated nominal/strong PA seeds generate simulation-only threshold evidence;
  keep the resulting ppm values separate from the board default until a real
  observation path exists.
- The expanded simulation covers gain, saturation, memory length, observation
  noise, and gain/phase-drift profiles. Its multi-seed leave-one-profile study
  shows the current distance/dispersion/residual gate is not stable across
  hidden PA changes. Add PL-observable monitor features to the confidence model
  before promoting any simulation-derived threshold into the board policy.
- The policy now consumes those PL-observable monitor features after its first
  candidate: input/output power, peak, average magnitude, EVM/ACPR proxies,
  fixed spectral proxies, clip, and saturation. The generated reference is a
  weighted center of retained selected-package traces; state distance beyond
  the generated tolerance triggers bounded search. The J1 nominal replay
  measured `252573 ppm` against `792666 ppm` and retained direct execution.
  The expanded behavioral LOSO covers 12 PA/observation profiles, eight
  QAM/bandwidth/backoff waveforms, and three seeds (288 records). Its
  distance/dispersion/residual gate is already extremely conservative,
  retaining only two held passing direct decisions and no held failures; the
  weighted monitor-state gate retains the same two. The minimum simulation
  monitor tolerance is compatible with all eight retained nominal JTAG traces,
  but their one-candidate policy cost is on average 2170 above their recorded
  full-search final cost. This is not sufficient reason to replace the board
  tolerance: keep behavioral and board evidence separate, and collect a
  multi-profile feedback data set before any policy-header promotion.
- The next policy objective is not another static confidence threshold. A
  behavioral regret predictor now uses the first polynomial candidate's visible
  waveform metadata and monitor-state ratios to estimate the cost reduction
  available from one bounded local-search round. In 12-profile LOSO, a direct
  decision requires predicted regret plus uncertainty at or below 100 cost
  units, a nearest normalized feature distance at or below 100000 ppm, and no
  clip/saturation. It directly accepts 36 of 288 modeled runs, saves 468 of
  4032 candidate evaluations, and each accepted run has actual regret no more
  than 98. This is a behavioral cost-control result, not an RF-quality or
  board-deployment result; keep the existing board policy unchanged.
- A C-friendly Q20 replay of that same regret predictor has now been applied
  offline to all eight retained JTAG full-calibration traces. Their nearest
  behavioral feature distances span 69688870 to 97544953 ppm, well beyond the
  100000-ppm in-distribution limit, so all eight select the 14-candidate local
  search branch. Removing only that distance protection would directly accept
  one trace whose retained one-candidate cost is 2577 above its full-search
  final cost. Keep the distance rejection. The historical 49-candidate traces
  cannot establish the cost of the 14-candidate branch; capture policy-only
  replay evidence before considering generated C constants.
- That measurement is now complete for all eight retained nominal waveform
  conditions. A test-only forced-policy build retained the existing static
  polynomial mode/package as the first candidate, then executed one bounded
  12-perturbation search plus final replay. Every JTAG trace contains exactly
  14 records with zero stall/error/clip/saturation. Relative to the measured
  one-candidate policy, final cost improves by 822 to 1473 (mean 1213.25).
  Relative to the retained 49-candidate calibration, the 14-candidate result
  saves 35 candidates per condition and has mean final-cost gap 957.12; the
  QAM64/BW40/backoff-0.58 case is only 77 above full search. This validates
  bounded fallback cost, not the behavioral regret predictor's direct path;
  do not generate or deploy regret predictor C constants.
- A DSM-aware host dataset builder now joins those eight measured bounded
  searches to their retained full-calibration traces. Every accepted row carries
  waveform/PA provenance, EFDSM build provenance, first-policy DPD coefficients,
  12 PL monitor values, and the policy, bounded-search, and full-search cost
  labels. Its measured bounded-search benefit is 822 to 1473 cost units (mean
  1213.25). This establishes a reproducible data contract for learning whether
  search is worthwhile, but the eight rows support only exploratory analysis.
- The current board set has exactly one DSM configuration: EFDSM 1-bit
  (`ALGORITHM=2`), `INTERP_MODE=0`, OSR 32. DSM fields are consequently
  constant, so it cannot yet determine whether joint DSM-plus-DPD selection
  improves over DPD-only selection. The next collection should hold waveform
  and PA metadata fixed while repeating policy/local/full traces for at least
  one additional DSM configuration. Keep the resulting analysis in PS/Python;
  no TinyML RTL or policy constants are justified yet.
- That second configuration is now board-measured: EFDSM2 1-bit
  (`ALGORITHM=3`) with the same bypass interpolation, OSR 32, DUC, DPD flow,
  waveform matrix, and nominal no-external-feedback provenance. Its ZU15EG
  implementation completed with `WNS=2.113 ns`, then produced eight complete
  49-candidate calibration traces and eight complete 14-record bounded-search
  traces with zero stall/error/clip/saturation.
- The combined 16-row data set permits the first paired DSM comparison. Across
  the eight matched waveform conditions, EFDSM2 minus EFDSM mean bounded-final
  proxy cost is `-998.38` and mean full-search-final proxy cost is `-1093.00`;
  negative means EFDSM2 is lower. EFDSM2 is lower on 4/8 bounded results, so
  the mean alone is not a selection rule. This is matched internal PL proxy
  evidence, not RF EVM/ACLR or PA-generalization evidence. Keep joint choice
  in offline analysis/PS software; add repeats and a third DSM configuration
  before fitting a joint policy or considering TinyML RTL.
- Repeat-aware manifests and paired statistics are now implemented. Each
  full/local pair is linked by the exact full-calibration trace path and each
  replicate retains its own `run_id`. The third-DSM gate requires three repeats
  per matched condition, 95% paired CI below zero for EFDSM2-minus-EFDSM proxy
  cost, and at least 75% EFDSM2 paired wins. The completed three-repeat board
  evidence remains correctly blocked: EFDSM2-minus-EFDSM mean local proxy cost
  is `-969.33`, its 95% paired CI is `-3457.07` to `1518.40`, and its paired
  win rate is 3/8 (37.5%).
- A joint DSM-plus-DPD waveform LOSO evaluator now uses waveform fields, DSM
  configuration, and first-candidate PL monitors to choose DSM, polynomial
  seed, and direct versus bounded-search action. It validates only actions
  whose selected seed matches a real held bounded trace. The remaining EFDSM2
  QAM16/BW40/backoff-0.58 action was replayed with its requested polynomial
  mode/package `1/0` seed (`0xFFF93FCD`, `0xF21A1EC1`, `0xDD023CA8`). Its safe
  14-record JTAG trace has final proxy cost `308660`, versus `305773` for the
  best fixed DSM. All 8/8 LOSO actions are now board-validated, but mean
  joint-minus-best-fixed cost is `1057.25`; joint selection is not beneficial
  and must remain out of deployment and TinyML RTL.
- LPDSM2 1-bit (`ALGORITHM=1`) is prepared as the third configuration, but its
  collection wrapper hard-blocks until the repeat gate passes. J1-only board
  collection is now validated, but LPDSM2 remains blocked by the failed paired
  stability criteria rather than JTAG availability.
- Keep policy selection and fallback in PS software until the feature set,
  fixed-point format, latency, area, and verification benefit justify a tiny-ML
  hardware block.
- The DPD-only AI software phase is complete. A 1728-row package-aware
  benchmark holds EFDSM 1-bit (`ALGORITHM=2`), OSR 32, and bypass interpolation
  fixed while varying PA/observation profile, waveform, random seed, and six
  Q2.14 seed packages. Strict grouped validation proves that one-candidate
  direct execution cannot meet the zero-violation criterion, so it is disabled.
- The final policy uses AI only where the evidence supports it: select a
  waveform-conditioned base coefficient set and seed offset, then always run
  one deterministic 14-candidate bounded search. A generated C LUT, A53
  execution mode, and J1 trace verify the complete software loop. Future work
  should add real RF feedback or broader modeled conditions; it should not
  reopen the direct path by merely relaxing thresholds.

Later tiny-ML extension:

```text
input power / peak / average magnitude / spectral proxy / temperature
  -> tiny regression or MLP
  -> predicted initial C1/C3/C5 or LUT package
  -> deterministic PS search refines the prediction
```

The tiny-ML block should first run in software. A hardware accelerator should
only be considered after the software-assisted loop is stable and the model has
a clear input feature set, output format, fixed-point quantization plan,
latency budget, area budget, and verification strategy.

Exit criteria:

- A baseline no-DPD case and an AI-assisted DPD case are compared under the same
  PA model and metric definitions.
- The coefficient update path is visible through AXI-Lite transactions.
- The project clearly separates simulated PA-model evidence from real RF lab
  measurement evidence.
- The calibration engine produces a candidate trace showing why a coefficient
  or LUT package was accepted or rejected.
- The selected calibration package is replayable on ZU15EG with matching
  input, DPD, frontend, and output counters.

### Phase 4: Hardware AI Accelerator Extension

Goal:

- Explore a small fixed-point inference block only after the deterministic DPD
  path is stable.

Candidate accelerators:

- Tiny MLP for coefficient prediction.
- Small regression engine for PA-model parameter estimation.
- Lightweight calibration search controller.

This phase is optional. It should be pursued only if the software-assisted
calibration loop is already working and the hardware accelerator has a clear
interface, latency, area, and verification story.

## Positioning

The project should be positioned as:

```text
Reusable digital TX IP with DSM modulation, interpolation frontend, AXI/DMA
integration, ZU15EG board smoke evidence, and an AI-assisted DPD/calibration
roadmap.
```

The strongest engineering value is the combination of:

- fixed-point communication modeling,
- synthesizable RTL datapath design,
- AXI-Lite and AXI-Stream integration,
- MATLAB/RTL bit-true verification,
- synthesis and board-level debug evidence,
- a realistic AI-assisted calibration path.

Avoid claiming real PA linearization or RF performance until an actual PA,
feedback receiver, reconstruction filter, and measurement setup are available.

# AI Communication IP Roadmap

Target platform:

- XCZU15EG MPSoC
- PL implementation and ILA-based observation
- no RF laboratory measurement chain assumed
- target role: digital IC design / verification engineer

## Recommended Direction

Build an AI-assisted communication TX calibration prototype. Do not replace the
high-speed datapath with AI.

The high-speed datapath should stay deterministic RTL:

```text
AXI-Stream source
  -> DPD frontend: bypass / polynomial / LUT
  -> interpolation/filter frontend
  -> DUC
  -> DSM / multibit DSM
  -> output monitor / ILA
```

The target MPSoC architecture is:

```text
PS bare-metal C first, optional PS Linux / Python later
  -> calibration / ML / optimization
  -> AXI-Lite writes DPD coefficients or LUT entries
  -> AXI DMA sends I/Q samples
  -> PL DPD + interpolation + DSM
```

The high-speed PL path remains deterministic and synthesizable. The AI or
optimization engine runs at a low control rate on PS first, then updates PL
parameters through AXI-Lite. This is practical on XCZU15EG because PS can host
the calibration loop while PL keeps the timing-critical datapath.

## Phase 1: Deterministic TX IP

Goal:

- make the communication TX datapath credible without AI

Tasks:

- finalize native metric definitions
- add interpolation/filter frontend
- keep single-bit DSM as verified baseline
- add MATLAB multibit DSM exploration
- expose AXI-Lite configuration/status registers
- verify with simulation, synthesis, and ILA-visible counters

Useful outputs:

- MATLAB vs RTL bit-true reports
- native EVM/SNDR/ACLR tables
- resource/timing reports on XCZU15EG and xc7z020

## Phase 2: On-Chip Metric Monitor

Goal:

- create hardware-visible evidence without RF lab instruments

Candidate monitors:

- sample counters
- clipping/saturation counters
- power estimator
- peak/RMS estimator
- rough PAPR estimator
- histogram of DSM output codes
- optional FFT/Goertzel bins for spectral proxy

These monitors are ILA-friendly and useful for digital IC interviews because
they show debuggability and observability.

Current implementation:

- `MON_INPUT_POWER`: accumulated input magnitude-power proxy
- `MON_OUTPUT_POWER`: accumulated RF output magnitude-power proxy
- `MON_CLIP_COUNT`: input near-full-scale clipping proxy count
- `MON_PEAK`: packed input/output peak magnitude
- `MON_AVG_MAG`: packed input/output EWMA average magnitude
- `MON_EVM_PROXY`: accumulated DPD correction-magnitude proxy
- `MON_ACPR_PROXY`: accumulated RF slew proxy
- `MON_SPEC_BIN0`: fixed-bin spectral proxy at DC/leakage
- `MON_SPEC_BIN1`: fixed-bin spectral proxy at the Fs/4 carrier bin
- `MON_SPEC_BIN2`: fixed-bin spectral proxy at Fs/2
- `MON_SPEC_ADJ`: adjacent/out-of-band proxy, `BIN0 + BIN2`

These are deliberately lightweight. They give the PS calibration loop hardware
feedback without adding a full FFT, receiver synchronizer, or RF reconstruction
model in PL. The spectral bins are multiplier-free fixed-bin accumulators, so
they are closer to Goertzel-style monitoring than a full FFT. A future monitor
can add configurable Goertzel bins or a small FFT if spectral ranking needs
more frequency resolution.

## Phase 3: Software/AI Calibration Loop

Goal:

- tune parameters automatically based on metrics

Parameters to tune:

- input drive level
- interpolation mode
- clipping threshold
- DSM algorithm
- multibit quantizer resolution
- optional FIR/compensation coefficients

Start with deterministic optimization:

```text
grid search -> coordinate descent -> Bayesian optimization
```

Then add a small AI model only if it improves the calibration loop.

## Phase 4: DPD Research Extension

Goal:

- connect this project to all-digital transmitter linearization

Recommended order:

1. memoryless PA model
2. memory polynomial PA model
3. conventional pre-DPD before DSM
4. DSM-embedded DPD feedback model
5. optional AI-assisted PA model or coefficient tuning

Do not put a neural network directly in the high-speed DSM loop first. It is
hard to close timing, hard to verify, and weak as a digital IC portfolio item
unless the deterministic baseline is already strong.

Current baseline:

- `matlab/dpd/run_dpd_memoryless_baseline.m` implements a MATLAB-only
  memoryless PA and indirect-learning polynomial DPD flow.
- `matlab/dpd/run_dpd_fixed_baseline.m` quantizes the learned DPD coefficients
  to signed Q2.14 and checks a Q1.15 integer datapath aligned with the first
  RTL DPD block.
- `rtl/dpd/dpd_poly.v` implements the first configurable polynomial DPD
  kernel.
- `rtl/dpd/dpd_frontend.v` wraps the DPD modes now used by the AXI wrapper:
  bypass, memoryless polynomial DPD, and amplitude-indexed LUT DPD. Mode 3 is
  reserved for future memory polynomial DPD.
- `matlab/dpd/run_ai_assisted_dpd_sweep.m` runs the first software
  optimization loop across multiple PA, input power, and OFDM/QAM scenarios.
  For polynomial DPD, it starts from an indirect-learning least-squares fit and
  then runs a fixed-point coordinate search directly over the quantized Q2.14
  `C1/C3/C5` coefficient words. The scalar loss combines EVM, SNDR, and ACLR
  target penalty. It emits fixed-point metrics plus AXI-Lite coefficient words
  for both optimized polynomial DPD and LUT DPD.
- `matlab/out/dpd/ai_assisted_dpd_coordinate_trace.csv` records the accepted
  and rejected coordinate-search candidates. This is the first explicit
  AI/optimization artifact in the project; it is deterministic optimization,
  not a neural-network accelerator.
- `fpga/zu15eg/ps_linux/dsm_dpd_ps_control.py` is the first PS-side Linux
  control helper. It writes polynomial or LUT DPD parameters through `/dev/mem`
  to the DSM IP AXI-Lite register map and reads status/counters.
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c` is the first Vitis
  standalone control application. It mirrors the XSDB board smoke in C using
  `Xil_In32`, `Xil_Out32`, and `XAxiDma`. It now runs the first PS-side
  calibration search loop: iterate exported polynomial/LUT DPD packages, run
  the DMA/datapath for each package, combine MATLAB proxy EVM/SNDR with
  hardware saturation/clipping/stall/error/correction/slew proxy penalties,
  spectral adjacent-bin penalties, use the best polynomial package as a seed,
  perturb Q2.14 `C1/C3/C5`
  coefficient words, accept lower-cost candidates, and leave the selected DPD
  configuration programmed in PL registers. After applying the selected
  configuration, the app re-runs the stream so final counters reflect the
  retained configuration rather than an intermediate search candidate.
- `matlab/dpd/export_dpd_coeff_header.m` exports MATLAB calibration output to
  `fpga/zu15eg/baremetal/src/dpd_coeffs.h`, allowing a bare-metal app to load
  AI-assisted DPD coefficient packages and proxy scores without Linux.
- `docs/AI_ASSISTED_DPD_RESULTS.md` summarizes the current memoryless PA,
  memory-PA observation, RTL, and board-control evidence.
- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m` is the current
  observation-receiver reference model. It applies a memory polynomial PA,
  frequency response, gain/phase drift, observation noise, RF band-pass and
  downconversion/recovery before computing native and RF-recovered
  EVM/SNDR/ACLR-style metrics.
- The baseline trains 1st/3rd/5th-order DPD coefficients and compares PA-only
  versus DPD-plus-PA EVM/SNDR/ACLR.
- The ZU15EG board smoke has verified PS/JTAG AXI-Lite DPD coefficient
  readback, AXI DMA I/Q streaming, DPD sample counting, frontend/output
  counting, and zero sticky error for the 4096-sample P0 transfer.
- The rebuilt ZU15EG bitstream has also verified LUT DPD mode with AXI-Lite
  LUT entry write/readback, `DPD_CTRL=2`, 4096-sample DMA streaming, matching
  DPD/frontend/output counters, and zero sticky error.
- The PS-side bare-metal calibration loop has been rebuilt and run on the
  ZU15EG board after the DPD pipeline update. The latest full regression
  rebuilt the bitstream and ELF, selected LUT DPD mode
  (`DPD_CTRL=0x00000002`) after package evaluation, and completed with matching
  4096-sample input/frontend/DPD/output counters, zero stalls, zero sticky
  errors, and zero DPD saturation.
- The next calibration-engine revision is now implemented in the bare-metal
  source: cost weights and search limits can be overridden at build time,
  package/search candidates emit CSV-style `CAL_TRACE` accept/reject records,
  the polynomial search is multi-round coarse-to-fine, and the selected result
  can be replayed through a replay-only ELF build or captured as a final XSDB
  CSV counter snapshot.
- The host-side post-processing path now has a calibration trace parser and a
  deterministic DPD seed-table generator. The parser converts captured
  `CAL_TRACE` / `CAL_SELECTED_REPLAY` text into CSV and Markdown summaries.
  The seed generator combines MATLAB DPD sweep rows with the latest board
  replay counters to produce a software lookup/nearest-neighbor seed artifact
  for the next PS-side run. Its optional generated C header is now consumed by
  the bare-metal app: the seed is measured on PL first and then competes with
  every exported package and coordinate-search candidate under the same cost.
  The first adaptive-seed ELF has completed a ZU15EG board regression with
  matching 4096-sample counters and zero stall/error/saturation. Candidate-level
  evidence is now available without UART: the A53 app publishes a cache-flushed
  binary trace buffer and XSDB exports it through J2 using the symbol address
  from the exact ELF. The first JTAG-only capture contains 50 records covering
  the software seed, package ranking, three-round coordinate search, and final
  replay selection.
- The first trace-aware predictor is now implemented as a conservative weighted
  k-NN mode/package policy over comparable board package costs. For the retained
  16-QAM, 48-subcarrier, 0.58-backoff trace, it selected LUT package 3. A
  J2-only one-candidate policy replay measured the same `3003709` cost as the
  50-candidate full calibration, reducing the measured candidate count from 50
  to 1. This is same-scenario reproduction, not unseen-scenario generalization.
- The next software-validation step is defined as a multi-scenario trace set:
  each full calibration trace must retain PA profile/strength, QAM, occupied
  bandwidth, used-subcarrier count, input backoff, deterministic waveform ID,
  calibration-cost profile, and run ID. The host evaluator holds every
  replicate of one `scenario_id` out before selecting a mode/package, reports
  action availability, package regret, candidate reduction, and aggregate
  coverage. It must report insufficient coverage rather than extrapolate from
  the current single-condition trace.
- The bare-metal build can now embed a deterministic Q1.15 QAM-OFDM DMA
  waveform whose QAM, used-subcarrier count, backoff, FFT size, and seed are
  recorded in its generated header. This makes waveform dimensions real board
  inputs instead of manifest-only labels. PA strength still requires a
  controlled PA/emulator and feedback observation chain; internal PL monitor
  proxies cannot establish RF PA generalization.
- J2 board collection now has one real eight-condition waveform trace matrix:
  QAM16/QAM64, 20/40 MHz occupied bandwidth, and 0.58/0.70 input backoff.
  Each run retained 49 candidate records with complete/no-overflow status.
  In strict leave-one-scenario-out evaluation, the weighted k-NN package
  action matched the held package optimum in 6/8 runs; mean package regret was
  `181.5` monitor-cost units and the offline candidate reduction was 49 to 1.
  This is evidence for waveform-condition selection only because all captures
  used one nominal, no-external-feedback PA profile.
- The offline-to-board step is now closed for the matrix's worst LOSO regret
  case. `board_nominal_qam64_bw40_bo58` was excluded from training, the
  manifest-aware policy used the other seven scenarios (84 package rows), and
  a J1-only policy ELF measured one mode 1/package 3 candidate at cost
  `296375`. This exactly reproduced the held trace's package-action cost while
  reducing execution from 49 candidates to 1. The next policy work is cost
  calibration/uncertainty gating: the weighted prediction was `333170`, so a
  confidence threshold should fall back to a short local search when nearest
  scenario distance or predicted-cost uncertainty is high.
- That confidence-gated fallback is now implemented and board-validated. The
  generated policy header carries nearest-distance and weighted cost-dispersion
  metrics plus thresholds. The normal `0.20` distance / `10%` dispersion gate
  chooses the one-candidate path; a test threshold of `0.10` forces one local
  coordinate round. The forced fallback produced 14 records and cost `294902`,
  only `77` above the retained 49-candidate full search while reducing the
  candidate count by 35.
- Runtime safety fallback is now implemented after the first policy
  measurement. It combines absolute predicted-cost residual with nonzero
  stall, sticky error, or saturation. J1 accepted `110439 ppm` under the
  default `150000 ppm` limit; lowering only that limit to `100000 ppm` forced
  the 14-record search and retained cost `294902`. The next upgrade is
  threshold calibration with repeated runs and a controlled second PA/feedback
  condition.
- Simulation-only PA robustness now exercises gain, saturation, memory taps,
  observation noise, and gain/phase drift. The 63-run leave-one-profile study
  found the current distance/dispersion/residual gate non-separable, so the
  next work is monitor-feature-based confidence prediction rather than adopting
  broad simulation ppm limits.
- The first monitor-feature confidence path is now implemented: selected-action
  trace centers cover input/output power, peak/average magnitude, EVM/ACPR and
  spectral proxies, clip, and saturation. A post-replay state distance can
  trigger the bounded search. The next upgrade is to generate corresponding
  proxy features in the behavioral PA sweep and validate their held-profile
  separation before tuning this new gate.
- The AXI wrapper now exposes PL monitor metrics to the same PS-side
  calibration loop. Package ranking can combine MATLAB proxy scores with
  hardware saturation, clipping, stall, sticky error, correction-magnitude,
  and RF-slew proxy penalties.
- This is not tied to a real PA device. It is a controlled software reference
  for the later configurable DPD RTL frontend.
- The first run shows large EVM/SNDR improvement and only small ACLR movement,
  which is expected for this simple memoryless PA and DPD model. Stronger ACLR
  work should add memory effects, a more realistic PA model, and a clearer RF
  observation path.
- The current "AI" boundary is a calibration architecture plus deterministic
  optimization loops: MATLAB models the PA/observation receiver and searches
  coefficients against EVM/SNDR/ACLR-style metrics, while the ZU15EG PS
  bare-metal app searches fixed-point coefficient words using PL monitor
  counters. This is a valid first AI-assisted calibration step, but it is not
  yet a neural-network PA model and it does not yet use real measured EVM/SNDR
  feedback from an RF observation receiver. The new seed table is a
  tiny-ML-ready software lookup artifact, not a trained neural model. A tiny
  hardware ML accelerator is still future work and should not replace the
  high-speed datapath.

Current software calibration trend:

- Pure DSM does not correct the behavioral PA nonlinearity.
- Optimized polynomial DPD gives the strongest improvement in the current
  memoryless PA sweep. For the nominal 16-QAM, 48-subcarrier, 0.58 backoff
  case, EVM improves from about `3.04%` to `0.082%`, and SNDR improves from
  about `30.34 dB` to `61.74 dB`.
- LUT DPD also improves the same case, but less strongly with the current
  16-bin amplitude-indexed table: EVM improves from about `3.04%` to `1.30%`,
  and SNDR improves from about `30.34 dB` to `37.70 dB`.
- ACLR improvement is currently small because the model is memoryless and the
  observation chain is simplified. Strong ACLR claims require a memory-effect
  PA model, an RF observation path, and a clearer reconstruction/downconversion
  assumption.
- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m` now adds a more realistic
  diagnostic PA/observation model: memory-polynomial PA taps, soft saturation,
  linear frequency response, gain/phase drift, observation noise, optimized
  fixed-point polynomial DPD, LUT DPD, and an assumed RF-observation receiver.
  It evaluates native complex-baseband metrics and RF-recovered metrics
  separately after Fs/4 upconversion, ideal RF band-pass filtering,
  downconversion, ideal low-pass reconstruction, and gain/delay alignment.
- In the more realistic memory-PA diagnostic sweep, optimized polynomial DPD
  still improves native EVM/SNDR, but the improvement is no longer unrealistically
  perfect. For the nominal 16-QAM, 48-subcarrier, 0.58-backoff case, native EVM
  improves from about `4.76%` to `3.19%`, and native SNDR improves from about
  `26.45 dB` to `29.94 dB`. RF-recovered EVM improves from about `7.25%` to
  `6.55%` under the current assumed observation chain.
- The 64-QAM, 96-subcarrier case intentionally exposes a system limitation:
  RF-recovered EVM remains poor because the assumed observation filters are too
  narrow for the occupied bandwidth. This is a useful diagnostic result and
  should not be interpreted as a DSM-core failure.

Current ZU15EG DPD smoke snapshot:

```text
DSM_BASE = 0xA0010000
DMA_BASE = 0xA0020000
DPD_C1   = 0xFFFB4009
DPD_C3   = 0xF1A41F6F
DPD_C5   = 0xDE503A39

INPUT_SAMPLE_COUNT    = 0x00001000
FRONTEND_SAMPLE_COUNT = 0x00001000
DPD_SAMPLE_COUNT      = 0x00001000
OUTPUT_SAMPLE_COUNT   = 0x00001000
INPUT_STALL_COUNT     = 0x00000000
ERROR_STATUS          = 0x00000000
```

## Portfolio Positioning

The strongest story is:

```text
Reusable communication TX digital IP with DSM, interpolation, AXI integration,
verification, synthesis evidence, and an AI-assisted calibration roadmap.
```

This demonstrates:

- RTL datapath design
- fixed-point MATLAB modeling
- AXI/IP wrapper design
- verification planning
- hardware debug strategy
- communication-system awareness
- practical AI acceleration integration without overclaiming

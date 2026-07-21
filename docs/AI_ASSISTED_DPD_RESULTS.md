# AI-Assisted DPD Results

Generated: 2026-07-15 16:47:36 +08:00

## Architecture

The current AI-assisted DPD prototype keeps the high-speed PL datapath
deterministic:

```text
AXI-Stream I/Q
  -> DPD frontend: bypass / polynomial / LUT
  -> interpolation frontend
  -> DSM
```

The calibration path is low-rate:

```text
MATLAB / PS software
  -> estimate or optimize polynomial coefficients or LUT entries
  -> export fixed-point coefficient package
  -> PS bare-metal C writes AXI-Lite registers
  -> AXI DMA sends I/Q samples
  -> PL counters feed a PS-side package/coordinate-search cost
```

This is "AI-assisted" in the calibration sense: the current implementation uses
deterministic optimization rather than a neural network. The PL hardware remains
fixed-point and verifiable while software searches or selects DPD parameters.

## Memoryless PA Sweep

Source:

- `matlab/dpd/run_ai_assisted_dpd_sweep.m`
- `matlab/out/dpd/ai_assisted_dpd_sweep.csv`

| Scenario | No DPD EVM % | Optimized Poly DPD EVM % | LUT DPD EVM % | No DPD SNDR dB | Optimized Poly DPD SNDR dB | LUT DPD SNDR dB |
|---|---:|---:|---:|---:|---:|---:|
| `pa_nominal_16qam_48sc_bo058` | 3.040391 | 0.081853 | 1.302691 | 30.341411 | 61.739314 | 37.703172 |
| `pa_nominal_16qam_48sc_bo070` | 3.704749 | 0.978348 | 1.688236 | 28.624824 | 40.190134 | 35.451335 |
| `pa_strong_16qam_48sc_bo058` | 4.356938 | 0.567147 | 2.144266 | 27.216372 | 44.926089 | 33.374428 |
| `pa_weak_16qam_48sc_bo058` | 2.000650 | 0.021582 | 0.777204 | 33.976577 | 73.318193 | 42.189302 |
| `pa_nominal_64qam_48sc_bo058` | 3.421048 | 0.097319 | 1.486048 | 29.316817 | 60.236022 | 36.559344 |
| `pa_nominal_16qam_96sc_bo052` | 2.462867 | 0.042227 | 1.129800 | 32.171181 | 67.488269 | 38.939968 |

Observations:

- Optimized polynomial DPD is currently strongest for the memoryless PA model.
- LUT DPD also improves EVM/SNDR, but the current 16-bin amplitude LUT is less
  accurate than the 1st/3rd/5th-order polynomial fit.
- ACLR movement is small in this memoryless model; strong ACLR conclusions
  require PA memory effects and a defined observation chain.

## Memory-PA Observation Sweep

Source:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/out/dpd/dpd_memory_pa_observation_sweep.csv`

The current sweep adds memory polynomial taps, soft saturation, linear
frequency response, gain/phase drift, and observation noise. This makes the DPD
improvement intentionally less ideal than the memoryless baseline.

| Scenario | Native no-DPD EVM % | Native optimized poly EVM % | Native LUT EVM % | RF no-DPD EVM % | RF optimized poly EVM % | RF LUT EVM % | Native no-DPD SNDR dB | Native optimized poly SNDR dB | RF no-DPD SNDR dB | RF optimized poly SNDR dB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `memory_pa_nominal_16qam_48sc_bo058` | 4.759378 | 3.185087 | 3.517158 | 7.252074 | 6.553810 | 6.658199 | 26.448995 | 29.937574 | 22.790755 | 23.670123 |
| `memory_pa_strong_16qam_48sc_bo058` | 6.307312 | 3.993049 | 4.531050 | 9.635675 | 8.638933 | 8.835218 | 24.003114 | 27.973907 | 20.322357 | 21.270798 |
| `memory_pa_nominal_64qam_96sc_bo052` | 6.636180 | 6.005271 | 6.117887 | 61.377822 | 61.343121 | 61.347450 | 23.561637 | 24.429348 | 4.239770 | 4.244683 |

Observations:

- Native complex-baseband metrics still improve with optimized polynomial DPD.
- LUT DPD also improves the native EVM/SNDR in this sweep, but the 16-bin LUT
  is weaker than optimized polynomial DPD.
- RF-recovered metrics are sensitive to the assumed RF band-pass and
  downconversion/reconstruction filters.
- The 96-subcarrier case is intentionally a diagnostic warning: the current
  RF observation assumptions are too narrow for that occupied bandwidth.

## Held-Out Memory-Polynomial Training Comparison

Source:

- `matlab/dpd/run_dpd_memory_poly_training_comparison.m`
- `matlab/out/dpd/dpd_memory_poly_comparison.md`
- `matlab/out/dpd/dpd_memory_poly_coefficients.csv`
- `docs/evidence/dpd/memory_poly_q214_20260715.csv`

The comparison uses one fixed behavioral PA for every path: three nonlinear
memory taps, soft saturation, a three-tap linear FIR, gain/phase drift, and
43 dB observation SNR. Fit seed 101, validation seed 137, and test seeds
211/223/239 are disjoint. For each test seed, no DPD, memoryless DPD, and
memory-polynomial DPD share the same PA parameters and observation-noise
realization. Both trained models use Q1.15 samples and Q2.14 coefficients.

| Mode | Mean EVM % | Mean NMSE dB | Mean SNDR dB | Mean ACLR dBc | DPD saturation | Drive limited |
|---|---:|---:|---:|---:|---:|---:|
| No DPD | 4.305013 | -27.326263 | 27.326263 | -32.159925 | 0 | 0 |
| Memoryless DPD | 3.117541 | -30.123855 | 30.123855 | -32.557627 | 0 | 0 |
| 4-tap memory-polynomial DPD, joint-safe | 2.827825 | -30.971072 | 30.971072 | -32.507411 | 0 | 0 |

The earlier EVM-only fit reached `1.897744%` mean EVM but was 0.37 dB worse in
ACLR than memoryless DPD. It is retained as exploratory evidence, not the
recommended package. The current trainer treats memoryless ACLR plus 0.05 dB as
a hard validation boundary and rejects saturation, drive limiting, and peak
violations. The selected joint-safe package improves EVM by 34.31% versus no
DPD and 9.29% versus memoryless DPD while remaining within 0.05 dB of the
memoryless ACLR on the validation set. Across the three independent test seeds,
the mean difference is 0.0502 dB; the largest per-seed difference is 0.0519 dB.

## Behavioral Observation Closed Loop

MATLAB now exports a Q1.15 TX reference and behavioral-PA feedback window plus
software-estimated delay and Q2.14 complex gain. XSim sends that feedback into
`dpd_observer`. The retained run used delay 3 and gain `(18239, -381)`, and RTL
matched MATLAB exactly: 63 pairs, one deliberately invalid/drop sample, 64-bit
L1 error `92046`, completed window, and observed `tlast`.

## Historical v1 Software TinyML Competition

The historical `behavioral_pa_observation_v1` candidate data set has 1728
rows: 12 PA profiles, eight QAM/bandwidth/
backoff waveforms, three random seeds, and six signed-Q2.14 memory-strength
packages. Strict leave-one-PA-profile evaluation compares the waveform LUT,
ridge-linear classifier, depth-4 decision tree, weighted k-NN, and 8-hidden-unit
MLP. Every model uses the same runtime metadata, monitor ratios, observation
error, confidence/distance gate, and zero-neighbor-violation release rule.

| Model | Direct | Fallback | Safety violations | Mean regret | Mean candidates | Non-worse PA folds | Strictly better PA folds |
|---|---:|---:|---:|---:|---:|---:|---:|
| LUT | 140 | 148 | 0 | 127.521 | 7.681 | baseline | baseline |
| Linear | 0 | 288 | 0 | 0.000 | 14.000 | 1/12 | 0/12 |
| Decision tree | 148 | 140 | 0 | 0.000 | 7.319 | 12/12 | 9/12 |
| k-NN | 148 | 140 | 0 | 0.000 | 7.319 | 12/12 | 9/12 |
| MLP | 107 | 181 | 0 | 0.000 | 9.170 | 3/12 | 0/12 |

Under that historical schema, the decision tree and k-NN satisfy the software
promotion rule: zero violations among released direct decisions in all 12
folds, no candidate or regret regression in any fold, and strict improvement
in nine folds. The decision tree is the preferred RTL-evaluation candidate
because it maps to comparisons and thresholds. These results do not authorize
deployment and are not numerically interchangeable with the exact
`aligned_complex_pa_monitor_v2` observer contract.

## Exact Observer-v2 TinyML Results

The behavioral generator now implements the exact finite-width arithmetic of
`aligned_complex_pa_monitor_v2`: Q2.14 complex-gain alignment, arithmetic
shift, Q1.15 saturation, signed absolute-value corner handling, 32-bit
accumulator wrap, complex slew, and DC/Fs/4/Fs/2 fixed-bin proxies. It emits
1728 package rows for 288 conditions and retains 288 raw complex-feedback
traces containing 497,664 Q1.15 complex samples. The only accepted schema is
`aligned_complex_pa_monitor_v2`; the training code rejects mixed or stale
schemas.

Strict fixed-point PA-profile LOSO retrains and quantizes inside every fold. A
standalone tree releases 121 direct suggestions and requests 167 fallbacks,
with zero safety violations, zero mean regret, and mean candidate count
`8.538`. It is non-worse than the LUT in only 2/12 folds and is therefore
rejected as an independent policy. The hierarchical tree-then-LUT policy makes
186 direct suggestions and 102 fallbacks, with zero safety violations, mean
regret `408.861`, and mean candidate count `5.604`. It is non-worse than the
LUT in 12/12 folds and strictly better in 5/12, so it is qualified only as a
software hierarchy whose final fallback remains the 14-candidate search.

A deterministic full-data depth-4 model is frozen separately as version
`0x00020000`. Its 13 signed-Q12.20 features are learned only after Q12.20
visibility reduction, and exported thresholds preserve the quantized
partitions. Inclusive domain bounds and conservative leaf qualification force
fallback for invalid, out-of-distribution, mixed, or unsafe leaves. The fit
produces 154 direct suggestions and 134 fallbacks with zero training safety
violations, zero training regret, and zero float/fixed path mismatches. These
are fitting results, not LOSO claims.

Python, host C, and standalone RTL match package, action, path, path length, and
OOD status on all 329 condition and boundary vectors. The C raw-feature builder
also matches Python on all 288 conditions. Independent raw complex-feedback
replay reconstructs all 288 MATLAB monitor records exactly. It observes 154
direct tree suggestions with zero labeled safety violations and zero mean or
maximum regret, plus 134 tree fallbacks.

Replay does not enable direct execution. Every replay row records deployment
action `fallback_14`; `dpd_tinyml_tree` remains uninstantiated in the AXI
wrapper, and the bare-metal application continues to report `direct=0` and
`local_candidates=14`. The evidence is behavioral simulation, not physical-PA
RF validation or an RF safety certification.

## Isolated Blind PA Result

Three new behavioral PA profiles were held out from fitting, threshold choice,
and model selection. They jointly vary gain, compression, memory length,
observation noise, and thermal gain/phase drift. Their 72 conditions and 432
candidate rows use the same exact `aligned_complex_pa_monitor_v2` arithmetic,
but are not part of the frozen model's 288-condition training matrix.

The frozen tree followed by the training-waveform LUT produced 19 unsafe seed
packages before the mandatory local search: 5/24 for
`blind_compression_noise`, 5/24 for `blind_gain_memory`, and 9/24 for
`blind_thermal_memory`. Tree/LUT/default seed sources were 30/33/9. This is a
failed promotion gate, not a reason to widen bounds or relax safety checks.

## Safety-First Seed Policy

The replacement policy changes the prediction target from lowest expected
package cost to seed safety under an unknown behavioral PA. The three
`blind_*` profiles remain permanent final-test data and are excluded from
fitting, threshold selection, and model selection. Eight separate
`dev_*` profiles provide the development-only selection set.

For a requested waveform and monitor state, each package first requires all
seven nearest same-waveform nonblind observations to be safe, and the nearest
monitor state must be inside the finite selected distance bound. If no package
qualifies, the policy returns `fallback_14`. Expected cost ranks packages only
after this safety qualification. The selected `k=7`, distance-`4.0` setting was
chosen solely by development PA LOSO: it selected 129 safe seeds and 63
fallbacks across 192 conditions, with zero unsafe seeds. Without changing the selected setting, the
frozen 72-condition blind final test selected 49 safe seeds and 23 fallbacks,
again with zero unsafe seeds. All actions still run the existing bounded
14-candidate local search; no one-candidate direct path is enabled.

This is an offline behavioral result, not a physical-PA/RF certification. The
legacy tree/LUT PS policy remains blocked because it is a different policy with
19 blind violations. A separately generated safety-first PS-C implementation,
Python/C equivalence, and trace replay are required before board enablement.

The required PS-C preparation is now complete. The generated fixed-point
selector contains 480 evidence conditions from the base and development sets,
with no blind record. It uses Q12.20 monitor features, `k=7`, and a Q12.20
distance cap of `4.0`; host C agrees with Python on all 552 nonblind-plus-blind
vectors, and the quantized policy retains all 72 frozen-blind decisions. The
A53 source also compiles with warnings treated as errors. It remains disabled
for board use until the bare-metal integration and completed-observer trace
replay are separately reviewed.

The PS implementation can build the observer-v2 tree -> LUT ->
memory-polynomial-search interface, but its generated policy header sets
`DPD_TINYML_HIERARCHY_POLICY_AVAILABLE=0` from this evidence. The board cannot
enable it, and no one-candidate operation is introduced. The reusable
comparison report is `docs/evidence/dpd/ai_calibration_comparison_20260717.md`:
it keeps DPD EVM/ACLR linearization results separate from AI seed/search safety
results.

## RTL and Board-Control Evidence

Implemented control paths:

- `rtl/dpd/dpd_frontend.v`: bypass, memoryless polynomial, LUT, and 2-to-4-tap
  memory-polynomial DPD.
- `rtl/dpd/dpd_lut.v`: double-buffered LUT DPD table with commit-based active
  bank switching.
- `rtl/axi/dsm_ip_axi_top.v`: AXI-Lite DPD registers and AXI-Stream datapath.
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`: Vitis standalone
  calibration smoke that iterates exported DPD packages, searches around the
  best polynomial seed by perturbing Q2.14 `C1/C3/C5`, checks counters, and
  leaves the lowest-cost DPD configuration in PL registers.
- `matlab/dpd/export_dpd_coeff_header.m`: exports multi-package C headers for
  PS bare-metal experiments.

Checks run:

- DPD MATLAB/RTL bit-true compare: 256 samples, 0 mismatches.
- DSM IP AXI smoke: passed.
- Vivado IP packaging: passed.
- ZU15EG bare-metal calibration demo: passed after bitstream programming,
  PS init, ELF launch, and post-run JTAG counter check.
- ZU15EG PS-side search-loop build: passed. The updated ELF compiles with the
  coordinate-search loop and final selected-configuration stream rerun.
- ZU15EG PS-side search-loop board rerun: blocked after one successful ELF
  launch by an unstable JTAG/DAP session during a later `dow` command
  (`Invalid DAP ACK value: 3`). This is a board/debug-link issue, not a C build
  failure. Reconnect or power-cycle the JTAG path before rerunning the board
  counter check.

## Current Limits

- The package-aware benchmark is complete: 1728 behavioral records cover 12
  PA/observation profiles, eight QAM/bandwidth/backoff waveforms, three random
  seeds, and six deterministic Q2.14 seed packages. Strict profile, waveform,
  and random-seed holdouts show that every non-empty one-candidate direct
  region has regret or modeled-EVM violations, even after requiring five safe
  monitor-state neighbors. Direct execution is therefore disabled in the
  final policy instead of being promoted through a looser threshold.
- The qualified AI function is seed selection followed by mandatory
  14-candidate bounded search. Compared with bounded search from fixed package
  3, its mean final-cost change is `-89.69`, `-53.51`, and `-89.69` for held
  profile, waveform, and random-seed validation; negative is better. It wins
  250/288, 160/288, and 250/288 decisions respectively, with no new modeled
  EVM/ACLR failure and no clip/saturation. A generated eight-waveform C LUT is
  integrated into the A53 application. J1 replay for QAM16/BW40/backoff-0.58
  selected package 2, improved PL proxy cost from `321062` to `311350` through
  exactly 14 records, and reported zero stall/error/clip/saturation. This is
  simulation qualification plus PL-monitor board evidence, not measured RF.
- No real PA feedback path has been measured on the board.
- The 2026-07-12 JTAG trace matrix contains eight complete full-calibration
  board runs across QAM16/QAM64, 20/40 MHz occupied bandwidth, and 0.58/0.70
  input backoff. The strict leave-one-scenario-out package policy selected the
  held trace's best package in 6/8 cases, with mean package regret `181.5`
  monitor-cost units and a 49-to-1 candidate reduction. These are PL monitor
  proxy results, not RF EVM/ACLR results.
- All eight traces use the single `nominal_no_external_feedback` PA profile.
  The PA-strength dimension is therefore not covered; no conclusion about
  unknown PA strength, PA device variation, or RF generalization is valid.
- The worst nonzero-regret LOSO case, `board_nominal_qam64_bw40_bo58`, has now
  been replayed on ZU15EG with its own trace excluded from policy training.
  The 84 training package observations selected polynomial mode/package 3.
  The J1-only board run evaluated one candidate and measured cost `296375`,
  exactly matching that action in the retained held-out full trace. This is a
  measured 49-to-1 candidate reduction. Cost was `1064` above the held trace's
  best package (`295311`) and `1550` above its coordinate-search final cost
  (`294825`). The weighted prediction `333170` was conservative by `36795`, so
  action selection is validated here but absolute cost calibration still needs
  improvement.
- Confidence/uncertainty gating is now implemented for that policy. The default
  gate accepts nearest distance `0.171429` against a `0.20` limit and relative
  selected-action cost standard deviation `5.3282%` against a `10%` limit, so
  the direct path retains the one-candidate result `296375`. Tightening only
  the distance limit to `0.10` forces a bounded one-round local search: 1
  policy candidate, 12 coefficient perturbations, and 1 final replay. The
  resulting cost is `294902`, reducing the direct policy gap by `1473` and
  finishing only `77` above the 49-candidate full-search final cost `294825`.
  All fallback counters remain clean and the JTAG trace is complete with 14
  records and no overflow.
- A post-measurement runtime guard is also board-validated. It computes the
  absolute measured/predicted cost residual with 64-bit integer arithmetic and
  combines it with stall, sticky error, and saturation. The measured residual
  was `110439 ppm`: the default `150000 ppm` limit retained the one-record
  direct path, while a test `100000 ppm` limit forced the 14-record search with
  `reason=cost_residual` and final cost `294902`. Both runs had zero safety
  counters. A second controlled PA/feedback condition is still required to
  calibrate these thresholds.
- A simulation-only threshold exercise now supplies that second PA condition
  through the existing MATLAB memory-PA and observation-receiver model. Three
  seeds cover nominal `0 dB` and strong `+6 dB` PA conditions plus a 64-QAM
  wideband diagnostic case. With simulated RF-recovered EVM limited to `8%`
  and ACLR to `-20 dBc`, 4 of 9 records fail. Leave-one-scenario policy
  features can retain the 3 nominal passing records while rejecting all 4
  failures with distance `1000000 ppm`, dispersion `941856 ppm`, and residual
  `746780 ppm`. These broad values are simulation-only fallback evidence and
  have not replaced the board policy's `15%` engineering default.
- The expanded robustness sweep varies PA gain, saturation, memory length,
  observation noise, and gain/phase drift across 12 profiles, three seeds,
  and eight QAM/bandwidth/backoff waveform combinations (`288` records).
  It contains `198` modeled passing and `90` modeled failing records at the
  documented EVM/ACLR limits. Its least-risk distance/dispersion/residual gate
  is now highly conservative: across leave-one-profile splits it accepts no
  failing held record but only two passing held records. This remains
  behavioral evidence, not a deployable ppm threshold.
- That monitor-state feature path is now implemented on the board policy. The
  generated reference includes input/output power, peak, average magnitude,
  EVM/ACPR proxies, spectral bins, clip, and saturation. A new J1 policy-only
  replay retained its one-record direct path: monitor distance was `252573 ppm`
  against the nominal-trace-derived `792666 ppm` limit, at cost `296375` with
  zero stall/error/clip/saturation. This verifies feature collection and the
  runtime decision path; its nominal-only training set cannot yet validate
  unknown-PA discrimination.
- The behavioral memory-PA sweep emits the twelve identically named
  monitor-state fields and creates a weighted, scale-robust leave-one-profile
  CSV. The weighted features emphasize gain, peak/average shape, correction,
  spectral ratios, clip, and saturation. Input-side arithmetic follows PL
  Q1.15 magnitude/correction semantics; output-side fields are behavioral
  post-PA observation proxies, not DSM RTL bit-true values. In the 12-profile
  LOSO, both the legacy and weighted-monitor gates accept zero failing held
  records and two passing held records. Offline replay of the minimum
  simulation threshold accepts all eight retained nominal JTAG traces, but
  their one-candidate cost averages `2170` above recorded full-search final
  cost. The candidate gate therefore is not copied into the board header.
- The current behavioral optimization objective is first-candidate regret:
  `initial polynomial cost - one-round local-search cost`. A five-neighbor,
  scale-normalized predictor sees first-candidate waveform metadata and monitor
  ratios only. Held PA-profile LOSO permits direct execution only when its
  predicted regret plus weighted-neighbor uncertainty is at most 100 cost
  units, nearest feature distance is at most 100000 ppm, and clip/saturation
  are zero. It accepts 36/288 modeled runs, reducing the candidate model from
  4032 to 3564; direct actual regret averages 26.61 and peaks at 98. Some
  direct modeled runs still fail the simulated RF feedback threshold, so regret
  control is not an RF pass/fail decision and cannot replace external feedback.
  It is not deployed to `dpd_trace_policy.h`.
- The matching Q20 Python offline replay against the eight retained JTAG
  traces selects local search for all eight. Their behavioral nearest-feature
  distances are 69.69M to 97.54M ppm, far outside the 100000-ppm simulation
  in-distribution limit. A diagnostic run without that distance rejection
  directly accepts one trace at a retained cost delta of 2577 to full search,
  confirming that simulation-to-board feature mismatch must force fallback.
  The recorded traces contain 49-candidate calibrations, not a measured
  14-candidate policy branch, so each local-search decision remains marked for
  a future policy-only board replay.
- The planned policy-only board replay is complete for all eight retained
  nominal waveform traces. A test-only forced local-search build keeps static
  polynomial mode/package 3 as the first candidate and executes 12 coefficient
  perturbations plus the final replay. All eight JTAG captures have exactly
  14 records and zero stall/error/clip/saturation. The measured final cost
  improves over the one-candidate policy by 822 to 1473 (mean 1213.25), while
  using 14 rather than 49 candidates. The mean gap to the retained full-search
  final cost is 957.12; one condition is within 77. This validates the bounded
  fallback branch, but not a simulation-regret direct decision or RF quality.
- A host-side DSM-aware dataset builder now joins each measured policy/local
  trace to its retained full-calibration trace. The eight rows include waveform
  and PA provenance, DSM build metadata, first-policy DPD coefficients, all 12
  visible PL monitor values, and `policy_cost`, `local_search_final_cost`,
  `full_search_final_cost`, and `search_benefit` labels. Its feature report is
  deliberately exploratory: the largest absolute Pearson correlation is
  `MON_SPEC_BIN1` at 0.601165, but eight rows are not sufficient to rank a
  deployable predictor or infer causality.
- All eight dataset rows use EFDSM 1-bit (`ALGORITHM=2`), `INTERP_MODE=0`, and
  OSR 32. No DSM field varies, so the data cannot test whether joint DSM-plus-
  DPD selection beats DPD-only selection. The next valid experiment repeats
  matched waveform/PA conditions under at least one alternate DSM build and
  retains the same one-policy, bounded-14, and full-49 cost labels.
- The matched alternate build is now complete: EFDSM2 1-bit (`ALGORITHM=3`),
  `INTERP_MODE=0`, and OSR 32. It contributes eight full-calibration and eight
  14-record bounded-search traces, all with zero stall/error/clip/saturation.
  The 16-row combined data set has two DSM configurations and a paired result:
  EFDSM2 minus EFDSM mean bounded-final proxy cost is `-998.38`, and mean
  full-search-final proxy cost is `-1093.00`, across the eight matched waveform
  rows. EFDSM2 is lower in 4/8 bounded rows. Treat this as an exploratory
  digital monitor-cost result only; it is not a measured RF advantage, a PA
  conclusion, or a joint-policy deployment decision.
- The repeated joint DSM+DPD LOSO evaluation initially had one unvalidated
  EFDSM2 QAM16/BW40/backoff-0.58 bounded-search action because the selected
  polynomial package was `1/0`, while the retained local trace used `1/3`.
  A separate J1 JTAG replay forced the requested package-0 seed
  (`C1/C3/C5 = 0xFFF93FCD/0xF21A1EC1/0xDD023CA8`) through one policy replay,
  12 perturbations, and a final replay. It produced exactly 14 records with
  zero stall/error/clip/saturation and final PL proxy cost `308660`, compared
  with the held best fixed-DSM local cost `305773`. The evidence completes
  8/8 joint LOSO actions, but raises mean joint-minus-best-fixed cost to
  `1057.25`; the current joint chooser is demonstrably not a deployment or
  TinyML RTL candidate.
- Memory-polynomial DPD is implemented as a 2-to-4-tap, 1st/3rd/5th-order
  signed-Q2.14 RTL datapath and is bit-true against MATLAB. Its coefficients
  remain behavioral-PA trained rather than calibrated to a physical PA.
- The current "AI" engine is deterministic coordinate-search optimization plus
  PS-side fixed-point coefficient search. It does not yet run a neural-network
  PA model or compute true EVM/SNDR/ACLR from measured RF feedback on PS.

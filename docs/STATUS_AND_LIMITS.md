# Status and Limits

## Verified Status

- Seven DSM paths are retained: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11,
  MASH111, and MASH22.
- MATLAB/RTL bit-true comparison passes with zero mismatches for all seven
  paths.
- XSim regression passes for all seven retained testbenches.
- IP smoke tests pass for the streaming top and AXI wrapper.
- Vivado IP packaging generates `ip/ip_repo/dsm_ip_1_0/component.xml`.
- OOC synthesis evidence is retained for `xc7z020clg400-1`,
  `xczu15eg-ffvb1156-1-i`, and `xczu48dr-ffvg1517-2-e`.
- Exploratory multibit Cartesian DSM modes are MATLAB/RTL bit-true over the P0
  65536-sample vector set with zero mismatches.
- The interpolation/filter frontend supports bypass, x4, x8, x16, and x32
  modes in RTL with MATLAB/RTL bit-true comparison, and is inserted before
  `dsm_ip_core` in `dsm_ip_top`.
- The interpolation FIR helpers use a four-stage registered compute pipeline
  with symmetric pre-add, grouped partial sums, adder-tree reduction, and
  round/saturate output registration.
- The DPD frontend now uses a deeper registered pipeline. The polynomial DPD
  multiplier/add path is split across square, radius, coefficient multiply,
  gain accumulation, complex multiply, and saturation stages. Bypass and LUT
  DPD modes are latency-aligned to the polynomial path.
- The ZU15EG bare-metal regression has been run after the DPD pipeline update.
  It rebuilt the bitstream, exported XSA, rebuilt the ELF, programmed the
  board, launched the PS-side calibration app, and passed post-run DSM/DPD
  counter readback.
- The PS-side calibration app source now includes v2 calibration controls:
  build-time configurable cost weights/search limits, multi-round coarse-to-fine
  polynomial coefficient search, CSV-style candidate traces, replay-only
  builds, and XSDB replay counter CSV capture.
- The PS calibration source can now consume an optional host-generated
  nearest-neighbor DPD seed. The seed is evaluated through the same DMA and PL
  monitor cost as every other candidate; it is not a direct unverified write.
- The adaptive-seed ELF has now been rebuilt and run on ZU15EG through the
  external J2 Digilent JTAG path. The full calibration completed, retained LUT
  DPD mode, and passed the final 4096-sample counter check with zero stalls,
  sticky errors, and DPD saturation.
- Candidate-level calibration evidence no longer depends on PS UART. The A53
  app publishes a versioned, cache-flushed memory trace buffer, and the board
  regression resolves its ELF symbol and exports it through J2/XSDB to CSV and
  Markdown. The first capture contains all 50 expected records with no overflow.
- A trace-aware weighted k-NN policy can now select a historical best
  mode/package for a policy-only replay. On the retained 16-QAM, 48-subcarrier,
  0.58-backoff scenario, LUT package 3 reproduced the full-calibration final
  cost `3003709` with one measured candidate instead of 50.
- The software trace-policy flow now has a manifest-controlled
  leave-one-scenario-out evaluator. It excludes every replicate of a held
  scenario before fitting, isolates calibration-cost profiles, reports package
  regret and candidate reduction, and marks a single-condition input as
  `insufficient_training` rather than reporting a generalization score.
- The bare-metal build can embed a deterministic Q1.15 QAM-OFDM DMA vector
  for a selected QAM order, used-subcarrier count, input backoff, FFT size,
  and seed. This makes those waveform conditions reproducible board inputs;
  PA profile/strength still requires external controlled metadata and feedback.
- Eight complete J2 trace captures now cover QAM16/QAM64, 20/40 MHz, and
  0.58/0.70 backoff on one nominal board configuration. Leave-one-scenario-out
  evaluation selected the held package optimum in 6/8 traces, produced mean
  package regret `181.5`, and reduced each 49-candidate full calibration to a
  one-candidate policy action in offline evaluation.
- The highest-regret LOSO waveform case (`QAM64`, 40 MHz, 0.58 backoff) has now
  been confirmed with a new J1-only policy replay. Its trace was excluded from
  the 84-observation training set; the generated mode 1/package 3 action ran as
  one measured candidate with cost `296375`, zero stall/error/saturation, and
  a complete one-record JTAG trace. This confirms the 49-to-1 execution-path
  reduction for one unseen waveform condition, but not unseen PA behavior.
- The policy now has a generated confidence gate. It uses integer-ppm nearest
  distance and relative cost dispersion to choose a one-candidate direct path
  or a bounded polynomial local search. Both branches passed on J1: direct was
  1 candidate at cost `296375`; forced fallback was 14 records at cost
  `294902`, versus `294825` for the retained 49-candidate full search. The
  current thresholds are waveform-matrix defaults, not RF-certified limits.
- A runtime safety guard now checks the first measured policy candidate. Cost
  residual above the generated limit or nonzero stall/error/saturation forces
  bounded polynomial search. J1 validated direct operation at `110439 ppm`
  against the default `150000 ppm` limit and runtime fallback against a test
  `100000 ppm` limit; the latter retained cost `294902` in 14 records.
- J1 is now the validated combined board connection. With FTDI channel A
  enabled, Vivado sees `Xilinx/15051A` for JTAG and PS UART0 is `COM11` at
  115200 8N1 on the current host. J2 must remain disconnected while J1 is in
  use because both adapters share the physical Zynq JTAG nets.
- The AXI wrapper includes a one-entry AXI-Stream skid buffer. Legal
  backpressure is counted in `INPUT_STALL_COUNT`; streaming while disabled or
  in reset is reported through sticky error status.
- The AXI wrapper preserves AXI-Stream `tlast` and `tuser`, exposes frame and
  `tuser` counters, and reports nonzero accepted `tuser` through sticky error
  status.
- TX frontend v1.2 includes the opt-in 2-to-4-tap Q1.15/Q2.14 memory-polynomial DPD
  mode with shadow/commit coefficients. Bypass, memoryless polynomial, and LUT
  modes retain their existing external latency and fixed-point behavior.
- A separate observation AXI-Stream slave provides programmed delay and complex
  gain alignment, training-window status, pair/drop counters, a 64-bit L1
  error accumulator, aligned complex magnitude/peak, clip/saturation, slew,
  fixed-bin spectral proxies, and start-latched Q8.8 temperature. It is
  optional and never backpressures TX.
- Runtime condition registers feed a conservative seed selector. Unknown or
  faulted conditions assert fallback, and local search remains mandatory; this
  does not reopen the rejected one-candidate direct policy.
- A leakage-safe behavioral comparison now trains Q2.14 memoryless and 4-tap
  memory-polynomial DPD on disjoint fit/validation OFDM data and evaluates
  three held-out 64-QAM seeds under the same PA/noise realization. Mean EVM is
  `4.3050%` without DPD, `3.1175%` with memoryless DPD, and `2.8278%` with the
  joint-safe memory-polynomial package; the 4-tap model wins on all 3/3 test seeds with zero
  DPD saturation and zero drive limiting.
- Joint validation now enforces memoryless ACLR plus 0.05 dB as a hard boundary
  and rejects saturation/drive limiting. Mean ACLR is `-32.5074 dBc` versus
  `-32.5576 dBc` for memoryless DPD, while EVM improves by 9.29%.
- Behavioral PA feedback has been driven through `dpd_observer` in XSim. Delay
  3, Q2.14 gain `(18239,-381)`, 63 pairs, one drop, L1 error `92046`, and all
  `aligned_complex_pa_monitor_v2` statistics match the MATLAB expectation
  exactly. Directed smoke also covers temperature latching and forced
  clip/saturation.
- The extended v1.2 AXI wrapper passes ZU15EG OOC synthesis at 100 MHz with
  8,975 LUTs, 7,562 flip-flops, 154 DSPs, and `+2.302 ns` WNS. Relative to the
  pre-extension v1.1 baseline, the aligned complex monitor adds 1,399 LUTs and
  387 flip-flops, adds no DSPs, and does not reduce the measured WNS.
- The 1728-row memory-DPD TinyML matrix has been regenerated with exact
  `aligned_complex_pa_monitor_v2` arithmetic over 12 PA profiles, eight
  waveforms, three seeds, and six Q2.14 packages. Strict quantized LOSO keeps
  zero safety violations. The standalone tree is non-worse than LUT in only
  2/12 folds and is rejected; the hierarchical tree/LUT/search policy is
  non-worse in 12/12 and strictly better in 5/12, with mean candidate count
  `5.604` and mean regret `408.861`.
- A deterministic full-data tree has been exported as signed-Q12.20 raw-feature
  comparisons with inclusive training-domain bounds. Conservative leaves make
  154 direct suggestions and 134 fallback decisions on the 288 behavioral conditions with
  zero training safety violations, zero training regret, and zero float/fixed
  path changes. Python and host C match all 329 condition/boundary decisions.
  Standalone synthesizable RTL and its XSim testbench pass all 329 generated
  Python/C/RTL decisions. The tree is not instantiated in the AXI wrapper; board behavior
  therefore remains mandatory 14-candidate search until RTL and trace replay
  gates pass.
- Retained-board schema replay covers 16 EFDSM/EFDSM2 policy rows and correctly
  produces 16/16 fallback decisions with Python/C agreement. All rows lack
  temperature and aligned observer error; gain, peak/average, EVM, and ACPR
  ratios are out of the behavioral model domain because current PL output
  monitors observe the post-DSM one-bit stream, not complex PA feedback. This
  is a feature-schema incompatibility, not a threshold-tuning problem. The
  aligned complex PA-feedback register contract now exists. The old v1 model
  is retired; the v2 tree remains uninstantiated because the standalone tree
  fails the LOSO deployment rule and the qualified hierarchy is PS-controlled.
- Raw complex-feedback replay covers 288 Q1.15 traces and 497,664 samples.
  Independent Python arithmetic reconstructs every v2 monitor record exactly.
  The full-data tree's 154 direct suggestions have zero labeled violations and
  zero regret; 134 rows request fallback. This is behavioral replay, not
  held-out physical-PA evidence. AXI integration remains disabled and the
  deployed action stays the mandatory 14-candidate search.
- A strictly isolated observer-v2 blind matrix now covers three additional PA
  profiles, 72 conditions, and 432 package rows. The frozen tree -> waveform
  LUT hierarchy selects an unsafe initial package in 19/72 conditions
  (`5/24`, `5/24`, and `9/24` by blind profile). It therefore fails promotion.
  The generated PS hierarchy header has `AVAILABLE=0`, direct execution is
  disabled, and no board replay is authorized for this policy. The negative
  result is retained as evidence rather than repaired by widening model bounds.
- A replacement safety-first offline policy uses eight newly generated
  development-only PA profiles for all model selection. It admits a package
  only with unanimous safety evidence from seven nearest same-waveform nonblind
  conditions and a finite in-distribution distance bound; it uses expected cost
  only after that safety gate. Development PA LOSO records zero unsafe selected
  seeds across 129 seeds and 63 `fallback_14` decisions; the permanently untouched three-profile blind
  final test records zero unsafe selected seeds across 49 seeds and 23
  `fallback_14` decisions. This is behavioral-PA evidence only. It does not
  enable the old PS tree/LUT header, direct execution, AXI TinyML, or board
  deployment until a separately generated PS-C implementation passes
  Python/C equivalence and board replay.
- Safety-first PS-C constants now exist and are independently checked against
  Python on 552 Q12.20 decisions, including all 72 frozen blind conditions;
  quantization changes none of those blind decisions. The constants include 480
  nonblind base/development evidence rows and reject blind-profile overlap.
  They remain a pre-board artifact: `BOARD_ENABLE_ALLOWED=0`, direct execution
  is `0`, and the bare-metal calibration loop does not yet invoke the selector.
- A test-only bare-metal entry point now invokes the safety selector under
  `CAL_SAFETY_SEED_POLICY_ONLY=1`. It fails closed without a completed
  `aligned_complex_pa_monitor_v2` window or a safety-qualified package, and it
  always performs the 14-record memory-polynomial local search. A direct A53
  ELF is built, but it has not been downloaded or run. The local Vitis Python
  application builder remains blocked by a host UTF-8 decode failure during
  client creation; this is separate from the direct A53 build.
- The current personal board target for new FPGA validation is
  `xczu15eg-ffvb1156-1-i`; older `xc7z020clg400-1` evidence remains historical
  proxy evidence.
- The final software AI calibration policy is complete for EFDSM 1-bit, OSR
  32, bypass interpolation. Its 1728-row behavioral benchmark and grouped
  profile/waveform/random-seed validation reject the unsafe one-candidate
  direct path. The deployed software policy selects one of six Q2.14 seed
  offsets from an eight-waveform C LUT and always executes the deterministic
  14-candidate bounded search. All three grouped splits improve mean final cost
  versus fixed package-3 bounded search and introduce no modeled EVM/ACLR,
  clip, or saturation failure. A representative J1 replay produced 14 complete
  records, cost `321062 -> 311350`, and zero safety counters.

## Timing Summary

On `xc7z020clg400-1`, all seven retained paths meet the 100 MHz proxy OOC
target in the 2026-07-03 evidence:

| Top | Status | LUT | FF | DSP | WNS ns | Fmax est MHz |
|---|---|---:|---:|---:|---:|---:|
| `p0_ooc_lp1` | PASS | 104 | 71 | 0 | 6.557 | 290.44 |
| `p0_ooc_lp2` | PASS | 270 | 87 | 0 | 0.165 | 101.68 |
| `p0_ooc_ef1` | PASS | 182 | 63 | 0 | 2.221 | 128.55 |
| `p0_ooc_ef2` | PASS | 316 | 119 | 0 | 0.080 | 100.81 |
| `p0_ooc_mash11` | PASS | 274 | 102 | 0 | 2.811 | 139.10 |
| `p0_ooc_mash111` | PASS | 398 | 148 | 0 | 2.594 | 135.03 |
| `p0_ooc_mash22` | PASS | 276 | 179 | 8 | 0.455 | 104.77 |

The retained evidence file is
`docs/evidence/ooc/p0_ooc_xc7z020_20260703_summary.csv`.

The 2026-07-05 multibit OOC evidence on `xc7z020clg400-1` uses 4-bit multibit
quantizers, `ACC_W_MB=16`, wrap/no-saturate state arithmetic, and post-place /
post-route physical optimization:

| Top | Status | LUT | FF | DSP | WNS ns | Fmax est MHz |
|---|---|---:|---:|---:|---:|---:|
| `p0_ooc_mb_lp1` | PASS | 492 | 60 | 0 | 1.466 | 117.18 |
| `p0_ooc_mb_lp2` | PASS | 619 | 96 | 0 | 0.018 | 100.18 |
| `p0_ooc_mb_ef1` | PASS | 504 | 60 | 0 | 1.392 | 116.17 |
| `p0_ooc_mb_ef2` | FAIL_TIMING | 596 | 92 | 0 | -0.093 | 99.08 |
| `p0_ooc_mb_mash11` | PASS | 975 | 116 | 0 | 0.960 | 110.62 |
| `p0_ooc_mb_mash111` | PASS | 1467 | 180 | 0 | 0.016 | 100.16 |
| `p0_ooc_mb_mash22` | FAIL_TIMING | 1203 | 188 | 0 | -0.688 | 93.56 |

The retained multibit evidence file is
`docs/evidence/ooc/p0_ooc_xc7z020_20260705_multibit_summary.csv`.

After the DPD pipeline update, the dedicated DPD MATLAB/RTL comparison still
passes with zero mismatches, and the integrated AXI smoke passes with matching
input, DPD, frontend, and output sample counters under interpolation
backpressure. The ZU15EG board implementation also rebuilt and generated a
bitstream with 0 errors and 0 critical warnings; Vivado reported no setup
violation. A previous partial ZU15EG post-synthesis matrix run completed the
first nine `dsm_ip_axi_top` combinations at about 129.9 MHz estimated Fmax.
The full matrix run timed out and is not treated as complete matrix timing
evidence.

On the conservative ZU15EG target `xczu15eg-ffvb1156-1-i`, the 2026-07-05 OOC
run closes all 14 single-bit/native and multibit DSM tops at the 100 MHz proxy
target:

| Top | Status | LUT | FF | DSP | WNS ns | Fmax est MHz |
|---|---|---:|---:|---:|---:|---:|
| `p0_ooc_lp1` | PASS | 103 | 71 | 0 | 8.955 | 956.94 |
| `p0_ooc_lp2` | PASS | 269 | 87 | 0 | 5.818 | 239.12 |
| `p0_ooc_ef1` | PASS | 181 | 63 | 0 | 7.150 | 350.88 |
| `p0_ooc_ef2` | PASS | 315 | 119 | 0 | 5.449 | 219.73 |
| `p0_ooc_mash11` | PASS | 246 | 90 | 0 | 6.926 | 325.31 |
| `p0_ooc_mash111` | PASS | 373 | 138 | 0 | 7.122 | 347.46 |
| `p0_ooc_mash22` | PASS | 251 | 169 | 72 | 5.107 | 204.37 |
| `p0_ooc_mb_lp1` | PASS | 468 | 50 | 0 | 6.263 | 267.59 |
| `p0_ooc_mb_lp2` | PASS | 584 | 82 | 0 | 5.283 | 212.00 |
| `p0_ooc_mb_ef1` | PASS | 480 | 50 | 0 | 6.453 | 281.93 |
| `p0_ooc_mb_ef2` | PASS | 570 | 82 | 0 | 5.176 | 207.30 |
| `p0_ooc_mb_mash11` | PASS | 964 | 105 | 0 | 5.884 | 242.95 |
| `p0_ooc_mb_mash111` | PASS | 1466 | 171 | 0 | 5.725 | 233.92 |
| `p0_ooc_mb_mash22` | PASS | 1168 | 179 | 0 | 4.896 | 195.92 |

The retained ZU15EG evidence file is
`docs/evidence/ooc/p0_ooc_xczu15eg_ffvb1156_1_i_20260705_summary.csv`.

The 2026-07-06 post-synthesis OOC matrix on `xczu15eg-ffvb1156-1-i` covers
all 70 compile-time `dsm_ip_axi_top` combinations:

```text
ALGORITHM = 0..13
INTERP_MODE = 0..4
DUC_MODE = 0
```

All 70 post-synthesis OOC combinations pass the 100 MHz target. This matrix is
post-synthesis evidence only; it is not routed timing closure.

Summary by interpolation mode:

| INTERP_MODE | Function | Count | Pass | Max LUT | Max FF | Max DSP | Worst WNS ns | Worst Fmax est MHz |
|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 0 | bypass | 14 | 14 | 1706 | 461 | 72 | 5.720 | 233.64 |
| 1 | x4 halfband | 14 | 14 | 5217 | 4093 | 540 | 5.546 | 224.52 |
| 2 | x8 halfband | 14 | 14 | 6969 | 5911 | 774 | 5.546 | 224.52 |
| 3 | x16 halfband | 14 | 14 | 8732 | 7729 | 1008 | 5.546 | 224.52 |
| 4 | x32 halfband + CIC-equivalent FIR + compensation FIR | 14 | 14 | 9183 | 8276 | 1350 | 5.546 | 224.52 |

Worst resource/timing summary by DSM algorithm across all interpolation modes:

| ALGORITHM | Algorithm | Count | Pass | Max LUT | Max FF | Max DSP | Worst WNS ns | Worst Fmax est MHz |
|---:|---|---:|---:|---:|---:|---:|---:|---:|
| 0 | LPDSM 1-bit | 5 | 5 | 7827 | 8167 | 1278 | 5.847 | 240.79 |
| 1 | LPDSM2 1-bit | 5 | 5 | 7991 | 8183 | 1278 | 5.847 | 240.79 |
| 2 | EFDSM 1-bit | 5 | 5 | 7903 | 8159 | 1278 | 5.847 | 240.79 |
| 3 | EFDSM2 1-bit | 5 | 5 | 8037 | 8215 | 1278 | 5.847 | 240.79 |
| 4 | MASH11 native | 5 | 5 | 7968 | 8187 | 1278 | 5.847 | 240.79 |
| 5 | MASH111 native | 5 | 5 | 8094 | 8235 | 1278 | 5.847 | 240.79 |
| 6 | MASH22 native | 5 | 5 | 7970 | 8234 | 1350 | 5.546 | 224.52 |
| 7 | LPDSM multibit | 5 | 5 | 8190 | 8147 | 1278 | 5.847 | 240.79 |
| 8 | LPDSM2 multibit | 5 | 5 | 8304 | 8179 | 1278 | 5.847 | 240.79 |
| 9 | EFDSM multibit | 5 | 5 | 8190 | 8147 | 1278 | 5.847 | 240.79 |
| 10 | EFDSM2 multibit | 5 | 5 | 8300 | 8179 | 1278 | 5.847 | 240.79 |
| 11 | MASH11 multibit | 5 | 5 | 8673 | 8204 | 1278 | 5.847 | 240.79 |
| 12 | MASH111 multibit | 5 | 5 | 9183 | 8268 | 1278 | 5.847 | 240.79 |
| 13 | MASH22 multibit | 5 | 5 | 8913 | 8276 | 1278 | 5.720 | 233.64 |

The full 70-row matrix is retained in
`docs/evidence/ooc/dsm_ip_axi_matrix_xczu15eg_ffvb1156_1_i_20260706_post_synth_summary.csv`.

The 2026-07-06 routed OOC subset on `xczu15eg-ffvb1156-1-i` covers three
representative `dsm_ip_axi_top` combinations after synthesis, placement,
routing, and post-route physical optimization:

| Top | Algorithm | INTERP_MODE | Status | LUT | FF | DSP | WNS ns | Fmax est MHz |
|---|---|---:|---|---:|---:|---:|---:|---:|
| `dsm_ip_axi_ef_dsm_bypass_default` | EFDSM 1-bit | 0 | PASS | 534 | 410 | 0 | 6.714 | 304.32 |
| `dsm_ip_axi_mash22_native_x32_worst_dsp` | MASH22 native | 4 | PASS | 8080 | 8301 | 1350 | 4.490 | 181.49 |
| `dsm_ip_axi_mash111_multibit_x32_max_lut` | MASH111 multibit | 4 | PASS | 9283 | 8335 | 1278 | 4.263 | 174.31 |

The routed subset evidence is retained in
`docs/evidence/ooc/dsm_ip_axi_routed_subset_xczu15eg_ffvb1156_1_i_20260706_summary.csv`.
This is stronger than post-synthesis OOC evidence, but it is still IP-level OOC
evidence, not complete ZU15EG board bitstream timing closure.

On `xczu48dr-ffvg1517-2-e`, all seven retained paths meet the 100 MHz proxy OOC
target in the current evidence.

## Safe Claims

- This repository is a reusable DSM RTL/IP handoff package.
- It includes MATLAB fixed-point reference models, RTL, testbenches, IP
  packaging scripts, and synthesis evidence.
- RFSoC4x2 board files, schematics, BOMs, reference manuals, and vendor board
  packages are local-only collateral and are not intended for public GitHub
  release unless redistribution rights are confirmed.

## Claims To Avoid

- Do not claim this is a complete RFSoC4x2 bitstream-ready project.
- Do not claim full RFSoC board timing/resource closure.
- Do not claim all algorithms close timing on all FPGA targets unless the
  target has explicit retained OOC or implementation evidence.
- Do not claim runtime algorithm switching unless it is implemented.
- Do not claim runtime interpolation switching. The current interpolation mode
  is a compile-time parameter.
- Do not claim final timing closure for the pipelined interpolation frontend
  from post-synthesis evidence alone. The 2026-07-06 matrix is post-synthesis
  OOC evidence, not routed timing closure.
- Do not claim all multibit modes close at 100 MHz on `xc7z020clg400-1`; EFDSM2
  multibit and MASH22 multibit still need timing closure work.
- Do not claim a complete ZU15EG board-level implementation or bitstream from
  OOC evidence alone. The current ZU15EG result is module-level OOC timing and
  resource evidence only.
- Do not claim the software seed is the final best DPD mode in the current
  board run. It was accepted as the best polynomial starting point, but LUT
  package 3 had a much lower proxy cost and was retained as the final mode.
- Do not claim trace-policy generalization or learned PA behavior from the
  current result. It uses one historical board scenario and validates only a
  same-scenario policy replay; multiple held-out waveform/PA conditions are
  required before ranking unseen scenarios.
- Do not treat the new eight-waveform trace matrix as two PA strength levels.
  It intentionally records a single `nominal_no_external_feedback` PA profile;
  a controlled PA/emulator plus feedback receiver must supply a second strength
  setting before the PA axis can be included in LOSO evidence.
- Do not treat the `15%` runtime residual or existing static thresholds as
  calibrated safety limits. They still require repeated measurements under a
  second controlled PA strength and an actual feedback observation path.
- The repository now provides a strict RF-feedback threshold-calibration
  workflow, but no second PA condition or external receiver record exists on
  this host yet. Its output will remain evidence-based engineering calibration,
  not RF safety certification.
- The replacement active path is simulation-only: the MATLAB memory-PA and
  observation model provides repeated nominal and strong PA feedback. Its
  calibrated limits are intentionally not copied into the generated board
  header; the board's `15%` residual remains an engineering default.
- The expanded 12-profile simulation sweep covers gain, saturation, memory,
  observation noise, drift, QAM, bandwidth, and backoff (288 records). The
  current distance/dispersion/residual gate is overly selective rather than
  broadly general: it accepts no failing held record but only two passing held
  records. Do not use its broad-sweep thresholds as a board policy.
- The board policy includes monitor-state distance as an additional runtime
  fallback condition. Its reference is trained from nominal JTAG package
  traces and its feature path has passed one J1 replay. The completed
  weighted-monitor 12-profile LOSO accepts no failing held record but only two
  passing held records, so it demonstrates conservative modeled fallback
  behavior rather than PA-profile discrimination. The minimum simulation
  threshold is compatible with all eight retained nominal traces in offline
  replay, but their direct policy cost averages 2170 above full-search final
  cost. No simulation-derived tolerance is copied into the board header.
- The behavioral policy can now predict whether the first polynomial candidate
  is worth refining with the existing bounded local search. The held-profile
  regret policy's 100-cost/100000-ppm in-distribution operating point accepts
  36 of 288 modeled runs and saves 468 of 4032 candidate evaluations; every
  accepted modeled run has actual search regret at most 98. This only bounds
  the behavioral cost label. It neither certifies RF EVM/ACLR nor authorizes a
  board-header update, and hard board stall/error/clip/saturation fallback must
  remain mandatory.
- The package-aware benchmark labels all six deterministic polynomial packages
  with actual 14-candidate outcomes and prevents held-profile seed-fit leakage.
  It establishes the final safety boundary: AI seed selection is qualified,
  while one-candidate direct execution is not. The generated C LUT and A53
  policy mode implement that exact boundary. This remains simulation-derived
  calibration logic with PL proxy replay; it is not measured PA/RF evidence
  and does not by itself justify TinyML RTL.
- The fixed-point Q20 regret predictor has been replayed offline against all
  eight retained JTAG traces. Every trace is outside the behavioral
  100000-ppm in-distribution distance, so every trace correctly requests the
  14-candidate local-search branch. Do not relax that distance merely to gain
  direct paths: without it one trace would be accepted with a recorded
  one-candidate-to-full-search delta of 2577. The existing full-calibration
  traces do not measure the 14-candidate branch and cannot authorize C
  constants; collect fresh policy-only replays first.
- Fresh policy-only replays now measure the required 14-candidate local-search
  branch for all eight nominal waveform conditions. Each starts from existing
  static polynomial package 3, records one policy candidate, 12 perturbations,
  and one final replay, with all safety counters zero. Final cost improves by
  822 to 1473 over the policy candidate and uses 35 fewer candidates than the
  retained 49-candidate calibration. This is bounded-search board evidence;
  it does not validate a direct behavioral regret decision, PA-profile
  generalization, external RF feedback, or regret-predictor C constants.
- The DSM-aware board dataset now contains eight provenance-linked rows with
  waveform, PA, DSM, DPD, monitor-state, policy-cost, bounded-search-cost, and
  full-search-cost fields. It records a 822 to 1473 PL-proxy-cost benefit from
  bounded search, but has only one EFDSM 1-bit/OSR-32/interpolation-mode-0
  build. Therefore DSM features are constants: no claim about joint DSM-plus-
  DPD optimization, no deployable feature ranking, and no TinyML RTL decision
  may be made from this set.
- The dataset now has a second matched DSM configuration, EFDSM2 1-bit
  (`ALGORITHM=3`) at the same OSR/interpolation/DUC settings. It contains 48
  board rows: three complete full-calibration and three complete bounded-search
  runs for each DSM/waveform condition. EFDSM2-minus-EFDSM mean bounded-final
  proxy cost is `-969.33`; EFDSM2 is lower on 3/8 paired conditions. These are
  repeated internal PL proxy results, not PA-profile variation or RF feedback,
  so they cannot rank DSM choices for deployment or justify TinyML RTL.
- The repeat gate was evaluated with the required three repeats. Its 95%
  paired CI is `-3457.07` to `1518.40` and EFDSM2 wins 3/8 conditions, so
  LPDSM2/third-DSM collection remains intentionally blocked. J1 is now a
  validated combined JTAG/UART board connection; the block is evidence quality,
  not JTAG visibility.
- Joint DSM+DPD LOSO is host-side only. The missing EFDSM2 QAM16/BW40/backoff-
  0.58 mode/package `1/0` action now has its own safe 14-record board replay
  with final proxy cost `308660`; it is `2887` above that condition's best
  fixed DSM cost. All 8/8 actions are therefore validated. Their mean joint
  minus best-fixed cost is `1057.25`, so do not claim a joint-policy benefit or
  build TinyML RTL from this completed negative result.
- Do not populate the multi-scenario manifest by relabelling the existing
  synthetic smoke-vector trace. A valid scenario trace must be produced with
  its declared QAM-OFDM waveform and controlled PA/feedback configuration.

## Public Release Notes

Before publishing to GitHub, keep restricted RFSoC board collateral out of the
public repository. If a board flow is restored later, document the required
private/local source path instead.

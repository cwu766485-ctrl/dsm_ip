# Weighted MASH full-chain QAM256 root-cause closure

Recorded 2026-11-17 00:12 SGT. Implementation commit:
`1fd679d` on independent branch `work/thermo5-mash-qam-root-cause`.
Original integration snapshot checkpoint: `7974508`; original branch HEAD:
`6c96c4e1b11bf193240fb8bf5d0e540e5b3c8b3c`.

The QAM failure has three confirmed causes: an omitted algorithmic delay in
the receiver FFT window, the wrong Stage 2 error signal, and q1 alignment that
changes around valid bubbles. The corrected candidate passes the unchanged
3,004-beat experiment and four enlarged fixed-seed RTL experiments. P5 system
verification and physical implementation remain OPEN; this is not final
product, continuous serializer, board, or RF signoff.

## Preservation and source scope

The actual starting session was on `thermo5`, not the requested working
branch. Its six dirty files were preserved separately. The requested Windows
worktree was found at `../dsm_ip_thermo5_vcu118`; its Windows-format Git link
was read through an explicit Git directory without changing that link.

Before changes, all dirty source/report files and every file under that
worktree's `runs/` were copied to
`../mash_root_cause_preservation/files/`, relative to this independent
checkout. The SHA256 manifest is
`../mash_root_cause_preservation/manifest.json`: 5,478 files, 1,811,338,023
bytes. The final source recheck found **zero changed original files**.
The named failing directory remains intact in the original worktree and in
the backup. No original Golden, EVM threshold, seed, input scaling, FIR/DPD
configuration, or failed measurement was overwritten.

A final legacy-mode rerun reproduces both original PA capture hashes exactly:

| Artifact | SHA256 |
| --- | --- |
| AXIS I input | `2b0f197c6b4a7d1254af6d1709f3bd1cf598412f953de34b0586bfd282c229e3` |
| AXIS Q input | `7fdff3d41ae062b71018209dbd06e149381c490fa630a057ccc29f5f1b07ccdf` |
| Legacy PA0 | `371b78ed29ae8854f0c470b8b6d8304840a388c166bdc443569d8d2cb756805a` |
| Legacy PA1 | `54f32d484aea866bff9c3da20615dd65e79a3417b0a0acbeb03f49a034790656` |

The existing MATLAB/parallel Python x-q1 experiment is retained unchanged.
`mash_accumulator_reference.py` is a separate, scalar mathematical oracle for
the explicitly corrected architecture. It predicts PA bits from independent
frontend input vectors, never from observed PA data. The MASH AXIS top now defaults to `USE_ACCUMULATOR_RESIDUE=1`; the historical
primitive/generic adapter retain default0 for compatibility. The capture
runner explicitly selects legacy mode unless `--correct-residue` is given.
Only isolated Stage 1
replays intentionally use the captured Pre-DSM input, as required by P1.

## P0: independent receiver sanity

`research/thermo5_integration/model/receiver_fs4_smoke.py` requires no RTL,
DSM, DPD, or PA Golden. It generates DC I-only, DC Q-only, a positive 40-MHz
complex tone, an impulse, and independently interpolated QAM256 OFDM.

All five pass. DC complex errors are below 1e-5 without fitting gain. The
tone has positive 40-MHz phase progression; the impulse peaks at its declared
sample position. Independent two-symbol ideal OFDM produces **2.223571% EVM,
33.0590 dB SNDR, BER 0/9,344**. The actual frontend's unquantized Fs/4 path
produces 2.354286% EVM on the full eight-symbol input.

The raw order is `I0,-Q0,-I1,Q1,...`, bit 0 earliest; bipolar bits mean
0 -> -1, 1 -> +1. The DDC LO is `[1,-j,-1,+j]`, both decimation phases are
zero, and the existing centered FIRs compensate their own group delays.
Ideal input here means unquantized digital RF samples: binary RF with
arbitrary OFDM amplitude would itself require quantization. The small ideal
EVM includes I/Q staggering and the declared receiver; it is not DSM noise.

The first tone diagnostic used a biased one-step phase estimator in the
presence of the Fs/4 image. It was corrected to fit the whole unwrapped phase
record. This did not change the receiver, OFDM input, or QAM acceptance gates.

## P1: complete scalar Stage 1 isolation

`pre_words.csv` exports all 5,257 accepted 32-lane words: **168,224 complex
Cartesian samples**. The scalar oracle uses one unsigned W-bit residue per
component, initialized to zero:

```
u = residue + signed_sample + 32768
bit = u >> 16
residue = u & 65535
```

Every raw bit is compared after independently applying Fs/4 polarity and
bit0-first packing. Integrated Stage 1 has 32 words of algorithmic fill;
336,448 captured bits, including reset fill, match with zero mismatches.
An isolated replay adds exactly 32 zero words solely to clock out the tail.
It checks **all 168,224 input samples**, including the last sample, against
338,496 output bits including fill. Both dense and bubble runs have
`total_mismatch=0`, `first_mismatch=null`, and zero differences from the
integrated capture prefix. This is not a 128-vector random sample.

Evidence: `runs/mash_final_stage1_complete/bubbles{0,1}/stage1_bittrue.csv`,
`stage1_replay.csv`, and `stage1_replay.vcd`. Integrated capture has 45 invalid
input/output observations including startup/drain; no accepted word is lost,
duplicated, or reordered. First Pre-DSM acceptance is 249174 ps; first Stage 1
output is 258318 ps. The first output is algorithmic fill, not source word 0.
Source word 0 reaches Stage 1 transaction 32 at 404622 ps.

The initial 33-word assumption produced 146,352 mismatches and was rejected.
Its failed CSVs remain in `runs/mash_stage1_complete/` and
`runs/mash_closure_seed281001_audit2/`. The historical Python tick samples
before state update; its call convention cannot be copied as RTL output lag.
No Golden function was modified to make that failed assumption pass.

## P2: timing and alignment contract

The independent [Timing Alignment Report](thermo5-mash-timing-alignment-20261117.md)
records the full derivation and stall/reset boundaries. The dedicated timing contract is
`research/thermo5_integration/model/mash_timing_contract.py:1`.
Receiver correction is in `thermo5_mash_axis_qam.py:134-138`.

| Delay or boundary | Measured/derived treatment |
| --- | --- |
| Source guard | 2,576 source samples; unchanged |
| Source beat 0 -> Pre-DSM token 0 | 108000 -> 249174 ps; transport only |
| Pre-DSM -> Stage 1 token | 2 observed core cycles; no sample crop |
| Stage 1 algorithmic stream delay | 32 words = 1,024 Pre-DSM complex samples = 256 source samples |
| Historical internal alignment | 35 registers; includes clock-boundary alignment, not a 35-word receiver crop |
| Final MASH stream delay | 66 words = 2,112 Pre-DSM samples = 4,224 raw RF samples = 528 source samples |
| Pre-DSM -> final PA token | 8 observed cycles, including core/FIFO/encoder boundaries; do not assume 7 |
| FIR0 group delay | 2,048 raw RF samples, compensated by the existing centered convolution |
| FIR1 group delay | 2,048 samples at 7 GS/s, also compensated |
| Decimation phases | 0, 0 |
| CP / FFT | 512 / 4,096 source-rate samples |
| MASH first FFT sample | 2,576 + 528 + 512 = 3,616 in the decimated output |

The VCD core period is 4,572 ps because of testbench time precision; nominal
hardware cadence is 218.75 MHz. Timing tables use actual VCD timestamps.
The PSD/receiver sequence analysis explicitly assumes the nominal 14-GS/s RF
sample rate. No physical GT serializer clock was simulated.

The 66-word contract is 32 Stage 1 words + 32 aligned Stage 2 words + two
explicit output reset-FIFO words. The corrected q1 companion advances on the
same accepted Stage 2 transactions, preserving this delay through bubbles.
Every capture retains all RF samples. Acceptance moves the CP/FFT window by
the fixed contract; it does not search for an EVM-minimizing crop.

| Same-input isolation | Fixed source offset | EVM RMS | Diagnostic correlation lag |
| --- | ---: | ---: | ---: |
| A: ideal Fs/4, actual frontend IQ, no DSM | 0 | 2.354286% | 0 |
| B: independent scalar Stage 1 | 0 | 12.002773% | 0 |
| C: actual RTL Stage 1 | 256 | 12.002773% | 256 |
| D: original RTL weighted MASH, timing corrected only | 528 | 13.145892% | 528 |
| D: corrected RTL weighted MASH | 528 | 2.551442% | 528 |

The original unaligned D remains **99.994117% EVM**, approximately 0-dB SNDR
and 50% BER. Stage 1 alone is a noisy first-order quantizer; its 12% EVM
matches the independent scalar result and does not imply a bit-true fault.
All A/B/C/D paths use the same DDC, LPFs, decimation, FFT, and QAM decisions.
Normalized correlation-vs-lag CSVs are under the two isolation run directories;
correlation results are diagnostic and never inputs to acceptance offsets.

## P3: first incorrect signal and cancellation

The first confirmed mathematical discrepancy is at
`dut.u_mash_backend.g_weighted_mash.u_mash_adapter.u_core.residual_i_vec[15:0]`,
transaction 0, I lane 0, **262890 ps**:

| Actual signal | Historical RTL | Correct accumulator error input |
| --- | ---: | ---: |
| Stage 2 signed I input | +32767 | -32768 |

The old calculation is
`research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_mash11_fs4_multipa_tx.sv:126`:
`sat_residual(delayed_x, q1)`. It subtracts a +/-32767 decoded level from
instantaneous input and clips the result. Stage 2 needs the Stage 1 fractional
accumulator state, not instantaneous x-q1. All 336,448 component samples were
checked: 336,438 differ from the independent centered accumulator state, and
the old subtraction has 139,878 clipping events.

For unsigned EFM residue r1, q1 = x + r1(previous) - r1. Feed
`r1 - 32768` into Stage 2. Then the 1:2 weighted output obeys
`q1 + q2 - q2(previous) = x - (1-z^-1)^2 r2`; the centering constant cancels.
A separate integer identity test checks this relation without saturation.

The corrected residue is exposed at the same raw-word boundary as q1 in
`tid32_cartesian_fs4_gt_tx.sv:83`. The MASH candidate selects it at
`tid32_mash11_fs4_multipa_tx.sv:110`. Both components match independent
accumulator states exactly; Stage 2 itself also matches an independent scalar
EFM driven by its actual captured input. `first-residual-vcd-witness.json`
records the VCD identifier, SHA256, and signed value at 262890 ps in both runs.

The weighted encoder itself was correct: all 336,448 component reconstructions
match `q1 + q2 - delayed_q2` exactly before and after the residue fix. The
corrected capture has zero Config ID, Reset Epoch, Frame Start/End or Tail
mismatches. Detailed samples and timestamps are in `cancellation_samples.csv`.

A separate real-data control test then exposed q1 alignment around bubbles:
first mismatch at output word **489**, epoch 1, **4181094 ps**. The original
q1 tap was read according to concurrent Stage 1 shifts instead of the Stage 2
transaction being returned. A companion q1 pipeline now follows Stage 2's
accepted-sample delay and raw boundary (`tid32_cartesian_fs4_gt_tx.sv:80`,
`tid32_mash11_fs4_multipa_tx.sv:49`). Dense PA words remain unchanged.

Full OFDM adapter replay now passes 400-cycle output stalls, input bubbles,
STOP/drain/restart, reset with traffic pending, and a complete new-epoch
replay: 5,257 checked PA pairs per full stream, zero mismatches. The failed
96-mismatch run remains under `runs/mash_corrected_control_replay/stress1/`;
final passing runs are under `runs/mash_evidence_controls/`.
This is adapter sequence evidence; the static MASH AXIS top has no software
STOP interface, and there is no physical serializer consuming through stalls.
Dynamic configuration changes across algorithmic frame delay remain unqualified.

## P4: actual RTL PA acceptance

Same seed 281001, eight symbols, RMS .09, 250-MHz bandwidth, unchanged input,
gain, identity DPD and both cubic stages:

| Measurement | Corrected actual RTL PA words |
| --- | ---: |
| EVM RMS | 2.551442% |
| SNDR | 31.864285 dB |
| Uncoded natural-binary BER | 15 / 37,376 = 0.000401327 |
| Independent PA bit-true mismatch | 0 |
| First token transport / steady II | 8 cycles / 1 cycle |
| Output bubbles within captured stream | 0 |
| Overflow error | 0 |
| DPD saturations, all 16 lanes | 0; 5,258 samples counted per lane |
| Corrected residual clipping | 0; centered residue is represented exactly |

All QAM256 values are recovered from the final captured RTL PA0/PA1 pair.
The old reference MASH result of 2.534587% EVM remains historical model evidence;
it was not substituted for these RTL results.

Four enlarged 32-symbol experiments use the same RMS, frontend and receiver:

| Fixed seed | EVM | SNDR dB | Bit errors / bits |
| --- | ---: | ---: | ---: |
| 281001 | 2.533985% | 31.923920 | 33 / 149504 |
| 281003 | 2.529758% | 31.938422 | 48 / 149504 |
| 281007 | 2.496494% | 32.053390 | 35 / 149504 |
| 281009 | 2.531561% | 31.932231 | 30 / 149504 |

Final confirmation at commit `b8dd38d` recompiled all four seeds with every
compiled file SHA256 matching its committed Git blob, including the final
passive probe bench. All PA bytes match the earlier runs; fresh receiver
evaluations reproduce every metric. All four now also have measured zero DPD
saturation, zero output bubbles and zero overflow. See
[data/thermo5-mash-qam-root-cause-20261117/committed-source-confirmation.json](data/thermo5-mash-qam-root-cause-20261117/committed-source-confirmation.json).

Total: **146 / 598,016 bits = 0.000244140625**. All four meet EVM <=3.5%
and SNDR >=29.12 dB. These are fixed-seed digital observations, not a zero-BER
claim or a calibrated physical link prediction.

`measure_mash_raw_psd.py` measures actual weighted PA RF before DDC/LPF with
65,536-point Blackman-window Welch averaging. On the unchanged eight-symbol
run, equal-250-MHz adjacent bands are -19.308 dBc (left), -19.420 dBc (right),
-16.353 dBc combined. Raw PSD CSV and method parameters are retained under
`runs/mash_evidence_raw_psd/`. The existing post-reconstruction-filter proxy
is -28.060 dBc and is explicitly a different measurement. No emissions or
ACLR signoff is claimed. Interpolator saturation counters and calibrated PA/
output-network behavior are not instrumented by this closure.

## Required checks and P5 boundary

- Independent receiver smoke: 5/5 PASS.
- Python reference suite: 69/69 PASS; weighted contract/identity tests: 3/3 PASS.
- Full captured Stage 1 dense/bubble/tail replay: PASS, all samples.
- Legacy PA preservation and corrected full-chain scalar PA miter: PASS.
- Actual-data adapter control replay including reset/restart: PASS.
- Directed XSim causal EF1/Generic, 56 words: PASS after correcting stale
  hierarchy and optional AXI-Lite-only VCD references in the testbench.
- MATLAB vector wrapper produced files but threw on exit-code handling:
  **not counted PASS**. The generated files were consumed by the passing XSim.
- Required VCS regression: **PARTIAL/FAIL**. Initial compilation found stale
  `u_frontend.u_tid` probes and an unguarded AXI-Lite VCD probe. They were fixed.
  The default vector directory then contained EF1/causal vectors for an EF2/
  centered compile; this was recorded as a configuration mismatch. With fresh
  matching EF2/centered vectors, seed1 bit-true PASS; seed2 stops at
  `BUBBLE_COVERAGE` (`interp2_empty_blocked` not hit). That requirement remains
  enabled; no coverage gate was weakened. Later regression tests did not run.
- Icarus full-chain compilation uses `-DSYNTHESIS` because Icarus 12 cannot
  parse the existing SVA. Explicit PA, metadata, count, underflow and overflow
  checks remain enabled. These runs do not establish SVA/formal signoff.

Dedicated MASH UVM integration, complete reset/STOP/AXIS regressions, CDC/RDC,
Formal, functional/code coverage, VCU118 full-top routed PPA and dual 14-Gb/s
GTY remain OPEN. Historical ZU15EG OOC timing is not reused as evidence here.
These open items must be closed before system or physical product signoff.

## Reproduction

Use a fresh checkout of this independent branch and new output directories.
Requirements: Python 3, NumPy, Icarus 12 / vvp. No commercial tool is needed
for the root-cause isolation and digital PA acceptance below.

```bash
export PYTHONPATH="$PWD/dv/uvm/refmodel/python"
export PYTHONDONTWRITEBYTECODE=1
python3 research/thermo5_integration/model/receiver_fs4_smoke.py --output runs/repro_receiver
python3 research/thermo5_integration/model/thermo5_mash_axis_qam.py prepare --run-dir runs/repro_source --seed 281001 --symbols 8 --rms-drive 0.09
python3 research/thermo5_integration/model/run_mash_capture.py --input-run runs/repro_source --output runs/repro_legacy
python3 research/thermo5_integration/model/run_stage1_replay.py --capture runs/repro_legacy --output runs/repro_stage1
python3 research/thermo5_integration/model/audit_mash_qam.py --capture runs/repro_legacy --output runs/repro_legacy_isolation
python3 research/thermo5_integration/model/audit_mash_cancellation.py --capture runs/repro_legacy --output runs/repro_legacy_cancellation
python3 research/thermo5_integration/model/run_mash_capture.py --input-run runs/repro_source --output runs/repro_corrected --correct-residue
python3 research/thermo5_integration/model/audit_mash_qam.py --capture runs/repro_corrected --output runs/repro_corrected_isolation
python3 research/thermo5_integration/model/audit_mash_cancellation.py --capture runs/repro_corrected --output runs/repro_corrected_cancellation --correct-residue
python3 research/thermo5_integration/model/thermo5_mash_axis_qam.py evaluate --run-dir runs/repro_corrected --seed 281001 --symbols 8 --rms-drive 0.09
python3 research/thermo5_integration/model/run_mash_control_regression.py --capture runs/repro_corrected --output runs/repro_controls
python3 research/thermo5_integration/model/run_mash_qam_regression.py --output runs/repro_fixed_seeds --seeds 281001,281003,281007,281009 --symbols 32
python3 research/thermo5_integration/model/measure_mash_raw_psd.py --capture runs/repro_corrected --output runs/repro_raw_psd
python3 -m unittest discover -s dv/uvm/refmodel/python/tests -v
python3 -m unittest discover -s research/thermo5_integration/model -p 'test_*.py' -v
```

For XSim, from Windows in this checkout, generate matching default EF1/causal
vectors and run the same directed test with a unique run label:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\sim\generate_thermo5_sku_vectors.ps1 -OutDir .\runs\uvm_thermo5_i2_d1\vectors -Words 56
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\subsystem\tx_frontend\run_xsim_thermo5_i2_d1_axis.ps1 -VectorDir .\runs\uvm_thermo5_i2_d1\vectors -RunLabel closure_probe_fixed
```

The first command's exit-code-wrapper failure remains a known issue. Exact
VCS matching-vector generation and failing regression reproduction:

```bash
python3 dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py --output-dir runs/repro_ef2_vectors --words 56 --seed 610216 --interp-mode centered_cubic --tidsm-order 2 --step 5120 --frame-start-words 1,15,36 --frame-gains 16384,14336,12288
export VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
make -C dv/uvm/sim thermo5-vcs-regression THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 THERMO5_FIFO_IMPL=generic THERMO5_VECTORS="$PWD/runs/repro_ef2_vectors" THERMO5_OUT="$PWD/runs/repro_vcs"
```

Run that command in the licensed Rocky-8.10 login environment. The complete
actual command arrays, compile source SHA256 values, per-seed metrics,
first VCD witness, and retained evidence hashes are in
[data/thermo5-mash-qam-root-cause-20261117/summary.json](data/thermo5-mash-qam-root-cause-20261117/summary.json),
[evidence-manifest.json](data/thermo5-mash-qam-root-cause-20261117/evidence-manifest.json),
and [first-residual-vcd-witness.json](data/thermo5-mash-qam-root-cause-20261117/first-residual-vcd-witness.json).
Large PA words, CSVs, logs and VCDs remain local and ignored. No automatic
merge into `thermo5` is authorized or performed.

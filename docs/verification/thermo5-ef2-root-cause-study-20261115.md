# Thermo5 EF2 Root-Cause Study (2026-11-15)

## Scope and source

This is an isolated study on `work/vcu118-ab-ppa`, source HEAD
`cc2c3ed5024ee86e244b6e1a4f0fc98b56facd7f`. Product EF2 RTL was not changed.
All new synthesis runs use Vivado 2026.1, part `xcvu9p-flga2104-2L-e`,
`AreaOptimized_high`, `W=16`, 4.571 ns clock, and `PAIR_LOOKAHEAD=0`.
The standalone OOC reports have no I/O delays; they describe the recurrence
path only and are not full-product routed signoff.

## EF2 recurrence and critical path

For each chronological sample, RTL computes `u = x + 2*err1 - err2`, decides
positive only when `u > 0`, subtracts `Q_ONE` for positive or adds `Q_ONE`
otherwise, saturates the result to the signed `(W+4)`-bit state range, then
updates `err2_next=err1` and `err1_next=e`. The following lane consumes that
updated state. The 22-bit arithmetic, quantizer decision, sign-dependent
constant selection, saturation comparison/mux, and feedback state update are
therefore serially repeated across lanes. I and Q have independent recurrences
but share the same long combinational word.

| Channels | Synthesis WNS (ns) | Path delay (ns) | Cell / net (ns) | Logic levels | CARRY8 | LUT | FF | DSP48 | BRAM |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 | -1.409 | 5.962 | 2.046 / 3.916 | 23 | 36 | 311 | 90 | 0 | 0 |
| 4 | -7.193 | 11.746 | 4.094 / 7.652 | 48 | 76 | 702 | 98 | 0 | 0 |
| 8 | -19.648 | 24.201 | 7.465 / 16.736 | 96 | 156 | 1,497 | 114 | 0 | 0 |
| 16 | -43.500 | 48.053 | 16.884 / 31.169 | 205 | 316 | 2,620 | 146 | 0 | 0 |
| 32 E0 | -91.093 | 95.646 | 33.284 / 62.362 | 407 | 636 | 5,301 | 210 | 0 | 0 |
| 32 E1 Pair Lookahead | -67.360 | 71.913 | 24.332 / 47.581 | 296 | 832 | 7,616 | 210 | 0 | 0 |

The new small-channel runs are under `runs/thermo5_ef2_channels{2,4,8,16}_E0_20261115/`.
The 32-lane baselines remain in `runs/thermo5_vcu118_ef2_E0_20261114/` and
`runs/thermo5_vcu118_ef2_E1_20261114/`. The critical endpoints are error-state
registers; the startpoints are prior error-state bits. E0 path delay grows
approximately with the number of chronological lanes. The path is not a
single 22-bit adder: it is the repeated state-dependent arithmetic/decision/
saturation chain. The report does not attribute separate delay to the
saturation comparison/mux. Removing saturation as a timing experiment would
change exact behavior and is not justified by workload observations.

```mermaid
xychart-beta
    x-axis "Chronological lanes" [2, 4, 8, 16, 32]
    y-axis "E0 synthesis path delay (ns)" 0 --> 100
    line [5.962, 11.746, 24.201, 48.053, 95.646]
```

At 32 lanes E1 reduces logic levels by 27.3% and path delay by 24.8%, while
LUT grows 43.7% and CARRY8 grows 30.8%. Its 71.913 ns synthesis path still
misses a 4.571 ns cycle by 67.360 ns. This is not a plausible direct timing
closure route for the current exact architecture. Exact local refactoring may
still reduce area or a small-lane block, but registering lanes without a
state-transfer proof would change the recurrence.

## Saturation reachability

The Python fixed-point recurrence retained the RTL state rails and sign rule.
The explicit W=16 constant-positive-full-scale stream (`x=32767`) first clamps
positive at zero-based index 263 (the 264th sample), matching the reported
state-evolution concern. Over 100,000 samples it clamps 188 times, all
positive. Constant `x=-32768` produced zero clamps. A deterministic 0.99-scale
sinusoid produced 490 clamps in 100,000 samples (250 positive, 240 negative).
A deterministic 64-tone high-PAPR stress proxy and a seeded full-scale random
stream each produced zero clamps over 100,000 samples. The latter two are
stress vectors, not the calibrated product communication workload.

The communication benchmark at
`runs/thermo5_vcu118_ef2_saturation_20261115/communication_workload.json`
ran centered-cubic interpolation, EF2 `STEP=5120`, 20-bit state, QAM256,
8 symbols for seeds 101/307/503, RMS drive 0.10, and reported zero input or
state saturation. Aggregate screening metrics were EVM 2.4724%, SNDR 32.1377
dB, and natural-binary uncoded BER 4.459e-5 (5/112,128 bits). These are model
results, not FPGA measurements or Gray-coded production BER.

The Python run does not prove clamp unreachability under product constraints.
No formal tool was run here, and no saturation branch may be removed. Reset
and backpressure affect which samples advance the recurrence; an RTL directed
simulation for those cases and a constrained Formal proof remain open.

## B Pipeline P0 status

The two prior routed B reports remain intact: Explore WNS/WHS +0.307/+0.028 ns
and RuntimeOptimized +0.249/+0.028 ns. The same-seed test used 56 source words,
seed 1, centered-cubic EF1/STEP=5120, identical frame starts, and identical
AXI-Lite writes. Generic original B and Pipeline B both pass the corrected
testbench scoreboard: 32 source beats, 56 PA outputs, 59 DPD inputs (the 56
data vectors and three centered-cubic frame tails), all four output planes,
and the requested identity DPD image. The first marked DPD input applies the
configuration at 638 ns for original B; each run's complete event timeline
and VCD are retained in its `gate1_*_generic` run directory. No payload,
metadata, or protocol assertion was removed.

The original XPM timeout log remains preserved. Vivado 2026.1's `xpm_fifo.sv`
defines `EN_RDC = EN_ADV_FEATURE[10]`; the prior `USE_ADV_FEATURES="0000"`
disabled `rd_data_count`, which the CDC gearbox uses for its two-entry
prefill gate. XPM writes filled the FIFO but `rd_count` stayed zero, so no
CDC/core handshake could occur. Changing the feature mask to `"0400"` enables
the count; original B XPM and Pipeline B XPM both pass with the same 32/56/59
counts. The PowerShell runner still reports a missing snapshot or returns
without capturing the native XSim output; manually launching XSim from each
run directory produces a complete PASS log and AXIL_TRACE VCD. Pipeline B
XPM is therefore functionally compared for this directed COMMIT case, but
Formal and the requested full reset, STOP/restart, and sustained backpressure
matrix remain open.

The no-saturation, shared-arithmetic, exact 2/4-sample prediction synthesis
experiments and new MASH/polyphase/short-feedback communication models were
not completed. Existing E0/E1 and 2/4/8/16-lane measurements remain the only
new EF2 hardware evidence in this study. No product EF2 RTL changed.

## Architecture decision and next gates

Do not expand exact Pair Lookahead or a 4-sample branch tree to 32 lanes
without an area/depth screen: E1 already shows substantial area growth while
remaining far from timing. A shared arithmetic implementation should first
prove a 2/4-lane state and output miter over `u=0`, both saturation rails,
reset and stall, then synthesize with a hard stop if LUT growth exceeds 15%
without at least a 20% delay reduction.

For a communication-equivalent second-order candidate, a pipelined MASH 1-1
with explicit digital cancellation is the most testable first model: its
first-order loops have short local feedback, while cancellation can be
registered between blocks. It will need a new quantization/NTF and fixed-point
stability analysis; output coding and four-plane mapping are not yet proven.
Polyphase/block DSM is the second candidate, but its exact state handoff
between phases must be derived before RTL. The repository survey records
high-speed references and their limits in `docs/Cartesian_DSM_Survey.md`,
including the 32-pipeline 5-GSa/s Wang et al. FPGA DSM and Xu et al. 2025
SMASH state propagation. No new MASH/polyphase model, EVM/SNDR/BER/PSD/adjacent
leakage, FPGA resource estimate, or routed result was produced in this turn;
there is no evidence yet that a new architecture beats Cubic+EF1 at the link
level or merits its hardware cost.

## Follow-up: feedback-path diagnostics and new-DSM model screen

The local experiment parameters `SATURATE_STATE` (default 1) and
`SHARED_ERROR_ARITH` (default 0) are diagnostic-only controls. Vivado 2026.1
VCU118 OOC synthesis used the same 4.571 ns clock, `AreaOptimized_high`, W=16
and lane counts 2/4/8. The no-saturation rows are intentionally not an exact
implementation. The shared-arithmetic rows retain saturation and exact
quantizer behavior but did not show an area/timing benefit.

| Variant | Lanes | LUT | FF | CARRY8 | Path (ns) | Cell / net (ns) | Levels | WNS (ns) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| E0 exact | 2 | 311 | 90 | 36 | 5.962 | 2.046 / 3.916 | 23 | -1.409 |
| No saturation diagnostic | 2 | 170 | 90 | 24 | 3.459 | 1.399 / 2.060 | 15 | +1.095 |
| Shared arithmetic exact | 2 | 333 | 90 | 40 | 6.193 | 1.978 / 4.215 | 22 | -1.640 |
| E0 exact | 4 | 702 | 98 | 76 | 11.746 | 4.094 / 7.652 | 48 | -7.193 |
| No saturation diagnostic | 4 | 338 | 98 | 48 | 6.435 | 2.286 / 4.149 | 27 | -1.881 |
| Shared arithmetic exact | 4 | 715 | 98 | 80 | 11.673 | 3.935 / 7.738 | 43 | -7.120 |
| E0 exact | 8 | 1,497 | 114 | 156 | 24.201 | 7.465 / 16.736 | 96 | -19.648 |
| No saturation diagnostic | 8 | 668 | 114 | 96 | 12.414 | 4.022 / 8.392 | 51 | -7.860 |
| Shared arithmetic exact | 8 | 1,423 | 114 | 160 | 23.450 | 7.794 / 15.656 | 93 | -18.897 |

The no-saturation synthesis reduces total path delay by 2.503/5.311/11.787 ns
at 2/4/8 lanes. This is a whole-cone remapping delta, not an independently
measured saturation-cell delay. The exact shared-arithmetic candidate is
slower at 2 lanes, effectively unchanged at 4 lanes, and improves 0.751 ns at
8 lanes while using 5.0% more LUT and 2.6% more CARRY8 than E0. That does not
meet the earlier 20% delay-reduction / 15% LUT-growth screening gate. The
22-bit feedback arithmetic remains the critical serial dependency; removing
saturation alone does not make four or eight chronological lanes meet 4.571 ns.

The new model runner is
`dv/uvm/refmodel/python/benchmark_thermo5_parallel_dsm_v2.py`. It compares
Legacy EF1, Legacy EF2, a MASH 1-1 candidate followed by explicit five-level
bit reduction, and 32 independent polyphase second-order loops. The latter's
scalar-stream NTF is `(1-z^-32)^2`, not the Legacy `(1-z^-1)^2`; neither new
candidate is bit-true equivalent to Legacy EF2. Both share the same centered
cubic interpolator, Q1.15 input, STEP=5120 input scaling, four-plane Fs/4
decode, RMS drive 0.09 and 4097-tap receiver. PA is disabled. EVM/SNDR/BER,
PSD and adjacent-band proxy are software-model results only, not FPGA or RF
measurements. BER uses natural-binary axis labels and is uncoded.

The held-out QAM16/64/256 matrix uses four fixed seeds and eight OFDM symbols
per seed; its final summary is stored in
`runs/thermo5_parallel_dsm_v2_20261115/summary_all_qam.csv`. Saturation counts
are model diagnostics; they do not prove formal state reachability. A
candidate that materially trails EF1/EF2 on the common receiver is No-Go for
RTL under this screen. Short-feedback MASH cancellation and a
state-transfer-correct block predictor remain future research, not validated
architectures.

| QAM | Candidate | EVM (%) | SNDR (dB) | Uncoded BER | Adjacent proxy (dBc) |
|---:|---|---:|---:|---:|---:|
| 16 | Cubic + EF1 | 3.585 | 28.910 | 0 | -24.088 |
| 16 | Cubic + Legacy EF2 | 2.482 | 32.105 | 0 | -25.921 |
| 16 | Cubic + MASH bit-reduced | 41.176 | 7.707 | 0.16678 | -7.873 |
| 16 | Cubic + 32-phase block EF2 | 98.971 | 0.090 | 0.45152 | -5.542 |
| 64 | Cubic + EF1 | 3.613 | 28.844 | 8.92e-6 | -24.041 |
| 64 | Cubic + Legacy EF2 | 2.489 | 32.081 | 0 | -25.803 |
| 64 | Cubic + MASH bit-reduced | 41.053 | 7.733 | 0.28739 | -7.827 |
| 64 | Cubic + 32-phase block EF2 | 98.981 | 0.089 | 0.47267 | -5.474 |
| 256 | Cubic + EF1 | 3.595 | 28.886 | 0.005672 | -23.894 |
| 256 | Cubic + Legacy EF2 | 2.484 | 32.096 | 0.000241 | -25.630 |
| 256 | Cubic + MASH bit-reduced | 41.528 | 7.633 | 0.34370 | -7.806 |
| 256 | Cubic + 32-phase block EF2 | 98.890 | 0.097 | 0.48539 | -5.542 |

These results make both model candidates a No-Go for RTL as currently defined:
MASH bit reduction is about 41% EVM with 7.6–7.7 dB SNDR, and the block
candidate is near 99% EVM with roughly 0.09 dB SNDR. Both lose 16–20 dB of
adjacent-band proxy against EF1. The large error is consistent with the
candidate output/cancellation normalization and changed NTF; these candidates
have not been gain-matched or optimized per architecture beyond the receiver's
common global complex gain. Do not interpret zero state-saturation count as
stability proof. No PA, BER coding, FPGA resource, latency, power, or routed
timing results exist for either candidate. A fair next step is to repair the
MASH cancellation/output scaling analytically and re-screen it before RTL;
the present polyphase definition should be discarded or re-derived with a
correct block-boundary state transfer and four-plane level mapping.

## MASH recovery update (2026-11-16)

The follow-up recovery found two independent software-path errors in the
initial communication-equivalent MASH candidate: the stage-two input sign was
reversed, and the direct RF stream omitted the odd-lane Fs/4 sign phase. The
stage-two sign is now covered by an exact error-state cancellation identity;
the RF sequence now follows `I,-Q,-I,+Q`. With both corrected, the historical
dual-PA 1:2 weighted output has QAM16/64/256 EVM 2.507/2.516/2.521%, SNDR
32.017/31.987/31.968 dB and adjacent-band proxy -25.535/-25.455/-25.173 dBc
on the same four held-out seeds. This is near Legacy EF2 and better than EF1.

The prior four-plane bit-reduced result remains poor (QAM256 EVM 36.543%).
The remaining first mismatch is its mapping of MASH `{-3,-1,+1,+3}` into
equal-weight four-plane `{-4,-2,+2,+4}` levels. The recovered historical
architecture uses two weighted PA streams and is not drop-in compatible with
the product's four equal planes. It is the only selected research candidate,
but RTL remains blocked on an encoding that preserves the four-plane contract.
Full historical source, checks and model-only results are in
`docs/verification/thermo5-historical-mash11-recovery-20261116.md` and
`runs/thermo5_parallel_dsm_v2_20261116_mash_weighted_fs4/`.

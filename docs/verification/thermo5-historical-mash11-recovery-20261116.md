# Thermo5 Historical MASH 1-1 Recovery (2026-11-16)

## Source recovery

The earliest complete Git snapshot containing the 32-lane two-stage TID-MASH
RTL, MATLAB oracle, bit-true vector generator, simulation testbench, and OOC
Tcl is commit `7b5c2a853f04c1a5073a9a84e84c64982f922d65` (`feat: add thermo5
frontend and serializer verification`). The focused single-lane study branch
was created at `f7e3fd47e08fd2a59047154e8846bddff763f6f4`; the later retirement
commit `798741357c063430029fdfb4ec53ae14008816da` removed the experimental
files from the then-current branch. The current isolated branch contains the
archived OOC report directory as local ignored output, but Git does not track
that output at either source commit. The OOC report itself records Vivado
2024.1 and the Windows run path.

Recovered source paths at `7b5c2a8`:

- `rtl/tx_bandpass_if/tid32_mash11_fs4_multipa_tx.sv`
- `rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv`
- `matlab/tx_bandpass_if/tid_mash11_pipelined_step.m`
- `matlab/tx_bandpass_if/tid_pipelined_first_order_step.m`
- `matlab/tx_bandpass_if/run_256qam_tid32_ofdm_demod.m`
- `matlab/tx_bandpass_if/gen_tid32_mash11_bittrue_vectors.m`
- `verif/block/bp_dsm/tb/tb_tid32_mash11_fs4_multipa_tx_bittrue.sv`
- `syn/run_ooc_tid32_mash11_fs4_multipa_tx.tcl`
- `syn/rtl/tid32_mash11_fs4_multipa_tx_ooc.sv`
- `verif/scripts/run_xsim_tid32_mash11_fs4_multipa_tx.ps1`

The RTL is a MASH 1-1 cascade built from two first-order 32-channel Cartesian
TID modulators. Stage 2 receives the delayed first-stage signed residual
`x-q1`; the delay aligns the TID stage latency. Each TID stage uses the
registered pre-sum matrix and adjacent-MSB differential output, so its
combinational feedback path is not a 32-lane serial recursion. The MATLAB
oracle preserves separate stage-one and stage-two one-bit streams. In its
communication model it performs digital cancellation and uses two analog PA
weights to represent `q1 + q2 - z^-1 q2`, whose levels are `{-3,-1,+1,+3}`.

This is not a MASH output followed by Bit Reduction. It is not the four-equal-
weight Thermo5 four-plane interface: the historical model assumes a two-bit,
1:2 weighted PA combination. The historical RTL top exposes two 64-bit PA
stage words. Compatibility therefore requires either the original two-PA
contract or a separately proven amplitude/encoding conversion; plugging the
two streams into four equal planes changes the transfer function.

The 256-QAM MATLAB model has an OFDM-domain branch named `tid_mash11`, uses a
zero guard, 1056-sample first-stage TID latency plus the cascaded alignment,
performs 3.5-GHz Fs/4 downconversion and filtering, and reports EVM/SNDR/ACLR.
No committed run result or fixed communication test vectors were found for
that branch. The committed bit-true generator uses 128 vectors of random
signed samples in [-12000,12000], and the SystemVerilog testbench compares
both complete PA output words. This proves that a reproducible RTL oracle
contract existed, but does not itself prove the OFDM performance claims or
modern product equivalence.

## Archived OOC evidence

The local archived report identifies part `xczu15eg-ffvb1156-2-i`, Vivado
2024.1, 218.75 MHz, routed WNS `+1.315 ns`, WHS `+0.029 ns`, and zero setup and
hold failing endpoints. Utilization is 14,276 CLB LUTs, 13,439 CLB registers,
1,012 CARRY8, 0 DSP and 0 BRAM tiles. The Tcl applies only a reset false path,
but has no input or output delay constraints. It is OOC evidence on ZU15EG,
not current VCU118 implementation, product integration, or board signoff.
`Fmax_est_MHz=307.08` in its CSV is a post-route slack-derived estimate, not a
separately timed routed clock result.

The report files are retained at
`syn/out/tid32_mash11_fs4_multipa_tx_ooc_xczu15eg_ffvb1156_2_i_218p75mhz_20260916_090822/`.

## Current MASH model diagnosis

The first Python candidate differed from the historical MATLAB state equation:
it fed `-e1` into stage 2. The historical oracle feeds the signed residual
`e1=x-q1` itself. For first-order quantizers
`q1=x-(1-z^-1)e1` and `q2=e1-(1-z^-1)e2`, so
`q1+(1-z^-1)q2=x-(1-z^-1)^2 e2`. An exact integer-state test checks this
identity over zero, positive/negative inputs and quantizer ties; all states
remain unsaturated for this directed test. The `u=0` rule is `q=-Q` (`u>0`
selects `+Q`). Replacing the erroneous negative stage-two input improves the
four-plane-bit-reduced QAM256 result from 41.5% to 36.5% EVM but does not close
the communication gap.

A second first-failure was in the RF boundary. The historical `tid_mash11`
receiver's `legacy_iq` default bypasses Fs/4; its optional `fs4_ddc` branch
formed interleaved `I,-Q` without the odd-lane `-I,+Q` phase. That malformed
RF sequence produces approximately 100% EVM in an independent direct-RF
replay. Applying the documented four-sample sequence `I,-Q,-I,+Q` before the
same DDC and RX filters restores the result.

With corrected feedback polarity and Fs/4 phase, the historical two-PA 1:2
weighted MASH output produces the following model-only held-out results. The
four seeds, eight OFDM symbols, 4097-tap RX, RMS drive 0.09, centered-cubic
input and no-PA condition match the prior candidate screen.

| QAM | EVM (%) | SNDR (dB) | Uncoded BER | Adjacent proxy (dBc) |
|---:|---:|---:|---:|---:|
| 16 | 2.507 | 32.017 | 0 | -25.535 |
| 64 | 2.516 | 31.987 | 0 | -25.455 |
| 256 | 2.521 | 31.968 | 2.81e-4 | -25.173 |

Compared with Cubic+EF1, weighted MASH improves EVM by about 1.1 percentage
points and improves adjacent-band proxy by 0.3–1.4 dB. It is close to
Cubic+Legacy EF2: QAM256 is 0.037 percentage points worse in EVM, 0.127 dB
lower in SNDR and 0.46 dB worse in adjacent-band proxy. The equal-weight
four-plane bit-reduced candidate remains at 36.5% EVM because mapping
`{-3,-1,+1,+3}` to `{-4,-2,+2,+4}` changes the level ratio. This is the first
identified error after cancellation: the current four-plane reduction is not
an equivalent encoding of the historical weighted two-PA output.

Per-stage Q1, Q2, uncancelled Q1+Q2 and cancelled output PSDs for QAM256 seed
281001 are saved in `runs/thermo5_parallel_dsm_v2_20261116_mash_stages/psd.csv`.
The four-seed aggregate is in
`runs/thermo5_parallel_dsm_v2_20261116_mash_weighted_fs4/summary.csv`.

The recovered weighted dual-PA MASH is the sole research candidate, and it
passes the communication threshold against EF1. It does not yet satisfy the
four-equal-plane product contract. Keep current product RTL unchanged and
derive/test a four-plane mapping before RTL; if equal-weight planes cannot
retain the level ratio, the product must explicitly support weighted PA
branches or this candidate is incompatible. No new FPGA result is claimed.

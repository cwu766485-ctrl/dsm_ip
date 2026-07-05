# Metric Definitions

This project uses two metric domains. They must not be mixed in reports.

## Primary IP Metrics: Native Complex Baseband

This is the primary metric domain for the reusable DSM communication IP.

```text
baseband I/Q
  -> interpolation/filter
  -> DSM_I and DSM_Q
  -> native complex output y_bb = yI + jQ
  -> low-pass reconstruction / decimation
  -> alignment to the original baseband
  -> EVM / SNDR / ACLR
```

Purpose:

- evaluate DSM algorithm quality
- compare LPDSM, EFDSM, MASH, and multibit variants
- verify MATLAB vs RTL behavior
- avoid assuming a specific DAC, PA, RF filter, board, or receiver

Use these columns as primary conclusions:

```text
native_EVM_percent
native_SNDR_dB
ACLR_avg_dBc
```

For current handoff and RTL comparison, the already verified single-bit and
native MASH outputs remain the reference.

MATLAB code paths:

```text
matlab/scripts/eval_p0_seven_metrics_from_xsim.m
  -> reads RTL XSim dumps for the seven current DSM algorithms
  -> lp_reconstruct_and_decimate(...)
  -> lp_align_and_ls_gain(...)
  -> lp_discard_settle_pair(...)
  -> lp_calc_sndr_evm(...)
  -> lp_calc_acpr_aclr_from_psd(...)

matlab/cartesian_dsm/DSM_2nd/lp/core/lp_reconstruct_and_decimate.m
  -> low-pass reconstruction and OSR decimation

matlab/cartesian_dsm/DSM_2nd/lp/core/lp_align_and_ls_gain.m
  -> delay alignment and least-squares gain correction

matlab/cartesian_dsm/DSM_2nd/lp/core/lp_calc_sndr_evm.m
  -> SNDR and RMS EVM calculation

matlab/cartesian_dsm/DSM_2nd/lp/core/lp_calc_acpr_aclr_from_psd.m
  -> adjacent-channel power / ACLR calculation

matlab/models/interp_frontend_system_eval.m
  -> reconstruct_native_iq(...)
  -> align_and_gain(...)
  -> lp_calc_sndr_evm(...)
  -> aclr_local(...)

matlab/cartesian_dsm/dsm_multibit/run_dsm_multibit_metrics.m
  -> exploratory native EVM/SNDR for multibit DSM MATLAB models
```

## Diagnostic System Metrics: RF-Recovered

This metric domain starts from the real Fs/4 output stream and tries to recover
baseband through an assumed RF chain.

```text
native I/Q DSM output
  -> Fs/4 merge: +I, +Q, -I, -Q
  -> real RF stream
  -> assumed RF band-pass / DAC / PA / reconstruction path
  -> downconversion
  -> baseband recovery
  -> EVM / SNDR / ACLR
```

Purpose:

- study sensitivity to the output chain
- evaluate assumed RF reconstruction filters
- compare possible board/DAC/PA assumptions
- diagnose whether RF recovery assumptions are dominating the result

Use these columns only as diagnostic metrics unless the RF chain is explicitly
defined:

```text
RF_recovered_EVM_percent
RF_recovered_SNDR_dB
```

MATLAB code paths:

```text
matlab/models/interp_frontend_system_eval.m
  -> fs4_duc(...)
  -> apply_ideal_rf_bandpass(...)
  -> reconstruct_from_fs4(...)
  -> align_and_gain(...)
  -> lp_calc_sndr_evm(...)
  -> aclr_local(...)

matlab/cartesian_dsm/DSM_2nd/lp/core/stage2_dsm_and_metrics_v3.m
  -> forms the Fs/4 RF sequence
  -> computes RF-domain ACPR around the carrier
  -> includes RF downconversion / equivalent-filter diagnostic helpers
```

These results depend on assumptions about:

- DAC or 1-bit output driver
- RF reconstruction/band-pass filter
- PA model
- board/package/channel response
- receiver/downconversion model

## Improving RF-Recovered Metrics

RF-recovered metrics can be improved, but the improvement path is mostly a
system-model calibration problem rather than a DSM-core-only problem.

Required assumptions:

- exact Fs/4 merge convention and sample timing
- RF carrier, occupied bandwidth, and adjacent-channel definition
- DAC or output-driver pulse shape
- reconstruction or band-pass filter response
- receiver downconversion phase, decimation phase, and gain alignment
- optional PA and channel model

Recommended workflow:

```text
1. validate the chain with no DSM
2. add single-bit DSM and compare native vs RF-recovered metrics
3. sweep RF band-pass bandwidth and transition band
4. add multibit DSM
5. only then add DAC/PA/phase-noise impairments
```

If the no-DSM chain cannot recover the original baseband with good EVM/SNDR,
the RF-recovered result is not a valid DSM quality indicator.

## Why a 0/1 Output Does Not Have One Unique Metric

The final DSM output can be a digital switching stream such as `0/1`, `-1/+1`,
or a signed multibit code. That does not make EVM/SNDR independent of the
reconstruction method.

The bitstream is a sampled switching waveform whose useful signal is encoded in
average value, spectrum, and noise shaping. To measure communication quality, a
receiver or analysis script must define how that switching waveform is converted
back to a baseband-equivalent waveform. Different valid assumptions can produce
different EVM/SNDR:

- low-pass reconstruction of separate I/Q DSM streams
- Fs/4 real RF merge followed by band-pass filtering and downconversion
- different reconstruction-filter bandwidths and transition bands
- different decimation phase, delay alignment, and gain normalization
- different DAC pulse shape, board response, PA model, and receiver filter

Therefore, the metric domain is part of the specification. For this reusable
digital IP, native complex-baseband metrics are the primary IP metrics because
they test the digital DSM/interpolation behavior without assuming a specific
analog/RF output chain. RF-recovered metrics are useful diagnostics only after
the downstream RF assumptions are fixed.

## Robustness Target

For a reusable communication IC IP, the correct goal is not to guarantee good
EVM/SNDR for every possible downstream analog chain. That is impossible.

The IP should instead:

- provide strong native-domain EVM/SNDR/ACLR
- keep quantization noise shaped away from the intended signal band
- expose configurable gain, interpolation, DSM mode, and status counters
- document output spectral assumptions so DAC/RF designers can filter it
- provide diagnostic RF-chain models for likely integration scenarios

## Summary of two Metric Domains

Use this wording in project reports:

```text
Primary IP quality is evaluated in the native complex-baseband domain using
EVM, SNDR, and ACLR after low-pass reconstruction, decimation, and alignment.
RF-recovered EVM/SNDR is reported only as a diagnostic system metric under an
explicit assumed RF reconstruction chain.
```

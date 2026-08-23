# MATLAB

This directory contains the MATLAB reference and analysis code used by the DSM
IP handoff.

## Directory Layout

| Path | Purpose |
|---|---|
| `bittrue/` | Fixed-point DSM reference models and RTL/XSim dump comparison. This is the current source of truth for the seven RTL DSM algorithms. |
| `models/` | Executable algorithm models for new IP blocks before RTL implementation, including interpolation frontend and system-level metric experiments. |
| `dpd/` | MATLAB-only DPD and PA-model baselines for the planned AI-assisted TX calibration path. |
| `tx_analog_iq/` | Low-pass I/Q DSM plus external analog-IQ-upconversion route notes. |
| `tx_bandpass_if/` | Fixed-point models and metrics for the separate full-precision IF plus BPDSM route. |
| `../ads/` | ADS circuit-level low-power DPA baseline and its MATLAB PWL-stimulus handoff. |
| `scripts/` | User-facing entry scripts for vector export, metric evaluation, calibration sweeps, and plots. |
| `cartesian_dsm/` | Cartesian I/Q DSM algorithm workspace, including retained legacy flow, single-bit wrappers, and exploratory multibit models. |
| `out/` | Generated CSV, MAT, PDF, and PNG result files |
| `path_setup.m` | Adds the retained MATLAB source folders to the MATLAB path |

Fixed-point DSM reference behavior lives under `bittrue/`; new pre-RTL
algorithm models live under `models/`; the retained waveform-generation and
metric helpers live under `cartesian_dsm/DSM_2nd/lp/core/`.
Single-bit and exploratory multibit Cartesian DSM models live under
`cartesian_dsm/dsm_singlebit/` and `cartesian_dsm/dsm_multibit/`.

## Tree

```text
matlab/
  README.md
  path_setup.m

  bittrue/
    p0_dsm_bittrue.m
    p0_compare_rtl_xsim.m
    README.md

  scripts/
    entry_p0_export.m
    entry_p0_eval.m
    entry_p0_eval_seven.m
    entry_p0_bittrue_check.m
    entry_plot_qam16_64_256.m
    entry_interp_frontend_model.m
    entry_interp_frontend_system_eval.m
    entry_interp_frontend_calibrate_system.m
    entry_dpd_memoryless_baseline.m
    entry_dpd_fixed_baseline.m
    entry_dpd_bittrue_check.m
    entry_ai_assisted_dpd_sweep.m
    entry_dpd_memory_pa_observation_sweep.m
    entry_export_ads_low_power_dpa_stimulus.m
    entry_export_dpd_coeff_header.m
    export_p0_rom_mem.m
    export_p1_rom_mem.m
    eval_p0_seven_metrics_from_xsim.m
    eval_profile_seven_metrics_from_xsim.m
    run_p0_eval_from_xsim.m
    run_p0_table52_compare.m
    plot_qam16_64_256_compare.m

  models/
    interp_frontend_float.m
    interp_frontend_fixed.m
    interp_frontend_system_eval.m
    interp_frontend_calibrate_system.m
    README.md

  dpd/
    run_dpd_memoryless_baseline.m
    run_dpd_fixed_baseline.m
    run_ai_assisted_dpd_sweep.m
    run_dpd_memory_pa_observation_sweep.m
    export_dpd_coeff_header.m
    prepare_dpd_bittrue_vectors.m
    compare_dpd_rtl_xsim.m
    README.md

  tx_analog_iq/
    analog-IQ transmitter boundary notes

  tx_bandpass_if/
    initial BP EFDSM fixed-point reference and route notes

  cartesian_dsm/
    dsm_singlebit/
      dsm_singlebit_model.m
      README.md
    dsm_multibit/
      dsm_multibit_model.m
      run_dsm_multibit_smoke.m
      run_dsm_multibit_metrics.m
      README.md
    DSM_2nd/
      README.md
      lp/
        path_setup.m
        README.md
        core/
          low-pass DSM waveform generation, reconstruction, metrics,
          legacy comparison, and RF diagnostic helper scripts

  out/
    generated outputs only; this folder is ignored by Git
```

The retained legacy file names under `cartesian_dsm/DSM_2nd/lp/core/` are kept
for reproducibility. New top-level work should use the cleaner `entry_*` scripts
under `matlab/scripts/`. Board captures and vendor-provided collateral are not
part of this public repository.

## Setup

From MATLAB:

```matlab
cd matlab
path_setup
```

## Bit-True RTL Comparison

Run after XSim has produced `verif/out_xsim_p0/`:

```matlab
T = p0_compare_rtl_xsim();
```

This compares LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, and MASH22
sample-for-sample against the RTL dumps.

Current single-bit/native RTL algorithms:

```text
LPDSM
LPDSM2
EFDSM
EFDSM2
MASH11
MASH111
MASH22
```

## Vector Export and Metrics

Common entry scripts:

```matlab
entry_p0_export
entry_p0_eval
entry_p0_eval_seven
entry_p0_bittrue_check
entry_plot_qam16_64_256
```

Wrapper scripts in the repository root call these entry points through
`scripts/run_matlab_*.cmd`.

## Interpolation Frontend Model

Run the pre-RTL interpolation frontend model:

```matlab
interp_frontend_float
interp_frontend_fixed
```

or use the entry script:

```matlab
entry_interp_frontend_model
```

This exports frequency-response summaries, fixed-point metrics, coefficients,
and bit-true vectors to:

```text
matlab/out/interp_frontend
```

The fixed-point metrics in this frontend model measure fixed-point error
against the floating-point reference only. They are not end-to-end communication
SNR/EVM results.

## ADS Low-Power DPA Stimulus

The circuit-level ADS baseline consumes the same 100 MHz LPDSM2 x32 Fs/4
one-bit stream used by the behavioral DPA endpoint. Generate the PWL sources
with:

```matlab
S = export_ads_low_power_dpa_stimulus('n_symbols', 8, 'n_samples', 256, 'seed', 211);
```

It writes generated files below `ads/low_power_dpa/data/`. The schematic
topology and electrical boundary are documented in `ads/README.md`; this is
not an RTL bit-true or physical-PA signoff flow.

After ADS exports `ads_observation.csv`, use
`analyze_ads_low_power_dpa_result` to summarize DC/output power and switching
waveform trends at the current 100 ohm differential pre-balun measurement
plane. The model must include the balun/matching network before interpreting
the result as a 50 ohm single-ended output.

Run the system-level behavioral metric check:

```matlab
entry_interp_frontend_system_eval
```

This produces `matlab/out/interp_frontend/interp_frontend_system_metrics.csv`.

Run the reduced calibration sweep:

```matlab
entry_interp_frontend_calibrate_system
```

## DPD Baseline

Run the first MATLAB-only DPD baseline:

```matlab
entry_dpd_memoryless_baseline
entry_dpd_fixed_baseline
```

This generates an OFDM/QAM source, applies a behavioral memoryless PA, trains a
memoryless polynomial DPD with indirect learning, quantizes the DPD to a
fixed-point Q1.15/Q2.14 datapath, and compares PA-only vs DPD-plus-PA
EVM/SNDR/ACLR.

For the staged LPDSM2 DPA endpoint, run:

```matlab
path_setup;
run('scripts/entry_lpdsmdpa_bpf_dpd_staged.m');
```

This reports `ideal_bb`, `linear`, `am_am`, `am_pm`, `memory`, and `noise`
cumulatively. The `linear` stage still exercises the one-bit DSM and modeled
Fs/4 observation path, but disables DPA impairments and observation noise. The
prior all-in-one result is retained as `legacy_full` diagnostic evidence and
must not be used as a communication-capability claim.

Generated outputs:

```text
matlab/out/dpd/dpd_memoryless_baseline.csv
matlab/out/dpd/dpd_memoryless_baseline.md
matlab/out/dpd/dpd_memoryless_baseline.mat
matlab/out/dpd/dpd_fixed_baseline.csv
matlab/out/dpd/dpd_fixed_baseline.md
matlab/out/dpd/dpd_fixed_baseline.mat
matlab/out/dpd/bittrue
```

Run DPD RTL/MATLAB bit-true comparison after XSim:

```matlab
entry_dpd_bittrue_check
```

Run the software calibration sweep:

```matlab
entry_ai_assisted_dpd_sweep
```

This sweep evaluates multiple PA/input/OFDM scenarios, trains deterministic
polynomial and LUT DPD corrections, quantizes them to the RTL Q2.14 format,
and exports AXI-Lite coefficient words for `DPD_C1`, `DPD_C3`, `DPD_C5`, and
LUT entries.

Generated outputs:

```text
matlab/out/dpd/ai_assisted_dpd_sweep.csv
matlab/out/dpd/ai_assisted_dpd_sweep.md
matlab/out/dpd/ai_assisted_dpd_sweep.mat
```

## Exploratory Multibit DSM

The multibit models are MATLAB-only exploration models. They are not RTL
bit-true yet.

Run a smoke check:

```matlab
T = run_dsm_multibit_smoke
```

Run native complex-baseband EVM/SNDR:

```matlab
T = run_dsm_multibit_metrics
```

The generated CSV is:

```text
matlab/out/dsm_multibit/dsm_multibit_metrics.csv
```

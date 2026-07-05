# Cartesian DSM Multibit Models

This folder contains exploratory multibit DSM MATLAB models. These models are
not yet RTL bit-true. They are used to study quantizer resolution, output
levels, and communication metrics before RTL implementation.

Supported algorithms:

- LPDSM multibit
- LPDSM2 multibit
- EFDSM multibit
- EFDSM2 multibit
- MASH11 multibit
- MASH111 multibit
- MASH22 multibit

Run:

```matlab
y = dsm_multibit_model(x, "ef2", 4);
T = run_dsm_multibit_smoke;
M = run_dsm_multibit_metrics;
C = run_dsm_single_multi_metric_compare;
BT = compare_multibit_rtl_xsim;
```

`nbits` is the quantizer resolution. The output is a signed integer sequence.
For example, `nbits = 4` uses a local quantizer range from `-7` to `+7`.
MASH combiner outputs can exceed this range because their final output is a
noise-cancellation sum of multiple quantizer streams.

## Current 4-Bit Native Metric Check

Command:

```matlab
cd matlab
path_setup
M = run_dsm_multibit_metrics
```

Result from the current MATLAB exploratory models:

| Algorithm | Min code | Max code | Levels seen | Native EVM (%) | Native SNDR (dB) |
|---|---:|---:|---:|---:|---:|
| LPDSM | -3 | 3 | 7 | 0.21019 | 53.548 |
| LPDSM2 | -4 | 4 | 9 | 0.18320 | 54.741 |
| EFDSM | -3 | 3 | 7 | 0.21019 | 53.548 |
| EFDSM2 | -4 | 4 | 9 | 0.18320 | 54.741 |
| MASH11 | -4 | 4 | 9 | 0.18320 | 54.741 |
| MASH111 | -5 | 5 | 11 | 0.31598 | 50.007 |
| MASH22 | -9 | 9 | 19 | 0.57893 | 44.748 |

Interpretation:

- all seven models execute and produce multilevel outputs
- LPDSM/EFDSM/MASH11 are stable in this narrowband native check
- MASH111 and MASH22 currently need scaling/noise-cancellation review before
  being promoted to RTL
- these numbers are not RF-recovered metrics and are not RTL signoff metrics

## Single-Bit vs Multibit Metric Compare

Run:

```matlab
cd matlab
path_setup
C = run_dsm_single_multi_metric_compare
```

This writes:

```text
matlab/out/dsm_multibit/dsm_single_multi_metric_compare.csv
```

The compare script reports both native and RF-recovered diagnostic columns.
Current RF-recovered values are not used as IP signoff because the ideal Fs/4
recovery model is not yet calibrated against a concrete DAC/RF reconstruction
chain. Use native-domain metrics for algorithm comparison until the RF chain is
explicitly specified.

## RTL Bit-True Compare

Run XSim first:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_multibit.ps1
```

Then run MATLAB:

```matlab
cd matlab
path_setup
BT = compare_multibit_rtl_xsim
```

Current default `nbits=4` result:

| Algorithm | Samples | Mismatches |
|---|---:|---:|
| LPDSM multibit | 65536 | 0 |
| LPDSM2 multibit | 65536 | 0 |
| EFDSM multibit | 65536 | 0 |
| EFDSM2 multibit | 65536 | 0 |
| MASH11 multibit | 65536 | 0 |
| MASH111 multibit | 65536 | 0 |
| MASH22 multibit | 65536 | 0 |

# DPD Models

This folder contains MATLAB models for the planned AI-assisted TX calibration
path. These models do not replace the DSM datapath. They establish the
conventional DPD and PA-model baseline before RTL implementation.

## Current Model

| File | Purpose |
|---|---|
| `run_dpd_memoryless_baseline.m` | Generates an OFDM/QAM source, applies a behavioral memoryless PA, trains a memoryless polynomial DPD with indirect learning, and compares PA-only vs DPD+PA EVM/SNDR/ACLR |
| `run_dpd_fixed_baseline.m` | Quantizes the learned polynomial DPD to signed Q2.14 coefficients and applies an integer Q1.15 datapath matching the first RTL DPD block |
| `run_ai_assisted_dpd_sweep.m` | Runs a multi-scenario software calibration sweep, refines polynomial DPD coefficients with fixed-point coordinate search, exports polynomial/LUT DPD metrics, and emits AXI-Lite coefficient words |
| `run_dpd_memory_pa_observation_sweep.m` | Adds a more realistic PA/observation model: memory polynomial PA taps, soft saturation, linear frequency response, gain/phase drift, observation noise, fixed-point optimized polynomial DPD, LUT DPD, and an assumed RF observation chain |
| `export_dpd_coeff_header.m` | Exports MATLAB DPD calibration words, LUT packages, and proxy EVM/SNDR scores to `fpga/zu15eg/baremetal/src/dpd_coeffs.h` for Vitis standalone experiments |
| `prepare_dpd_bittrue_vectors.m` | Generates deterministic Q1.15 inputs, Q2.14 coefficients, and expected fixed-point DPD outputs for RTL comparison |
| `compare_dpd_rtl_xsim.m` | Compares `dpd_poly` XSim dumps against MATLAB expected vectors |

## Run

From MATLAB:

```matlab
cd matlab
path_setup
T = run_dpd_memoryless_baseline
```

or use the entry script:

```matlab
entry_dpd_memoryless_baseline
entry_dpd_fixed_baseline
entry_dpd_bittrue_check
entry_ai_assisted_dpd_sweep
entry_dpd_memory_pa_observation_sweep
entry_export_dpd_coeff_header
```

The exported C header contains:

- polynomial DPD coefficient packages,
- LUT DPD gain packages,
- package names,
- fixed-point proxy EVM scores,
- fixed-point proxy SNDR scores.

The polynomial DPD package is no longer only a static least-squares result. It
starts from an indirect-learning fit and then searches the quantized Q2.14
`C1/C3/C5` coefficient space with a coordinate-search loss based on EVM, SNDR,
and ACLR target penalty. The per-candidate trace is written to:

```text
matlab/out/dpd/ai_assisted_dpd_coordinate_trace.csv
```

The ZU15EG bare-metal calibration app uses the exported proxy scores together
with hardware saturation, stall, clipping, sticky error, correction-magnitude,
and RF-slew proxy counters. It first selects a best exported package, then runs
a small PS-side coordinate search around the best polynomial package by
perturbing the fixed-point Q2.14 `C1/C3/C5` words. This is the current
hardware-facing calibration loop.

Run the RTL bit-true flow from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1
matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_dpd_rtl_xsim; disp(T); assert(all(T.mismatch==0));"
```

Generated outputs:

```text
matlab/out/dpd/dpd_memoryless_baseline.csv
matlab/out/dpd/dpd_memoryless_baseline.md
matlab/out/dpd/dpd_memoryless_baseline.mat
matlab/out/dpd/dpd_fixed_baseline.csv
matlab/out/dpd/dpd_fixed_baseline.md
matlab/out/dpd/dpd_fixed_baseline.mat
matlab/out/dpd/ai_assisted_dpd_sweep.csv
matlab/out/dpd/ai_assisted_dpd_sweep.md
matlab/out/dpd/ai_assisted_dpd_sweep.mat
matlab/out/dpd/ai_assisted_dpd_coordinate_trace.csv
matlab/out/dpd/dpd_memory_pa_observation_sweep.csv
matlab/out/dpd/dpd_memory_pa_observation_sweep.md
matlab/out/dpd/dpd_memory_pa_observation_sweep.mat
matlab/out/dpd/dpd_memory_pa_observation_coordinate_trace.csv
matlab/out/dpd/bittrue/dpd_input_iq.csv
matlab/out/dpd/bittrue/dpd_coefficients.csv
matlab/out/dpd/bittrue/dpd_expected_iq.csv
fpga/zu15eg/baremetal/src/dpd_coeffs.h
```

## Boundary

The behavioral PA is a simulation model only. The memory-PA observation sweep
now includes memory effects, saturation, linear frequency response, gain/phase
drift, and observation noise, so its DPD improvement is intentionally less
ideal than the memoryless baseline. The coefficients are still not tied to any
real PA device. A real board or product would recalibrate coefficients for the
actual PA, frequency, bandwidth, temperature, and output power.

The LUT DPD flow is intended as the first hardware-friendly target for future
AI or optimization engines. The current implementation uses deterministic
least-squares fitting; a later model can replace the search method while
keeping the same AXI-Lite coefficient/LUT programming interface.

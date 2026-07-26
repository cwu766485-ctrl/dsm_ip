# DPD Models

This folder contains MATLAB models for the implemented AI-assisted TX
calibration path. These models do not replace the DSM datapath. They train and
evaluate coefficient packages for the deterministic DPD RTL.

## Current Model

| File | Purpose |
|---|---|
| `run_dpd_memoryless_baseline.m` | Generates an OFDM/QAM source, applies a behavioral memoryless PA, trains a memoryless polynomial DPD with indirect learning, and compares PA-only vs DPD+PA EVM/SNDR/ACLR |
| `run_dpd_fixed_baseline.m` | Quantizes the learned polynomial DPD to signed Q2.14 coefficients and applies an integer Q1.15 datapath matching the first RTL DPD block |
| `run_ai_assisted_dpd_sweep.m` | Runs a multi-scenario software calibration sweep, refines polynomial DPD coefficients with fixed-point coordinate search, exports polynomial/LUT DPD metrics, and emits AXI-Lite coefficient words |
| `run_dpd_memory_pa_observation_sweep.m` | Adds a more realistic PA/observation model: memory polynomial PA taps, soft saturation, linear frequency response, gain/phase drift, observation noise, fixed-point optimized polynomial DPD, LUT DPD, and an assumed RF observation chain |
| `run_dpd_memory_poly_training_comparison.m` | Trains Q2.14 memoryless and 4-tap memory-polynomial coefficients on disjoint fit/validation OFDM data, then compares both against no DPD on held-out test seeds under the same behavioral PA and observation conditions |
| `run_dpd_model_selection_sweep.m` | Sweeps PA saturation, input backoff, polynomial order (3/5/7), and memory depth (1/2/4/6); rejects clipped candidates and emits a PPA-aware behavioral recommendation |
| `run_dpd_memory_tinyml_dataset.m` | Generates six joint EVM/ACLR/safety memory-DPD package labels plus exact `aligned_complex_pa_monitor_v2` raw Q1.15 complex-feedback traces; `training` produces the 12-profile base matrix, `development` produces eight profile-LOSO/model-selection profiles, and `blind` produces three permanently isolated final-test profiles |
| `prepare_dpd_observer_behavioral_vectors.m` | Exports Q1.15 reference and behavioral-PA feedback vectors plus programmed delay/gain and exact observer counters for XSim closed-loop checking |
| `export_dpd_coeff_header.m` | Exports MATLAB DPD calibration words, LUT packages, and proxy EVM/SNDR scores to `fpga/zu15eg/baremetal/src/dpd_coeffs.h` for Vitis standalone experiments |
| `prepare_dpd_bittrue_vectors.m` | Generates deterministic Q1.15 inputs, Q2.14 coefficients, and expected fixed-point DPD outputs for RTL comparison |
| `compare_dpd_rtl_xsim.m` | Compares `dpd_poly` XSim dumps against MATLAB expected vectors |
| `prepare_dpd7_bittrue_vectors.m` | Generates deterministic Q1.15 and Q2.14 `C1/C3/C5/C7` vectors for the seventh-order memoryless DPD core |
| `compare_dpd7_rtl_xsim.m` | Compares seventh-order `dpd_poly` XSim dumps against MATLAB expected vectors |

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
entry_dpd_memory_poly_training_comparison
entry_dpd_model_selection_sweep
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

Run the complete no-board AI-assisted DPD signoff from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_ai_dpd_offline_signoff.ps1
```

Add `-RegenerateDatasets` to rebuild the long-running MATLAB training,
development, blind, and seed/regret data sets before evaluation. The default
run verifies the retained data and does not require a board, JTAG, PS, DMA, or
an RF laboratory setup.

The offline signoff also evaluates a dependency-free 11-input, 16-hidden-unit,
six-output tiny MLP seed-cost regressor. It uses one fixed package-3 probe and
observer monitor state to choose a DPD seed, but it never bypasses the mandatory
14-candidate bounded search. The model is a PS-software research candidate;
its report does not authorize RTL or board deployment.

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
matlab/out/dpd/dpd_memory_poly_comparison.csv
matlab/out/dpd/dpd_memory_poly_comparison_summary.csv
matlab/out/dpd/dpd_memory_poly_coefficients.csv
matlab/out/dpd/dpd_memory_poly_comparison.md
matlab/out/dpd/dpd_memory_poly_comparison.mat
matlab/out/dpd/dpd_model_selection_sweep.csv
matlab/out/dpd/dpd_model_selection_recommendation.csv
matlab/out/dpd/dpd_model_selection_sweep.md
matlab/out/dpd/bittrue/dpd_input_iq.csv
matlab/out/dpd/bittrue/dpd_coefficients.csv
matlab/out/dpd/bittrue/dpd_expected_iq.csv
fpga/zu15eg/baremetal/src/dpd_coeffs.h
fpga/zu15eg/baremetal/src/dpd_tinyml_packages_v2.h
```

## Boundary

The behavioral PA is a simulation model only. The memory-PA observation sweep
now includes memory effects, saturation, linear frequency response, gain/phase
drift, and observation noise, so its DPD improvement is intentionally less
ideal than the memoryless baseline. The coefficients are still not tied to any
real PA device. A real board or product would recalibrate coefficients for the
actual PA, frequency, bandwidth, temperature, and output power.

Memoryless polynomial, LUT, and 2-to-4-tap memory-polynomial DPD are implemented
in RTL. The current coefficient flow uses deterministic indirect learning and
held-out validation; a later learned model can guide package selection while
keeping the same AXI-Lite programming interface.

The memoryless `dpd_poly` primitive supports compile-time polynomial orders 3,
5, and 7. The seventh-order path adds `C7*abs(x)^6`; its direct RTL test is
included in `run_xsim_dpd_bittrue.ps1`. Full per-sample MATLAB/RTL signoff also
requires the local MATLAB launcher to generate `dpd7_*` vectors. The banked
memory-polynomial hardware path remains limited to C1/C3/C5.

The first learned package selector is now frozen as a depth-4 signed-Q12.20
decision tree. Generate and verify it with
`verif/scripts/run_tinyml_tree_equivalence.ps1`. Python owns ratio formation
and quantization; C and RTL consume the same 13 integer features. The standalone
tree is intentionally not connected to AXI until XSim and retained board-trace
replay pass. See `docs/DPD_TINYML_TREE.md` for the exact contract and limits.

Run `entry_dpd_memory_tinyml_development_dataset` to create the 192-condition
development matrix, then run `entry_dpd_memory_tinyml_blind_dataset` only for
the permanently frozen 72-condition final test. The legacy observer-v2
tree/LUT hierarchy has 19 unsafe blind seeds and remains blocked with
`AVAILABLE=0`. The new offline safety-first policy accepts a seed only after
unanimous nearest-development safety evidence and otherwise requests
`fallback_14`; it does not alter the mandatory 14-candidate safety search or
authorize the legacy PS interface.

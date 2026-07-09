# AI-Assisted DPD Results

Generated: 2026-07-08 22:20:00 +08:00

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

## RTL and Board-Control Evidence

Implemented control paths:

- `rtl/dpd/dpd_frontend.v`: bypass, polynomial DPD, LUT DPD.
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

- No real PA feedback path has been measured on the board.
- Memory-polynomial DPD is modeled at MATLAB/system level but is not yet RTL.
- The current "AI" engine is deterministic coordinate-search optimization plus
  PS-side fixed-point coefficient search. It does not yet run a neural-network
  PA model or compute true EVM/SNDR/ACLR from measured RF feedback on PS.

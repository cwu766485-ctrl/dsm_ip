# Block Signoff Matrix

This matrix is the project-level block signoff for the fixed RTL revision and
the listed parameters. It is not a production ASIC signoff and must be rerun
after a relevant RTL, fixed-point, latency, or interface change.

## Exit Criteria

Every block requires all of the following:

1. An exact arithmetic/vector oracle where the block transforms values.
2. A reproducible randomized protocol test with signed extrema and bubbles.
3. Reset, completion, and local safety/error behavior checked at the DUT port.
4. Zero `ERROR`/`FATAL` messages and the named PASS marker in its XSim log.

## Matrix

| Block | DUT boundary | Exact oracle | Random/boundary test | PASS marker |
|---|---|---|---|---|
| DPD | `dpd_poly`, `dpd_lut`, `dpd_memory_poly`, `dpd_frontend` | MATLAB fixed-point vectors for Poly3/5/7 and Memory-Poly | `tb_dpd_frontend_random_protocol`, protocol/safety/feature-gate/compile matrix, and direct `tb_dpd_memory_poly_random_protocol` | `DPD_RANDOM_PROTOCOL_PASS` plus DPD bit-true checks and `DPD_MEMORY_RANDOM_PROTOCOL_PASS` |
| Interpolation | `dsm_interp_frontend` and FIR/CIC support RTL | MATLAB fixed-point vectors, modes 0 to 4 and x32 I0/I1/I2/I3 | `tb_interp_frontend_random_protocol` | `INTERP_RANDOM_PROTOCOL_PASS` |
| Fs/4 mixer | `bp_fs4_iq_mixer` | Directed +I/+Q/-I/-Q and phase sequence | `tb_bp_fs4_iq_mixer_random` | `FS4_MIXER_RANDOM_PASS` |
| BP EFDSM2 | `dsm_core_bp_ef2`, `dsm_core_ef2` | Python integer vector model | `tb_dsm_core_bp_ef2_random` using the same golden rows with enable bubbles | `BP_EFDSM2_RANDOM_PROTOCOL_PASS` |
| Observer bridge | `dpd_axis_async_fifo`, `dpd_observer_async_bridge` | Ordered complex transaction/sideband contract | `tb_dpd_observer_async_bridge_random` with a depth-4 FIFO and randomized sink ready | `DPD_ASYNC_BRIDGE_RANDOM_PASS` |
| Monitor | `dpd_observer` | MATLAB behavioral PA feedback vectors | `tb_dpd_observer_random_protocol` for invalid beats, extrema, clear and window completion | `DPD_OBSERVER_RANDOM_PROTOCOL_PASS` |

## Reproducibility

Use the following command from the repository root on Windows with Vivado and
MATLAB configured:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_block_signoff.ps1
```

The runner writes only disposable XSim products below `verif/out_xsim_*`.
Golden data stays single-source in `matlab/out/` or the Python reference-model
output. The vector manifests under individual block directories describe the
inputs, seeds, extrema, and generator rather than duplicating generated CSVs.

## Recorded Result

On 2026-08-12, `run_block_signoff.ps1 -BpSamples 4096` completed with exit
code zero. The recorded configuration passed every matrix entry:

- DPD Poly3/5/7 and Memory-Poly MATLAB/RTL comparisons: 256 samples each,
  zero mismatch.
- Interpolation modes 0 to 4, including x32 I0/I1/I2/I3: 4096 samples per
  output, zero mismatch; the random protocol test observed 97 inputs and
  1084 output stalls.
- Fs/4 mixer: eight directed corners and 257 randomized samples.
- BP EFDSM2: 4096 seeded random/extrema samples and enable bubbles.
- Observer bridge: 24 directed samples plus 129 randomized samples with 225
  output stalls.
- Monitor: MATLAB behavioral-window counters and a 129-sample random test
  with 12 invalid beats and counter clear.

This is the historical baseline for the listed tests. The later direct
Memory-Poly full-pipeline-stall test is required to close FSKU-010 and has not
yet produced a trustworthy current XSim/VCS log: the Windows XSim launcher
returns without emitting a log. Therefore the overall DPD block is not claimed
fully re-signed after the new flow-control scope until the Linux/VCS command in
`verif/block/dpd/README.md` reports its named PASS marker.

Formal CDC/RDC, lint signoff, gate-level/SDF simulation, physical signoff, and
measured RF feedback remain separate verification phases.

# Thermo5 Digital PPA and Interpolation Study

The FPGA frozen SKU is the baseline for all ASIC and algorithm comparisons.
Keep the source profile, clock assumptions, gain, DPD identity image, output
word count, and measurement definitions fixed across rows.

## Frozen Baseline

| Identifier | DPD behavior | Mapping interface | Interpolation | FIFO | Timing boundary |
|---|---|---|---|---|---|
| `thermo5_fpga_frozen` | identity, one active tap in UVM | DPD coefficient pins remain runtime inputs in OOC | two x2 stages, 2 taps each | FPGA XPM | FPGA ZU15EG OOC, 125 / 218.75 MHz |
| `thermo5_asic_frozen` | same identity image | DPD coefficients tied as constants | same two x2 stages, 2 taps each | generic async FIFO | Design Compiler pre-layout, 125 / 218.75 MHz |

The ASIC wrapper, FPGA OOC parameters, and FPGA UVM identity-DPD image are
checked by `check_thermo5_frozen_config.py`. The wrappers implement the same
frozen behavior, but the direct FPGA OOC top preserves programmable coefficient
inputs while the ASIC top specializes the image. FPGA and ASIC resource
numbers therefore differ for reasons beyond the FIFO implementation; do not
call their area or timing a controlled comparison without a fixed-image FPGA
OOC wrapper rerun.

## Interpolation Benchmark Rows

`dv/uvm/refmodel/python/benchmark_thermo5_interp.py` compares these two-stage
cascades:

| Row | Phase-1 interpolation | Implementation status |
|---|---|---|
| `rtl2` | current Q14 `[1, 1]/2` causal preset | frozen FPGA baseline |
| `rtl3` | current Q14 `[3, 6, -1]/8` causal preset | RTL-supported experiment |
| `rtl4` | current Q14 `[5, 15, -5, 1]/16` causal preset | RTL-supported experiment |
| `forward_linear` | midpoint of current and next sample | lookahead candidate; requires one-sample buffering |
| `centered_cubic` | Lagrange `[-1, 9, 9, -1]/16` midpoint | lookahead candidate; requires two-sample buffering |

The benchmark uses deterministic 64-QAM OFDM and reports raw EVM and
per-symbol common gain/phase-corrected EVM against ideal 4x bandlimited
interpolation, adjacent-band leakage proxy, and first interpolation-image
rejection. The two lookahead modes are algorithmic
comparators, not existing RTL. The spectral metrics are not standard ACLR and
exclude DPD, TID, PA, RF filtering, and receiver effects. They screen designs;
they do not authorize changing the frozen tap count.

## Evidence Required Before Promoting a Candidate

1. Repeat the Python benchmark over more seeds and relevant occupied bandwidths.
2. Compare the Python bit-true model against the MATLAB oracle or the RTL on
   identical source `.mem` vectors.
3. Run the full thermo5 regression for the candidate, including both FIFO
   implementations where supported.
4. Re-run FPGA routed OOC and ASIC mapped PPA with identical algorithm
   parameters; record the FIFO and library differences.
5. For communications claims, include the intended digital upconversion,
   modulation, defined channel mask, receiver EVM, and PA/DPD endpoint.

Record tool versions, library identity and PVT, clock constraints, source
revision, parameters, raw report paths, and activity provenance. Vectorless
power remains an estimate. FPGA OOC and ASIC pre-layout reports are not
system or silicon signoff.

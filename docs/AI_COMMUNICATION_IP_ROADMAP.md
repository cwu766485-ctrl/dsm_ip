# AI Communication IP Roadmap

Target platform:

- XCZU15EG MPSoC
- PL implementation and ILA-based observation
- no RF laboratory measurement chain assumed
- target role: digital IC design / verification engineer

## Recommended Direction

Build an AI-assisted communication TX calibration prototype. Do not replace the
high-speed datapath with AI.

The high-speed datapath should stay deterministic RTL:

```text
AXI-Stream source
  -> interpolation/filter frontend
  -> DUC
  -> DSM / multibit DSM
  -> output monitor / ILA
```

The AI/control path should be low-rate:

```text
ILA / internal monitor / simulated feedback
  -> metric extraction
  -> optimization or AI model
  -> AXI-Lite coefficient and mode update
```

This is practical on XCZU15EG because the PL can host the datapath while PS,
RISC-V, or an AI accelerator updates parameters at a slow control rate.

## Phase 1: Deterministic TX IP

Goal:

- make the communication TX datapath credible without AI

Tasks:

- finalize native metric definitions
- add interpolation/filter frontend
- keep single-bit DSM as verified baseline
- add MATLAB multibit DSM exploration
- expose AXI-Lite configuration/status registers
- verify with simulation, synthesis, and ILA-visible counters

Useful outputs:

- MATLAB vs RTL bit-true reports
- native EVM/SNDR/ACLR tables
- resource/timing reports on XCZU15EG and xc7z020

## Phase 2: On-Chip Metric Monitor

Goal:

- create hardware-visible evidence without RF lab instruments

Candidate monitors:

- sample counters
- clipping/saturation counters
- power estimator
- peak/RMS estimator
- rough PAPR estimator
- histogram of DSM output codes
- optional FFT/Goertzel bins for spectral proxy

These monitors are ILA-friendly and useful for digital IC interviews because
they show debuggability and observability.

## Phase 3: Software/AI Calibration Loop

Goal:

- tune parameters automatically based on metrics

Parameters to tune:

- input drive level
- interpolation mode
- clipping threshold
- DSM algorithm
- multibit quantizer resolution
- optional FIR/compensation coefficients

Start with deterministic optimization:

```text
grid search -> coordinate descent -> Bayesian optimization
```

Then add a small AI model only if it improves the calibration loop.

## Phase 4: DPD Research Extension

Goal:

- connect this project to all-digital transmitter linearization

Recommended order:

1. memoryless PA model
2. memory polynomial PA model
3. conventional pre-DPD before DSM
4. DSM-embedded DPD feedback model
5. optional AI-assisted PA model or coefficient tuning

Do not put a neural network directly in the high-speed DSM loop first. It is
hard to close timing, hard to verify, and weak as a digital IC portfolio item
unless the deterministic baseline is already strong.

## Portfolio Positioning

The strongest story is:

```text
Reusable communication TX digital IP with DSM, interpolation, AXI integration,
verification, synthesis evidence, and an AI-assisted calibration roadmap.
```

This demonstrates:

- RTL datapath design
- fixed-point MATLAB modeling
- AXI/IP wrapper design
- verification planning
- hardware debug strategy
- communication-system awareness
- practical AI acceleration integration without overclaiming

# Project Prospective

Timestamp: 2026-07-07 00:33:39 +08:00

## Current Position

This repository has moved from a DSM algorithm collection to a reusable digital
TX IP prototype. The current baseline contains:

- MATLAB fixed-point and bit-true reference models.
- Synthesizable RTL for single-bit and multibit Cartesian DSM paths.
- A compile-time selectable interpolation/filter frontend.
- AXI-Stream input and AXI-Lite control/status wrapper.
- A configurable DPD frontend with bypass, polynomial DPD, and LUT DPD modes.
- XSim smoke and bit-true regressions.
- Vivado IP packaging.
- ZU15EG synthesis evidence and local board bring-up evidence.

The local ZU15EG smoke test has validated the internal digital path:

```text
PS DDR -> AXI DMA MM2S -> AXI-Stream -> interpolation frontend -> DSM
       -> status counters / ILA observation
```

This proves the PS-to-PL streaming integration and the packaged DSM datapath on
the local MPSoC board. It does not prove an external DAC, RF, PA, or analog
measurement chain.

## Strategic Direction

The next major upgrade should be an AI-assisted TX calibration IP, not a neural
network replacement for the high-speed datapath.

The high-speed PL datapath should remain deterministic and timing-friendly:

```text
AXI-Stream source
  -> optional DPD / correction block
  -> interpolation/filter frontend
  -> DUC / Fs/4 merge
  -> DSM
  -> output monitor / board observation
```

The AI or optimization logic should initially run at a low control rate:

```text
simulation feedback / ILA-visible metrics / future observation receiver
  -> Python or MATLAB model fitting and optimization
  -> DPD or calibration coefficients
  -> AXI-Lite coefficient update
```

This partition keeps the FPGA datapath practical while still demonstrating a
modern communication SoC-style calibration architecture.

## Technical Route

### Phase 0: Freeze The Board-Validated Baseline

Goal:

- Preserve a known-good DSM TX datapath before adding DPD or AI features.

Tasks:

- Commit the current ZU15EG board bring-up state.
- Keep generated bitstreams, hardware projects, board collateral, and local
  binaries out of the repository.
- Add or retain a repeatable smoke flow for bitstream programming, PS
  initialization, AXI-Lite register reads, DMA transfer, counter checks, and ILA
  observation.

Exit criteria:

- `VERSION`, `ALGORITHM`, `DUC_MODE`, and `INTERP_MODE` read back correctly.
- A P0 DMA transfer increments input, frontend, and output counters.
- `ERROR_STATUS=0` and `INPUT_STALL_COUNT=0` for the basic smoke transfer.

### Phase 1: Deterministic TX Datapath Hardening

Goal:

- Make the non-AI TX IP strong enough to serve as the reference platform.

Tasks:

- Keep DSM and interpolation modes compile-time selectable for low-resource
  builds.
- Maintain MATLAB/RTL bit-true checks for DSM and interpolation behavior.
- Improve reset, valid, ready, and counter documentation.
- Keep ZU15EG synthesis or routed evidence for representative configurations.
- Add more directed board-level checks when useful.

Exit criteria:

- The existing bit-true regressions pass.
- The packaged IP can be rebuilt without manual RTL edits.
- ZU15EG board smoke remains repeatable after RTL or wrapper changes.

### Phase 2: Conventional DPD Frontend

Goal:

- Add a configurable correction block before DSM without depending on a fixed
  real PA.

Current status:

- The first DPD frontend is implemented in RTL and connected in the AXI
  wrapper. It supports bypass, memoryless polynomial DPD, and LUT DPD modes.
- Coefficients are software-writable through AXI-Lite as signed Q2.14 packed
  complex values.
- The MATLAB fixed-point model shows that the Q1.15/Q2.14 datapath tracks the
  floating DPD baseline closely.
- The AXI smoke test covers DPD coefficient readback and sample counting.
- A dedicated MATLAB-versus-RTL DPD vector comparison is in place and passes
  with zero mismatches for the current directed vector set.

Recommended first implementation:

- Memoryless polynomial DPD with 1st, 3rd, and 5th order terms.
- AXI-Lite writable coefficients.
- Bypass mode.
- Fixed-point MATLAB model and RTL bit-true regression.
- Amplitude-indexed LUT DPD.
- AXI-Lite or BRAM-backed LUT update path.
- Optional interpolation between LUT entries.

The DPD hardware should be parameterized and coefficient-driven. A real PA model
is not hard-coded into RTL. Different PA, temperature, frequency, bandwidth, or
output-power cases should be handled by recalibrating coefficients, not by
rewriting the datapath.

Exit criteria:

- MATLAB behavioral PA model shows EVM or ACLR improvement with trained DPD
  coefficients.
- RTL DPD output is bit-true against MATLAB for the same coefficients.
- AXI-Lite coefficient writes are covered by simulation and board smoke.

### Phase 3: AI-Assisted Calibration Loop

Goal:

- Use AI or optimization to generate DPD/calibration parameters, while PL
  hardware executes deterministic fixed-point correction.
- Keep the first AI-assisted version explainable and verifiable: the PS or
  MATLAB/Python side searches calibration parameters, and the PL side remains a
  deterministic DPD + interpolation + DSM datapath.

Recommended first control loop:

```text
MATLAB/Python PA model or captured diagnostic metrics
  -> coefficient fitting / grid search / Bayesian optimization / small model
  -> coefficient table
  -> AXI-Lite update
  -> TX datapath smoke and metric comparison
```

Useful calibration targets:

- Polynomial DPD coefficients.
- LUT DPD entries.
- Input drive level.
- Clipping threshold.
- Multibit DSM resolution in compile-time experiments.
- Interpolation mode in compile-time experiments.

The first AI model should assist coefficient prediction or calibration search.
It should not sit directly inside the high-speed DSM feedback loop.

Current implementation boundary:

- The PL side already exposes DPD controls and monitor feedback through
  AXI-Lite: DPD mode, polynomial coefficients, LUT entries, sample counters,
  saturation count, clipping count, correction-magnitude proxy, RF-slew proxy,
  and fixed-bin spectral proxies.
- The ZU15EG bare-metal app already runs a first PS-side calibration loop:
  it evaluates exported polynomial/LUT DPD packages, runs DMA/datapath tests,
  reads hardware counters, applies a scalar cost, performs a small coordinate
  search around the best polynomial package, and leaves the selected DPD
  configuration programmed in PL.
- This is a valid first AI-assisted calibration architecture because the
  decision loop is automatic and feedback-driven, but it is still deterministic
  optimization. It is not yet a neural-network PA model or a hardware ML
  accelerator.

Next implementation target: AI-assisted calibration engine v2.

- Modularize the calibration policy so the cost function is explicit:

```text
cost =
  MATLAB proxy EVM/SNDR score
  + PL EVM proxy
  + PL ACPR/slew proxy
  + PL fixed-bin spectral proxy
  + saturation/clip/stall/sticky-error penalties
```

- Make the cost weights configurable in the PS app or in a generated
  calibration header.
- Upgrade the search strategy from a single small coordinate pass to a more
  useful optimizer:
  - multi-round coordinate search,
  - coarse-to-fine step reduction,
  - optional random restart,
  - optional Bayesian-like candidate table or lookup-guided search.
- Emit a calibration trace for every candidate:

```text
candidate id
DPD mode/package
C1/C3/C5 or LUT id
EVM proxy
ACPR/slew proxy
spectral proxy
saturation/clip/stall/error counters
cost
accept/reject reason
```

- Store the best package and final coefficients clearly so the result is
  reproducible from logs.

Later tiny-ML extension:

```text
input power / peak / average magnitude / spectral proxy / temperature
  -> tiny regression or MLP
  -> predicted initial C1/C3/C5 or LUT package
  -> deterministic PS search refines the prediction
```

The tiny-ML block should first run in software. A hardware accelerator should
only be considered after the software-assisted loop is stable and the model has
a clear input feature set, output format, fixed-point quantization plan,
latency budget, area budget, and verification strategy.

Exit criteria:

- A baseline no-DPD case and an AI-assisted DPD case are compared under the same
  PA model and metric definitions.
- The coefficient update path is visible through AXI-Lite transactions.
- The project clearly separates simulated PA-model evidence from real RF lab
  measurement evidence.
- The calibration engine produces a candidate trace showing why a coefficient
  or LUT package was accepted or rejected.
- The selected calibration package is replayable on ZU15EG with matching
  input, DPD, frontend, and output counters.

### Phase 4: Hardware AI Accelerator Extension

Goal:

- Explore a small fixed-point inference block only after the deterministic DPD
  path is stable.

Candidate accelerators:

- Tiny MLP for coefficient prediction.
- Small regression engine for PA-model parameter estimation.
- Lightweight calibration search controller.

This phase is optional. It should be pursued only if the software-assisted
calibration loop is already working and the hardware accelerator has a clear
interface, latency, area, and verification story.

## Positioning

The project should be positioned as:

```text
Reusable digital TX IP with DSM modulation, interpolation frontend, AXI/DMA
integration, ZU15EG board smoke evidence, and an AI-assisted DPD/calibration
roadmap.
```

The strongest engineering value is the combination of:

- fixed-point communication modeling,
- synthesizable RTL datapath design,
- AXI-Lite and AXI-Stream integration,
- MATLAB/RTL bit-true verification,
- synthesis and board-level debug evidence,
- a realistic AI-assisted calibration path.

Avoid claiming real PA linearization or RF performance until an actual PA,
feedback receiver, reconstruction filter, and measurement setup are available.

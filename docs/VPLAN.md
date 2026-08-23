# Verification Plan

## Verification Objectives

The plan is split by ownership. RTL verification proves digital behavior;
software and RF models are separate checks.

| Level | Scope | Primary method |
|---|---|---|
| Model | Algorithm, fixed point, metrics | MATLAB and Python integer models |
| Block | DPD, interpolation, mixer, BP DSM, observer, monitor | Directed and random SV testbenches |
| Subsystem | TX frontend, IF/DSM, feedback, control | SV testbenches and VCS regression |
| System | AXI-Lite, AXI-Stream, frozen datapath, error handling | UVM/VCS with Python scoreboard |
| Integration | Clocks, implementation, board replay | Vivado and board-specific flows |

## Frozen-SKU System UVM

The frozen SKU uses Memory-Poly5 with four taps, x32 interpolation, Fs/4
mixing, and BP EFDSM2. System tests cover normal traffic, reset, coefficient
bank commit, sticky errors, AXI stalls, and observation flow.

Acceptance requires all of the following for every run:

- simulator return status is zero;
- `UVM_ERROR=0` and `UVM_FATAL=0`;
- the test prints its completion marker;
- applicable scoreboards drain expected transactions;
- the regression summary marks the run as `PASS`.

Functional coverage for declared system covergroups reached 100% in the
recorded 300-run regression. Raw DUT code coverage is not 100% and must not be
described as closed. The current coverage audit and source-linked waiver ledger
are stored in `docs/evidence/`.

## Open Work

1. Close or formally justify remaining reachable code-coverage bins.
2. Run lint and CDC/RDC with the licensed static-analysis flow.
3. Rebuild the frozen SKU's full ZU15EG implementation and board replay.
4. Keep RF/DPA results separate from RTL signoff until a declared feedback
   receiver and measurement setup are available.

# Thermo5 fault-detection experiment

Date: 2026-10-06 (Asia/Singapore)

## Scope and method

Four one-fault-at-a-time RTL copies were built and simulated in
`runs/thermo5_fault_detection_xsim_wp3_20261006c/`. No canonical RTL or
existing UVM environment file was changed. Each copy was compiled from the
same source set as its clean control, with only the listed fault injected.
The three datapath faults used the existing directed full-chain thermo5
bit-true test, seed 1, and `STRESS_PA_READY`. Its clean baseline passed with
32 accepted source beats, 56 output words, and eight observed stall cycles.
The generic FIFO reset fault used the isolated reset probe in
`dv/uvm/sim/thermo5_fault_stale_fifo_tb.sv`; its clean control passed.

Vivado XSim 2024.1 compiled and ran all four mutants. The Rocky VCS installation
selected VCS V-2023.12-SP1, but its compiler could not launch in this session:
it reported that Linux `6.6.87.2-microsoft-standard-WSL2` is unsupported.
VCS UVM fault runs are therefore not claimed. XSim returns process status zero
after some `$fatal` reports, so the launcher explicitly requires the expected
fatal text and rejects any normal PASS marker for each mutant.

## Results

| Mutant | Injection | Matching clean test | First detected failure | Result |
|---|---|---|---|---|
| `swap_plane` | Connect output branch `b` to PA plane `3-b` in a staged copy of `tid32_thermo5_fs4_multipa_tx.sv` | Full-chain bit-true, seed 1, PA stress | 432054 ps: `word=32 plane=0 got=377742674646eeee exp=3bbb819b8989ddde` | Compiled; detected by the per-plane bit-true checker before PASS |
| `drop_stall` | Ignore `in_ready` in a staged copy of `gt_tx_user_bridge.sv`, allowing a held output to be overwritten | Full-chain bit-true, seed 1, PA stress | 445770 ps: `plane0 changed on stall` | Compiled; detected by the output hold checker before PASS |
| `late_gain` | Capture `active_gain` for the accepted frame-start word instead of the newly supplied frame gain in a staged copy of `dsm_frame_gain_vector.sv` | Full-chain bit-true, seed 1, PA stress | 505206 ps: `word=46 plane=0 got=9a9a91da989819db exp=9f9f9a981d98b9db` | Compiled; detected by the independent MATLAB bit-true checker before PASS |
| `stale_fifo` | Preserve the read pointer on a subsequent reset in a staged copy of `dsm_async_fifo.sv` | Generic FIFO reset probe, seed 1 | 157734 ps: `stale FIFO word visible after reset: valid=1 empty=0 data=2468` | Compiled; detected by post-reset empty/valid check before PASS |

The reproducible launch command is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\sim\run_thermo5_fault_detection_xsim.ps1 -RunId <unique-id>
```

The run directory contains each staged source copy, compile/elaboration/run
logs, command text, first-failure line, and `summary.csv`. Use a fresh run ID
for every repetition. The clean datapath control is the same full-chain test,
seed, and PA-ready schedule used for the three matching datapath mutants.

## Checker and scope notes

- The directed XSim testbench terminates on the first bit-true mismatch and
  explicitly checks all-plane valid atomicity and data stability during PA
  backpressure. This experiment demonstrates those checkers detect the
  selected plane-routing, stall, and frame-gain faults.
- Review found that the UVM scoreboard originally reported a plane mismatch
  with `uvm_error` and incremented `checked`, which could emit an in-test PASS
  marker after a mismatch. It was hardened separately to `uvm_fatal` on
  source metadata/data or PA-plane mismatch. The complete generic/XPM VCS
  baseline regression passed after that checker-only change. The four XSim
  mutants were not rerun as VCS-UVM mutants, so this experiment does not
  claim a VCS mutant-detection result.
- The reset mutant probes the generic FIFO. The real-XPM reset path, GT
  behavior, CDC metastability, and full subsystem midstream-reset replay were
  not exercised by this XSim experiment.
- The gain fault models the first accepted word of a new frame using the
  preceding frame's gain. It is a frame-boundary gain-update fault; it does
  not claim to characterize every possible early-update timing fault.

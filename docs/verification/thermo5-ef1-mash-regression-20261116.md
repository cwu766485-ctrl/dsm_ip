# Thermo5 EF1 and Weighted MASH Regression

Date: 2026-11-16 SGT
Worktree: `E:\workspace\chip\dsm_ip_thermo5_vcu118`
Branch: `work/vcu118-ab-ppa`
HEAD: `4ff7425b1b5ba68b38c60ca596fdb5ed84e91c4d`

## EF1 COMMIT Runner

The XSim runner now waits for the elaborated `xsimk.exe` and the `Built
simulation snapshot` marker before starting XSim. It also waits for the final
simulation PASS marker before copying `console_xsim.log`. XSim is launched
through an auditable `run_xsim.cmd`; the compile macro set is saved in
`compile_configuration.txt`. `Words=1008` appends `THERMO5_LONG_1008` instead
of replacing the Centered-Cubic, order, or STEP macros.

All four fresh runs used seed 1, 56 words, centered cubic, EF1, STEP=5120,
AXI-Lite control and the same vectors. Each reported
`THERMO5_AXIL_CONFIG_BITTRUE_PASS source=32 output=56 taps=2 identity=1` and
produced an `axil_trace.vcd`:

| Configuration | Run directory | Result |
|---|---|---|
| Original + Generic | `runs/uvm_thermo5_i2_d1/axis_xsim_axil_generic_centered_ef1_seed1_words56_p0_runner_final_original_generic` | PASS |
| Pipeline + Generic | `runs/uvm_thermo5_i2_d1/axis_xsim_axil_generic_centered_ef1_seed1_words56_p0_runner_final_pipeline_generic` | PASS |
| Original + XPM | `runs/uvm_thermo5_i2_d1/axis_xsim_axil_xpm_centered_ef1_seed1_words56_p0_runner_final_original_xpm` | PASS |
| Pipeline + XPM | `runs/uvm_thermo5_i2_d1/axis_xsim_axil_xpm_centered_ef1_seed1_words56_p0_runner_final_pipeline_xpm` | PASS |

The testbench count is 32 source beats, 59 DPD inputs including three frame
tails, and 56 PA output words. Generic and XPM both pass without scoreboard
relaxation. The AXI-Lite COMMIT bench elaborates `DPD_MAX_TAPS=4` so it can
exercise the two-tap identity image; the routed product PPA remains the
separate `DPD_MAX_TAPS=1` configuration.

## Weighted MASH Extended DV

The new independent testbench is
`research/thermo5_weighted_mash/verif/block/bp_dsm/tb/tb_tid32_mash11_fs4_multipa_tx_extended.sv`.
It was compiled with Icarus Verilog 12.0 against the existing MATLAB vectors
and RTL, then run from the vector directory so all `$readmemh` paths resolve:

```bash
cd runs/thermo5_weighted_mash_vcu118_20261118/vectors
iverilog -g2012 -s tb_tid32_mash11_fs4_multipa_tx_extended -o extended2.vvp \
  ../../../research/thermo5_weighted_mash/rtl/gt/gt_tx_user_bridge.sv \
  ../../../research/thermo5_weighted_mash/rtl/gt/gt_tx_raw64_boundary.sv \
  ../../../research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv \
  ../../../research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_mash11_fs4_multipa_tx.sv \
  ../../../research/thermo5_weighted_mash/verif/block/bp_dsm/tb/tb_tid32_mash11_fs4_multipa_tx_extended.sv
vvp extended2.vvp
```

Result: `TID32_MASH11_FS4_MULTIPA_EXTENDED_PASS words=128 accepted=128
produced=128 latency=6 alignment_words=35 II=1`. Every PA bit of both weighted
branches matched the MATLAB oracle; output gaps were checked cycle by cycle.
The six-cycle external first-output latency is distinct from the RTL's
35-vector internal alignment register, which is asserted as a parameter in the
testbench.

The historical block has no downstream ready/valid or STOP input. Therefore
output blocking, reset during traffic, and STOP/restart cannot be claimed for
this module. A buffering wrapper is required before those protocol properties
can be tested. Product-level reset/STOP/random-backpressure regression and
VCS/VC Formal/SpyGlass remain OPEN; no replacement tool result is treated as
formal signoff.

## Timing and Interface Boundary

The preserved VCU118 MASH routed baseline remains WNS/WHS `+1.090/+0.032 ns`,
LUT 14,279, FF 13,440, CARRY8 1,004, DSP/BRAM 0. The worst path is the
293-sink `s1_valid` enable net, with 0.079 ns cell delay and 3.200 ns routing
delay. `check_timing` reports 1,025 input ports without input delay and 129
outputs without output delay. No new input/output delay was invented; the
interface timing contract and parent integration remain OPEN.

# Thermo5 ASIC Mapping Flow

This directory maps the frozen thermo5 digital transmitter to a permitted
standard-cell library with Synopsys Design Compiler, then compares the mapped
netlist with the RTL using Formality. The FPGA frozen configuration is the
SKU source of truth. The ASIC wrapper is checked against the FPGA OOC Tcl
before every mapping or equivalence run.

## Frozen FPGA Configuration

```text
14-lane AXI-Stream input, 125 MHz
  -> async FIFO / 14:8 gearbox
  -> frame Q2.14 gain
  -> x2 interpolation, 2 taps
  -> identity DPD, one active tap
  -> x2 interpolation, 2 taps
  -> four-plane thermo5 TID output, 218.75 MHz
```

The public RTL parameters are `INTERP_TAPS=2`, `DPD_MAX_TAPS=1`,
`BYPASS_DPD=0`, and `ENABLE_LOW_POWER_CTRL=0`. The frozen UVM configuration
ties one active DPD tap with `c1_re=0x4000` and every other coefficient zero.
That is Q2.14 identity gain. The ASIC wrapper ties these values as constants.
The FPGA routed OOC top still exposes the DPD coefficient pins as runtime
inputs, so its mapped resource result is not a like-for-like comparison with
the constant-specialized ASIC wrapper. FPGA uses XPM for its async FIFO; ASIC
uses the generic FIFO.

`syn/run_ooc_tid32_thermo5_axis_frontend_tx.tcl` is the canonical FPGA OOC
parameter set. `check_thermo5_frozen_config.py` checks the FPGA OOC parameters,
frozen UVM identity-DPD configuration, and ASIC wrapper. It checks functional
configuration alignment; it does not make their mapped netlists identical.

## Requirements and Run

Use an authorized standard-cell timing `.db` and licensed `dc_shell` and
`fm_shell`. Do not copy PDK, library, or license files into the repository.
The flow consumes the standard-cell `.db`; it does not inspect or qualify
analog, RF, memory, I/O, or device-model collateral.

```bash
python3 syn/asic/check_thermo5_frozen_config.py
python3 syn/asic/run_thermo5_frozen.py \
  --db /approved/local/path/standard_cell_tt.db \
  --out-dir runs/thermo5_asic_<unique>
```

Both Synopsys shells must be on `PATH`. The command writes a local report
bundle and provenance manifest below `runs/`. The SDC clocks are 125 MHz and
218.75 MHz and use assumed IP-boundary budgets; they are not parent-chip I/O
constraints.

## Scope and Limitations

This is pre-layout digital mapping and RTL/netlist equivalence. It does not
perform placement, routing, extracted-RC STA, MCMM signoff, IR/EM analysis,
activity-based power signoff, or analog/RF implementation. The standard-cell
`.db` alone cannot establish whether the process supports an integrated DAC,
PLL, RF front end, PA, or the required passive devices. Those require separate
foundry PDK options, device models, RF/analog design kits, and IP evidence.

For interpolation studies, keep the frozen FPGA row fixed as the baseline.
Any alternate taps or coefficient set is an experiment until its digital
communication benchmark, bit-true tests, and FPGA/ASIC implementation evidence
are reviewed together.

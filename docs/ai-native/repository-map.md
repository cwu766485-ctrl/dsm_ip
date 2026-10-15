# Thermo3 Branch Repository Map

This map describes source present on the `thermo3` branch. `main` retains the
full multi-architecture repository; thermo5 source is on branch `thermo5`.

## Active design and verification

- `rtl/axis/`: async FIFO, XPM wrapper, 14:8 AXI gearbox, reset and power
  control.
- `rtl/frontend/`: vector frame-gain stage.
- `rtl/dpd/`: memory-polynomial DPD and word-elastic boundary.
- `rtl/interp/`: x2 polyphase vector interpolator.
- `rtl/tx_bandpass_if/`: thermo3 AXI/core datapaths and paired Cartesian TID.
- `rtl/gt/`: vendor-neutral 64-bit raw GT user boundary.
- `dv/verif/`: directed thermo3 bit-true, generic CDC, XPM CDC, and sparse-TDD
  power activity tests. There is no UVM tree on this branch.
- `matlab/tx_bandpass_if/`: thermo3 fixed-point references and vector
  generators.
- `syn/`: thermo3 OOC and ASIC/DC flows.
- `fpga/zu15eg/`: thermo3 dual-SFP GTH integration flow.
- `fpga/thermo3_lp/`: thermo3 low-power OOC flow.
- `docs/`: specifications, status, historical evidence, and execution plans.

## Protected or historical content

Board/vendor project collateral under `fpga/hardware/`, generated evidence
under `syn/reports/`, and retained historical documents are intentionally not
source-pruned. Their presence does not mean they are part of the active
thermo3 RTL build.

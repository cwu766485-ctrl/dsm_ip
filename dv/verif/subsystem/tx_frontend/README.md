# Thermo5 TX Frontend Subsystem

This subsystem covers the thermo5 core-word frontend processing chain: frame
gain, two x2 interpolation stages, the frozen identity-configured memory-DPD
path, and its handoff to the four-plane output logic. The separate four-plane
TID/Fs4 backend has its own subsystem test directory.

```text
AXI 14-lane I/Q
    -> async FIFO + 14:8 gearbox
    -> 8 complex samples/core word
    -> gain -> x2 (8->16) -> 1-tap identity DPD
    -> x2 (16->32) -> four offset TID branches
    -> four aligned 64-bit output words
```

The local SystemVerilog tests are:

- `tb/tb_thermo5_i2_d1_axis_bittrue.sv`: full 14:8-to-four-plane bit-true
  test with the MATLAB vector contract.
- `tb/tb_tid32_thermo5_frontend_tx_bittrue.sv`: frontend arithmetic and
  handshake boundary.
- The dedicated four-plane backend comparison is in
  `../tx_backend/tb/tb_tid32_thermo5_fs4_multipa_tx_bittrue.sv`.
- Behavioral serializer loopback and optional GT-parent tests are under
  `../../integration/`; neither is a physical GT/board signoff.

`dv/uvm/` remains the full IP-system verification source of truth, including
AXI-Stream and optional AXI-Lite control variants. Focused simulator commands
are in `dv/verif/RUN_REGRESSION.md`.

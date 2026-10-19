# Thermo5 TX Frontend Subsystem

This subsystem group covers the thermo5 input-to-core frontend: AXI-Stream
ingress, AFIFO/14:8 gearbox, frame gain, two x2 interpolation stages, the
memory-DPD path, and its handoff to the four-plane output logic. The focused
core-word arithmetic bench starts after the gearbox; the full-chain bench
checks from AXI ingress. The separate TID/Fs4 backend has its own subsystem
test directory.

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
  MATLAB bit-true baseline. It currently keeps the sink ready and streams the
  generated vectors without intentional input bubbles.
- `tb/tb_tid32_thermo5_frontend_tx_flow_control.sv`: a separate frozen-SKU
  flow-control case. It inserts AXI input bubbles and partial four-plane PA
  ready windows, checks that stalled output words remain stable, and compares
  every accepted four-plane word against the same MATLAB oracle.
- The dedicated four-plane backend comparison is in
  `../tx_backend/tb/tb_tid32_thermo5_fs4_multipa_tx_bittrue.sv`.
- Behavioral serializer loopback and optional GT-parent tests are under
  `../../integration/`; neither is a physical GT/board signoff.

`dv/uvm/` remains the full IP-system verification source of truth, including
AXI-Stream and optional AXI-Lite control variants. Focused simulator commands
are in `dv/verif/RUN_REGRESSION.md`.

The focused arithmetic runner is `run_xsim_tid32_thermo5_frontend_tx.ps1`.
Run the separate bubble/backpressure scenario with
`run_xsim_thermo5_frontend_flow_control.ps1`. Reset replay remains an IP-level
UVM responsibility rather than being duplicated in this arithmetic subsystem
bench.
The full AXI-ingress-to-output directed IP comparison is launched by
`run_xsim_thermo5_i2_d1_axis.ps1`; it is stored here for source locality, but
its test level is full-IP integration rather than a frontend-only block test.

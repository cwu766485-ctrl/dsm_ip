# Legacy and Integration Testbenches

This directory retains historical top-level and cross-module testbenches.

- `tb_p0_*`: P0 regression for the seven DSM algorithms.
- `tb_dsm_ip_top_smoke.sv`: IP-top smoke test.
- `tx_analog_iq/` and `tx_bandpass_if/`: broader transmitter-chain integration
  testbenches.

New block tests belong in `verif/block/<block>/tb/`. New subsystem tests belong
in `verif/subsystem/<name>/tb/`. UVM system tests are maintained under
`uvm_verif/`.

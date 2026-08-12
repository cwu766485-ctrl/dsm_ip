# Directed IP and Route Tests

This directory deliberately contains tests that are wider than one RTL block:

- `tb_p0_*`: seven DSM P0 algorithm regressions.
- `tb_dsm_ip_top_smoke.sv` and `tb_dsm_ip_axi_smoke.sv`: packaged IP-top and
  AXI-Lite/AXI-Stream smoke tests.
- `tx_analog_iq/` and `tx_bandpass_if/`: route-level integration tests.

Do not add new isolated DPD, interpolation, mixer, BP DSM, observer, or monitor
testbenches here. Put them under `verif/block/<block>/tb/` with a vector entry
and a documented runner.

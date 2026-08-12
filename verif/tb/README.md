# Directed IP and Route Tests

This directory deliberately contains tests that are wider than one RTL block:

- `tb_p0_*`: seven DSM P0 algorithm regressions.
- `tb_dsm_ip_top_smoke.sv`: packaged IP-top smoke test.
- `tx_analog_iq/` and the remaining `tx_bandpass_if/` test: retained
  route-level integration tests.

The AXI control smoke now lives in `verif/subsystem/control/tb/`; the
AXI-wrapped BP route smoke now lives in `verif/subsystem/if_dsm/tb/`.

Do not add new isolated DPD, interpolation, mixer, BP DSM, observer, or monitor
testbenches here. Put them under `verif/block/<block>/tb/` with a vector entry
and a documented runner.

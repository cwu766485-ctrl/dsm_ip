# Thermo5 AXI-Lite DPD Configuration Block

`rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv` is a standalone register and
configuration-mailbox block. It is distinct from the Memory-Polynomial DPD
arithmetic block and is used by the optional AXI-Lite thermo5 wrapper; the
frozen parallel-configuration SKU does not instantiate this control plane.

## Verification split

- `tb/thermo5_axil_cfg_coverage_tb.sv` is a direct block harness for selected
  request/pending/reset overlap tuples. It intentionally observes internal
  state and is not an external AXI protocol test or system CDC/RDC signoff.
- `tb/thermo5_axil_parameter_guard_tb.sv` instantiates illegal `MAX_TAPS=0`
  and `MAX_TAPS=5` configurations; the expected elaboration-time errors are
  checked by the Make target.
- External AXI-Lite register behavior is checked by
  `dv/uvm/tests/thermo5/axil/thermo5_sku_axil_register_access_test.svh` using
  the reusable UVM AXI-Lite agent. It covers AW/W skew, WSTRB, address errors,
  read/write response stalls and register readback without stream traffic.
- Commit/mailbox behavior combined with stream output is tested by the named
  wrapper-integration UVM scenarios listed in
  `dv/uvm/tests/thermo5/axil/README.md`.

Run the standalone VCS block checks from the Rocky/VCS environment:

```bash
make -C dv/uvm/sim thermo5-axil-cfg-unit-vcs THERMO5_OUT=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_axil_block_20261016
make -C dv/uvm/sim thermo5-axil-vcs-parameter-guard THERMO5_OUT=/mnt/e/workspace/chip/dsm_ip/runs/thermo5_axil_block_20261016
```

The first target uses a coverage-enabled VCS build. Its internal-state probes
complement, but do not replace, the public-pin UVM tests. Keep raw URG code
coverage distinct from functional covergroup closure and from reviewed exact
waivers.

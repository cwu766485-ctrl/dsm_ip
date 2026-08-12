# Control Subsystem

Scope: AXI-Lite register access, coefficient banks, atomic commit, reject,
sticky errors, counters, reset behavior, and safe fallback.

## Local Testbench

`tb/tb_dsm_ip_axi_control.sv` is a directed XSim control-in-context test. It
instantiates `dsm_ip_axi_top` and verifies legal AW-first/W-first writes,
write strobes, B/R response stalls, register readback, soft reset, coefficient
bank commits, invalid-package rejection, sticky-error clear, and monitor/
observer status readback. Run it through:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

## Current Evidence

On 2026-08-12, the Linux VCS environment completed the following directed
system tests without UVM errors or fatals:

- `dsm_memory_dpd_bittrue_test`: writes an inactive coefficient bank, commits
  it, streams 24 I/Q samples, and compares 768 RF transactions against the
  Python Memory-Poly5 reference.
- `dsm_memory_dpd_safety_test`: checks invalid coefficient rejection, sticky
  error reporting, and preservation of the active coefficient bank.

This is directed functional evidence, not multi-seed coverage closure or
formal protocol signoff.

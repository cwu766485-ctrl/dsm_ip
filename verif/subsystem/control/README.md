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

`tb/tb_dsm_ip_axi_active_reset.sv` keeps a legal AXI-Stream source active
while requesting `CTRL.soft_reset`. It checks reset-window backpressure,
source recovery, reset-count readback, no false sticky error, and post-reset
RF output. It uses `INTERP_MODE=0` to isolate reset/control behavior.

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

## Control-Stress UVM Evidence

On 2026-08-13, `dsm_control_stress_test` passed in VCS V-2023.12-SP1 with
seeds `1`, `7`, and `31`; all three runs reported `UVM_ERROR=0` and
`UVM_FATAL=0`. The test uses the real AXI-Lite, TX AXI-Stream, and observer
AXI-Stream interfaces to cover independent AW/W arrival, B/R stalls, TX
backpressure, active-stream soft reset, `tuser`/`tlast`, observer start
backpressure, counter clear, and observer-window completion.

URG coverage was merged under `uvm_verif/sim/out/vcs/coverage/`. It is evidence
for this defined control scenario only; it does not constitute full-IP code or
functional coverage closure.

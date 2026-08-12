# Subsystem Verification

Subsystem tests focus on width, latency, flow control, reset propagation, and
state interaction across block boundaries. Each subsystem owns its testbench
under `<subsystem>/tb/`; generated simulation output remains under
`verif/out_xsim_*` and is ignored by Git.

| Subsystem | Composition | Status |
|---|---|---|
| TX frontend | DPD bypass -> x4 interpolation | 2026-08-12: Python-to-RTL XSim bit-true passed, 97 inputs / 388 outputs / 140 output stalls |
| IF/DSM | Fs/4 mixer -> BP EFDSM2 | 2026-08-12: Python-to-RTL XSim bit-true passed, 4096 transactions |
| Feedback | async bridge -> observer | 2026-08-12: XSim integration passed, 129 samples / 117 pairs / 12 invalid / 191 source stalls |
| Control | AXI-Lite registers -> commit/error/status | `control/tb/tb_dsm_ip_axi_control.sv` covers directed AXI-Lite/AXI-Stream control-in-context smoke; Linux VCS UVM passed memory-DPD bit-true and safety tests with 768 RF transactions and zero UVM error/fatal |

The complete IP system is verified by `uvm_verif/`; it is not duplicated here.

Run the three arithmetic/streaming XSim subsystem regressions as one suite:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_subsystem_signoff.ps1
```

The control smoke is part of the reusable IP smoke runner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

It also has a local subsystem entry point:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_control_subsystem.ps1
```

## UVM Boundary

Subsystems use focused SystemVerilog testbenches because their interface and
state spaces are small and their golden checks are deterministic. `uvm_verif/`
is the IP-system environment: it composes the AXI-Lite, TX AXI-Stream,
observation AXI-Stream, and passive RF agents for cross-interface sequencing,
random backpressure, error injection, scoreboarding, assertions, and coverage.
There is no benefit in duplicating the entire UVM environment for each
subsystem.

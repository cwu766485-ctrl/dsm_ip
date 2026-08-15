# Subsystem Verification

Subsystem tests focus on width, latency, flow control, reset propagation, and
state interaction across block boundaries. Each subsystem owns its testbench
under `<subsystem>/tb/`. Linux VCS is the signoff simulator; Windows XSim is a
local smoke-only path. Generated output remains ignored by Git.

| Subsystem | Composition | Status |
|---|---|---|
| TX frontend | DPD bypass -> x4 interpolation | Linux VCS focused bit-true test passed |
| IF/DSM | Fs/4 mixer -> BP EFDSM2 | Linux VCS focused bit-true test passed |
| Feedback | async bridge -> observer | Linux VCS focused transport test passed |
| Control | AXI-Lite registers -> commit/error/status | Linux VCS UVM regression passed |

The complete IP system is verified by `uvm_verif/`; it is not duplicated here.

Run the formal subsystem suite through the existing Linux/VCS bridge:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_subsystem_vcs_bridge.ps1
```

The 2026-08-13 unified regression passed. Its bridge status reported
`last_exit=0`, the result log contained `SUBSYSTEM_VCS_SIGNOFF_PASS`, and the
generated summary recorded all four subsystems as `PASS`:

```text
verif/out_vcs_subsystem/subsystem_summary.csv
```

The focused TX frontend, IF/DSM, and feedback tests remain plain SystemVerilog
testbenches because they have deterministic numeric oracles. Control remains
UVM because it spans AXI-Lite, TX/OBS AXI-Stream, reset, commit, error, and
random timing behavior. XSim runners remain useful for local smoke only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_control_subsystem.ps1
```

`uvm_verif/` remains the full IP-system environment: it composes AXI-Lite, TX
AXI-Stream, observation AXI-Stream, and passive RF agents for cross-interface
sequencing, random backpressure, error injection, scoreboarding, assertions,
and coverage. There is no benefit in duplicating the entire UVM environment
for every arithmetic subsystem.

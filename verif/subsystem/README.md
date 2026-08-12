# Subsystem Verification

Subsystem tests focus on width, latency, flow control, reset propagation, and
state interaction across block boundaries.

| Subsystem | Composition | Status |
|---|---|---|
| TX frontend | DPD bypass -> x4 interpolation | 2026-08-12: Python-to-RTL XSim bit-true passed, 97 inputs / 388 outputs / 140 output stalls |
| IF/DSM | Fs/4 mixer -> BP EFDSM2 | 2026-08-12: Python-to-RTL XSim bit-true passed, 4096 transactions |
| Feedback | async bridge -> observer | 2026-08-12: XSim integration passed, 129 samples / 117 pairs / 12 invalid / 191 source stalls |
| Control | AXI-Lite registers -> commit/error/status | 2026-08-12: Linux VCS UVM passed memory-DPD bit-true and safety tests; 768 RF transactions in the bit-true test, with zero UVM error/fatal |

The complete IP system is verified by `uvm_verif/`; it is not duplicated here.

Run the three XSim subsystem regressions as one suite:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_subsystem_signoff.ps1
```

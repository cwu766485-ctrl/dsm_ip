# Thermo5 Subsystem Verification

Subsystem tests compose multiple RTL blocks. The thermo5 organization has two
signal-processing subsystems only:

| Subsystem directory | Scope |
|---|---|
| `tx_frontend/` | AXI-Stream ingress/AFIFO/14:8 gearbox, frame gain, two x2 interpolation stages, DPD and core-word handoff. |
| `tx_backend/` | Four offset Cartesian TID branches produce synchronized Fs/4/thermometric PA-code planes. |

The continuous GT-user policy at the output is tested separately as one
adjacent block; it is not a third subsystem and is not part of the four-branch
bit-true bench.

Focused XSim entry points:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\subsystem\tx_frontend\run_xsim_tid32_thermo5_frontend_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\subsystem\tx_frontend\run_xsim_thermo5_frontend_flow_control.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\subsystem\tx_backend\run_xsim_tid32_thermo5_fs4_multipa_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\subsystem\tx_backend\run_xsim_tid32_thermo5_fs4_multipa_tx_backpressure.ps1
```

The `*_bittrue` benches isolate oracle comparison with an always-ready sink.
The `*_flow_control` / `*_backpressure` benches are separate scenario tests
that add valid bubbles and deliberate downstream stalls while retaining the
same bit-true scoreboard. Reset/replay and FIFO CDC cases remain at IP level.

Behavioral serializer loopback and optional GT-parent checks are kept in
`dv/verif/integration/`, not counted as additional subsystems. The loopback
does not instantiate physical GT hardware. The optional AXI-Lite variant is a
separate control block plus wrapper-level integration; its UVM scenarios are
listed in `dv/uvm/tests/thermo5/axil/README.md`.

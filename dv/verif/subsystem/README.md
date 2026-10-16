# Thermo5 Subsystem Verification

Subsystem tests compose multiple RTL blocks. The thermo5 organization has two
signal-processing subsystems only:

| Subsystem directory | Scope |
|---|---|
| `tx_frontend/` | Frame gain, two x2 interpolation stages, DPD and the core-word frontend path. Its full-chain test also verifies upstream AXI CDC/14:8 gearbox integration. |
| `tx_backend/` | Four offset Cartesian TID branches and synchronized Fs/4/thermometric PA-code planes. |

Focused XSim entry points:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo5_frontend_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo5_fs4_multipa_tx.ps1
```

Behavioral serializer loopback and optional GT-parent checks are kept in
`dv/verif/integration/`, not counted as additional subsystems. The loopback
does not instantiate physical GT hardware. The optional AXI-Lite variant is a
separate control block plus wrapper-level integration; its UVM scenarios are
listed in `dv/uvm/tests/thermo5/axil/README.md`.

# Thermo5 Regression Entry Points

Run commands from the repository root. XSim output is written under ignored
`runs/` directories. Tests are layered; use the full-chain UVM regression as
the IP-level gate, and focused tests to isolate a changed block or boundary.

## Block tests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_axis14_to_core8_cdc.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_axis14_to_core8_cdc_xpm.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_interp2_reachable.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_cartesian_fs4_gt_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_thermo5_raw64_continuous_tx.ps1
```

Additional FIFO, reset-release, and frame-power block checks:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_xpm_async_fifo_reset.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_frame_power_ctrl.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\block\axis\run_xsim_thermo5_reset_sync_release_audit.ps1
```

## Thermo5 subsystem tests

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo5_frontend_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo5_fs4_multipa_tx.ps1
```

The first command targets `subsystem/tx_frontend/`; the second targets
`subsystem/tx_backend/`.

For a scenario-by-scenario block/subsystem purpose and expected-result matrix,
see `docs/verification/thermo5-test-level-matrix.md`.

## Full IP-system test

The maintained full-chain UVM filelist is
`dv/uvm/sim/thermo5_sku_filelist.f`. See `dv/uvm/sim/README.md` for the
licensed generic/XPM regression commands and required simulator setup.

The optional AXI-Lite top has a separate UVM configuration (`THERMO5_USE_AXIL=1`);
it is not enabled by the frozen base-SKU default.

Behavioral serializer loopback and optional GT-parent checks are system
integration tests, not subsystem signoff. Run the serializer model with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo5_serdes_loopback.ps1
```

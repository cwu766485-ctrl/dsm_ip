# Run Regression

Run the retained P0 DSM RTL regression:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
```

Run the directed packaged DSM IP smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

Run the BP IF/DSM Python-to-RTL transaction comparison:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_if_dsm_bittrue.ps1
```

Run the DPD-bypass plus x4 interpolation subsystem comparison:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_tx_frontend_bittrue.ps1 -Inputs 97
```

Run isolated Fs/4 mixer and BP EFDSM2 block tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_fs4_mixer_block.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_bp_dsm_block.ps1
```

Run the observer metric-accumulator block test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_observer_behavioral.ps1
```

Run every block-level signoff entry with one command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_block_signoff.ps1 -BpSamples 4096
```

Run the XSim subsystem suite:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_subsystem_signoff.ps1
```

The suite covers TX frontend, IF/DSM, and feedback. The AXI control subsystem
is also executed through the reusable IP smoke runner because it requires the
full `dsm_ip_axi_top` context:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

The full AXI control/data-plane UVM regression is intentionally separate under
`uvm_verif/` and uses Linux VCS/Verdi. See `uvm_verif/README.md`.

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

The full AXI control/data-plane UVM regression is intentionally separate under
`uvm_verif/` and uses Linux VCS/Verdi. See `uvm_verif/README.md`.

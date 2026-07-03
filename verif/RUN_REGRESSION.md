# Run Regression

Run the retained 100 MHz RTL regression:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
```

Run the packaged DSM IP top smoke test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
```

This runs `tb_p0_lp1`, `tb_p0_ef1`, and `tb_p0_ef2`.

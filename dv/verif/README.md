# DSM Verification

This branch retains two deterministic P0 XSim suites: seven single-bit
algorithm carriers and seven multi-bit algorithm selections. Both use fixed
I/Q ROM vectors and write per-run logs, sample dumps, and CSV summaries under
`runs/dsm/`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_multibit.ps1
```

Use `-OutDir` for a known run path and `-VivadoSettings` for a non-default
Vivado install. MATLAB comparison follows XSim and is required for a
bit-true-model claim. These are lightweight directed testbenches, not UVM or
full-system verification.

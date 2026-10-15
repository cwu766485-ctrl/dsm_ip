# Reproducible Commands

Run from the repository root in Windows PowerShell.

## XSim regressions

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_multibit.ps1
```

Both scripts accept `-OutDir` and `-VivadoSettings`. Without `-OutDir`, each
creates a timestamped directory under `runs/dsm/`.

## MATLAB

```text
scripts/run_matlab_p0_bittrue_check.cmd
scripts/run_matlab_p0_eval.cmd
```

For an explicit output directory, call the MATLAB compare function with
`'xsim_dir', '<runs/dsm/...>'` after `cd matlab; path_setup`.

## OOC comparison

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

Outputs are timestamped below `syn/reports/`. The flow is a proxy comparison;
it is not board-level timing signoff.

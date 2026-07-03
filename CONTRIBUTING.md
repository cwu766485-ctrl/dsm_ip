# Contributing

## Scope

This repository is a reusable DSM digital IP handoff package. Keep changes
focused on RTL quality, MATLAB/RTL bit-true behavior, verification, IP
packaging, synthesis evidence, and documentation.

## Development Rules

- Keep documentation in English.
- Do not add personal information, passwords, server addresses, license files,
  or private account data.
- Do not commit generated Vivado/XSim logs or local tool caches.
- Preserve bit-true behavior unless the change is intentional and documented.
- Update docs when changing interfaces, register maps, latency, fixed-point
  formats, or verification status.

## Checks

Run the relevant checks before opening a pull request:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1
.\scripts\run_matlab_p0_bittrue_check.cmd
```

For IP wrapper changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
```

If a licensed tool is unavailable, state clearly which checks were not run.

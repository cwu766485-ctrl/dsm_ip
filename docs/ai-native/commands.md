# Thermo3 Branch Commands

Run from the repository root in Windows PowerShell with Vivado 2024.1 and
MATLAB R2025a configured. Each runner writes to a unique timestamped directory
under ignored `runs/`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo3_frontend_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo3_fs4_multipa_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_axis14_to_core8_cdc.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_axis14_to_core8_cdc_xpm.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_lp_power_activity.ps1 -Mode baseline -Workload tdd_sparse
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_lp_power_activity.ps1 -Mode lp -Workload tdd_sparse
```

Thermo3 OOC/ASIC/GT builders are documented alongside their scripts in
`syn/` and `fpga/`. Board-level constraints, RX recovery, serial deskew, and
physical RF validation remain separate from these RTL/XSim checks.

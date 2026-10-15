# Thermo3 Design and Verification Index

## RTL design

- Top: `rtl/tx_bandpass_if/tid32_thermo3_axis_frontend_tx.sv`.
- AXI CDC/gearbox: `rtl/axis/dsm_axis14_to_core8_cdc.sv`.
- Core DPD/interpolation: `rtl/tx_bandpass_if/tid32_thermo3_frontend_tx.sv`.
- Paired PA planes/TID: `rtl/tx_bandpass_if/tid32_thermo3_fs4_multipa_tx.sv`.
- Full ASIC/DC source manifest: `syn/asic/thermo_frontend_dc_sources.f`.

## Verification entry points

- Full thermo3 x2/DPD/x2/TID bit-true: `dv/verif/scripts/run_xsim_tid32_thermo3_frontend_tx.ps1`.
- Paired TID plane bit-true: `dv/verif/scripts/run_xsim_tid32_thermo3_fs4_multipa_tx.ps1`.
- Generic 14:8 CDC FIFO: `dv/verif/scripts/run_xsim_axis14_to_core8_cdc.ps1`.
- XPM 14:8 CDC FIFO: `dv/verif/scripts/run_xsim_axis14_to_core8_cdc_xpm.ps1`.
- Frame-safe LP activity: `dv/verif/scripts/run_xsim_lp_power_activity.ps1`.

The branch uses directed SystemVerilog/XSim verification, not UVM. See
`docs/exec-plans/active/execution-frontier.md` for the latest actual results
and open integration limits.

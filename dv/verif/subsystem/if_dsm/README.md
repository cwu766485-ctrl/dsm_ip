# IF/DSM Subsystem

## Scope

The subsystem contains the registered Fs/4 mixer followed by the BP EFDSM2
core:

```text
I/Q input -> bp_fs4_iq_mixer -> dsm_core_bp_ef2 -> rf_bit/rf_signed
```

## DUT Boundary

- `rtl/tx_bandpass_if/bp_fs4_iq_mixer.sv`
- `rtl/tx_bandpass_if/dsm_core_bp_ef2.sv`
- `rtl/dsm/singlebit/dsm_core_ef2.sv`
- `rtl/tx_bandpass_if/tx_bp_if_top.sv`

## Evidence

`tb/tb_if_dsm_python_bittrue.sv` is the transaction-level Python bit-true
testbench. `tb/tb_dsm_ip_bp_axi_smoke.sv` is the AXI-wrapped BP route smoke
used by the IP smoke runner.

`tb_if_dsm_python_bittrue.sv` compares mixer IF samples, RF bit, signed code,
and the aligned phase label against `dsm_refmodel.bp_ef2`. On 2026-08-12, the
following command passed 4096 transactions with zero mismatch:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_if_dsm_bittrue.ps1 -Samples 4096
```

This is a subsystem result only. Interpolation and DPD are intentionally kept
outside this DUT boundary and are verified by the TX frontend subsystem.

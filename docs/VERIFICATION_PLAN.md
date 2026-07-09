# Verification Plan

## RTL Simulation

Run retained XSim testbenches:

- `tb_p0_lp1`
- `tb_p0_lp2`
- `tb_p0_ef1`
- `tb_p0_ef2`
- `tb_p0_mash11_mb`
- `tb_p0_mash111_mb`
- `tb_p0_mash22_mb`

## MATLAB Bit-True Check

Run after XSim:

```powershell
.\scripts\run_matlab_p0_bittrue_check.cmd
```

Pass when all rows in `matlab/out/p0_bittrue_compare.csv` have
`Mismatches == 0`.

Run DPD RTL/MATLAB bit-true comparison:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1
matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_dpd_rtl_xsim; disp(T); assert(all(T.mismatch==0));"
```

Pass when the comparison table reports `mismatch == 0`.

## Timing

Run OOC synthesis for representative ZU15EG configurations and IP-wrapper
matrices:

- `p0_ooc_lp1`
- `p0_ooc_lp2`
- `p0_ooc_ef1`
- `p0_ooc_ef2`
- `p0_ooc_mash11`
- `p0_ooc_mash111`
- `p0_ooc_mash22`

Pass when reported timing meets the selected 100 MHz target. Current project
planning prioritizes the ZU15EG target; smaller xc7z020 proxy results are
historical and not the main acceptance target.

## Board Evidence

First ZU15EG board target:

```text
PS DDR
-> AXI DMA MM2S
-> DSM IP s_axis
-> rf_valid / rf_signed
-> ILA capture
```

Minimum board checks:

- AXI-Lite register readback for `VERSION`, `ALGORITHM`, `DUC_MODE`, and
  `INTERP_MODE`.
- Software reset and counter clear behavior.
- AXI DMA MM2S transfer of packed Q1.15 I/Q vectors.
- ILA visibility of `s_axis_tvalid`, `s_axis_tready`, `s_axis_tdata`,
  `rf_valid`, and `rf_signed`.
- Counter consistency for `INPUT_SAMPLE_COUNT`, `FRONTEND_SAMPLE_COUNT`, and
  `OUTPUT_SAMPLE_COUNT`.

Use `fpga/zu15eg` for current ZU15EG bring-up notes and helper scripts. Use
`matlab/board_validation` for later captured-waveform analysis when board data
is exported from ILA, scope, or another capture path.

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

## Timing

Run OOC proxy synthesis for:

- `p0_ooc_lp1`
- `p0_ooc_lp2`
- `p0_ooc_ef1`
- `p0_ooc_ef2`
- `p0_ooc_mash11`
- `p0_ooc_mash111`
- `p0_ooc_mash22`

Pass when routed `WNS >= 0` at 100 MHz.

The current seven-path OOC report shows LPDSM, EFDSM, and EFDSM2 pass 100 MHz;
LPDSM2 and MASH currently fail the 100 MHz timing criterion.

## Board Evidence

Use `matlab/board_validation` with the preserved DSM000 capture to reproduce the
board-output consistency checks.

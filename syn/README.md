# Synthesis

This folder contains the 100 MHz proxy OOC synthesis flow.

Retained OOC tops:

- `p0_ooc_lp1`
- `p0_ooc_lp2`
- `p0_ooc_ef1`
- `p0_ooc_ef2`
- `p0_ooc_mash11`
- `p0_ooc_mash111`
- `p0_ooc_mash22`

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1
```

Baseline:

- FPGA part: `xc7z020clg400-1`
- Clock target: 100 MHz
- Pass criterion: routed `WNS >= 0`

Checked summary:

```text
syn/reports/p0_ooc_summary_xc7z020_20260512.csv
```

The current seven-structure OOC report shows LPDSM2 and MASH are restored but
not timing-clean at 100 MHz.

## BP EFDSM2 AXI SKU

`run_ooc_bp_ef2_axi.ps1` targets the complete experimental transmitter SKU:

```text
AXI-Stream -> DPD frontend -> x32 interpolation -> full-precision Fs/4 IF
mixer -> one-bit BP EFDSM2
```

It uses `DUC_MODE=3`; this is distinct from the legacy `DUC_MODE=0` one-bit
low-pass I/Q merge. The 28 nm pre-layout DC launcher for the same complete AXI
SKU is `run_bp_ef2_28nm_dc.sh`. Both need fresh tool output before any PPA
claim is made.

## RTL lint-only check

`run_lint_bp_ef2_axi.sh` runs the same BP EFDSM2 AXI source list and compile
parameters through DC `analyze`, `elaborate`, `link`, `check_design`, and
`check_timing`. It intentionally stops before `compile_ultra`, so its output
is structural RTL evidence, not area, timing, or power signoff.

From WSL/Linux:

```bash
export DC_SHELL=/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell
bash syn/run_lint_bp_ef2_axi.sh
```

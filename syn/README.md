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

## Frozen Performance SKU Routed OOC

The delivery configuration is fixed as follows:

```text
Memory-Poly5, 4 tap -> x32 CIC plus compensation FIR -> Fs/4 BP EFDSM2
ALGORITHM=3, DUC_MODE=3, INTERP_MODE=4, 100 MHz
```

Run the complete routed OOC implementation on ZU15EG with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_performance_sku_routed.ps1 `
  -Part xczu15eg-ffvb1156-2-i -TargetMHz 100
```

The script runs synthesis, placement, routing, physical optimization, and
reports timing, utilization, power estimate, and routed DRC. It does not use
board XDC constraints, generate a bitstream, or sign off I/O hold timing.

The 2026-08-16 routed artifact reports `WNS=+2.632 ns`, `TNS=0`, and no setup
failing endpoints at 100 MHz. Its resource result is 12,964 LUTs, 15,316 FFs,
266 DSP48s, and no BRAM/URAM. The corresponding power report is an estimate
without activity annotation, not a measured board value. DSP pipeline DRC
recommendations remain an RTL PPA improvement item.

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

The tool path alone is insufficient: the 2026-08-16 rerun reached `dc_shell`
but stopped with `DCSH-1: Design Compiler is not enabled`. Do not report lint
as passing until the Design Compiler license is available and the script writes
`LINT_PASS` plus all required reports.

## Reproducible ASIC PPA Flow

`syn/asic/` contains the public pre-layout Design Compiler launcher for the
frozen Performance SKU. Unlike the retained historical script, it has no
default private PDK path. Supply a permitted standard-cell database at runtime:

```bash
export DSM_ASIC_STDCELL_DB=/path/to/standard_cell_tt.db
export DSM_ASIC_NODE=28nm
bash syn/asic/run_performance_sku_dc_sweep.sh 100 200 300 400 500
```

The values above are placeholders. Run the command from a Linux shell, not
from a `dc_shell>` Tcl prompt. If `dc_shell` is available on `PATH`, the
launcher finds it automatically; otherwise use
`export DC_SHELL="$(command -v dc_shell)"` with the actual executable path.

The flow emits one report bundle per target and a normalized `summary.csv`.
It reports cell area, combinational/sequential area, timing, critical path,
and power provenance. Without an annotated SAIF file, power is marked as a
vectorless estimate and must not be presented as measured power.

The flow validates the selected mapping library by its own library name and
cell inventory before elaboration. `library.rpt` records that deterministic
evidence directly; this avoids a tool-version-dependent generic `report_lib`
redirect error without weakening synthesis, timing, or unmapped-logic checks.

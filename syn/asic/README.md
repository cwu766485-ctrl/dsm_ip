# ASIC PPA Flow

This directory contains a reproducible pre-layout Design Compiler flow for the
frozen Performance SKU. It is deliberately separate from FPGA OOC reports and
does not contain a PDK, license path, or generated report.

## Frozen Configuration

```text
AXI4-Stream I/Q
  -> Memory-Polynomial DPD, order 5, four taps
  -> interpolation mode 4, x32 CIC plus compensation FIR
  -> Fs/4 band-pass mixer
  -> one-bit BP EFDSM2
```

The implementation parameters are fixed to `ALGORITHM=3`, `DUC_MODE=3`,
`INTERP_MODE=4`, `INTERP_IMPL=0`, `DPD_POLY_ORDER=5`,
`DPD_MP_MAX_TAPS=4`, `ENABLE_DPD_MEMORY=1`, `ENABLE_DPD_POLY=0`, and
`ENABLE_DPD_LUT=0`.

`DUC_MODE=3` selects the BP EFDSM2 datapath. It is therefore not a valid
like-for-like full-chain comparison point for the legacy LP/EF/MASH DSM modes.
Those structures remain separate core-level architecture studies.

## Prerequisites

Use a permitted standard-cell `.db` and a licensed `dc_shell`. Do not copy
either asset into this repository.

```bash
export DSM_ASIC_STDCELL_DB=/path/to/standard_cell_tt.db
export DSM_ASIC_NODE=28nm
```

The launcher uses `dc_shell` from `PATH` by default. Set `DC_SHELL` only when
the required executable is not already on `PATH`.

Do not copy the literal `/path/to/...` example into the environment. Run the
launcher from the Linux shell prompt (`user@host$`), never from the
`dc_shell>` Tcl prompt:

```bash
unset DC_SHELL
export DC_SHELL="$(command -v dc_shell)" # Optional when dc_shell is on PATH.
```

### Standard-Cell Mapping Probe

A readable `.db` is not necessarily a usable standard-cell mapping library.
Before a new PPA sweep, run the read-only probe:

```bash
bash syn/asic/run_stdcell_probe.sh
```

The command must print at least one `STDCELL_PROBE_LIB` record with a nonzero
cell count and a nonzero inverter match count. Keep the generated local
`library_*.rpt` next to the PPA reports.
If DC reports that the target library has no inverter, choose the nominal
standard-cell timing DB that contains logic cells, rather than a timing-only,
interface, or voltage-specific auxiliary view.

Optional environment variables:

```bash
export DSM_ASIC_LABEL=performance_sku
export DSM_ASIC_TARGET_MHZ=100
export DSM_ASIC_ACTIVITY_FILE=/path/to/annotated.saif
```

When `DSM_ASIC_ACTIVITY_FILE` is absent, the power report is a vectorless
estimate and is explicitly labelled as such in `summary.csv`.

## One Configuration

```bash
bash syn/asic/run_performance_sku_dc.sh
```

The command writes an ignored directory below `syn/reports/` containing the
DC log, mapped netlist, timing, area, hold, power, and constraint reports.
It also writes `summary.csv` with the report provenance and critical path.

## Frequency Sweep

```bash
bash syn/asic/run_performance_sku_dc_sweep.sh 100 200 300 400 500
```

Each frequency is an independent constrained synthesis run. A target is a
timing pass only when its report has non-negative setup slack and no unmapped
logic. `fmax_est_mhz` is derived from the reported critical path delay; it is
not post-layout or multi-corner signoff.

## Frontend Pareto Matrix

```bash
bash syn/asic/run_frontend_pareto_dc.sh
```

The matrix compares x4/x8/x16/x32 interpolation with DPD bypass, plus the
frozen x32 Memory-Poly5 four-tap implementation. It is a PPA experiment only;
use the matching MATLAB fixed-point analysis to attach EVM/SNDR/ACLR results.

## Required Evidence

For each reported row retain the generated, local report bundle and record:

- technology label and PVT library identity;
- target clock, critical path delay, setup slack, and hold slack;
- total, combinational, and sequential cell area;
- dynamic, leakage, and total power with its activity provenance;
- critical startpoint and endpoint;
- the exact RTL revision and parameter set.

This flow is pre-layout synthesis only. It does not replace physical design,
extracted-RC STA, MCMM signoff, IR/EM analysis, or activity-based power
signoff.

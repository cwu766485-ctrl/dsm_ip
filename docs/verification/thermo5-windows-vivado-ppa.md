# Thermo5 Windows Vivado A/B PPA Run

Status: `FLOW_PREPARED; VIVADO_NOT_RUN` (2026-11-13).

This flow compares the same AXI-Lite product top,
`tid32_thermo5_axi_lite_axis_frontend_tx`, for four algorithm configurations:

| Case | Interpolator | TIDSM order | STEP |
|---|---|---:|---:|
| A | Causal | 1 | 5120 |
| B | Centered cubic | 1 | 5120 |
| C | Causal | 2 (EF2) | 5120 |
| D | Centered cubic | 2 (EF2) | 5120 |

All use `DPD_MAX_TAPS=1`, `FPGA_USE_XPM_FIFO=1`, part
`xczu15eg-ffvb1156-2-i`, Source=125 MHz, Core=218.75 MHz and AXI-Lite=100 MHz.
Synthesis uses `AreaOptimized_high`, one synthesis thread, no hierarchy
flattening and the same RTL file order. Routing starts from each successful
synthesized DCP and uses `route_ooc_thermo5_axil_from_checkpoint.tcl` with
`resume_from=synth` and route directive `Default`; this applies the same
opt/place/phys-opt/route strategy to each candidate.

## Windows commands

From the repository root in Windows PowerShell:

```powershell
$vivado = 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
.\syn\run_thermo5_axil_ab_ppa.ps1 -VivadoBat $vivado
```

The runner first synthesizes all four cases and verifies the elaborated top,
DPD hierarchy, XPM FIFO hierarchy and effective generic values. It starts
routing only after all four synthesis checkpoints and configuration manifests
exist. Outputs go to a fresh timestamped directory below `runs/`; existing
output directories are not overwritten. The final
`ab_ppa_manifest.csv` points to each route log, checkpoint, configuration,
utilization report, timing report, and power report.

Existing XDC/CDC handling is shared across all cases: 8 ns Source, 4.571 ns
Core, and 10 ns AXI-Lite clocks; Source/Core and Source/AXI-Lite are declared
asynchronous. Reset paths are false-pathed, synchronizer input paths are
false-pathed, and the AXI-Lite bundled config mailbox has a 10 ns datapath
max-delay. These are the current OOC constraints, not parent-level timing or
CDC signoff. Vivado version and constraint hashes must be captured from each
run output before comparing results.

The Tcl emits `report_power` without a SAIF/VCD activity file. This is a
vectorless estimate only and must not be reported as activity-based measured
dynamic power. For an activity-based comparison, generate a common workload
and provide validated per-configuration SAIF with matching hierarchy mapping.

The Windows Vivado 2026.1 files are mounted at
`/mnt/d/AMDDesignTools/2026.1/Vivado`, but Windows PowerShell/command
interoperability is not available in this Linux session. Vivado's Linux
launcher is present but the Linux payload is not installed; `vivado -version`
exits with a missing `bin/unwrapped/lnx64.o/prodversion` error. Therefore no
four-case synthesis or routed run was possible. No LUT, FF, DSP, BRAM, WNS,
WHS, Fmax, route-delay or power result is claimed by this document.

The current algorithm-only held-out model comparison remains in
`thermo5-tx-design-ablation.md` and is not FPGA PPA. The requested new local
eight-group held-out raw CSV/seed/parameter/script bundle was not located in
the searched candidate and mounted workspace paths; it remains
`NOT_VALIDATED` and is not merged into the existing four-cell model data.

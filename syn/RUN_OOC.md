# P0 Core OOC

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1
```

The OOC flow instantiates DSM + Fs/4 DUC logic directly from registered I/Q
inputs. It intentionally excludes simulation ROMs and optional NCO logic so the
reported LUT/FF/DSP/WNS/Fmax numbers describe the core datapath proxy.

Baseline target:

- FPGA: `xc7z020clg400-1`
- Clock: 100 MHz
- Flow: Vivado out-of-context proxy implementation

Current checked reference summaries:

```text
syn/reports/p0_ooc_summary_xc7z020_20260512.csv
docs/evidence/ooc/p0_core_ooc_xc7z020_100mhz_summary.csv
```

The flow includes LPDSM2, MASH11, MASH111, and MASH22. The current seven-path
report shows those restored paths do not meet the 100 MHz timing criterion yet.

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

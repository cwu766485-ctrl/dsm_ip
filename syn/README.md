# DSM OOC Comparison

`run_ooc_all_dsm.ps1` runs out-of-context synthesis, placement, routing, and
timing reports for seven single-bit and seven multi-bit DSM wrappers. The
default part is `xc7z020clg400-1`; the XDC targets a 100 MHz clock and excludes
top-level I/O timing, so results compare core implementation cost and are not
board-level signoff.

Run on Windows with Vivado available:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

Each invocation writes a timestamped folder under `syn/reports/`. The latest
committed historical 14-top summary is
`docs/evidence/ooc/p0_ooc_xc7z020_20260705_multibit_summary.csv`: 12/14 tops
met the 100 MHz proxy setup target; `p0_ooc_mb_ef2` and `p0_ooc_mb_mash22`
did not. These results must not be presented as a fresh run of a modified
source tree.

For the 14 top names and flow steps, see [RUN_OOC.md](RUN_OOC.md).

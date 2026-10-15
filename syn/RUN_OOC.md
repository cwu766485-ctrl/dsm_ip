# OOC Run Notes

The comparison flow builds these 14 independent out-of-context tops:

- Single-bit: `p0_ooc_lp1`, `p0_ooc_lp2`, `p0_ooc_ef1`, `p0_ooc_ef2`,
  `p0_ooc_mash11`, `p0_ooc_mash111`, `p0_ooc_mash22`.
- Multi-bit: `p0_ooc_mb_lp1`, `p0_ooc_mb_lp2`, `p0_ooc_mb_ef1`,
  `p0_ooc_mb_ef2`, `p0_ooc_mb_mash11`, `p0_ooc_mb_mash111`,
  `p0_ooc_mb_mash22`.

The script reads `syn/rtl/p0_ooc_tops.sv`, the DSM RTL, and
`syn/constraints/p0_ooc_100mhz.xdc`, then runs synthesis, optimization,
placement, physical optimization, routing, and reports utilization, timing,
power estimate, DRC, and methodology. A status of `PASS` means the Tcl flow
completed; `FAIL_TIMING` is assigned when the reported setup slack is negative.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

Review each top's reports, not just the summary. The clock is 100 MHz; I/O
delays are intentionally excluded. No board constraints, analog behavior, or
RF performance are covered. The checked-in 2026-07-05 summary is historical
and records 12/14 tops meeting the proxy setup target.

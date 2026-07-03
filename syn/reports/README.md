# Synthesis reports

Place **regenerated** Vivado (or other) reports here:

- One subdirectory per tool run, e.g. `reports/2026-05-11_xc7z020_ooc_lpdsm/`
- Include: utilization, timing summary, power (if enabled), and the exact Tcl / constraint set used.

**Do not** commit large proprietary IP caches. Commit **text summaries** and scripts to reproduce.

Naming convention (suggested):

```text
<date>_<part>_<ooc|impl>_<dsm_tag>/
  timing_summary.rpt
  utilization.rpt
  runme.tcl
```

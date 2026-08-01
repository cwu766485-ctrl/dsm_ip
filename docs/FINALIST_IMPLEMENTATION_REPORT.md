# Finalist implementation report

## Scope

Four x32 I0 interpolation + Memory-Poly5 + Fs/4 DUC AXI-top finalists were
implemented out of context on `xczu15eg-ffvb1156-1-i` with a 10.000 ns
`aclk` constraint. Each run includes synthesis, placement, routing,
post-route physical optimization, timing, utilization, power, DRC, and
methodology reports.

The same four configurations completed a parameterized 28 nm and 40 nm
standard-cell DC synthesis sweep. All eight full AXI-top cases passed and the
matrix exited zero. These are pre-layout estimates only; the exact cell area,
timing, power method, constraints, and limitations are recorded in
`docs/FINALIST_ASIC_PPA_REPORT.md`.

## FPGA post-route results

| Finalist | DSM output | LUT | FF | DSP | BRAM | WNS (ns) | Estimated Fmax (MHz) | Vectorless power (W) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| I0+D0 EFDSM | 1 bit | 14,245 | 17,063 | 296 | 0 | +1.352 | 115.63 | 1.145 |
| I0+D1 LPDSM2 | 1 bit | 14,298 | 17,087 | 296 | 0 | +1.400 | 116.28 | 1.145 |
| I0+D3 MASH11 | 3 bit | 14,286 | 17,095 | 296 | 0 | +0.814 | 108.86 | 1.146 |
| I0+D5 multibit EFDSM | 4 bit | 14,455 | 17,062 | 296 | 0 | +1.163 | 113.16 | 1.146 |

All four pass the 100 MHz setup target. Resource and power changes are small
because the shared interpolation and Memory-Poly datapaths dominate the full
AXI top. The initial `summary.csv` resource counts use primitive-name cell
queries and overcount LUT/DSP helper cells; the table above is the authoritative
post-route `report_utilization` data.

## Decision

- Keep **I0+D1 LPDSM2** as the one-bit Balanced choice: it has the largest
  implementation timing margin among the finalists and the earlier MATLAB
  matrix gives it the best one-bit quality point. It is also within 0.57% of
  the lowest 28 nm cell area and within 0.32% of the lowest 40 nm cell area in
  the complete AXI-top DC runs, so it is the recommended next verification
  target.
- Keep **I0+D5 multibit EFDSM** as the practical multi-bit/DAC-DPA choice: it
  retains 113 MHz class timing with a four-bit output and avoids the additional
  cost of multibit EFDSM2.
- Keep **I0+D0 EFDSM** as the minimum-complexity baseline, and **I0+D3 MASH11**
  as the native three-bit comparison point. MASH11 is not the default because
  it has the smallest full-top timing margin.

## Evidence and limitations

- FPGA reports: `syn/reports/finalists_axi_routed_xczu15eg_ffvb1156_1_i_20260729_195441/`
  on the Windows workspace.
- This is routed **OOC** evidence, not a board-level timing sign-off. It has no
  board XDC/I/O delays, no assigned `HD.CLK_SRC`, and expected partial-routing
  warnings for top-level ports. The power numbers use vectorless activity and
  are comparative estimates only.
- ASIC evidence: all eight reports are under
  `syn/reports/finalists_asic_dc_full_axi_20260730_0145/`. The earlier
  `DCSH-1` diagnostic was caused by sandbox license-server isolation, not a
  missing DC feature. The completed DC results remain pre-layout and have
  unannotated power activity plus unresolved library-default design-rule
  entries; they are not physical or signoff PPA.

# Thermo3 and Thermo5 routed PPA comparison

## Scope

This comparison uses the same FPGA, clocks, RTL integration boundary, runtime
identity memory-DPD, and full implementation flow.  Both designs include the
125 MHz AXI ingress, XPM asynchronous FIFO, fixed 14:8 gearbox, 218.75 MHz
frontend, two x2 interpolators, 16-lane four-tap memory-DPD, and the complete
32-lane Cartesian TID.  The only intended architectural difference is the
number of thermometric output planes: two for thermo3 and four for thermo5.

Device: `xczu15eg-ffvb1156-2-i`

Flow: `synth_design -> opt_design -> place_design -> phys_opt_design -> route_design`

| Metric | Thermo3 | Thermo5 | Thermo5 - thermo3 |
|---|---:|---:|---:|
| Core clock | 218.75 MHz | 218.75 MHz | 0 |
| AXI clock | 125.00 MHz | 125.00 MHz | 0 |
| WNS | +0.290 ns | +0.308 ns | +0.018 ns |
| WHS | +0.027 ns | +0.027 ns | 0 ns |
| Total CLB LUTs | 59,921 | 71,869 | +11,948 |
| LUT as logic | 54,122 | 62,308 | +8,186 |
| LUT as memory | 5,799 | 9,561 | +3,762 |
| CLB registers | 83,797 | 97,249 | +13,452 |
| BRAM tiles | 6.5 | 6.5 | 0 |
| DSP48E2 | 2,030 | 2,032 | +2 |
| Output code planes | 2 | 4 | +2 |
| Core pipeline depth | matched | matched | 0 |

Both implementations report zero setup and hold failures, zero errors, and
zero critical warnings.  Pipeline depth is matched because both variants use
the same gain, interpolation, elastic-buffer, memory-DPD, TID input-register,
and raw-word boundary stages.  The variants therefore have the same fixed
core-word latency contract; the asynchronous FIFO fill and clock-phase
relationship are intentionally not expressed as a fixed cross-domain cycle
latency.  Both sustain one accepted core word per core clock once running.

## Critical path and fanout

| Detail | Thermo3 | Thermo5 |
|---|---:|---:|
| Worst data-path delay | 3.966 ns | 3.962 ns |
| Logic delay | 2.730 ns | 2.603 ns |
| Route delay | 1.236 ns | 1.359 ns |
| Logic levels | 10 | 10 |
| Worst-path class | memory-DPD DSP/carry | memory-DPD DSP/carry |
| Reported core-clock fanout | 103,766 | 121,078 |

The large fanout numbers above belong to the routed global core clock.  They
must not be described as a failing ordinary data/control net.  The earlier
high-fanout valid/enable data paths no longer appear as the worst paths.  The
thermo5 resource increase is the expected cost of two additional TID/code
planes and does not reduce timing margin in this routed seed.

## Evidence

- Thermo3: `syn/out/tid32_thermo3_axis_frontend_20260921_104738/`
- Thermo5: `syn/out/tid32_thermo5_axis_frontend_20260921_213551/`
- Each directory contains `summary.csv`, `utilization.rpt`,
  `timing_summary.rpt`, and `timing_max_paths.rpt`.

This is FPGA fabric OOC evidence.  It does not include a GT primitive,
package-pin assignment, reference-clock network, PCB channel, or RF hardware.

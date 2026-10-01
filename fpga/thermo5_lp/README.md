# Thermo5 Low-Power FPGA OOC Project

This project implements the complete two-clock thermo5 AXI frontend with the
frame-safe low-power controller enabled. It is an OOC timing and power project
for `xczu15eg-ffvb1156-2-i`, not a board bitstream.

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\thermo5_lp\run.ps1
```

Generated project and reports are written below `project/` and `reports/`.

The retained pre-run-request routed checkpoint passed at 218.75 MHz with WNS
0.103 ns and WHS 0.026 ns. It is now superseded by the run-request, ingress,
and drain-protocol RTL revision and must be rebuilt before being cited as the
timing result for current RTL. Open `project/thermo5_lp_ooc/thermo5_lp_ooc.xpr`
in the GUI.
The power report is vectorless and must not be interpreted as measured idle or
workload power. OOC `HD.CLK_SRC` and `HD.PARTPIN_LOCS` warnings are integration
constraints that must be supplied by a future device-level parent design.

# Thermo3 Low-Power FPGA OOC Project

This project implements the complete two-clock thermo3 AXI frontend with the
frame-safe low-power controller enabled. It is an out-of-context (OOC) timing
and power project for `xczu15eg-ffvb1156-2-i`; it is not a board bitstream.

OOC mode is intentional. Wide IQ, coefficient, and raw-word ports remain
partition ports and are not mapped to package I/O pins.

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\thermo3_lp\run.ps1
```

Generated project and reports are written below `project/` and `reports/`.

The retained pre-run-request routed checkpoint passed at 218.75 MHz with WNS
0.147 ns and WHS 0.027 ns. It is now superseded by the run-request, ingress,
and drain-protocol RTL revision and must be rebuilt before being cited as the
timing result for current RTL. Open `project/thermo3_lp_ooc/thermo3_lp_ooc.xpr`
in the GUI.
The power report is vectorless and must not be interpreted as measured idle or
workload power. OOC `HD.CLK_SRC` and `HD.PARTPIN_LOCS` warnings are integration
constraints that must be supplied by a future device-level parent design.

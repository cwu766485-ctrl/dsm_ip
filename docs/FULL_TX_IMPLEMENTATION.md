# ZU15EG Full-TX Implementation Contract

## Selected Build

The reproducible full-TX FPGA build uses one 100 MHz PL clock and the following
compile-time datapath configuration:

| Parameter | Value |
|---|---:|
| `ALGORITHM` | `2` (EFDSM 1-bit) |
| `INTERP_MODE` | `4` (x32 CIC plus compensation FIR) |
| `DUC_MODE` | `0` (fixed Fs/4) |
| `DPD_POLY_ORDER` | `5` |
| `DPD_MP_MAX_TAPS` | `4` |
| `ENABLE_DPD_POLY` | `0` |
| `ENABLE_DPD_LUT` | `0` |
| `ENABLE_DPD_MEMORY` | `1` |
| AXI-Lite address width | 9 bits |
| PL clock | 100 MHz |

At the default 3.125 MHz baseband sample rate, the x32 frontend produces the
100 MHz DSM sample clock rate. The fixed Fs/4 DUC places the nominal IF at
25 MHz.

## Clock and Reset Contract

- `dsm_ip_axi_top`, AXI DMA MM2S, AXI-Lite, and ILA use the same PS-derived
  `pl_clk0` clock.
- Datapath reset uses `proc_sys_reset/peripheral_aresetn`. Direct use of raw
  PS reset is rejected by the BD template and full-TX implementation script.
- `s_axis_obs_*` is synchronous to `aclk`. A feedback ADC or RF receiver with
  another clock must use an AXI-Stream Clock Converter or asynchronous FIFO
  before the IP. No unrelated-clock signal may directly drive the observer.
- A software reset clears the TX datapath and skid buffer. Software must stop
  issuing DMA traffic before reset, wait for reset release, clear sticky
  status, then enable the stream. In-flight samples are intentionally dropped
  at that reset boundary rather than being replayed.

## Build and Evidence

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\implement_full_tx.ps1
```

The build runs IP packaging, synthesis, placement, routing, `write_bitstream`,
and XSA export. It fails on missing reset topology, mixed DMA/IP clock nets,
negative routed WNS, or a missing bitstream. Generated reports are written to
`fpga/zu15eg/out/full_tx/` and remain untracked.

The required review artifacts are `clocks.rpt`, `timing_summary.rpt`,
`utilization.rpt`, `power.rpt`, `cdc.rpt`, `drc.rpt`, `top.bit`, and
`full_tx_zu15eg.xsa`.

## Completed 2026-07-26 Performance-SKU Build

The selected Memory-Poly5, four-tap performance SKU completed implementation on
`xczu15eg-ffvb1156-2-i` with a generated bitstream and XSA. It retains only
the C1/C3/C5 memory-polynomial branch; the standalone polynomial and LUT
branches are compile-time pruned. Final routed timing met the 100 MHz
constraint: WNS `+2.314 ns` and TNS `0.000 ns`; the routed maximum-delay
report also has a `+3.500 ns` minimum pulse-width slack. The router's final
minimum-delay estimate was WHS `+0.010 ns` and THS `0.000 ns`. Integrated
utilization was 16,296 LUTs, 20,763 registers, 3.0 BRAM tiles, and 266
DSP48E2 blocks. Vectorless power estimation reported 4.114 W total, 3.268 W
dynamic, and 0.846 W static. Compact evidence is
`docs/evidence/integration/full_tx_zu15eg_20260726_memory_poly5_4tap_summary.csv`.

The routed CDC report contains no unsafe endpoints. Its warnings are limited
to the expected JTAG debug hub and false-pathed input-port crossings. The
upgraded legacy board design ties the optional observer stream to synchronous
zero constants; it therefore validates the TX implementation boundary, not a
physical PA feedback capture. The compact result is retained in
`docs/evidence/integration/full_tx_zu15eg_20260726_memory_poly5_4tap_summary.csv`.

The routed DRC has no errors and 236 warnings: eight `DPIP-2`, 98 `DPOP-3`,
and 122 `DPOP-4` DSP-pipelining advisories, plus debug/IP-generated LUT and
FIFO advisories. The selected SKU is timing clean at 100 MHz, but additional
DSP-register staging remains a performance and power optimization before
raising the clock target.

This build establishes FPGA integration evidence only. It does not establish
physical RF EVM, ACLR, PA linearization, or measured board power.

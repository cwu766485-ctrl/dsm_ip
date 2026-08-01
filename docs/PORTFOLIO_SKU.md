# Portfolio Demonstration SKU

## Selected Configuration

The recommended configuration for an interview demonstration is the validated
Performance SKU:

| Function | Selection |
|---|---|
| DSM | One-bit EFDSM (`ALGORITHM=2`) |
| Interpolation | Mode 4, x32 CIC plus compensation FIR |
| Upconversion | Fixed Fs/4 DUC (`DUC_MODE=0`) |
| DPD | Fifth-order, four-tap memory polynomial |
| DPD feature gates | Memory DPD enabled; polynomial and LUT paths removed |
| Control and observability | AXI-Lite, AXI-Stream, observer statistics, safe coefficient-bank commit |

This is the best portfolio point because it is an integrated, fixed-point
datapath rather than an isolated algorithm: it has MATLAB/RTL bit-true
evidence, directed XSim coverage of the protocol and coefficient-update
behavior, packaged IP, and a routed FPGA implementation. The fifth-order
four-tap DPD demonstrates a practical PA-memory tradeoff without presenting
an unintegrated TinyML policy as a deployed product feature.

The routed ZU15EG implementation at 100 MHz uses 16,296 LUTs, 20,763
registers, 3.0 BRAM tiles, and 266 DSP48E2 blocks. Its setup WNS is +2.314 ns.
See `docs/FULL_TX_IMPLEMENTATION.md` and
`docs/evidence/integration/full_tx_zu15eg_20260726_memory_poly5_4tap_summary.csv`.

## Preliminary 28 nm Logic-Synthesis Estimate

An existing local Design Compiler run used the complete top level and exactly
the selected configuration above. The constraint and library assumptions were:

| Item | Value |
|---|---|
| Standard-cell condition | 28 nm RVT, SS, 0.72 V, 125 C |
| Clock | 10.000 ns (100 MHz) `aclk` period |
| Clock uncertainty | 0.200 ns |
| I/O timing | 1.000 ns maximum input/output delay |
| I/O electrical assumptions | 0.100 ns input transition, 0.010 load |

The 100 MHz setup result has +1.22 ns slack. Holding mapping and constraints
constant, the corresponding zero-setup-slack estimate is 113.9 MHz:

```text
Fmax_est = 1 / (10.000 ns - 1.22 ns) = 113.9 MHz
```

The same run reports 120,392 um^2 standard-cell area. Its vectorless power
estimate is 5.54 mW dynamic plus 1.07 mW cell leakage at 100 MHz.

## Important Boundary

This is a preliminary logic-synthesis estimate, not an ASIC sign-off result.
The run reports a -0.11 ns worst hold violation and 20,802 hold violations,
one maximum-transition violation, zero-wireload interconnect, and no physical
RC, clock-tree, DFT, SRAM, I/O, or multi-corner/multi-mode analysis. Therefore
the appropriate interview statement is: **"100 MHz meets preliminary 28 nm
setup timing; about 114 MHz is the pre-layout setup estimate."** Do not claim
that 114 MHz is closed or sign-off clean.

The active Design Compiler license service was unavailable on 2026-07-28, so
this repository update does not claim a new 28 nm run. A fresh run must repeat
setup and hold analysis across the intended PVT corners after the license is
available.

# ASIC PPA Baseline

## Purpose

This document records the provenance of an existing Design Compiler result for
the frozen Performance SKU. It is a pre-layout synthesis baseline, not ASIC
signoff and not measured silicon power.

## Historical Report Snapshot

| Item | Reported value |
|---|---:|
| Technology library | 28 nm standard-cell RVT library |
| PVT | TT, 0.9 V, 25 C |
| Target clock | 100 MHz (10 ns) |
| Setup critical path delay | 4.45 ns |
| Setup slack | +5.42 ns |
| Hold slack | +0.03 ns |
| Total cell area | 125647.956 library area units |
| Combinational area | 84400.148 library area units |
| Sequential area | 41247.808 library area units |
| Estimated dynamic power | 8.1476 mW |
| Estimated leakage power | 73.1951 uW |
| Estimated total power | 8.2218 mW |
| Critical path | Memory-DPD state register to Memory-DPD arithmetic register |

The report used a wire-load model and low-effort zero-delay switching
propagation. It also reported unannotated primary inputs and sequential cell
outputs. Consequently, the power figures are vectorless estimates and must not
be used as activity-based power, board power, or silicon power.

## Frozen RTL Configuration

```text
Memory-Poly5, 4 tap
-> x32 CIC plus compensation FIR
-> Fs/4 band-pass mixer
-> one-bit BP EFDSM2
```

The complete elaborated top is `dsm_ip_axi_top` with `DUC_MODE=3`,
`INTERP_MODE=4`, `DPD_POLY_ORDER=5`, and `DPD_MP_MAX_TAPS=4`. Poly and LUT DPD
paths are disabled with compile-time feature gates.

## Required Refresh Before External Use

Run `syn/asic/run_performance_sku_dc.sh` with an approved local PDK and Design
Compiler license. Retain the fresh report bundle, archive its `summary.csv`,
and record the RTL revision. Use an annotated SAIF for a power result intended
for an external PPA comparison.

This baseline does not cover place-and-route, extracted parasitics, MCMM STA,
IR/EM, DFT, or physical signoff.

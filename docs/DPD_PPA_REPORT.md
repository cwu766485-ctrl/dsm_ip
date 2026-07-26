# ZU15EG DPD OOC PPA Report

## Scope

This report records the completed Vivado 2024.1 post-synthesis out-of-context
(OOC) sweep for `xczu15eg-ffvb1156-1-i`. Each configuration uses a 10.000 ns
`aclk` constraint and the fixed-function top in `syn/rtl/dpd_ooc_tops.sv`.
The raw reports are generated under `reports/dpd_ooc_zu15eg/`; the compact,
tracked evidence is:

```text
docs/evidence/ooc/dpd_ooc_xczu15eg_ffvb1156_1_i_20260725_summary.csv
```

## Results

| Configuration | LUT | FF | DSP48E2 | BRAM | WNS (ns) | Fmax estimate (MHz) | Dynamic power estimate (W) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Bypass | 1 | 33 | 0 | 0 | NA | NA | 0.000 |
| LUT DPD | 82 | 0 | 4 | 0 | NA | NA | 0.001 |
| Polynomial order 3 | 301 | 336 | 16 | 0 | +6.355 | 274.348 | 0.008 |
| Polynomial order 5 | 398 | 338 | 22 | 0 | +5.811 | 238.720 | 0.014 |
| Polynomial order 7 | 490 | 338 | 28 | 0 | +5.419 | 218.293 | 0.019 |
| Memory polynomial, 1 tap | 608 | 502 | 26 | 0 | +5.811 | 238.720 | 0.016 |
| Memory polynomial, 2 taps | 1,229 | 1,030 | 60 | 0 | +5.806 | 238.436 | 0.036 |
| Memory polynomial, 4 taps | 2,409 | 1,956 | 120 | 0 | +5.806 | 238.436 | 0.068 |
| Memory polynomial, 6 taps | 3,587 | 2,880 | 180 | 0 | +5.806 | 238.436 | 0.101 |

`Fmax estimate = 1000 / (10.000 - WNS)` and is reported only where Vivado
found a register-to-register maximum-delay path. Bypass has no such path; the
current LUT top is combinational. Their `NA` values are not timing failures.

## Current Feature-Gated Matrix

The following is the current RTL result on `xczu15eg-ffvb1156-2-i`. It uses
`syn/rtl/dpd_frontend_ooc_top.sv`, exposes polynomial coefficients as top-level
inputs to prevent constant folding, and applies `ENABLE_DPD_*` compile-time
gates. `development_all` keeps a variable runtime mode so all three branches
remain in the synthesized netlist.

| Configuration | LUT | FF | DSP48E2 | BRAM | WNS (ns) | Fmax estimate (MHz) | Dynamic power estimate (W) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Bypass | 52 | 75 | 0 | 0 | +9.221 | 1283.697 | 0.001 |
| Poly3 | 471 | 576 | 18 | 0 | +7.044 | 338.295 | 0.021 |
| Poly5 | 505 | 644 | 26 | 0 | +6.572 | 291.715 | 0.030 |
| Poly7 | 691 | 676 | 34 | 0 | +5.911 | 244.559 | 0.041 |
| LUT only | 199 | 141 | 4 | 0 | +9.163 | 1194.743 | 0.003 |
| Memory1 | 677 | 873 | 30 | 0 | +6.572 | 291.715 | 0.020 |
| Memory2 | 1,300 | 1,620 | 60 | 0 | +6.572 | 291.715 | 0.037 |
| Memory4 | 2,480 | 3,058 | 120 | 0 | +6.572 | 291.715 | 0.069 |
| Memory6 | 3,658 | 4,494 | 180 | 0 | +6.572 | 291.715 | 0.102 |
| Development all modes | 3,077 | 3,691 | 150 | 0 | +6.572 | 291.715 | 0.100 |

The tracked source record is
`docs/evidence/ooc/dpd_feature_ooc_zu15eg_ffvb1156_2_i_20260725_summary.csv`.

### Current Decision

- `Poly5` is the lightweight deterministic default when a PA fit does not
  require memory effects.
- `Memory4` is the justified memory-polynomial candidate: it doubles the
  `Memory2` arithmetic to 120 DSP48E2 and therefore requires measured PA or
  observation-model benefit before deployment.
- `Development all modes` costs 150 DSP48E2 because it retains Poly5, LUT,
  and Memory4 for runtime selection. It is suitable for integration/debug but
  is not the preferred production SKU.

## Architecture Decision

- All registered polynomial and memory-polynomial configurations close the
  100 MHz OOC target with more than 5.4 ns WNS.
- Fifth-order memoryless DPD is the default PPA point: it uses 22 DSP48E2 and
  has a 238.720 MHz post-synthesis estimate. Seventh order costs six more DSPs
  and reduces the estimate to 218.293 MHz; it should be selected only when a
  PA sweep demonstrates a material EVM or ACLR benefit.
- Memory depth is expensive in the fully unrolled implementation. Moving from
  one to four taps changes 26 to 120 DSP48E2 and 608 to 2,409 LUTs. Use the
  four-tap mode only for PA models or measured feedback that demonstrate memory
  effects; it is not the default deployment mode.
- The LUT path has the lowest arithmetic cost, but this OOC top does not
  include the complete coefficient-update/control path. It must be evaluated
  with its intended table size, update policy, and full wrapper before an ASIC
  architecture decision.

## Evidence Limits

- This is post-synthesis OOC evidence, not placed-and-routed timing closure or
  bitstream timing. It excludes the AXI wrapper, DMA, DSM/interpolation chain,
  I/O, and board clocks.
- The fixed OOC tops use constant coefficient inputs. Resource and timing
  trends are useful for the selected datapath architecture, but a dynamic
  AXI-programmable integration can differ after constant propagation is
  removed.
- Vivado `report_power` used default vectorless switching assumptions. The
  dynamic-power values are comparative synthesis estimates only, not measured
  board power or sign-off power.
- PPA does not establish DPD linearization quality. Select order and memory
  depth from the PA/observation-receiver validation sweep, then confirm the
  selected configuration in the routed TX integration.

## Reproduction

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_dpd_matrix.ps1
```

The script writes `reports/dpd_ooc_zu15eg/summary.csv` and now parses the
Vivado 2024.1 `CLB LUTs` and `CLB Registers` labels plus vectorless power
estimates.

For the current feature-gated matrix:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_dpd_feature_matrix.ps1 -Part xczu15eg-ffvb1156-2-i
```

Use `-Config poly5` or another named configuration for a focused rerun. A
focused rerun preserves the other rows in `summary.csv` and replaces only the
requested configuration.

# Evidence Index

This directory contains compact evidence for the DSM IP handoff.

## Timing-Clean OOC Paths

Reference file:

```text
ooc/p0_ooc_xc7z020_20260702_summary.csv
ooc/p0_ooc_xczu48dr_20260702_summary.csv
```

### Zynq-7020 / PYNQ-Z2 Proxy

| Top | LUT | FF | DSP | WNS (ns) | Fmax est. (MHz) |
|---|---:|---:|---:|---:|---:|
| `p0_ooc_lp1` | 104 | 71 | 0 | +6.557 | 290.44 |
| `p0_ooc_lp2` | 470 | 167 | 0 | -1.175 | 89.49 |
| `p0_ooc_ef1` | 182 | 63 | 0 | +2.221 | 128.55 |
| `p0_ooc_ef2` | 316 | 119 | 0 | +0.080 | 100.81 |
| `p0_ooc_mash11` | 274 | 100 | 0 | -2.098 | 82.66 |
| `p0_ooc_mash111` | 407 | 143 | 0 | -7.438 | 57.35 |
| `p0_ooc_mash22` | 276 | 177 | 8 | -8.646 | 53.63 |

LPDSM, EFDSM, and EFDSM2 have `WNS >= 0` at a 100 MHz target. LPDSM2 and
MASH are restored but currently fail the 100 MHz timing criterion on this
target.

### RFSoC 4x2 / ZU48DR Proxy

| Top | LUT | FF | DSP | WNS (ns) | Fmax est. (MHz) |
|---|---:|---:|---:|---:|---:|
| `p0_ooc_lp1` | 103 | 71 | 0 | +9.072 | 1077.59 |
| `p0_ooc_lp2` | 469 | 167 | 0 | +5.624 | 228.52 |
| `p0_ooc_ef1` | 181 | 63 | 0 | +7.363 | 379.22 |
| `p0_ooc_ef2` | 315 | 119 | 0 | +6.558 | 290.53 |
| `p0_ooc_mash11` | 246 | 88 | 0 | +5.764 | 236.07 |
| `p0_ooc_mash111` | 382 | 133 | 0 | +3.908 | 164.15 |
| `p0_ooc_mash22` | 251 | 167 | 72 | +2.017 | 125.27 |

All seven paths have `WNS >= 0` at a 100 MHz target on `xczu48dr-ffvg1517-2-e`.

## Release Summary

Reference file:

```text
closure/p0_100mhz_release_summary.csv
```

This combines retained RTL simulation pass records and timing-clean OOC records
from the checked 100 MHz snapshot.

## Evidence Boundary

LPDSM2 and native-multibit MASH paths have been restored into RTL, simulation,
and OOC scripts. They are not 100 MHz timing-clean on `xc7z020clg400-1`, but
they are 100 MHz timing-clean in the current `xczu48dr-ffvg1517-2-e` proxy OOC
run.

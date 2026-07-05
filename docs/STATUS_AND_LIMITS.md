# Status and Limits

## Verified Status

- Seven DSM paths are retained: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11,
  MASH111, and MASH22.
- MATLAB/RTL bit-true comparison passes with zero mismatches for all seven
  paths.
- XSim regression passes for all seven retained testbenches.
- IP smoke tests pass for the streaming top and AXI wrapper.
- Vivado IP packaging generates `ip/ip_repo/dsm_ip_1_0/component.xml`.
- OOC synthesis evidence is retained for `xc7z020clg400-1`,
  `xczu15eg-ffvb1156-1-i`, and `xczu48dr-ffvg1517-2-e`.
- Exploratory multibit Cartesian DSM modes are MATLAB/RTL bit-true over the P0
  65536-sample vector set with zero mismatches.
- The interpolation/filter frontend supports bypass, x4, x8, x16, and x32
  modes in RTL with MATLAB/RTL bit-true comparison, and is inserted before
  `dsm_ip_core` in `dsm_ip_top`.
- The AXI wrapper includes a one-entry AXI-Stream skid buffer. Legal
  backpressure is counted in `INPUT_STALL_COUNT`; streaming while disabled or
  in reset is reported through sticky error status.

## Timing Summary

On `xc7z020clg400-1`, all seven retained paths meet the 100 MHz proxy OOC
target in the 2026-07-03 evidence:

| Top | Status | LUT | FF | DSP | WNS ns | Fmax est MHz |
|---|---|---:|---:|---:|---:|---:|
| `p0_ooc_lp1` | PASS | 104 | 71 | 0 | 6.557 | 290.44 |
| `p0_ooc_lp2` | PASS | 270 | 87 | 0 | 0.165 | 101.68 |
| `p0_ooc_ef1` | PASS | 182 | 63 | 0 | 2.221 | 128.55 |
| `p0_ooc_ef2` | PASS | 316 | 119 | 0 | 0.080 | 100.81 |
| `p0_ooc_mash11` | PASS | 274 | 102 | 0 | 2.811 | 139.10 |
| `p0_ooc_mash111` | PASS | 398 | 148 | 0 | 2.594 | 135.03 |
| `p0_ooc_mash22` | PASS | 276 | 179 | 8 | 0.455 | 104.77 |

The retained evidence file is
`docs/evidence/ooc/p0_ooc_xc7z020_20260703_summary.csv`.

The 2026-07-05 multibit OOC evidence on `xc7z020clg400-1` uses 4-bit multibit
quantizers, `ACC_W_MB=16`, wrap/no-saturate state arithmetic, and post-place /
post-route physical optimization:

| Top | Status | LUT | FF | DSP | WNS ns | Fmax est MHz |
|---|---|---:|---:|---:|---:|---:|
| `p0_ooc_mb_lp1` | PASS | 492 | 60 | 0 | 1.466 | 117.18 |
| `p0_ooc_mb_lp2` | PASS | 619 | 96 | 0 | 0.018 | 100.18 |
| `p0_ooc_mb_ef1` | PASS | 504 | 60 | 0 | 1.392 | 116.17 |
| `p0_ooc_mb_ef2` | FAIL_TIMING | 596 | 92 | 0 | -0.093 | 99.08 |
| `p0_ooc_mb_mash11` | PASS | 975 | 116 | 0 | 0.960 | 110.62 |
| `p0_ooc_mb_mash111` | PASS | 1467 | 180 | 0 | 0.016 | 100.16 |
| `p0_ooc_mb_mash22` | FAIL_TIMING | 1203 | 188 | 0 | -0.688 | 93.56 |

The retained multibit evidence file is
`docs/evidence/ooc/p0_ooc_xc7z020_20260705_multibit_summary.csv`.

On the conservative ZU15EG target `xczu15eg-ffvb1156-1-i`, the 2026-07-05 OOC
run closes all 14 single-bit/native and multibit DSM tops at the 100 MHz proxy
target:

| Top | Status | LUT | FF | DSP | WNS ns | Fmax est MHz |
|---|---|---:|---:|---:|---:|---:|
| `p0_ooc_lp1` | PASS | 103 | 71 | 0 | 8.955 | 956.94 |
| `p0_ooc_lp2` | PASS | 269 | 87 | 0 | 5.818 | 239.12 |
| `p0_ooc_ef1` | PASS | 181 | 63 | 0 | 7.150 | 350.88 |
| `p0_ooc_ef2` | PASS | 315 | 119 | 0 | 5.449 | 219.73 |
| `p0_ooc_mash11` | PASS | 246 | 90 | 0 | 6.926 | 325.31 |
| `p0_ooc_mash111` | PASS | 373 | 138 | 0 | 7.122 | 347.46 |
| `p0_ooc_mash22` | PASS | 251 | 169 | 72 | 5.107 | 204.37 |
| `p0_ooc_mb_lp1` | PASS | 468 | 50 | 0 | 6.263 | 267.59 |
| `p0_ooc_mb_lp2` | PASS | 584 | 82 | 0 | 5.283 | 212.00 |
| `p0_ooc_mb_ef1` | PASS | 480 | 50 | 0 | 6.453 | 281.93 |
| `p0_ooc_mb_ef2` | PASS | 570 | 82 | 0 | 5.176 | 207.30 |
| `p0_ooc_mb_mash11` | PASS | 964 | 105 | 0 | 5.884 | 242.95 |
| `p0_ooc_mb_mash111` | PASS | 1466 | 171 | 0 | 5.725 | 233.92 |
| `p0_ooc_mb_mash22` | PASS | 1168 | 179 | 0 | 4.896 | 195.92 |

The retained ZU15EG evidence file is
`docs/evidence/ooc/p0_ooc_xczu15eg_ffvb1156_1_i_20260705_summary.csv`.

On `xczu48dr-ffvg1517-2-e`, all seven retained paths meet the 100 MHz proxy OOC
target in the current evidence.

## Safe Claims

- This repository is a reusable DSM RTL/IP handoff package.
- It includes MATLAB fixed-point reference models, RTL, testbenches, IP
  packaging scripts, and synthesis evidence.
- RFSoC4x2 board files, schematics, BOMs, reference manuals, and vendor board
  packages are local-only collateral and are not intended for public GitHub
  release unless redistribution rights are confirmed.

## Claims To Avoid

- Do not claim this is a complete RFSoC4x2 bitstream-ready project.
- Do not claim full RFSoC board timing/resource closure.
- Do not claim all algorithms close timing on all FPGA targets unless the
  target has explicit retained OOC or implementation evidence.
- Do not claim runtime algorithm switching unless it is implemented.
- Do not claim runtime interpolation switching. The current interpolation mode
  is a compile-time parameter.
- Do not claim the interpolation frontend is deeply pipelined for maximum
  frequency. The current RTL reduces FIR arithmetic cost with symmetric
  pre-adds and zero-coefficient pruning while keeping the existing latency and
  bit-true behavior.
- Do not claim all multibit modes close at 100 MHz on `xc7z020clg400-1`; EFDSM2
  multibit and MASH22 multibit still need timing closure work.
- Do not claim a complete ZU15EG board-level implementation or bitstream from
  OOC evidence alone. The current ZU15EG result is module-level OOC timing and
  resource evidence only.

## Public Release Notes

Before publishing to GitHub, keep restricted RFSoC board collateral out of the
public repository. If a board flow is restored later, document the required
private/local source path instead.

# Status and Limits

## Verified Status

- Seven DSM paths are retained: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11,
  MASH111, and MASH22.
- MATLAB/RTL bit-true comparison passes with zero mismatches for all seven
  paths.
- XSim regression passes for all seven retained testbenches.
- IP smoke tests pass for the streaming top and AXI wrapper.
- Vivado IP packaging generates `ip/ip_repo/dsm_ip_1_0/component.xml`.
- OOC synthesis evidence is retained for `xc7z020clg400-1` and
  `xczu48dr-ffvg1517-2-e`.

## Timing Summary

On `xc7z020clg400-1`, LPDSM, EFDSM, and EFDSM2 meet the 100 MHz proxy OOC
target in the current evidence. LPDSM2 and MASH paths synthesize but do not
meet 100 MHz timing on that smaller target.

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
- Do not claim all algorithms close timing on all FPGA targets.
- Do not claim runtime algorithm switching unless it is implemented.

## Public Release Notes

Before publishing to GitHub, keep restricted RFSoC board collateral out of the
public repository. If a board flow is restored later, document the required
private/local source path instead.

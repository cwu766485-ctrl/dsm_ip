# PPA Study Matrix

The fixed Performance SKU is the primary implementation result. It should be
measured across a clock sweep before comparing optional microarchitectures.

## Primary Result

| Identifier | DPD | Interpolation | Modulator | Intended evidence |
|---|---|---|---|---|
| `performance_sku` | Memory-Poly5, 4 tap | x32 CIC plus compensation FIR | BP EFDSM2 | Full AXI top, DC pre-layout and FPGA routed flow |

Sweep the target clock at 100, 200, 300, 400, and 500 MHz, retaining only
legal mapped implementations with non-negative setup slack. The supplied
`run_frontend_pareto_dc.sh` implements x4/x8/x16/x32 bypass rows and the x32
Memory-Poly5 four-tap row at one selected target clock.

## Architecture Studies

| Study | Variable | Keep constant | Required paired evidence |
|---|---|---|---|
| Interpolation tradeoff | mode x4, x8, x16, x32 | input amplitude and bandwidth | MATLAB spectral metrics plus independent PPA runs |
| DPD tradeoff | bypass versus Memory-Poly5 4 tap | PA profile and input backoff | behavioral EVM/ACLR plus PPA runs |
| Legacy DSM core tradeoff | LP/EF/MASH core | core I/O width and target clock | core-level bit-true and OOC PPA |

Do not merge the legacy LP/EF/MASH core study with the `DUC_MODE=3` BP EFDSM2
full-chain result. The two paths have different sampling and RF conventions.

## Report Discipline

Record raw report paths, RTL revision, PVT label, target clock, constraints,
area units, and power activity source beside every reported table. Do not use
a vectorless or zero-delay power estimate as measured power.

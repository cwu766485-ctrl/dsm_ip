# DSM Digital Transmitter IP Specification

## Scope

This repository contains two deliberately separate synthesizable paths.

| Path | Status | Purpose |
|---|---|---|
| BP-EFDSM2 transmitter IP | Frozen reusable baseband/IF IP | AXI-stream I/Q, DPD, interpolation, Fs/4 mapping and one-bit BP-EFDSM2 |
| Cartesian x4/TI64 raw-GTH prototype | Verification-first FPGA prototype | Sixteen ordered I/Q samples per word to a 64-bit, 14 Gb/s raw-GTH word |

Neither path proves PA/DPA behavior, RF EVM/ACLR, a physical serial link, or
ASIC signoff without its separate verification and implementation evidence.

## Frozen BP-EFDSM2 IP contract

| Item | Contract |
|---|---|
| Top | `dsm_ip_axi_top` |
| Input | Signed Q1.15 complex I/Q through AXI4-Stream |
| DPD | Five-order, four-tap memory polynomial; inactive-bank update and safe commit |
| Interpolation | x32 fixed-point interpolation |
| Upconversion | Real Fs/4 mapping |
| DSM | One-bit BP-EFDSM2 |
| Control | AXI4-Lite, coefficient banks, status and sticky errors |
| Primary FPGA target | `xczu15eg-ffvb1156-2-i`, 100 MHz integration clock |

Widths, signedness, scaling, rounding, saturation, reset state, update order,
latency and vector formats are RTL/model contracts. They must not change
without updating golden models and verification evidence.

## Cartesian x4/TI64 contract

```text
16 ordered I/Q samples/word
 -> 16-way vector DPD (bypass or memoryless polynomial)
 -> x4 vector polyphase FIR
 -> 64 ordered I/Q samples
 -> [I, Q, I, Q]
 -> 64 independent LP1 TI64 lanes; one output-side +,+,-,- Fs/4 translation
 -> ordered 64-bit raw-GTH user word
```

Lane 0 is the earliest temporal sample. The Fs/4 translation is owned exactly
once by TI64; applying it both before and after the lane quantizers cancels
under odd-symmetric lane quantization. TI64 is a 64-way time-interleaved LP1
implementation; it is not temporal BP-EFDSM2 and it is not MASH. The FIR
retains seven source-rate history samples across words. Its five elastic stages
preserve `(low + middle) + high` fixed-point arithmetic, rounding, saturation,
history and lane order, while adding latency only.

At `TXUSRCLK2=218.75 MHz`, 64 raw bits per word represent a 14 Gb/s one-bit
serial boundary. Fs/4 places its intended digital center at 3.5 GHz; this is
not a 14 GHz RF carrier claim.

## Current evidence and limits

The clean ZU15EG x4 raw-GTH implementation closed with zero errors and zero
critical warnings: WNS `+0.387 ns`, WHS `+0.010 ns`, TNS/THS `0`; 20,835 LUTs,
21,203 FFs, 385 DSPs and 4 BRAM tiles. Independent x4 bit-true XSim, P0 XSim
7/7, and five IP-smoke tests passed.

This is digital and routed-implementation evidence only. Before board use or
ASIC work, satisfy the dedicated verification-first gates in `VPLAN.md`.
Board loopback then establishes physical SFP0 word order and link behavior.
ASIC work additionally needs a target-library lint/CDC/DFT plan, synthesis,
multi-corner STA, power analysis, reset/clock implementation and equivalence
strategy.

## Reproducible entry points

Use the static catalog through:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\eda\invoke-eda-task.ps1 -Task <id>
```

Relevant x4 tasks are `xsim-ti64-x4-frontend`, `ooc-ti64-x4-frontend` and
`build-zu15eg-raw-gt14-sfp0-x4`. Vivado-generated GT/IP products and bitstreams
must be created outside the repository.

`VPLAN.md` is the source of truth for verification criteria. The active
execution state is maintained separately in `docs/exec-plans/`.

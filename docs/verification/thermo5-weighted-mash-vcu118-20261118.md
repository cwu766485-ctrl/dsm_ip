# Thermo5 Weighted MASH VCU118 Candidate

Run date: 2026-11-15 (Vivado host local time). Source worktree HEAD: `cadb3dc4c1736d6b11858ce14a9bb5d32eebf81d`. The independent RTL/MATLAB bundle was recovered unchanged from `7b5c2a853f04c1a5073a9a84e84c64982f922d65`; its two GT boundary dependencies were also recovered from that commit. Product Thermo5 RTL and defaults were not changed.

## Functional Evidence

MATLAB R2025a generated 128 vectors with seed `20260916`, 32 lanes per I/Q vector, signed W=16 inputs uniformly selected from [-12000, 12000]. The historical SystemVerilog testbench compared both 64-bit PA branch words for all 128 outputs. Icarus Verilog compiled and ran the same testbench: `TID32_MASH11_FS4_MULTIPA_BITTRUE_PASS words=128 samples=4096`. Thus 4,096 I plus 4,096 Q lane samples and both encoded output branches matched the MATLAB oracle exactly.

The recovered model uses the TID first-order sign decision from the registered accumulator MSB and the historical MASH stage-2 saturated residual `x-q1`. The MATLAB oracle defines zero-sign ties through its registered-MSB decision, and its stage-2 input applies the `x-q1` polarity; the random-stream RTL comparison checks the resulting branch bits, but there is no separate directed tie-only or residual-polarity assertion. The test compares both PA branch streams but does not separately assert the weighted analog cancellation equation. The Fs/4 raw-bit order is exercised by all vector comparisons. The test exercises 128 consecutive input vectors and reset startup, but does not independently assert cycle-accurate latency or a named II property. RTL has a documented 35-vector fixed alignment delay (33 algorithmic alignment vectors plus two raw-GT boundary vectors); steady-state stage valid is generated once for each accepted input vector. A backpressure-capable downstream output contract is not part of this historical MASH block.

Historical link-model results from the corrected common receiver remain model-only: QAM16/64/256 EVM 2.507/2.516/2.521% and SNDR 32.017/31.987/31.968 dB for four held-out seeds; QAM256 natural-binary BER was 2.81e-4. These are not a fresh MATLAB rerun in this turn and are not FPGA measurements. No new comparison claim against the already routed Cubic+EF1 product is made here.

## VCU118 OOC Implementation

Vivado 2026.1, part `xcvu9p-flga2104-2L-e`, one 4.571 ns clock (218.75 MHz target), OOC top `tid32_mash11_fs4_multipa_tx_ooc`, AreaOptimized_high synthesis directive, then `opt_design`, `place_design`, `phys_opt_design`, and `route_design`.

| Metric | Routed result |
| --- | ---: |
| LUT (logic + SRL) | 14,279 (8,475 logic LUT; 5,804 SRL) |
| FF | 13,440 |
| CARRY8 | 1,004 |
| DSP48 | 0 |
| BRAM / URAM | 0 / 0 |
| WNS / TNS | +1.090 ns / 0.000 ns |
| WHS / THS | +0.032 ns / 0.000 ns |
| Setup / hold failing endpoints | 0 / 0 |
| Critical path | `gt_valid_reg/Q` to `s1_delay_reg[32][1].../CE`, 3.279 ns data delay: 0.079 ns cell + 3.200 ns net, 0 logic levels, fanout 293 |
| Route status | 20,761/20,761 routable nets fully routed; 0 routing errors |
| Power | 3.204 W vectorless estimate (0.725 W dynamic, 2.480 W static), medium confidence; no SAIF/activity workload |
| Throughput / latency | 32 samples per accepted vector; II=1 by the RTL's accepted-vector cadence; documented 35-vector alignment latency, not separately cycle-measured by the TB |

The routed slack is positive against the modeled OOC clock, but does not establish board-level timing. `check_timing` reports 1,025 input ports without input delay and 129 output ports without output delay; these interface budgets are absent from the OOC wrapper. Vivado emitted `HD.CLK_SRC` unset for the clock and repeated `HD.PARTPIN_LOCS` warnings for vector input ports, so input-to-register/port timing and partial-route export are limited. The report also emitted four synthesis warnings: two large 3D register-array runtime warnings and two trimmed unused MSB-differential bits. These did not stop synthesis or route. `report_timing -nets` emitted a deprecation warning. Vectorless power is an estimate, not measured dissipation.

The corresponding historical ZU15EG/Vivado 2024.1 OOC report was approximately 14,276 LUT, 13,439 FF, 1,012 CARRY8, 0 DSP/BRAM, WNS +1.315 ns and WHS +0.029 ns. It is a different device/tool run and is not substituted for this VCU118 result.

## B Pipeline Status

The two existing VCU118 Pipeline B implementation DCPs remain intact:

| Strategy | WNS / WHS | DCP SHA-256 |
| --- | ---: | --- |
| Explore | +0.307 / +0.028 ns | `1f5cd3c950c8da8b1a2781b7d788fd0c09f307549836aedb0098e6a645a9088f` |
| RuntimeOptimized | +0.249 / +0.028 ns | `e694a728b7523a50d65683314d957316ef716dd6f63c2cffb0457cad42fe8173` |

Previously preserved Original/Pipeline × Generic/XPM COMMIT runs all contain `THERMO5_AXIL_CONFIG_BITTRUE_PASS source=32 output=56 taps=2 identity=1` and each has an `axil_trace.vcd`. A fresh automated replay was not completed: XVlog/Xelab produced snapshots, but the XSim launcher intermittently reported the compiled snapshot missing when launched from WSL-hosted PowerShell. A proposed runner change was reverted because it did not fix the issue. Product-level Reset During Traffic, STOP/Restart, long random backpressure, ECO CDC/RDC, formal, and code-coverage closure remain OPEN. VCS/VC Formal/SpyGlass were not run in this environment.

## Reproduction

Run the MATLAB generator and RTL test from the independent bundle with MATLAB R2025a and Vivado 2026.1 installed. The recorded vector directory is `runs/thermo5_weighted_mash_vcu118_20261118/vectors/`; the Icarus executable and simulator result are under that run root. The VCU118 Tcl invocation was:

```powershell
vivado.bat -mode batch -source research/thermo5_weighted_mash/syn/run_ooc_tid32_mash11_fs4_multipa_tx.tcl -tclargs xcvu9p-flga2104-2L-e 218.75 E:/workspace/chip/dsm_ip_thermo5_vcu118/runs/thermo5_weighted_mash_vcu118_20261118/ooc_vcu118_retry
```

Artifact hashes and exact source/vector identities are recorded in `docs/verification/data/thermo5-weighted-mash-vcu118-20261118-manifest.json`. Routed DCP and full native logs remain in ignored `runs/`.

## Decision

The historical weighted MASH implementation is a viable independent high-speed FPGA candidate: this OOC run routed at the target clock with positive setup/hold slack and substantially lower logic resources than the four-plane EF2 matrix measurements. It is not directly compatible with the current Thermo5 four-plane PA interface, and its product AXI-Stream/reset/backpressure integration, latency accounting, CDC/RDC, power activity, and system timing are unverified. Keep it as a separate weighted-PA SKU candidate; do not replace Cubic+EF1 or claim product signoff from this OOC result.

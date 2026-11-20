# Four-frame Live AXIS-to-GTY digital regression — 2026-11-18

**Status: PASS for the bounded digital simulation.** This is not hardware or RF signoff.

Vivado 2026.1 build 6511674, `xcvu9p-flga2104-2L-e`, was configured for dual 14.000 Gb/s RAW GTY lanes, 125 MHz reference, and 64-bit lane payloads. The live test drove four continuous frames through the AXI-Stream frontend, Runtime MASH 1-1, weighted PA outputs, the research elastic buffer, and GT Wizard TX/RX loopback. TXUSRCLK2 measured 4571.429 ps.

The test sent and emitted 21,056 PA words per lane (1,347,584 serial bits per lane). TX and RX loopback recovered every bit exactly. The measured TX bit-search starts were 22,866 / 22,866, and RX starts were 23,713 / 23,713; lane skew was zero. All four frame boundary markers, architecture=MASH, config ID=1, and tail=0 matched the expected sequence. Final drain completed with zero backend underflow, serializer underflow, protocol errors, buffer overflow, or output gap cycles.

The test stops after the final frame and drains. It does not include random AXIS bubbles, random downstream backpressure, reset during this four-frame stream, or a product-propagated transaction epoch. The testbench currently scans the serial capture for the known payload pattern and reports the resulting offsets; fixed serializer capture latency is not asserted. The elastic-buffer input epoch is constant zero in this run. Prior one-frame digital receiver evidence remains EVM 2.551442%, SNDR 31.864285 dB, and uncoded BER 15/37,376; those metrics were not recomputed in this four-frame run. Board RF EVM and ACLR are NOT_MEASURED.

## Evidence

- Run result: `runs/live_long_4frame_02/result.json`
- Console: `runs/live_long_4frame_02/console_retry01.log`
- Vivado log: `runs/live_long_4frame_02/vivado_retry01.log`
- XSim log: `runs/live_long_4frame_02/project/project/gty_sim.sim/sim_1/behav/xsim/simulate.log`
- Captured serialized lanes: `serial_pa0.mem` SHA-256 `88c65cf314e848b0b4a3e0bc7fa5d5c0e7ec4f74d60bc38ac73000d8d4a36224`; `serial_pa1.mem` SHA-256 `66388784fc95389438d7b6675843ffe8cce8f097318f446a46bb1a32a4b4c21b`
- Source hashes: `runs/live_long_4frame_02/all_source_sha256.txt`
- Reproduction: run `runs/live_long_4frame_02/run_retry01.cmd` from Windows.

## Receiver metrics from the four-frame serial capture

The exact captured PA words were checked against the continuous Python
Golden: all 21,056 words on each lane match with no first mismatch. The first
frame was evaluated with the existing runtime receiver at its fixed
`SOURCE_OFFSET=528`; no best-lag search was used. Results are EVM 2.551442%,
SNDR 31.864285 dB, and uncoded BER 15/37,376 (0.04013%). The receiver result
is saved at `runs/live_long_4frame_02/receiver_metrics_01/qam_metrics.json`.
This is a metric on the first frame in the continuous capture; it does not
claim that all four frames were separately demodulated, and it is not a board
RF/ACLR measurement.

## Reset-boundary supplement — bounded only

The v4 runtime wrapper also passes a small Icarus reset-boundary smoke at
`runs/de_v4_reset_contract_smoke_02/`: Core-only reset aborts the source and
serializer epochs while AXI-Lite remains ready; AXI-Lite reset aborts the
stream epochs; each local reset release completes. This does not inject reset
during the active four-frame stream and does not close the live reset/epoch
contract.

## Preserved frame-boundary failure

An earlier continuous-serialization attempt in
`runs/live_long_continuous_01/console.log` fails at `emitted=5264`, the first
frame boundary, with `continuous PA gap before final word`. Its console SHA-256
is `43e2202cab962b006728536149ad7e3ea9bf68916cb060b35870deca4ca37fca`.
The failure is retained. The later two-frame elastic-buffer snapshot
(`runs/live_long_elastic_05/console.log`, SHA-256
`f7550c398ccff44ce74af22ed8b9379c3d4d469c24aac14424a8f9a2905ead0e`) and
four-frame snapshot above both pass. The earlier run did not preserve a full
source/elaboration manifest, but the Tcl command and console show that it
instantiated `thermo5_frame_prefill_tx`. That research module only starts
reading the next bank on the cycle after it frees the current bank and toggles
`rd_bank`; the registered output mask is cleared in between, so it necessarily
inserts a one-cycle bank-handover bubble. The later `thermo5_elastic_pa_tx`
implementation uses one continuously counted FIFO and removes that handover
bubble; its two-frame and four-frame digital tests pass. This identifies the
failure mechanism in the tested buffer implementation, but does not prove the
elastic buffer is integrated into the product top. Randomized stalls, reset
during the same long stream, and product-propagated epochs remain untested.


## 16-frame continuous test attempt — BLOCKED, no simulation result

A separate continuous-state scalar Golden and 16-frame testbench were prepared
under `runs/live_long_16frame_02/`. The vector set contains 84,224 PA words
per lane (5,390,336 serialized bits per lane). The watchdog was increased to
500 us, covering the expected approximately 385 us serial duration. No Golden,
DUT, pass threshold, or source vector was changed to make this run pass.

Nine preserved Vivado/XSim startup or compile attempts did not reach DUT
simulation. The generated `compile.bat` could not resolve `xvlog`; changing
launcher/Tcl PATH and adding local command wrappers did not alter the child
process environment. A direct unwrapped-Vivado start lacked loader runtime
setup, and the replicated loader attempt stalled before producing a log; that
process was stopped. Per-attempt artifacts and dispositions are in
`runs/live_long_16frame_02/manifest.json`. Therefore this 16-frame regression
is **BLOCKED**, not a functional pass or failure. The four-frame result above
remains the longest completed continuous-chain evidence. Random active
backpressure, reset during the same long stream, and physical RF EVM/ACLR remain
unmeasured.


## 16-frame runner closure — 2026-11-20

The prior “16-frame attempt — BLOCKED” section above is the historical state
for the nine runs in runs/live_long_16frame_02/; those logs and manifest
remain unchanged. The launcher root cause was reproduced independently in
runs/live_long_16frame_blocked_repro_01/: with Vivado absent from the child
PATH, compile.bat returns exit 1 and reports that xvlog is not recognized.

With Vivado/bin before Vivado/bin/unwrapped/win64.o, the new no-wave runner
completed all stages with return code 0 in
runs/live_long_16frame_fix04/. It built the XSim snapshot, sent and emitted
84,224 words per lane across 16 frames, drained without underflow/overflow or
protocol fault, and passed dual-lane TX and RX serial bit-true checks at
14.000 Gb/s with zero lane skew. Both 84,224-word PA captures match the
independent continuous Golden exactly (first_mismatch=null).

First-frame receiver analysis at fixed source offset 528, without lag search,
reports EVM RMS 2.551442%, SNDR 31.864285 dB, and uncoded BER 15/37,376. Board
RF EVM/ACLR are NOT_MEASURED. This is a GT Wizard behavioral digital test
using the research Runtime wrapper and elastic FIFO snapshot. The test uses
constant epoch 0, no random backpressure, and stops after the final frame.
Reset-during-traffic and STOP/Restart results remain separate bounded runs;
the combined stress case and product-top integration remain open.

Full evidence, stage exit codes, source hashes, serial hashes, Golden hashes,
receiver JSON, and exact reproduction command are in
runs/live_long_16frame_fix04/manifest.json,
runs/live_long_16frame_fix04/source_sha256.txt, and
docs/verification/vcu118_de_closure_20261118/de_final_closure_20261120.md.
This closes the XSim environment/16-frame regression blocker, not DE Freeze.

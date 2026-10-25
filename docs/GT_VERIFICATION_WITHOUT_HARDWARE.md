# GT verification boundary without FPGA hardware

## What can be completed without a board

The digital handoff can verify the 64-bit, 218.75 MHz user-side contract,
word atomicity, earliest-bit ordering, reset and ready/valid behavior, and
phase alignment between output planes.  A behavioral serializer/deserializer
can prove that a 64-bit raw word emitted LSB-first at 64 serial edges is
recovered unchanged.  PRBS/known-word generators, checkers, sticky error
status, counters, and the link/reset controller can also be verified in RTL.

If a concrete FPGA, package, GT quad, line rate, reference clock, and pin map
are selected, a generated GT Wizard wrapper and its vendor simulation model
can be compiled and the complete design can be implemented for static timing.
That remains a model- and constraint-based result, not a measured link.

Behavioral channel studies may add AWGN, bounded jitter, loss, or bit errors.
The digital reconstruction path may then calculate EVM, SNDR, ACLR, and BER.
These studies are useful sensitivity analyses, but their accuracy is limited
by the assumed clock, channel, PA, filter, and receiver models.

## What requires physical hardware

The following cannot be signed off by RTL or vendor simulation alone:

- actual PLL/CDR lock and reset bring-up;
- reference-clock quality and recovered-clock behavior;
- 14 Gb/s electrical eye, deterministic/random jitter, and measured BER;
- package, connector, PCB, cable, and channel loss;
- physical serial loopback and recovered-word alignment;
- PA, coupler, reconstruction filter, antenna, and measured EVM/ACLR.

## Current project evidence

Thermo5 now has two complementary serialization simulations. The fast,
vendor-neutral behavioral raw64 loopback passed 64 words (4,096 bits) per
plane against the MATLAB golden code planes. Separately, the ZU15EG GT-parent
XSim regression instantiates the generated four-channel GT Wizard model,
drives AXIS frames through the thermo5 frontend, samples the GT TXP pins at
the configured 14.0-Gb/s unit interval, and bit-compares two complete 56-word
frames on all four lanes against the GT parallel user words. It also checks
alternating idle serialization and differential TX polarity. The reproducible
command is documented in `dv/verif/integration/README.md`; results are under
`runs/thermo5_gt14_e2e_clean_20261025_222945/` for the current run.

Additional four-lane GT-parent stress and negative-frame scenarios also pass.
Four separate full-chain XSim runs cover signed ramp, zero I/Q, alternating
`0x7fff`/`0x8000` I/Q endpoints, and a two-sample impulse; each applies eight
fixed-seed AXIS valid-gap cycles during the initial prefill beats, then sends
the packet without injected bubbles after the AXI-Lite RUN write. All four
runs compare the 56 64-bit words on each lane against
the words sampled at the GT user interface. The bad-frame run observes sticky
`core_protocol_error` for an early beat-15 `TLAST`, then sticky GT-user
`stream_fault` and PA blanking after a 16-beat incomplete transfer. A common
reset clears each fault and two subsequent legal replays pass the same TXP
serial comparison. Logs are under
`runs/thermo5_gt14_stress_20261025_224631/`; the test contract and commands
are in `docs/GT_PARENT_STRESS_AND_ERROR_TESTS.md`.

The generic-FIFO VCS full-IP regression also passes its nominal bit-true,
valid-gap/backpressure, FIFO boundary/starvation, active reset/replay, five
residual-state reset sweep, and intentional misaligned-frame negative tests.
The latter expects the RTL alignment assertion and verifies reset clears the
sticky protocol diagnostic. Its run is under
`runs/thermo5_stress_dv_regression_20261025/`.

This proves digital serialization behavior in AMD's GT Wizard simulation
model. It does not model or sign off electrical eye/jitter, analog channel
loss, physical lane skew across relock, measured BER, PA/RF output, or board
performance. The GT RX comparison remains open because the current behavioral
loopback does not recover active RX user data.

The thermo3 and thermo5 complete FPGA fabric frontends both pass routed OOC
timing at 218.75 MHz. GT-PMA placement/routing and board I/O timing remain
separate from that fabric result and from the behavioral serial simulation.

## Concrete ZU15EG GT Wizard status

Vivado 2024.1 successfully generated a board-independent GT Wizard IP for
`xczu15eg-ffvb1156-2-i` with GTH channel `X1Y12`, 14.0 Gb/s TX/RX line rate,
125 MHz reference clock, 64-bit user data, RAW encoding, and generated
synthesis/simulation targets.  The reproducible source is
`fpga/zu15eg/scripts/generate_ti64_raw_gt14_ip.tcl`; generated XCI and vendor
HDL remain outside the repository under `tmp/gt_wizard_probe_20260922/`.

This proves the selected device/IP configuration is accepted by Vivado.  The
The repository now contains `ti64_raw_gt14_sfp0_bert_top.sv` and
`run_ti64_raw_gt14_bert_sim.tcl`.  The wrapper instantiates the generated
ZU15EG GTH, crosses recovered 64-bit words through an asynchronous FIFO, and
connects `gt_link_bringup_bist` at the TX user-clock boundary.  RAW RX word
alignment uses the generated `RXSLIDE` port and requires a stable known-word
observation before enabling the CDC FIFO.  The vendor behavioral model reaches
TX/RX active, TX/RX done, power-good, and CDR-stable.  The implementation entry
point is `build_ti64_raw_gt14_sfp0_bert.tcl`; it completed on the ZU15EG part
with 0 DRC errors, setup slack +1.844 ns, and hold slack +0.052 ns for the
constrained fabric/user-clock paths.  These are implementation-model results;
they do not prove electrical eye/jitter, BER, or recovered data on a board.

## Digital-IC portfolio claim

The defensible project statement is:

> Designed and verified a multi-clock streaming digital transmitter with
> fixed-point MATLAB/RTL bit-true checking, asynchronous FIFO CDC, a 14:8
> gearbox, pipelined memory-DPD and TID datapaths, executable protocol
> assertions, and full routed FPGA fabric timing closure at 218.75 MHz.  The
> 64-bit raw interface represents 14 Gb/s per output plane; ideal behavioral
> serializer loopback is verified, while physical GT and RF measurements are
> explicitly deferred pending hardware.

For a digital IC design role, the strongest next hardware-independent
deliverable is a vendor-neutral link-control verification block: PRBS31
generator/checker, known-word mode, reset/link FSM, error counters, sticky
faults, assertions, and a behavioral error-injection channel.  A board-specific
GT wrapper should be added only after its device, reference clock, quad, and
pin constraints are known.

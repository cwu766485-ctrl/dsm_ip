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

The thermo5 simulation uses four ideal behavioral raw64 serializers.  At a
218.75 MHz user clock and an ideal 64x serial clock, it passed 64 words per
path, or 4,096 bits per path.  All four recovered word streams matched the
MATLAB golden code planes.  This proves the modeled bit order and word
alignment only; the model is not a GTHE4 primitive or a physical channel.

The thermo3 and thermo5 complete FPGA fabric frontends both pass full routed
OOC timing at 218.75 MHz.  No current result proves GT line-rate timing or a
board link.

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

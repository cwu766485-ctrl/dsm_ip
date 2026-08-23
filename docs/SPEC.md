# DSM Digital Transmitter IP Specification

## Scope

The IP accepts fixed-point complex baseband samples and produces a synchronous
one-bit real-IF stream. It provides AXI4-Lite control, AXI4-Stream input,
optional observation input, status counters, and a deterministic DPD,
interpolation, mixer, and delta-sigma datapath.

This document defines the frozen validation SKU. Other DSM and DPD variants are
kept for reusable block-level experimentation and are not part of the system
release configuration.

## Frozen Validation SKU

```text
Top:                    dsm_ip_axi_top
Device target:          xczu15eg-ffvb1156-2-i
Clock:                  100 MHz
Baseband format:        signed Q1.15 I/Q
DPD:                    fifth-order memory polynomial, four taps
Interpolation:          x32 CIC plus compensation FIR
Digital upconversion:   real Fs/4 mixer
DSM:                    one-bit band-pass EFDSM2
Output:                 rf_bit, rf_signed, rf_valid
```

The nominal IF centre frequency is one quarter of the sample clock. At the
frozen 100 MHz clock, that is 25 MHz. `rf_bit` is synchronous data, not a
clockless high-speed interface. A physical switching PA requires a retiming,
non-overlap, gate-driver, and matching-network boundary outside this IP.

## Interfaces

### AXI4-Stream TX input

```text
tdata[15:0]  signed I, Q1.15
tdata[31:16] signed Q, Q1.15
tvalid/tready handshake
tlast/tuser are checked by the control and verification flows
```

### AXI4-Lite control

The register map configures enable/reset behavior, DPD coefficient banks,
commit requests, status reads, and sticky-error clear. Coefficient updates use
an inactive bank followed by a safe commit; a rejected request must not alter
the active bank.

### Output and observation

`rf_valid` qualifies `rf_bit` and `rf_signed`. The optional observation stream
is intended for an external feedback receiver. When its clock differs from the
datapath clock, the async bridge is the only defined CDC boundary.

## Fixed-Point Contract

The MATLAB fixed-point implementation is the algorithm reference. The Python
integer model reproduces the same signed widths, truncation, saturation,
state-update ordering, and valid latency for Linux/VCS regression. RTL changes
must preserve these contracts or update all three implementations and their
bit-true vectors together.

## Boundaries

- The repository does not claim measured RF output, PA efficiency, ACLR, or
  EVM from hardware.
- Behavioral PA/DPA and receiver models are development tools, not silicon
  models.
- The current release does not provide a multi-lane serializer, RF clock tree,
  DAC, gate driver, PA, or antenna interface.

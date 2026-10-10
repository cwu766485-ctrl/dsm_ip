# Thermo5 Four-PA Serializer Contract

## Scope

This contract defines the digital boundary required by the five-level
thermometric transmitter.  It is a hardware-integration requirement, not a
claim that the current ZU15EG carrier has four routed high-speed outputs.

## Plane map

| Raw plane | Threshold offset | PA weight |
|---|---:|---:|
| `PA0` | `+3 * STEP` | `+1/4` |
| `PA1` | `+1 * STEP` | `+1/4` |
| `PA2` | `-1 * STEP` | `+1/4` |
| `PA3` | `-3 * STEP` | `+1/4` |

The four switching-PA paths must have matched delay and equal calibrated
amplitude before their RF outputs are combined.

## Clock, reset, and word contract

- Each serializer accepts one 64-bit raw word on the shared 218.75-MHz GT
  user clock.  The aggregate raw rate is `64 * 218.75 MHz = 14 Gb/s` per PA
  path.
- All four GT user clocks must be phase-related and must use one common word
  cadence.  A code plane may not advance independently of the other planes.
- `link_reset_n` releases only after all four GT PLL/reset-done and user-clock
  indications are stable.  Any loss of one path's lock resets all four word
  sources and inhibits PA enable.
- The simulation contract serializes `TXDATA[0]` first.  The generated GT
  Wizard configuration and board loopback must explicitly prove this bit
  order; a vendor-specific lane/byte remap must be corrected at the boundary.
- The source side uses all-or-none `ready`: `pa_ready[3:0]` must be all high
  before one thermometric symbol advances.

## Board boundary

The earlier public implementation exposed only the dual-SFP mapping; this
did **not** prove the board lacked four TX lanes. A local schematic audit on
2026-10-03 found four QSFP1 TX/RX pairs on GTH bank 128. Vivado 2024.1
independently matched them on the actual `xczu15eg-ffvb1156-2-i` package to
`GTHE4_CHANNEL_X0Y4..X0Y7`, with `MGTREFCLK0_128` on
`GTHE4_COMMON_X0Y1`. The schematic symbol says xczu9eg, so the package
database cross-check is essential; this is a *pin feasibility result*, not a
completed four-lane GT implementation.

The schematic labels the bank-128 clock-generator output 156.25 MHz. An
actual four-channel GT Wizard IP probe rejects exact 14.0 Gb/s with that
reference frequency. It accepts 14.0625 Gb/s at 156.25 MHz, which would
require a 219.7265625-MHz raw-64 user clock and is **not** the frozen
14.0-Gb/s/218.75-MHz contract. The same IP accepts 14.0 Gb/s at 125 MHz,
but no 125-MHz bank-128 clock-generator configuration has been provided or
verified. Do not apply the old 218.75-MHz OOC WNS/WHS to a 14.0625-Gb/s
variant. Full QSFP routing, lane alignment, reset release, and board output
remain unverified; the board power fault also remains unresolved.

## Simulation evidence

`tb_tid32_thermo5_frontend_serdes_loopback` drives the full frontend through
four shared-clock, raw-64 serializer/receiver models.  It verifies reset,
continuous word cadence, bit-0-first serialization, and exact recovered words
for all four PA planes.  It does not model GT analog behavior, clock jitter,
channel loss, PA mismatch, or a board loopback.

## Four-lane GT alignment and PA blanking contract (parent closure)

The current `thermo5_qsfp_gt14_parent` maps each 256-bit TX user word as
`[63:0]=PA0`, `[127:64]=PA1`, `[191:128]=PA2`, `[255:192]=PA3`. One 256-bit
word is consumed every 218.75-MHz TX user-clock edge; the GT has no backpressure
input. Common user-clock cadence and exact parallel user-data loopback are
necessary, but do **not** prove serial phase alignment between channels.

Before external PA unblank, a board-level integration must assert all four
channels are reset-done/power-good, all user clocks are active, all four
lane/word aligners report `deskew_done`, and the same frame epoch is selected
for every plane. Any loss of one lane's lock/deskew must blank the common PA
gate and restart all four code-plane streams from a common epoch. The generated
GT configuration currently uses buffer mode and has no demonstrated
deterministic inter-channel phase alignment. A common `TXUSRCLK` therefore
does not substitute for `deskew_done`.

The physical phase requirement is deliberately parameterized until the PA/RF
combiner specifies a tolerance. Define and measure `SKEW_MAX_UI` as the
maximum peak-to-peak start-of-word skew over all lane pairs, across reset,
relock and repeated power cycles. The board must demonstrate
`measured_skew_pp <= SKEW_MAX_UI`; both the numeric limit and measurement
method are currently **TBD/open**, not silently assumed zero.

PA blanking must be aligned to the actual serial-data and switch paths. For
each lane `k`, let `t_payload_k` be the first RF payload transition after its
GT/trace delay, and `t_unblank` the physical PA-switch enable arrival. Require
`t_unblank <= min_k(t_payload_k) - T_GUARD`; after the last payload transition
require blanking by `max_k(t_payload_end_k) + T_GUARD`. On lock loss or a
mid-frame stream fault, require the common PA gate to assert within a
specified `T_BLANK_MAX`. `T_GUARD`, `T_BLANK_MAX`, GT serial latency, lane
trace skew and PA-switch latency must be measured/derived from the selected
board and RF path. The RTL `pa_enable` is only a digital request; it is not
the physical PA enable or proof of RF silence.

The current parent reset-only behavioral regression passes 64 accepted AXI
beats and 112 transmitted words, including power-good, TX-active and common-
reset recovery. Exact four-lane RX comparison remains open. External serial
pin self-loopback times out without recovered words. A generated-GT near-end
PMA-loopback experiment reaches `rx_done`/`cdr_lock` but has no active RX user
clock or recovered frame, so it is not a functional RX pass. The four-lane
parallel TX mapping is verified only through existing TX/raw-word checks;
serial phase, deskew and analog PA timing remain open until RX comparison and
board measurements close the contract.

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

The public current-board target exposes only the existing dual-SFP mapping.
It cannot validate four physical serializers.  A physical thermo5 target
requires four qualified 14-Gb/s TX differential pairs, their reference-clock
and reset topology, and four PA input paths.  Pin names are intentionally not
invented until those board resources are provided.

## Simulation evidence

`tb_tid32_thermo5_frontend_serdes_loopback` drives the full frontend through
four shared-clock, raw-64 serializer/receiver models.  It verifies reset,
continuous word cadence, bit-0-first serialization, and exact recovered words
for all four PA planes.  It does not model GT analog behavior, clock jitter,
channel loss, PA mismatch, or a board loopback.

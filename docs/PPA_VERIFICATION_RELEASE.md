# PPA and Implementation Evidence

## Evidence Rules

OOC synthesis, routed implementation, pre-layout ASIC synthesis, and board
measurements answer different questions. A result is reported only with its
configuration, target, tool flow, and evidence class. No pre-layout or
behavioral result is a post-layout or measured-silicon claim.

## Frozen SKU

```text
Target:       xczu15eg-ffvb1156-2-i
Clock:        100 MHz
DPD:          Memory-Poly5, 4 taps
Interpolation:x32 CIC plus compensation FIR
DSM:          one-bit BP EFDSM2
```

## Available Evidence

- Feature-level ZU15EG OOC summaries are stored under `docs/evidence/ooc/`.
- The 28 nm Design Compiler baseline is documented in
  [ASIC_PPA_BASELINE.md](ASIC_PPA_BASELINE.md). It is pre-layout and vectorless.
- Historical full-TX records in `docs/evidence/integration/` use an older
  Cartesian/Fs/4 route and are retained only as historical evidence.

## Current Limits

- The frozen BP EFDSM2 SKU does not yet have a checked-in full routed,
  bitstream, and board-replay closure artifact.
- Dynamic power estimates require declared activity; board power requires a
  measurement setup.
- No current document claims an ASIC physical implementation, RF PA efficiency,
  or measured transmitter spectrum.

Use the local `syn/` and `fpga/` scripts only with licensed tools and approved
libraries. Their generated reports are intentionally not version-controlled.

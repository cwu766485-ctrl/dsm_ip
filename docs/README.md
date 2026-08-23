# Documentation Index

This directory contains the public handoff documentation for the DSM digital
transmitter IP. Claims are limited to reproducible RTL, model, verification,
or implementation evidence. Behavioral RF and pre-layout ASIC results are not
presented as measured silicon results.

| Document | Purpose |
|---|---|
| [SPEC.md](SPEC.md) | Frozen SKU, interfaces, fixed-point behavior, and limits |
| [PROJECT_GUIDE.md](PROJECT_GUIDE.md) | Repository layout and repeatable development flows |
| [IP_HANDOFF.md](IP_HANDOFF.md) | Integration contract for AXI, clocks, resets, and outputs |
| [VPLAN.md](VPLAN.md) | Verification scope, pass criteria, and open work |
| [PPA_VERIFICATION_RELEASE.md](PPA_VERIFICATION_RELEASE.md) | Evidence hierarchy and implementation results |
| [ASIC_PPA_BASELINE.md](ASIC_PPA_BASELINE.md) | Pre-layout synthesis baseline and its limitations |
| [CDC_STA_SIGNOFF.md](CDC_STA_SIGNOFF.md) | CDC, reset, and timing signoff scope |
| [UPDATE_LOG.md](UPDATE_LOG.md) | Concise change history |
| [evidence/README.md](evidence/README.md) | Small checked-in evidence summaries |

## Frozen Validation SKU

```text
Target:       xczu15eg-ffvb1156-2-i
Clock:        100 MHz
Datapath:     Memory-Poly5 (4 taps) -> x32 interpolation
              -> Fs/4 mixer -> one-bit BP EFDSM2
DPD features: memory path enabled; Poly/LUT execution disabled
```

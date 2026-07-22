# AI-Assisted DPD Offline Signoff

- Timestamp: `2026-07-21 23:56:43 +08:00`
- Board required: `false`
- Result: `PASS`
- Data: `1728` records, `12` behavioral PA/receiver profiles, `8` waveforms, `3` random seeds, `6` DPD packages
- Policy: AI/optimization seed selection followed by mandatory `14`-candidate bounded search
- Direct one-candidate promotion: `BLOCKED` by strict profile/waveform/random-seed holdouts
- Tiny MLP seed candidate qualified in all behavioral strict splits: `True`; deployment remains `false`

## Checks

- Seed/regret evaluator self-test: `PASS` (0.191 s)
- Strict seed/regret LOSO: `PASS` (32.308 s)
- Tiny MLP seed-selector strict LOSO: `PASS` (6.399 s)
- Safety-first policy Python/C equivalence: `PASS` (2.922 s)
- TinyML pre-board equivalence: `PASS` (24.779 s)
- DPD MATLAB/RTL sample bit-true: `PASS` (113.04 s)
- Observation receiver MATLAB/RTL equivalence: `PASS` (48.575 s)

## Evidence Boundary

This signoff covers behavioral PA/observation modeling, strict holdout evaluation, and fixed-point software/RTL equivalence. It does not use the ZU15EG board or a physical PA/receiver. PS/DMA replay and measured RF EVM/SNDR/ACLR remain board and laboratory tasks.

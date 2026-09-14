# DSM transmitter IP documentation

The documentation set is intentionally small. Current engineering claims must
be supported by reproducible RTL, models, regressions, or archived reports.

| Document | Source of truth |
|---|---|
| [SPEC.md](SPEC.md) | Design contract, fixed-point behavior, interfaces, implementation limits, and FPGA/ASIC boundary |
| [VPLAN.md](VPLAN.md) | Verification plan, pass criteria, required evidence, and unfinished signoff gates |
| [Cartesian_DSM_Survey.md](Cartesian_DSM_Survey.md) | Chinese survey of the four supplied transmitter papers and their design implications |
| [UPDATE_LOG.md](UPDATE_LOG.md) | Concise material-change record |
| [exec-plans/active/execution-frontier.md](exec-plans/active/execution-frontier.md) | Active execution state; maintained separately and not an architecture specification |

Archived CSV, report, and waveform evidence remains in `docs/evidence/` when
present. FPGA routing closure does not prove a physical serial link, RF
carrier, EVM, ACLR, or ASIC signoff.

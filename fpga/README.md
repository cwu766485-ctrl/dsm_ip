# FPGA

| Path | Role |
|---|---|
| `data/coe` | 100 MHz-aligned P0 ROM initialization data. |
| `hardware` | Local-only RFSoC 4x2 board collateral. This path is ignored for public GitHub release unless redistribution rights are confirmed. |
| `rfsoc4x2` | Preserved source-only RFSoC 4x2 board fragments for the historical Cartesian DSM path. |
| `rtl` | Legacy board helper RTL fragments mirrored from the RFSoC path. |

This folder contains board-integration collateral. The reusable IP package is
generated from `rtl/ip` and `ip`.

Do not publish restricted board PDFs, schematics, BOMs, reference manuals, or
vendor board packages.

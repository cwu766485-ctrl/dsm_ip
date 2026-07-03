# cartesian_dsm

This is the preserved source-only RFSoC board-integration fragment for the
historical Cartesian DSM mainline.

## Included

- `cartesian_dsm.srcs/`
- `constrs_1/`

## Not Included

- current complete Vivado `.xpr`
- current top-level board wrapper source
- generated run folders
- Vivado caches
- simulator clutter

Use a private local `fpga/hardware/` copy for RFSoC 4x2 board files and full
PL/SYZYGY constraints. These files are ignored for public GitHub release unless
redistribution rights are confirmed.

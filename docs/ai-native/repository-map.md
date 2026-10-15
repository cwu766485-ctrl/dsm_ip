# Repository Map — DSM Study Branch

- `rtl/dsm/singlebit/`: scalar single-bit LP/EF/MASH cores.
- `rtl/dsm/multibit/`: scalar multi-bit generic core and algorithm wrappers.
- `rtl/top/`: P0 I/Q regression carriers only.
- `rtl/duc/`, `rtl/mem/`: P0 test-carrier dependencies.
- `matlab/bittrue/`: P0 fixed-point reference and output compare.
- `matlab/cartesian_dsm/`: single-bit and multi-bit algorithm models.
- `dv/verif/tb/`: deterministic P0 simulation testbenches.
- `dv/verif/vectors/p0/`: fixed I/Q playback vectors.
- `dv/verif/scripts/`: Windows XSim flows.
- `syn/`: 14-top FPGA OOC comparison flow and constraints.
- `docs/`: branch specification, verification plan, evidence, and status.
- `runs/dsm/`: ignored, per-run simulation and PPA output.

The P0 wrappers carry pairs of independent scalar I/Q lanes for regression;
the algorithm cores themselves remain single-lane. System-transmitter source
and full-system verification are outside this branch.

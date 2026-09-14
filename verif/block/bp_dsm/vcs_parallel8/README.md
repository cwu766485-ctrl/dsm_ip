# BP EFDSM2 Parallel8 VCS Regression

This directory is an independent VCS test entry for the eight-sample temporal
unroll. It does not depend on Vivado, XSim, a generated CSV, or the UVM
environment.

The testbench creates 32 vectors of eight consecutive samples. A scalar
reference recurrence calculates the expected bit, signed output, and final
state. The DUT is checked for all 256 samples. Deterministic idle gaps are
inserted between transactions to verify that `enable=0` does not advance the
feedback state.

Run on the Linux machine with VCS:

```bash
cd /mnt/e/workspace/chip/dsm_ip/verif/block/bp_dsm/vcs_parallel8
make run VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

Expected marker:

```text
BP_EF2_PARALLEL8_VCS_BITTRUE_PASS vectors=32 samples=256
```

The regression is not a timing result. Vivado OOC is still required for the
`218.75 MHz` Fmax/PPA decision.

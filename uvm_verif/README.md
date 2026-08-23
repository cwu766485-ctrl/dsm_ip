# UVM Verification Environment

This environment verifies the synthesizable `rtl/axi/dsm_ip_axi_top.v` wrapper.
It is separate from the lightweight `verif/` testbenches and does not duplicate
the DUT RTL.

## Structure

- `agent/`: AXI4-Lite, AXI4-Stream, and passive RF agents.
- `env/`: configuration, register map, virtual sequences, scoreboard, and
  environment wiring.
- `formal/`: SystemVerilog assertions and optional formal-tool checks.
- `refmodel/python/`: integer reference-vector generation for Linux/VCS runs.
- `sim/`: Makefile, regression scripts, coverage configuration, and generated
  output locations.
- `tb/`: UVM top-level testbench.
- `tests/`: test classes that configure and start virtual sequences.

The active agents are AXI4-Lite, TX AXI4-Stream, and observation AXI4-Stream.
The RF agent is passive. TX and observation use separate instances of the same
AXI4-Stream agent type.

## Frozen Performance SKU

The main system configuration is Memory-Poly5 with four taps, x32
interpolation, Fs/4 mixing, and BP EFDSM2 at 100 MHz. Poly and LUT DPD paths
are compiled out for this SKU.

Key system tests cover deterministic Python-to-RTL RF comparison, memory-DPD
bank programming and rejection, AXI ordering and backpressure, observer
windows, reset, error handling, and directed coverage corners. The current
coverage boundary is documented in
`docs/evidence/SYSTEM_CODE_COVERAGE_AUDIT.md`.

## Running VCS

From a licensed Linux VCS environment:

```bash
cd <repository-root>
make -C uvm_verif/sim check-tools
make -C uvm_verif/sim vcs PYTHON=python3.12 COVERAGE=1
make -C uvm_verif/sim vcs-run UVM_TESTNAME=dsm_memory_dpd_bittrue_test \
  UVM_SEED=1 COVERAGE=1
```

Use `bash uvm_verif/sim/run_ip_extended_regression_linux.sh` for the guarded
multi-seed system regression. Generated VDBs, logs, and waveforms are ignored.

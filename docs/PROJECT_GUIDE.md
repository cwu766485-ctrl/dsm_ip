# Project Guide

## Repository Layout

| Path | Contents |
|---|---|
| `rtl/` | Synthesizable Verilog and SystemVerilog RTL |
| `matlab/` | Algorithm models, fixed-point reference, vector generation |
| `uvm_verif/` | Linux/VCS UVM environment, Python reference model, regression tools |
| `verif/` | Block and subsystem testbenches, XSim scripts, checked-in vectors |
| `ip/` | Vivado IP packaging scripts |
| `syn/` | FPGA OOC and ASIC pre-layout synthesis flows |
| `fpga/` | Board integration and bare-metal support sources |
| `ads/` | Optional behavioral/circuit DPA experiments |
| `docs/` | Public specifications, plans, and compact evidence |

## Development Flows

1. Use MATLAB to explore an algorithm and create fixed-point vectors.
2. Align the Python integer model with MATLAB for VCS regression.
3. Verify RTL at block and subsystem level.
4. Run system UVM for the frozen SKU.
5. Package the IP and run synthesis or implementation with the required local
   tools and licensed libraries.

## Common Commands

```powershell
# MATLAB bit-true regression
.\scripts\run_matlab_p0_bittrue_check.cmd

# XSim smoke checks when Vivado is available
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1

# Vivado IP packaging
powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1
```

```bash
# Linux/VCS system regression
make -C uvm_verif/sim check-tools
make -C uvm_verif/sim vcs PYTHON=python3.12 COVERAGE=1
make -C uvm_verif/sim vcs-run-only UVM_TESTNAME=dsm_memory_dpd_bittrue_test UVM_SEED=1 COVERAGE=1
```

All simulator output, databases, waveforms, implementation runs, PDK files,
licenses, board collateral, and local capture data are ignored by Git.

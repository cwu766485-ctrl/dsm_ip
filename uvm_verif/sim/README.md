# UVM Simulation Flow

This directory is the Linux VCS/Verdi entry point for system-level verification.
Windows XSim scripts under `verif/scripts/` are retained for local smoke runs;
they are not the signoff flow.

## Main Files

- `Makefile`: compile, run, coverage merge, and Verdi targets.
- `run_regression.py`: testcase/seed matrix, log checks, and CSV summaries.
- `run_ip_coverage_linux.sh`: short system-coverage regression.
- `run_ip_extended_regression_linux.sh`: 300-run stress regression.
- `run_ip_extended_coverage_linux.sh`: merge passing stress-run VDBs.
- `coverage/`: reviewed frozen-SKU coverage triage scripts and waivers.

Generated output is written under `out/` and is ignored by Git.

## Prerequisites

Use a Linux shell with VCS, URG, and Python 3.12 available. Tool licensing and
environment setup are site-specific and are intentionally not stored here.

## Common Commands

From the repository root:

```bash
make -C uvm_verif/sim check-tools
make -C uvm_verif/sim vcs PYTHON=python3.12 COVERAGE=1
make -C uvm_verif/sim vcs-run-only \
  UVM_TESTNAME=dsm_system_closure_test UVM_SEED=1 COVERAGE=1
```

Run the short closure suite:

```bash
bash uvm_verif/sim/run_ip_coverage_linux.sh
```

Run and merge the extended suite:

```bash
bash uvm_verif/sim/run_ip_extended_regression_linux.sh
bash uvm_verif/sim/run_ip_extended_coverage_linux.sh
```

## Optional Windows-to-Linux Bridge

The `*_bridge.ps1` scripts only copy a Linux command into a user-managed shared
folder. They never implement verification logic. Pass the folder explicitly:

```powershell
.\uvm_verif\sim\run_ip_extended_regression_bridge.ps1 `
  -BridgeRoot 'D:\shared\dsm_uvm_bridge'
```

The Linux-side bridge is local infrastructure and must not be committed.

## Pass Criteria

A run is accepted only when all of the following hold:

1. The simulator exits with status zero.
2. `UVM_ERROR` and `UVM_FATAL` are zero.
3. The test completion marker is present.
4. Bit-true tests drain all expected transactions.

The regression parser rejects a run that satisfies only the process exit-code
check.

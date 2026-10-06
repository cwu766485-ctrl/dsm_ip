# UVM Simulation Flow

## One-command graduate-DV package

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dv/uvm/sim/run_thermo5_dv_package_wsl.ps1
```

The entry creates a unique `runs/` directory and executes fresh generic/XPM
baselines, exact interpolation and TID/counter coverage follow-ups, scoped
VC Formal with zero black boxes, and two historical commit-bug negative
controls. It emits a raw coverage summary, complete per-bit direction delta,
source/vector/binary hashes, seeds, VDB paths and unified checker/assertion
diagnostics. `-DryRun` plans commands without claiming a pass. Generate/stage
the baseline, payload-seed, endpoint and 2072-word plateau oracle sets first;
see `docs/verification/thermo5-dv-portfolio.md` for scope and prerequisites.

This directory is the Linux VCS/Verdi entry point for system-level verification.
Windows XSim scripts under `dv/verif/scripts/` are retained for local smoke runs;
they are not the signoff flow.

## Main Files

- `Makefile`: compile, run, coverage merge, and Verdi targets.
- `run_regression.py`: testcase/seed matrix, log checks, and CSV summaries.
- `run_ip_coverage_linux.sh`: short system-coverage regression.
- `run_ip_extended_regression_linux.sh`: 300-run stress regression.
- `run_ip_extended_coverage_linux.sh`: merge passing stress-run VDBs.
- `coverage/`: reviewed frozen-SKU coverage triage scripts and waivers.
- `thermo5_sku_filelist.f`: separate two-clock thermo5 subsystem target.
- `uvm_filelist.f`: original AXI-IP target. Each filelist selects only its
  own `env/`, `sequences/`, and `tests/` include directories; reusable
  protocol agents remain under `agent/`.

The AXI-IP flow writes generated output under `out/`; thermo5 writes under
`runs/uvm_thermo5_i2_d1/`. Both are ignored by Git.

## Prerequisites

Use a Linux shell with VCS, URG, and Python 3.12 available. Tool licensing and
environment setup are site-specific and are intentionally not stored here.

## Common Commands

For the thermo5/2-tap/DPD1 subsystem, first generate MATLAB vectors using
`generate_thermo5_sku_vectors.ps1` on Windows, then in licensed Linux VCS:

```bash
make -C dv/uvm/sim thermo5-vcs-run UVM_SEED=1
make -C dv/uvm/sim thermo5-vcs-run UVM_SEED=2 THERMO5_EXTRA_ARGS=+STRESS_PA_READY
make -C dv/uvm/sim thermo5-vcs-regression
make -C dv/uvm/sim thermo5-vcs-multiseed
make -C dv/uvm/sim thermo5-coverage-merge
```

The thermo5 regression runs seven independent cases: normal four-plane
bit-true with PA stalls, a directed AXI valid-gap plus heavy PA-backpressure
case (interpolator stage holds, output holds, and empty-blocked observations),
FIFO full/backpressure and recovery, FIFO starvation
with expected sticky underflow, midstream reset and clean replay, a sweep of
five more CDC residual states at reset, and an illegal frame-start negative
assertion. The functional coverage component
reports event counts plus source/core covergroup percentages; tests require
their own event bins to be hit. The URG target requires all seven VDBs and
rejects an URG process that returns zero while reporting design-load errors.
The 2026-10-01 licensed six-case run merged the reports:
functional groups 100%, overall 86.59%, DUT hierarchy 85.94%, FSM 100%.
This is not full RTL coverage closure. A finite source has no end-of-stream
flag in this SKU; a sticky underflow after all source beats have arrived can
occur during downstream drain. Normal tests reject underflow before the final
source beat; the starvation test deliberately exercises the sticky error.

On 2026-10-03 the final seven-case generic and real-XPM regressions passed.
Their separate URG scores are 86.97% and 80.14% overall, respectively;
condition coverage is 78.72% and 69.83%. XPM includes vendor hierarchy.
Generate independent payloads with
`generate_thermo5_sku_vectors.ps1 -Seed <seed> -OutDir <runs/...>`; after
generating seeds 101/202/303 under
`runs/uvm_thermo5_payload_20261003/vectors_seed<seed>/`, run
`bash dv/uvm/sim/run_thermo5_payload_matrix.sh` in the licensed Linux
environment. It recompiles both FIFO targets and checks all three MATLAB
payloads against their own four-plane golden vectors. See the coverage record
for exact open instance/bin dispositions.

`thermo5-vcs-multiseed` additionally runs PA-stall bit-true and FIFO-boundary
tests for seeds 11 through 20 (20 passing simulations). The directed full-chain
XSim launcher supports `-XpmFifo`; seeds 7/8/9 passed with the vendor FIFO
model and ready stalls. To compile and run the same seven UVM scenarios with the
real vendor XPM simulation model (not the portable FIFO fallback), use:

```bash
make -C dv/uvm/sim thermo5-vcs-regression \
  THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=<Vivado-install-root>
make -C dv/uvm/sim thermo5-coverage-merge \
  THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=<Vivado-install-root>
```

On 2026-10-03 both commands passed using VCS V-2023.12-SP1 and Vivado
2024.1 XPM sources. XPM artifacts live in `runs/uvm_thermo5_i2_d1_xpm/`;
generic artifacts remain separate. XPM URG functional groups are 100%;
vendor-internal coverage makes its overall score incomparable with generic.
The current eight-VDB merge also includes the independent extreme-input
seed-404 bit-true test. Run it against the matching compiled FIFO variant,
then pass its VDB with
`THERMO5_URG_EXTRA_VDBS=<runs/.../cov_thermo5_sku_bittrue_test_seed404.vdb>`
to `thermo5-coverage-merge`. Generic overall/condition/toggle coverage is
87.20/79.79/84.20%; XPM is 80.16/69.68/81.56% including vendor hierarchy.
The XSim vendor test also passed seed 10 with
14 PA stalls. This is still simulation evidence, not hardware GT/PA signoff.

The original AXI-IP regression remains a different DUT top:

From the repository root:

```bash
make -C dv/uvm/sim check-tools
make -C dv/uvm/sim vcs PYTHON=python3.12 COVERAGE=1
make -C dv/uvm/sim vcs-run-only \
  UVM_TESTNAME=dsm_system_closure_test UVM_SEED=1 COVERAGE=1
```

Run the short closure suite:

```bash
bash dv/uvm/sim/run_ip_coverage_linux.sh
```

Run and merge the extended suite:

```bash
bash dv/uvm/sim/run_ip_extended_regression_linux.sh
bash dv/uvm/sim/run_ip_extended_coverage_linux.sh
```

## Optional Windows-to-Linux Bridge

The `*_bridge.ps1` scripts only copy a Linux command into a user-managed shared
folder. They never implement verification logic. Pass the folder explicitly:

```powershell
.\dv\uvm\sim\run_ip_extended_regression_bridge.ps1 `
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

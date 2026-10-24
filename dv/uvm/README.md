# UVM Verification Environment

Graduate-DV review entry: `sim/run_thermo5_dv_package_wsl.ps1` on Windows,
or `sim/run_thermo5_dv_package.py` in a licensed Linux login shell. The
coverage and bug tables, prerequisites and limitations are in
`docs/verification/thermo5-dv-portfolio.md`.

This tree contains two DUT targets: the original `rtl/axi/dsm_ip_axi_top.v`
IP-system regression and the frozen two-clock thermo5 transmitter subsystem.
They share the verification directory and Makefile, but require distinct
testbench tops and filelists because their interfaces and clocks differ.
Neither testbench duplicates DUT RTL.

## Structure

- `agent/`: AXI4-Lite, AXI4-Stream, and passive RF agents.
- `env/axi_ip/` and `env/thermo5/`: target-specific configuration,
  scoreboards, coverage, control, package, and environment wiring.
- `sequences/axi_ip/`: AXI-IP cross-interface virtual scenarios.
- `sequences/thermo5/`: MATLAB- or Python-vector source scenario for the frozen
  SKU. Protocol-local sequences stay with their respective agents.
- `formal/`: SystemVerilog assertions and optional formal-tool checks.
- `refmodel/python/`: integer reference-vector generation for Linux/VCS runs.
- `sim/`: Makefile, regression scripts, coverage configuration, and generated
  output locations.
- `tb/`: UVM top-level testbench.
- `tests/axi_ip/` and `tests/thermo5/`: target-specific test classes;
  thermo5 AXI-Lite wrapper tests are isolated under `tests/thermo5/axil/`.

The active agents are AXI4-Lite, TX AXI4-Stream, and observation AXI4-Stream.
The RF agent is passive. TX and observation use separate instances of the same
AXI4-Stream agent type.

These are agents of the original AXI-IP environment, not of the thermo5
subsystem. Thermo5 has its own active AXI source agent (item, sequencer,
driver, and accepted-beat monitor), passive four-plane output monitor, and
control BFM. The source sequence owns the `.mem` stimulus; MATLAB and the pure
Python frozen-SKU reference can generate those vectors. The scoreboard
consumes both monitor analysis ports and resets its comparison index on each
reset epoch. The four-plane output is still a passive monitor, not a physical
PA or GT agent.
An agent normally owns one protocol endpoint/role; multiple endpoints may
instantiate the same agent class, and a single physical interface may expose
several monitored channels.

## Frozen thermo5 transmitter subsystem

The `thermo5 / INTERP_TAPS=2 / DPD_MAX_TAPS=1` testbench is
`tb/thermo5_sku_uvm_tb.sv`; its source manifest is
`sim/thermo5_sku_filelist.f`. Its interface and source/PA agents live under
`agent/`, its scenario under `sequences/thermo5/`, package, scoreboard,
configuration, coverage, and control BFM under `env/thermo5/`, and tests under
`tests/thermo5/`. Common setup/checks are in
`tests/thermo5/thermo5_sku_base_test.svh`; the nominal bit-true test and each
corner scenario are separate classes/files. The optional AXI-Lite wrapper test is under
`tests/thermo5/axil/`; it reuses the same thermo5 environment and bit-true
scoreboard. It drives
14 complex samples per 125 MHz AXI beat through the asynchronous FIFO/14:8
gearbox, two x2 interpolation stages, identity-configured memory-DPD, temporal
DSM, and four 64-bit output planes at 218.75 MHz. The scoreboard compares 32
accepted source beats and 56 ordered four-plane output words with MATLAB- or
Python-generated bit-true vectors.
Random common-plane ready stalls also check output stability and ordering.
The corner regression adds FIFO-full source backpressure, deliberate FIFO
starvation and sticky underflow, midstream reset followed by a fresh bit-true
replay, a five-residual-state reset sweep, and a misaligned-frame negative
assertion. A functional covergroup
samples those events and each test gates its required event counters. VCS
code coverage is compiled separately and can be merged with URG. See
`docs/verification/thermo5-uvm-coverage.md` for the test/check/bin map and
open coverage holes.
The full-IP test classes are now split one scenario per file under
`tests/thermo5/full_ip/`; `thermo5_sku_corner_tests.svh` remains as a
compatibility include hub, so existing `+UVM_TESTNAME` values and Makefile
targets do not change. `tests/thermo5/full_ip/README.md` maps each class to its
stimulus/check purpose. AXI-Lite wrapper, serializer-loopback, and GT-parent
tests remain separate configurations/verification levels rather than being
implicitly included in this frozen-SKU corner suite.
The interface/RTL/reference-model ownership map is in
`docs/verification/thermo5-uvm-architecture.md`.

Generate vectors on Windows, then run in a licensed Linux VCS environment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\sim\generate_thermo5_sku_vectors.ps1
```

```bash
make -C dv/uvm/sim thermo5-vcs-run UVM_SEED=1
make -C dv/uvm/sim thermo5-vcs-run UVM_SEED=2 THERMO5_EXTRA_ARGS=+STRESS_PA_READY
make -C dv/uvm/sim thermo5-vcs-regression
make -C dv/uvm/sim thermo5-vcs-multiseed
make -C dv/uvm/sim thermo5-coverage-merge
```

The optional centered-cubic x2 interpolation path has a separate bit-true
target. Generate matching vectors, then run:

```bash
python3 dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
  --output-dir runs/thermo5_centered_cubic_vectors \
  --interp-mode centered_cubic

make -C dv/uvm/sim thermo5-centered-cubic-vcs PYTHON=python3 \
  THERMO5_VECTORS="$PWD/runs/thermo5_centered_cubic_vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_centered_cubic_vcs"
```

This option requires `TLAST` at a complete 56-sample gearbox boundary. The
normal regression keeps the causal interpolation preset.

The six-case VCS regression passed on 2026-10-01 using the running local
Synopsys license service. After the agent/control refactor, URG merged six
tests: functional groups 100%, overall score 86.59%, DUT hierarchy 85.94%,
and FSM 100%. These
numbers are evidence for the tested generic-FIFO SKU, not all RTL/configuration
coverage. The illegal-frame test is intentionally negative: it
must produce the RTL 56-sample alignment assertion and the UVM observation
marker; it is not treated as an ordinary clean simulation. The runnable directed full-chain
XSim test is `dv/verif/subsystem/tx_frontend/run_xsim_thermo5_i2_d1_axis.ps1`. Its
`-XpmFifo` switch selects the vendor XPM FIFO model; the 2026-10-01 XPM
full-chain simulation passed seeds 7/8/9 with PA-ready stalls. On
2026-10-03 the same UVM top gained a separately compiled XPM target using
`THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=<Vivado root>`; its seven-case VCS
regression and independent URG merge passed after adding a full-chain AXI
valid-gap/empty-pipeline-backpressure test. Three independent MATLAB
payloads also passed in both FIFO configurations. The generic-FIFO target and
coverage database remain separate. See `sim/README.md` for commands and
`docs/verification/thermo5-uvm-coverage.md` for the remaining CDC/coverage
boundary. The old IP-system regression is preserved below.

## Historical Performance SKU (separate legacy AXI-IP design)

Older AXI-IP documents use Memory-Poly5 with four taps, x32 interpolation,
Fs/4 mixing, and BP EFDSM2 at 100 MHz as a performance configuration. It is
not the frozen thermo5 transmitter described above. The active thermo5 frozen
configuration uses two x2 stages with two taps each and one-tap identity DPD.

Key system tests cover deterministic Python-to-RTL RF comparison, memory-DPD
bank programming and rejection, AXI ordering and backpressure, observer
windows, reset, error handling, and directed coverage corners. The current
coverage boundary is documented in `docs/VPLAN.md`.

## Running VCS

From a licensed Linux VCS environment:

```bash
cd <repository-root>
make -C dv/uvm/sim check-tools
make -C dv/uvm/sim vcs PYTHON=python3.12 COVERAGE=1
make -C dv/uvm/sim vcs-run UVM_TESTNAME=dsm_memory_dpd_bittrue_test \
  UVM_SEED=1 COVERAGE=1
```

Use `bash dv/uvm/sim/run_ip_extended_regression_linux.sh` for the guarded
multi-seed system regression. Generated VDBs, logs, and waveforms are ignored.

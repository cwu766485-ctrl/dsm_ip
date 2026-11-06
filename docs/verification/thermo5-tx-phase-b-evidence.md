# Thermo5 TX System Verification — Phase B Evidence

Date: 2026-11-02
Implementation source commit: `35115626a95c14db76e29ee36bf68f5d80132aba`
Parent Phase A commit: `52b94f8e7ddce42f1ec890038ed3bc7068e02d26`
Product RTL/configuration: unchanged from `2d7a58df43f7bffecd3d34edd2f21bb3262abe2b`.

## Scope

Phase B adds a PA sink agent with active/passive configuration, makes its
driver the sole procedural owner of `PA_READY`, wraps reset/direct-core-enable
control in a Control agent, and adds a virtual sequencer plus one deterministic
AXIS/AXI-Lite/PA packet smoke sequence. Existing source and AXI-Lite agents
remain the protocol owners for their respective interfaces. Test code now asks
the PA agent to change readiness instead of assigning interface pins.

The outstanding-counter SVA bind is now compiled only for the AXI-Lite DUT
configuration that contains those counter signals. This allowed the existing
non-AXI full-chain test configuration to elaborate; it does not change DUT
behavior or the assertion itself.

Product configuration for AXI-Lite tests: Centered-Cubic x2+x2, EF2 ORDER=2,
STEP=5120, `DPD_MAX_TAPS=1`, Identity reset image, Generic FIFO. No RX,
AI-DPD, algorithm, or product RTL change is included.

## Linux Regression Results

Tool: Synopsys VCS V-2023.12-SP1, UVM-1.1d; Python was not changed in this
phase. VCS compile and run instrumentation enabled line, condition, FSM,
toggle, branch, and assertion collection. These per-test VDBs were not merged
with URG and no aggregate DUT code-coverage percentage is claimed.

| Test | Seed | Result | Independent checks |
|---|---:|---|---|
| AXIL virtual-sequence smoke | 620301 | PASS | 32 accepted AXIS beats, 56 accepted four-plane PA words, RUN/STOP, drained STATUS; predictor mismatches 0; underflow 0; UVM errors/fatals 0 |
| AXIL graceful STOP/Drain | 620304 | PASS | 32 beats through TLAST, 56 PA words, partial-ready stall observed for 7 cycles, 2 stable and 1 transition-masked STATUS reads; predictor mismatches 0; underflow 0; UVM errors/fatals 0 |
| AXIL reset sweep | 620305 | PASS | Four partial-DSP-frame resets, five CDC residual resets, 91 PA words across reset epochs and 56-word post-reset replay; predictor mismatches 0; underflow 0; UVM errors/fatals 0 |
| Generic full-chain bubble/backpressure diagnostic | 620302 | SIMULATION PASS; NOT ACCEPTED as legal-stream PASS | Test reported 56 PA words and atomic-plane coverage, but also 361 underflow cycles, 180 before final source acceptance. The existing test does not fail on this counter. |
| Generic full-chain, one-cycle source-gap diagnostic | 620303 | SIMULATION PASS; NOT ACCEPTED as product PASS | Early underflow 0, but 100 sticky underflow cycles after the final source beat in the direct-core/no-drain configuration. |

The two Generic direct-core runs are diagnostic only and are not counted as
legal product regressions. They expose that the old full-chain bubble test can
print its PASS marker without requiring zero underflow, and that its direct
core wrapper has no product RUN/Drain contract. Phase C must use the
AXI-Lite product path for normal packet-level random tests and fail a normal
seed on any unexpected underflow.

## Reproduction Commands

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/uvm/sim thermo5-tx-agent-vseq-smoke \
  THERMO5_OUT="$PWD/runs/thermo5_tx_phase_b_axil" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors"
```

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/uvm/sim thermo5-vcs-run-only \
  THERMO5_OUT="$PWD/runs/thermo5_tx_phase_b_axil" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_TESTNAME=thermo5_sku_axil_graceful_stop_test UVM_SEED=620304 \
  THERMO5_EXTRA_ARGS='+CORE_WORDS=56 +PACKET_BEATS=32'
```

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/uvm/sim thermo5-vcs-run-only \
  THERMO5_OUT="$PWD/runs/thermo5_tx_phase_b_axil" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_TESTNAME=thermo5_sku_axil_reset_sweep_test UVM_SEED=620305 \
  THERMO5_EXTRA_ARGS='+CORE_WORDS=56'
```

The non-AXIL core test was compiled and run as a diagnostic with:

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/uvm/sim thermo5-vcs-run \
  THERMO5_USE_AXIL=0 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_TESTNAME=thermo5_sku_bubble_backpressure_test UVM_SEED=620302 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_phase_b_core" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors"
```

The one-cycle gap diagnostic used the compiled non-AXIL image:

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C dv/uvm/sim thermo5-vcs-run-only \
  THERMO5_OUT="$PWD/runs/thermo5_tx_phase_b_core" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_USE_AXIL=0 \
  THERMO5_TESTNAME=thermo5_sku_bubble_backpressure_test UVM_SEED=620303 \
  THERMO5_EXTRA_ARGS='+BUBBLE_GAP_CYCLES=1'
```

The exact output hashes and the diagnostic commands are in
[`thermo5-tx-phase-b-evidence.json`](data/thermo5-tx-phase-b-evidence.json).
The 56-word MATLAB fixture is a local symlink to
`runs/thermo5_ef2_qualification/vectors56`; all eight input/reference files
are SHA-256 indexed in the JSON manifest. Generated logs and VDBs remain under
ignored `runs/` paths; this report does not claim an URG Raw/Adjusted coverage
merge.

## Status and Remaining Work

- Phase B deterministic agent coordination: PASS for the AXI-Lite packet,
  graceful-drain, and reset scenarios above.
- Four interface ownership: PA_READY has one writer, the PA sink driver;
  AXIS, AXI-Lite, and reset/direct-core control each retain distinct owners.
- Dynamic clock fault control is not implemented; clocks remain generated by
  the testbench top. Control-agent fault/clock extensions are OPEN.
- System-level constrained-random packet scheduling, transaction trace
  persistence, required cross coverage, 100-seed and long-stream campaigns:
  OPEN for Phase C.
- Phase D Code Coverage/Formal/Waiver closure and Phase E Linux Benchmark are
  OPEN. No FPGA, GT Wizard, XPM, routed PPA, or physical RF signoff is claimed.
- PR-B is stacked on PR-A and must remain unmerged unless separately approved.

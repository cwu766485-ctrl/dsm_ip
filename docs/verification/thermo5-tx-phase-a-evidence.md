# Thermo5 TX System Verification — Phase A Evidence

## Status

Phase A Dynamic Oracle is **PASS** on the Linux Generic FIFO product setup. The
change is based on `thermo5` HEAD
`2d7a58df43f7bffecd3d34edd2f21bb3262abe2b` and does not modify product RTL or
frozen algorithm behavior.

Product configuration: Centered-Cubic x2 + x2, EF2 ORDER=2, STEP=5120,
20-bit state, four 64-bit PA planes, DPD_MAX_TAPS=1 with identity reset image,
AXI-Lite control, and Generic FIFO.

## Changes

- The Python monitor-trace oracle validates global event sequence numbers,
  reset epoch transitions, source/PA transaction order, packet/frame alignment,
  write/read response association, and COMMIT → CDC Pending → Frame Boundary
  Apply → Core ACK → COMMIT completion ordering.
- A reset-ended partial DSP frame is modeled with zero padding only to obtain a
  candidate reference. Comparison is limited to the causally known PA prefix;
  accepted output beyond the safe-prefix bound is rejected.
- Python and UVM STATUS prediction derive RUN/Drain state from AXI-Lite RUN/STOP
  transactions, accepted source packet/TLAST beats, and accepted PA words. DUT
  core status outputs are observation-only. A four-AXI-cycle CDC settling
  window masks only RUN_ACTIVE and DRAINING; other STATUS fields remain checked.
- The source monitor records idle source-clock cycles between accepted beats.
  TVALID held under TREADY backpressure is not classified as a source gap.
- The product reset sweep now covers 1, 2, 3, and 5 accepted-beat partial-frame
  prefixes, five existing CDC residual values, and complete post-reset static
  vector replay.
- Python mutation tests reject PA data corruption, STATUS corruption, event
  reordering, and configuration apply before CDC Pending.

## Checks

Environment: VCS V-2023.12-SP1; Python 3.12.13.

| Check | Result |
|---|---|
| Python reference-model suite | PASS, 57/57 |
| Python byte compilation | PASS |
| STOP/Drain/Restart, seed 610215 | PASS, 112/112 PA words against static Golden; 6 STATUS reads; predictor mismatches 0; UVM errors/fatals 0 |
| STOP/Drain/Restart with a 1-cycle source gap, seed 610216 | PASS, 112/112 PA words; 1 gap event / 1 cycle; underflow 0; predictor mismatches 0; UVM errors/fatals 0 |
| Reset sweep, seed 610802 | PASS, 4 partial-frame resets + 5 CDC residual resets; 91 accepted PA words; 56/56 post-reset replay words; underflow 0; UVM errors/fatals 0 |
| Dynamic trace replay: STOP/Restart, gap, reset sweep | PASS, 112 / 112 / 91 compared words; no underflow |
| `git diff --check` | PASS |

The one-cycle gap run establishes one passing point only; it does not define a
universal maximum legal gap. FIFO backlog, core service, and PA backpressure
jointly determine starvation. Deliberate starvation remains a separately
classified negative test.

## Reproduction commands

Run from the repository root. The test output directory is ignored by Git and
retained locally for audit; hashes are recorded in the evidence JSON.

```bash
(cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v)

VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make -C dv/uvm/sim \
  thermo5-tx-product-axil-reset-sweep \
  THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_system_phase_a" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors"

VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make -C dv/uvm/sim \
  thermo5-vcs-run-only THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_system_phase_a" \
  THERMO5_VECTORS="$PWD/runs/thermo5_centered_stop_restart_vectors" \
  THERMO5_TESTNAME=thermo5_sku_axil_stop_restart_test UVM_SEED=610215 \
  THERMO5_EXTRA_ARGS="+CORE_WORDS=112 +PACKET_BEATS=32 +THERMO5_TRACE_JSONL=$PWD/runs/thermo5_tx_system_phase_a/stop_restart_trace.jsonl"

VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make -C dv/uvm/sim \
  thermo5-vcs-run-only THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_system_phase_a" \
  THERMO5_VECTORS="$PWD/runs/thermo5_centered_stop_restart_vectors" \
  THERMO5_TESTNAME=thermo5_sku_axil_stop_restart_test UVM_SEED=610216 \
  THERMO5_EXTRA_ARGS="+CORE_WORDS=112 +PACKET_BEATS=32 +THERMO5_SOURCE_GAP_BEAT=10 +THERMO5_SOURCE_GAP_CYCLES=1 +THERMO5_TRACE_JSONL=$PWD/runs/thermo5_tx_system_phase_a/stop_restart_gap1_trace.jsonl"

ROOT="$PWD"
(cd dv/uvm/refmodel/python && python3.12 check_thermo5_monitor_trace.py \
  "$ROOT/runs/thermo5_tx_system_phase_a/reset_sweep_trace.jsonl" \
  --step 5120 --tidsm-order 2 --max-taps 1)
```

The same trace command was run for `stop_restart_trace.jsonl` and
`stop_restart_gap1_trace.jsonl`.

## Evidence boundary and open work

The UVM static-vector checker and independent Python trace oracle both pass.
The Python mutation tests exercise checker rejection paths; they are not a
formal proof or DUT fault-injection campaign. VCS coverage instrumentation was enabled, but no URG merge or Raw/Adjusted
DUT code-coverage metric was generated or signed off in this Phase A. VC Formal, XPM FIFO, GT
Wizard, FPGA PPA, physical RF output, and QAM256 BER remain outside this phase.
Phase B agent ownership/Virtual Sequence and Phase C constrained-random seed
replay remain OPEN and are tracked separately.

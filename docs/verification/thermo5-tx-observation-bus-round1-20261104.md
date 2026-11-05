# Thermo5 TX Observation Event Bus — Round 1

**Status: PARTIAL.** This change adds passive internal observers and a common
UVM transaction event path. It does not complete the planned online unified
scoreboard or final system signoff.

## Source and configuration

- Parent: PR #38 head `184c68b6d704998f5126a75a8f86d7577bb69a1a`
- Implementation commit: `8a70597245a7ff18fd7eabb1bda714d0974be4f5`
- Product configuration: Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 /
  20-bit state, DPD_MAX_TAPS=1, Identity reset image, AXI-Lite, Generic FIFO.
- No product RTL, default algorithm, RX, AI-DPD, or FPGA implementation files
  changed.

## Implemented

- Added passive CDC, DSP-boundary, and EF2-input observers. They publish
  accepted CDC 8-lane words, DSP state/counter transitions, and accepted
  32-lane words immediately before the EF2 branches. The EF2 observer also
  checks valid/data hold while that interface is stalled.
- Added a typed transaction event and analysis-port fan-in. Accepted AXIS
  source beats, AXI-Lite writes/reads/responses, four-plane PA words, internal
  observations, and reset epochs are published to Functional Coverage and the
  JSONL Trace Recorder through this event bus.
- Added source, PA, and AXI-Lite reset-epoch/index metadata. The virtual
  sequencer now holds the Control Agent handle and checks that all four
  interface/control handles are present.
- Extended JSONL with CDC/DSP/EF2 observations. The Python oracle retains the
  internal records for diagnosis but does not use DUT internal values to
  construct expected PA data; expected values still come from accepted source
  transactions and independently modeled configuration.
- Broadened the Makefile's PASS-marker check so existing test-specific
  `THERMO5_*_PASS` markers are accepted, including the system-random packet
  test marker.

## Verification evidence

VCS V-2023.12-SP1 compiled the exact product configuration and ran
`thermo5_sku_axil_random_packet_test` with seed `491802`:

- UVM test: PASS; UVM errors `0`, fatals `0`.
- Event stream: AXIS `32`, CDC `56`, EF2 input `56`, PA `56`; AXI-Lite writes
  `2`, reads `2`, responses `4`; DSP snapshots `76`, EF2 stalls `10`, reset
  epochs `1`.
- The event-kind covergroup observed all 10 event kinds in this run. This is a
  monitor-plumbing check, not the full product Functional Coverage signoff.
- Existing Register Predictor: 2 read checks, 2 write-response checks,
  0 mismatches. Existing static PA Scoreboard and the test's drain/count
  checks passed.
- The non-AXI full-stream bit-true test also passed at seed `491803`, with
  source/CDC/EF2/PA counts `32/56/56/56`, UVM errors/fatals `0`, and all four
  PA planes matching the static bit-true vectors.
- JSONL replay with Python 3.12: PASS, 56/56 PA words compared, zero underflow.
- Python reference-model suite: 60/60 tests passed.
- `git diff --check`: PASS.

Reproduction commands from the repository root:

```bash
make -C dv/uvm/sim thermo5-vcs-run \
  THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 \
  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_OUT="$PWD/runs/thermo5_platform_observation_pr39/vcs" \
  THERMO5_TESTNAME=thermo5_sku_axil_random_packet_test UVM_SEED=491802 \
  THERMO5_EXTRA_ARGS=+THERMO5_TRACE_JSONL="$PWD/runs/thermo5_platform_observation_pr39/vcs/random_packet_trace.jsonl"

make -C dv/uvm/sim thermo5-vcs-run \
  THERMO5_USE_AXIL=0 THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 \
  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_OUT="$PWD/runs/thermo5_platform_observation_pr39/core_vcs" \
  THERMO5_TESTNAME=thermo5_sku_bittrue_test UVM_SEED=491803

(cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v)
(cd dv/uvm/refmodel/python && python3.12 check_thermo5_monitor_trace.py \
  "$PWD/../../../../runs/thermo5_platform_observation_pr39/vcs/random_packet_trace.jsonl" \
  --step 5120 --tidsm-order 2 --max-taps 1)
```

The VCS compile logs, simulation logs, and JSONL Trace remain under the
ignored `runs/` directory. Their SHA-256 hashes and exact observed event totals
are in `data/thermo5-tx-observation-bus-round1-20261104.json`.

## Remaining work

- The event bus is now the common transport for external accepted transactions
  and the three new internal observers. Some legacy configuration/status
  observations in the Trace Recorder still use its existing passive sampling
  threads; these should move onto the event bus in a follow-up.
- The online scoreboard still uses the existing static `.mem` bit-true
  comparison. A transaction/epoch manager, dynamic expected queue, and
  independent stage-by-stage checks for CDC/DSP/EF2 are not implemented here.
- The Python oracle is still an offline replay. It intentionally ignores
  internal DUT values when predicting expected PA output.
- The Control Agent is accessible from the virtual sequencer, but reset/fault
  injection is not yet coordinated by the system virtual sequences.
- This single UVM scenario does not refresh merged DUT-only Raw/Adjusted URG,
  Formal, Mutation, complete system-random Cross Coverage, XPM, GT Wizard,
  FPGA PPA, or RF/QAM256 evidence. No final signoff is claimed.

An exploratory run used the AXI-Lite wrapper with the non-AXI core-enable
bit-true test and timed out. That test/configuration pairing is invalid for
this wrapper; the AXI-Lite random-packet test above is the passing validation
for this change.

# Thermo5 TX Final Integration Review — 2026-11-04

## Executive status

This review advances the four integration priorities, but it is **not a final
TX or FPGA signoff**. P0 is complete on the local integration branch. P1 has
independent CDC, EF2-input and PA checks in the trace replay path, but the EF2
numeric checker is offline rather than a live UVM expected queue. P2 has
several passing system campaigns but not the complete requested cross matrix.
P3 remains open: Raw code coverage is below 100%, waivers are pending, and two
Formal goals remain inconclusive.

## Source and product configuration

- Branch: `codex/thermo5-final-integration`
- Current implementation commit: `7e1ab1930921be1b293d8c59323611ef0b3f9359`
- Integrated parent before the stage-Oracle change:
  `d2b5a1217707514d6d48047ff66f25f7c651000a`
- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state;
  four 64-bit PA planes; `DPD_MAX_TAPS=1`, Identity reset image; AXI-Lite;
  Generic FIFO.
- The commit adds Python reference/checker/tests and documentation only. No
  product RTL, UVM SystemVerilog, algorithm, RX or AI-DPD source changed.
- The branch is a local integration result. This work did not push it or merge
  it into `thermo5`.

## Roadmap disposition

| Priority | Result | Evidence and remaining work |
|---|---|---|
| P0 — integrate UVM/Formal and establish a baseline | **PASS locally** | The cumulative UVM Event Bus, epoch-aware Unified Scoreboard, Formal follow-ups and waiver-audit work are present in one source history. Fresh VCS core and AXI-Lite product runs pass at the implementation SHA. It is not an upstream `thermo5` merge. |
| P1 — Unified Scoreboard and stage checkers | **PARTIAL** | Online UVM checks accepted AXIS against CDC and checks PA against the existing bit-true scoreboard. The Python trace Oracle now independently checks CDC, EF2 input and PA. EF2 numerical prediction is not yet compared in a live UVM expected queue; the requested all-stage online unified checker remains open. |
| P2 — complete system scenario matrix | **PARTIAL** | The 110-seed Identity-DPD baseline, separate DPD/gain/profile matrix, randomized COMMIT/reset campaigns and directed boundary tests pass. The campaigns are separate, not a complete Cartesian cross. Long-frame STOP while PA is stalled still deadlocks in the testbench and needs a checker/sequence correction. |
| P3 — coverage/Formal/signoff | **OPEN** | Raw and Adjusted coverage remain below 100%; no waiver is approved. Counter-guard and full-chain DPD Identity Formal are inconclusive/open. Two legal frame-tail assertions remain unattempted. Hardware/vendor signoff is not run. |

## P0 — unified local baseline

The integration branch contains the recent TX verification and scoped Formal
follow-ups in one reviewable history. Fresh VCS runs used VCS/URG
V-2023.12-SP1, centered-cubic, EF2 order 2 / step 5120, one-tap Identity DPD,
Generic FIFO and the product AXI-Lite configuration.

The Generic-FIFO core regression passed six legal tests (bit-true stream,
bubble/backpressure, FIFO boundary, FIFO empty, reset and reset sweep) plus its
separate expected-negative illegal-frame test. The AXI-Lite product regression
passed six positive product tests, its separate illegal-frame and mailbox
negative tests, the parameter-guard test with its two expected `$error`
messages, and the product URG merge marker. UVM error/fatal counts were zero
for the reported tests; intentional assertion/error behavior is kept in the
negative or parameter-guard classification.

Commands:

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make -C dv/uvm/sim thermo5-vcs-regression \
  THERMO5_OUT="$PWD/runs/thermo5_final_integration_7e1ab19/core" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 \
  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120

VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 make -C dv/uvm/sim thermo5-axil-product-vcs-regression \
  THERMO5_OUT="$PWD/runs/thermo5_final_integration_7e1ab19/axil_product" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 \
  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120
```

Both commands exited 0. Fresh compile logs, per-test logs, product URG merge
log and their SHA-256 values are recorded in
[`thermo5-tx-final-integration-20261104.json`](data/thermo5-tx-final-integration-20261104.json).

## P1 — independent stage Oracle

The Python model exposes a separate `run_centered_cubic_ef2_inputs()` path to
predict the 32-lane EF2 input from accepted source data, frame gain, the two
Centered-Cubic stages and the modeled DPD configuration. The trace checker
compares:

1. accepted CDC samples against the corresponding accepted AXIS source prefix;
2. each accepted EF2-input word against the independent frame/interpolation/
   DPD model;
3. four-plane PA words against the existing independent bit-true model.

DUT DSP snapshots remain diagnostic; they do not create expected values. A
reset-terminated trace checks only the accepted causal prefix and accounts for
discarded/unsafe tail words. Unit tests deliberately corrupt CDC and EF2 trace
data and require a first-stage mismatch failure.

The full retained stage replay passed:

| Trace campaign | Files | CDC words | EF2 words | PA words | Underflows |
|---|---:|---:|---:|---:|---:|
| DPD/gain/profile matrix | 60 | 3,360 | 3,360 | 3,360 | 0 |
| COMMIT boundary + PA stall | 2 | 112 | 112 | 112 | 0 |
| Reset with pending COMMIT | 8 | 448 | 448 | 448 | 0 |
| Randomized COMMIT/reset control | 48 | 2,688 | 2,688 | 2,688 | 0 |
| System random | 110 | 6,720 | 6,720 | 6,720 | 0 |
| **Total** | **228** | **13,328** | **13,328** | **13,328** | **0** |

The replay is reproducible with the following command from the repository root
(the trace directories and output JSON are under ignored `runs/`):

```bash
PYTHONPATH=dv/uvm/refmodel/python python3.12 - <<'PY'
from pathlib import Path
from dsm_refmodel.monitor_trace import run_monitor_trace

root = Path("runs/thermo5_final_integration_d2b5a12")
groups = {
    "dpd_matrix": root / "directed/dpd_matrix",
    "commit_boundary_stall": root / "directed/commit_boundary_stall",
    "reset_pending_commit": root / "directed/reset_pending_commit",
    "randomized_control": root / "randomized_control/traces",
    "system_random": root / "system_random/traces",
}
files = [p for directory in groups.values() for p in sorted(directory.rglob("*.jsonl"))]
assert len(files) == 228, len(files)
totals = {"cdc": 0, "ef2": 0, "pa": 0, "underflow": 0}
for trace in files:
    results = run_monitor_trace(trace, step=5120, tidsm_order=2, max_taps=1)
    assert results and all(result.passed for result in results), trace
    totals["cdc"] += sum(result.compared_cdc_words for result in results)
    totals["ef2"] += sum(result.compared_ef2_words for result in results)
    totals["pa"] += sum(result.compared_words for result in results)
    totals["underflow"] += sum(result.underflow_events for result in results)
assert totals == {"cdc": 13328, "ef2": 13328, "pa": 13328, "underflow": 0}, totals
print(f"STAGE_ORACLE_PASS traces={len(files)} totals={totals}")
PY
```

The full Python suite passed **61/61**. Replay log and compact per-campaign
trace-set hashes are in ignored
`runs/thermo5_final_integration_d2b5a12/final_recheck/`; each original
campaign also retains per-seed trace, UVM/oracle logs, command and hashes
under `runs/thermo5_final_integration_d2b5a12/`.

**Remaining P1 item:** the online UVM Unified Scoreboard independently queues
accepted source samples and checks CDC data/metadata, event ordering and epoch
indices; it does not yet calculate the centered-cubic/DPD EF2 expected stream
inside UVM. That check is currently performed by the offline Python Oracle on
the same accepted transaction trace.

## P2 — system scenario evidence and gaps

The product system-random campaign passed 100 packet seeds plus 10 longer
streams (110/110). It uses legal 56-sample DSP frames, 32-beat packets,
bounded source bubbles, randomized PA ready masks, FIFO-full pressure,
prefill/RUN and graceful STOP/drain. It holds DPD at the product Identity
reset image. Separate campaigns passed 60 DPD/gain/input-profile cases,
48 randomized COMMIT/reset control cases, two COMMIT-boundary/PA-stall tests,
and eight reset-with-pending-COMMIT tests. The Python stage Oracle passed on
all their accepted traces as shown above.

Existing mutation evidence at parent SHA `d2b5a121...` detects both a late
frame-gain application and a PA-plane swap with the bit-true checker; the
baseline mutant-free test passes. This is useful checker sensitivity evidence,
not complete mutation coverage for all requirements.

The current set does **not** prove all seven requested crosses as a single
system matrix. The 110-seed campaign exercises Identity DPD only; non-Identity
DPD and gain/profile checks are separate. Reset/COMMIT controls are also
separate campaigns, so combinations such as Reset × pending COMMIT × EF2 state
and STATUS × COMMIT × STOP need explicit per-requirement closure. The attempted
long-frame graceful STOP + PA-stall pairing deadlocks because the test waits
for packet completion while the stalled PA fills the finite FIFO. This is an
unresolved sequence/checker issue, not evidence of a DUT functional failure.

## P3 — coverage, assertions, Formal and signoff

The latest product DUT-only Raw URG snapshot was generated at parent SHA
`d2b5a1217707514d6d48047ff66f25f7c651000a` from one design VDB plus 238 test
VDBs (236 positive/legal and two expected-negative, with the retained campaign
inventory described in the manifest). It is mixed-provenance retained
coverage, not a fresh same-source corpus. The current implementation
commit changes only Python reference/checker/tests and documentation; it makes
no RTL or UVM SystemVerilog change, so these DUT coverage bins are unchanged.
Raw and Adjusted are identical because there are zero approved waivers and zero
active `.el` exclusions.

| DUT metric | Raw | Adjusted | Status |
|---|---:|---:|---|
| Branch | 524/637 (82.26%) | 524/637 (82.26%) | 113 uncovered |
| Condition | 657/849 (77.39%) | 657/849 (77.39%) | 192 uncovered |
| Line | 3338/3796 (87.93%) | 3338/3796 (87.93%) | 458 uncovered |
| Toggle | 91112/104480 (87.21%) | 91112/104480 (87.21%) | 13368 uncovered |
| FSM states | 13/13 | 13/13 | all states hit |
| FSM transitions | 18/22 | 18/22 | 4 uncovered |

The inventory reports score 83.88 and `RAW_100_OPEN`. The current Raw URG
Functional Coverage detail was reparsed against the negative-bin audit: 440
total rows, 416 URG-scoreable rows, 416/416 scoreable hits, and 412/412
legal-product rows hit. Those legal rows represent 206 distinct bins
duplicated across covergroup-type and monitor-instance reports; all 13
product groups are complete. Four illegal-test-only rows and 24 URG-excluded
rows are reported separately. An older saved detail log in the retained run
directory was from an earlier URG snapshot and showed stale misses; the fresh
parse passed and is the result recorded here. This closes the declared legacy
product functional bins; it does not close the new system cross matrix above.
The retained assertion reports are split by legal and expected-negative VDBs:

- Legal-only: 13 DUT assertion properties have successes, zero legal DUT
  assertion failures, and two DUT `q1_tail` properties have no attempts—one
  per centered interpolator stage at
  `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310`. Two additional
  without-attempt entries are Synopsys UVM register-map assertions.
- Expected-negative-only: three intended RTL assertion failures were observed
  (CDC frame alignment and each interpolator frame-tail assertion). They are
  not counted as legal-regression failures.
- Waiver inventory: 371 candidates remain pending; approved=0, rejected=0,
  active URG exclusions=0. Raw and Adjusted are kept intact.
- Formal: scoped Generic-FIFO `core_data_empty`, DPD ready/valid and AXI-Lite
  write-fire Condition roots have prior exact reachability proofs; the Raw
  bins remain visible pending waiver review. The composed frame-tail work is
  partial and does not prove the full intervening FIFO/DPD chain. Outstanding
  counter saturation/underflow assertions and exact guard Covers remain
  **INCONCLUSIVE**. Full-chain DPD Identity remains **OPEN/INCONCLUSIVE**;
  the existing leaf proof is limited to the DPD datapath. No new Formal run
  was performed in this Python/checker-only change.

The Raw/Adjusted URG reports and inventories remain under
`runs/thermo5_final_integration_d2b5a12/coverage_full_product/`. Their source
SHA, exact commands, denominators and assertion reports are in the adjacent
manifest. Existing scoped proof details are linked from
[`thermo5-tx-linux-system-verification-signoff.md`](thermo5-tx-linux-system-verification-signoff.md).

## Outside Linux signoff

The product regression uses Generic FIFO. This report does not claim real XPM
behavior, GT Wizard TXP behavior, top-level CDC/RDC integration, Vivado routed
timing/PPA, FPGA resource/power closure, or physical RF/QAM256 BER. Those need
the vendor IP, target FPGA project/constraints and board-level measurements.

## Reproduction and evidence

Python checks run:

```bash
PYTHONPATH=dv/uvm/refmodel/python python3.12 -m unittest discover \
  -s dv/uvm/refmodel/python/tests -v
python3.12 -m py_compile \
  dv/uvm/refmodel/python/check_thermo5_monitor_trace.py \
  dv/uvm/refmodel/python/dsm_refmodel/monitor_trace.py \
  dv/uvm/refmodel/python/dsm_refmodel/thermo5.py \
  dv/uvm/refmodel/python/tests/test_monitor_trace.py
git diff --check
```

Python tests: **61/61 PASS**. Stage replay: **228/228 PASS**, zero
underflows. The full snapshot and hashes are in
[`data/thermo5-tx-final-integration-20261104.json`](data/thermo5-tx-final-integration-20261104.json).

## Acceptance conclusion

P0 is acceptable as a local reproducible integration baseline. P1 is improved
but still needs the online EF2 expected queue. P2 remains partial until the
missing combined scenarios and the long-frame STOP/backpressure testbench
deadlock are resolved. P3 is not signed off: keep `RAW_100_OPEN`, all
unapproved waiver candidates pending, Formal inconclusives open, and vendor/
FPGA/physical work explicitly outside the Linux result.

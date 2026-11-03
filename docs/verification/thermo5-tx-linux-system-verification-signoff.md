# Thermo5 TX Linux System Verification Closure

Date: 2026-11-03 (Asia/Singapore)  
VCS execution branch: `codex/thermo5-tx-system-random`
Publication branch: `codex/thermo5-tx-w1c-coverage-round2` (Draft PR #30, stacked on PR #29)
Product RTL source SHA: `1236d49c72360aa62e316aea147528d93a1b3705`
Coverage audit utility fix: `52892f66b4fc80ac41557272a1434ac216ddd073`
Product: Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state,
four 64-bit PA planes, `DPD_MAX_TAPS=1`, Identity reset image, AXI-Lite,
Generic FIFO.

## Signoff status

**Linux TX functional coverage is closed for the declared legal product bins;
DUT code coverage and Formal closure remain open.** The fail-closed gate result
is `RAW_100_OPEN`. Raw and Adjusted code coverage are identical because there
are no approved waivers and no active URG exclusions. This is not a complete
TX, FPGA, or physical signoff.

**Gate 1 waiver-candidate audit update (2026-11-03):** An independent audit
rebound all 371 pending candidate rows to the exact current product compile,
source parameter chains, Raw bins, and the existing same-list Raw/Adjusted
URG/VDB reports. It classifies 361 as fixed-configuration candidates and 10
as exact Formal candidates. The review pipeline reports 371 pending, zero
approved, and zero active `.el` exclusions; Raw and Adjusted remain equal and
the code-coverage denominator is unchanged. This is candidate evidence only,
not waiver approval or code-coverage closure. See the
[`Gate 1 waiver audit report`](thermo5-tx-waiver-review-round1.md) and its
machine-readable artifacts.

The previously open Phase C stimulus dimensions now have separate evidence:
the original packet/long-stream random campaign, a 60-case runtime DPD matrix,
48 randomized reset/COMMIT trials, directed reset/commit boundary tests, and
the exact legal functional-bin audit. They are separate test campaigns; they
do not represent one exhaustive Cartesian product of every system dimension.

## Phase C — System-level tests

| Campaign | Result | Scope and checker |
|---|---:|---|
| Packet and long-stream random | PASS, 110/110 | 100 packet seeds plus 10 two-packet streams; VCS UVM and independent Python trace replay; zero PA mismatch, STATUS predictor mismatch, protocol error, unexpected underflow, lost/duplicate/reordered transaction, UVM error, or fatal. |
| Runtime DPD × gain × input profile | PASS, 60/60 | Identity and legal non-Identity 1-tap coefficient tuples; independent four-plane Python integer oracle. Product reset/default remains Identity. |
| Random reset / pending COMMIT | PASS, 48/48 | 24 reset and 24 COMMIT trials, scheduler seed `20261103`; exact reset-prefix × pending-coefficient, commit-boundary × PA-stall, and STATUS × COMMIT × STOP crosses hit 4/4, 2/2, and 1/1. |
| Directed reset / commit tests | PASS, 8/8 | Reset-prefix × pending-coefficient classes; source-gap / PA-stall / FIFO-full targeted matrix is separately recorded as 12/12. |
| Expected-starvation test | PASS, separate | 32 source beats, one TLAST, 56 bit-true PA words, zero protocol errors; one reported underflow after the packet. This is a starvation/error-class test, not a normal-stream zero-underflow result. |
| Mutation checks | PASS | Independent PA scoreboard detected both `late_gain` and `plane_swap` mutants; baseline passed. This covers these two mutations only. |

The baseline random campaign keeps DPD at Identity. Non-Identity coefficients
were verified in the separate 60-case matrix, so the product default was not
changed. The randomized control, DPD, reset/commit, and original 110-seed
campaigns were compiled from the same product RTL. The 243-VDB coverage merge
contains 240 earlier positive VDBs and two earlier expected-negative VDBs from
source SHA `732a64ab...`, plus the additive starvation VDB compiled at
`1236d49...`. The diff from `732a64ab...` to `1236d49...` has no RTL changes;
the UVM package change only registers the added starvation test and the older
test classes/drivers/checkers are unchanged. Raw and Adjusted URG were rerun
from the same exact 243-VDB list and current design VDB. This provenance is
recorded explicitly; it is not represented as 243 fresh simulations from one
full-tree SHA. The latest coverage refresh adds one targeted VCS VDB to that
retained list; the new VDB was compiled from the verification worktree based on
`ad3211b98677055646975e35924a5809c8d29bac`, with current compile inputs
hash-bound in its manifest. Product RTL remained unchanged.

## Coverage closure round 2 — AXI-Lite STATUS W1C

The targeted legal one-tap DPD test now checks the externally visible STATUS
completion lifecycle: COMMIT completes, STATUS reads DONE=`1`, a legal W1C
write clears DONE, and the next STATUS read returns zero. The AXI-Lite
register predictor independently checks sampled STATUS and transaction
responses. A same-cycle `commit_done`/STATUS-read observer-ordering issue in
the Python trace oracle was corrected and covered by a mutation test that
rejects a corrupted STATUS value.

The test ran with seed `930000`, `C1_RE_Q14=15000`, `C3_RE_Q14=C5_RE_Q14=0`,
and 56 input words. VCS reported zero UVM errors/fatals, zero predictor
mismatches, 17 checked write responses, four STATUS/register reads, and 56
four-plane words matched against the Python bit-true oracle. Trace replay
reported zero underflows.

The added VDB closed seven exact Raw DUT bins, with no waiver or denominator
change:

| Metric | Exact source bin | Result |
|---|---|---|
| Branch | `94c317079c444447221e`, `thermo5_sku_uvm_tb.dut.u_cfg`, `thermo5_dpd_axi_lite_cfg.sv:264` | Hit; legal DONE clear through `REG_STATUS` |
| Line | `51e1eab855e96c50a4fd`, same instance, line 264 | Hit |
| Condition | `de2c421694e6e9174223`, line 264, operands `1/1` | Hit |
| Condition | `87c647010ed34a0a7091`, line 265, operands `1/0` | Hit; legal W1C write leaves ERROR bit clear |
| Toggle | `d209311686c25596f406`, `u_cfg.cfg_done`, `1→0` | Hit |
| Toggle | `fdf1c5a010c986e614fc`, `u_cfg.cfg_done_q`, `1→0` | Hit |
| Toggle | `64f234d6e5984d7c570e`, DUT `cfg_done`, `1→0` | Hit |

The aggregate now contains 244 test VDBs; the positive-only assertion and
functional view contains 242. The 243-test baseline was 522/637 Branch,
654/849 Condition, 3336/3796 Line, and 84177/104480 Toggle. The refreshed Raw
and Adjusted reports use the same 244-VDB list and the same DUT hierarchy;
coverage is now 523/637 Branch, 656/849 Condition, 3337/3796 Line, and
84180/104480 Toggle. FSM remains 13/13 states and 17/22 transitions. There are
21,071 uncovered code records across 475 root-cause groups; all remain OPEN.
The 371 waiver candidates remain pending, with zero approved waivers and zero
active exclusions. `RAW_100_OPEN` remains the correct gate result.

The latest exact VDB lists, URG reports, gate output, waiver audit, and
root-cause artifacts are recorded in
[`thermo5-tx-coverage-w1c-round2-20261103.json`](data/thermo5-tx-coverage-w1c-round2-20261103.json).

## Functional coverage

The source-linked bin audit reports **392/392 (100%) legally applicable
product bins** across 12 functional groups. The matrix covers runtime DPD
classes, gain and input profiles, COMMIT timing, PA stalls, reset epochs,
source gaps, FIFO-full observations, STOP/TLAST/Drain, and STATUS ordering.

Two semantic bins are illegal-test-only (`malformed_early` and `bad_frame`),
each shown in covergroup-type and monitor-instance views. The separate negative
regression hits them and checks public `protocol_error` plus reset recovery.
All four report rows remain visible; the 24 URG-model-excluded records are
also retained in the detail CSV. No denominator was edited and no bin was
removed.

The all-test Raw URG view includes expected negative-test assertion failures.
The separate positive assertion inventory has zero failures. Expected-negative
results are not counted as legal assertion failures.

## DUT Raw and Adjusted code coverage

The DUT-only URG hierarchy selects the elaborated TX product path. The latest
Raw and Adjusted reports use the same 244 VDBs; Adjusted applies zero
exclusions and therefore exactly matches Raw.

| Metric | Raw | Adjusted | Missing |
|---|---:|---:|---:|
| Branch | 523/637 (82.1036%) | 523/637 (82.1036%) | 114 |
| Condition | 656/849 (77.2674%) | 656/849 (77.2674%) | 193 |
| Line | 3337/3796 (87.9083%) | 3337/3796 (87.9083%) | 459 |
| Toggle, both directions | 84180/104480 (80.5704%) | 84180/104480 (80.5704%) | 20300 |
| FSM states | 13/13 (100%) | 13/13 (100%) | 0 |
| FSM transitions | 17/22 (77.2727%) | 17/22 (77.2727%) | 5 |

There are **21,071 open code records** in 475 root-cause task groups. Every
record remains `OPEN`; the root-cause classes are triage hypotheses, not
reachability decisions. Priority gaps include 115 Branches, 195 Conditions,
and five exact `rem_count_q` transitions at
`rtl/axis/dsm_axis14_to_core8_cdc.sv:125`:
`'h2->'h0`, `'h4->'h0`, `'h6->'h0`, `'ha->'h0`, and `'hc->'h0`.

The 371 existing waiver candidates remain **PENDING**. There are zero approved
waivers and zero active `.el` exclusions. The waiver pipeline now permits a
pending candidate to point to an exact current OPEN Raw bin, while still
requiring a source/configuration-bound, non-vacuous proof and approval record
before any exclusion can be generated. The pipeline and its fail-closed tests
passed 34/34.

## Assertions and Formal

The positive assertion inventory reports 13 successful DUT properties, zero
failures, two uncovered properties, and two properties without attempts. The
two exact no-attempt properties are the centered-cubic frame-end assertion
`assert (q1_tail)` at `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:309-310`,
one per interpolator instance. They remain OPEN; no-attempt is not proof of
unreachability. The positive regression has zero unexpected assertion
failures. The all-test aggregate separately contains two expected failures
from the negative tests.

The outstanding-counter Formal harness ran with zero assumptions and zero
black boxes. Source/core/output activity covers were witnessed, and the two
assertions were non-vacuous. After 502 seconds VC Formal returned
`INCONCLUSIVE` for both the saturation and underflow guard assertions and both
target guard covers. The corresponding two DUT Branch bins remain OPEN; no
waiver was created.

The DPD Identity equivalence attempt remains inconclusive: one assertion
proven, 12 inconclusive, five constrained, and four of four activity covers
witnessed; zero black boxes. This does not sign off Identity DPD arithmetic.
The existing EF2 stability and pair-lookahead equivalence PASS evidence is
retained, but pair-lookahead remains a disabled candidate and is not part of
the product code denominator.

## Commands and evidence

The current coverage refresh is under the ignored local directory
`runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/`. Its manifests
record exact commands, tool versions, VDB fingerprints, and log hashes. Key
artifacts:

- `logs/seed_930000.log` and `traces/seed_930000.jsonl` — targeted W1C UVM run and captured monitor trace.
- `final_dual_urg_bound/report_manifest.json` — 244-VDB same-list Raw/Adjusted URG manifest.
- `legal_positive_dual_urg_bound/report_manifest.json` — 242-VDB positive-only assertion/functional report.
- `coverage_gate.json` — `RAW_100_OPEN`, 392/392 legally applicable functional bins.
- `rootcause/thermo5-tx-coverage-root-cause-summary.json` — 21,071 OPEN records, 475 groups.
- `waiver_audit.json` and `thermo5_tx_main.el` — 371 pending, zero approved, no active exclusions.
- `product_compile_manifest.json` — exact 90-file product compile source inventory.

The retained 243-VDB baseline and earlier Phase C artifacts remain under
`runs/thermo5_tx_closure_current/source_1236d49/` and
`source_732a64/`; no full regression was repeated.

- `coverage_243/final_dual_urg/report_manifest.json` — same-list Raw/Adjusted URG manifest.
- `coverage_243/coverage_gate_final.json` — `RAW_100_OPEN` gate output.
- `coverage_243/rootcause_final/thermo5-tx-coverage-root-cause-summary.json` — exact open-bin totals and legal functional audit.
- `coverage_243/waiver_audit.json` and `coverage_243/thermo5_tx_main.el` — 371 pending, zero approved, zero active exclusions.
- `formal/outstanding_final/formal_manifest.json` — current counter-guard proof result.
- `starvation/summary.json` — directed starvation UVM, oracle, and coverage evidence.
- `verification/tools_hw_tests.log` and `verification/python_reference_tests.log` — latest utility and reference tests.
- Earlier Phase C evidence is under `source_732a64/{system_random,dpd_matrix,randomized_control_final,reset_pending,mutation,formal_identity_lemmas}/`.

Reproduction commands for the latest closure inputs:

```bash
python3.12 -m unittest discover -s tools/hw/tests -v
(cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v)
python3.12 dv/uvm/sim/run_thermo5_axil_starvation.py \
  --out-dir runs/thermo5_tx_closure_current/source_1236d49/starvation_replay
python3.12 tools/hw/thermo5_tx_product_compile_manifest.py \
  --compile-log runs/thermo5_tx_closure_current/source_1236d49/starvation/build/compile.log \
  --source-manifest runs/thermo5_tx_closure_current/source_1236d49/starvation/source_manifest.json \
  --product-filelist dv/uvm/sim/thermo5_sku_filelist.f \
  --coverage-hierarchy dv/uvm/sim/thermo5_product_dut_coverage.hier \
  --output runs/thermo5_tx_closure_current/source_1236d49/product_compile_manifest.json
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_axil_outstanding_fpv.py \
  --out-dir runs/thermo5_tx_closure_current/source_1236d49/formal/outstanding_replay
```

Latest checks: Python reference suite **59/59 PASS**; hardware utility suite
**34/34 PASS**; `py_compile` and `git diff --check` PASS; targeted W1C VCS UVM
and Python trace oracle PASS; same-list Raw/Adjusted URG and gate generation
PASS. The prior counter Formal result remains **INCONCLUSIVE**, not PASS.

## Remaining signoff items

- Close or formally disposition all 21,071 open DUT code records without
  changing the valid denominator; first investigate reachable Branch and
  Condition records, then Lines, Toggle, and the five FSM transitions.
- Resolve the two interpolator assertions with legal witnesses or exact
  non-vacuous reachability proof.
- Improve EF2 DPD Identity Formal convergence and the outstanding-counter
  proofs; Formal inconclusive remains OPEN.
- Preserve the current separate expected-starvation classification and settle
  the source-gap contract for the system interface.
- Run real XPM FIFO and GT Wizard simulation, FPGA PPA/routed timing, and
  physical RF/QAM256 BER on their required vendor/platform flows.

No RX, AI-DPD, Vivado physical implementation, product RTL, default DPD image,
or frozen TX algorithm was modified in this closure round. No PR was merged.

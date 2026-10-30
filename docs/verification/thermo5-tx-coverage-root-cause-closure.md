# Thermo5 TX Coverage Root-Cause Closure — Step 1/2

- Raw VCS/URG product source SHA: c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b; product RTL/UVM compile source hashes match.
- The inherited product source manifest has one Formal-only harness mismatch (`dv/uvm/formal/thermo5_axil_cfg_coverage_harness.sv`), which is outside the VCS product filelist. This closure carries fresh source-bound Formal evidence for the updated harness in `thermo5-tx-formal-bin-dispositions.json`; it is not mixed into the Raw VCS source identity.
- Raw gap ledger: 18,593 rows; SHA-256 e586d27684fffe4e98b1d4c4bd43b22839c349ef31c07b1779d4a69c4ce45222.
- Expression-aware semantic IDs: 18,593; old ID collisions: 17 groups, 17 extra rows.
- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; 32 chronological lanes; DPD_MAX_TAPS=1 identity; AXI-Lite wrapper and Generic FIFO.
- All code gaps start OPEN. Root-cause labels are review hypotheses, not approved exclusions.
- Raw equals Adjusted; approved waivers 0; exclusions 0.
- The VCS compile transcript resolves the product build to 73 local parsed
  sources plus the filelist and coverage hierarchy. This derived 75-entry
  manifest matches the captured hashes and current source; 14 other broad
  manifest entries were not parsed by the product compile.
- The fail-closed Raw gate recheck returned `RAW_100_OPEN`, with Raw identical
  to Adjusted. Gate output SHA-256:
  `62f32d3c27baba959eb1302a3efc0875f8af4ea074d938664ded3e517501e6c2`.

## Functional Group Report audit

The complete Raw URG Group Report has 214 denominator-eligible bin records across covergroup-type and monitor-instance views: 210 hit and four zero-hit. The earlier 170/174 tally omitted 40 generated EF2 cross-bin records (20 in each view) and is superseded; the URG database and denominator were not modified. The four zero-hit records are two semantic illegal-frame bins repeated in both report views. Separate negative URG evidence hits them; they remain in the Raw denominator and are not legal positive-product stimulus.

| Group | Raw hits / scoreable records | Uncovered |
|---|---:|---:|
| core_cg | 14/16 | 2 |
| source_cg | 38/40 | 2 |
| stop_restart_cg | 12/12 | 0 |
| ef2_cg | 68/68 | 0 |
| plane_atomic_cg | 16/16 | 0 |
| read_cg | 22/22 | 0 |
| write_cg | 36/36 | 0 |
| reset_cg | 4/4 | 0 |
| **Total** | **210/214** | **4** |

The complete detail export contains 226 rows, including 12 bins already marked Illegal/Excluded by the existing URG model. See [`thermo5-tx-functional-bin-detail.csv`](data/thermo5-tx-coverage-root-cause/thermo5-tx-functional-bin-detail.csv) for each Group, coverpoint/cross, bin, count, report view, status, and source-page SHA. The 12 pre-existing URG model statuses are disclosed separately and are not new waiver or `.el` exclusions.

| Exact URG scope | Raw product hits | Separate negative hits | Classification |
|---|---:|---:|---|
| thermo5_sku_uvm_pkg::thermo5_sku_coverage::source_cg.cp_packet_quanta.malformed_early | 0 | 1 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_tb.me.obj.source_cg.cp_packet_quanta.malformed_early | 0 | 1 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_pkg::thermo5_sku_coverage::core_cg.cp_illegal.bad_frame | 0 | 49 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_tb.me.obj.core_cg.cp_illegal.bad_frame | 0 | 49 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |

Legally applicable positive scoreable bins are 210/210. The four Raw zero-hit report rows remain visible in the denominator; no waiver or denominator edit was applied.

## Code coverage and root-cause task inventory

| Metric | Raw covered / total | Raw missing | Closure tasks |
|---|---:|---:|---:|
| branch | 440/637 (69.0738%) | 197 | 53 |
| condition | 583/846 (68.9125%) | 263 | 107 |
| line | 3,190/3,796 (84.0358%) | 606 | 123 |
| toggle | 86,951/104,478 (83.2242%) | 17,527 | 209 |

The task CSV has 492 source/instance/location-rooted tasks. The compressed bin ledger preserves all 18,593 source rows and includes expression-aware IDs, URG Condition text, instance, source file/location, product SHA, and status. Every row was OPEN at the initial audit; the exact later dispositions are listed below.

| Metric / root-cause hypothesis | Raw gap rows |
|---|---:|
| branch / CDC_OR_RESIDUAL_STATE | 4 |
| branch / FIXED_PRODUCT_CONFIGURATION | 92 |
| branch / IDENTITY_DPD_ARITHMETIC | 64 |
| branch / LEGAL_STIMULUS_OR_CHECKER_REVIEW | 37 |
| cond / INTERPOLATOR_EMPTY_OR_BLOCKED | 4 |
| cond / RESET_RELEASE_OR_STATE_HOLD | 259 |
| line / CDC_OR_RESIDUAL_STATE | 7 |
| line / DPD_TAP_HISTORY_CONFIGURATION | 192 |
| line / FIXED_PRODUCT_CONFIGURATION | 244 |
| line / IDENTITY_DPD_ARITHMETIC | 128 |
| line / LEGAL_STIMULUS_OR_CHECKER_REVIEW | 35 |
| toggle / CDC_OR_RESIDUAL_STATE | 130 |
| toggle / COUNTER_HIGH_BITS | 640 |
| toggle / DATA_VALUE_OR_TOGGLE_STIMULUS | 3,452 |
| toggle / DPD_TAP_HISTORY_CONFIGURATION | 8,192 |
| toggle / FIXED_PRODUCT_CONFIGURATION | 793 |
| toggle / IDENTITY_DPD_ARITHMETIC | 4,320 |

The initial Step 1/2 inventory was a deterministic re-analysis of fixed-SHA VCS/URG evidence. Its later targeted follow-up is recorded below; no Raw/Adjusted denominator changed.

## Evidence inputs

- Raw Group Report: runs/thermo5_tx_product_axil_reset_cov_20261030/product_raw_after_source_gap_current_20261030
- Separate expected-negative Group Report: runs/thermo5_tx_product_axil_register_access_20261030/negative_expected_assertions/report
- Source-linked gap ledger: runs/thermo5_tx_product_axil_reset_cov_20261030/gap_ledger_after_source_gap_current_20261030/thermo5-tx-gate3-coverage-ledger.csv
- Source manifest: runs/thermo5_tx_product_axil_reset_cov_20261030/gap_ledger_after_source_gap_current_20261030/axil_gap_ledger.json
- Closure evidence JSON: docs/verification/thermo5-tx-linux-coverage-closure-evidence.json


## Targeted Branch/Formal follow-up — 2026-10-30

Product-scoped branch attempt used two legal packet organizations (four back-to-back 32-beat frames and one 32-beat frame) with the existing four-plane independent oracle. The monitor saw zero `q_count==1 && pop_head && push_input` events in both interpolator instances. UVM stopped at the required coverage assertion; the attempt was not merged into the product VDB set. The Raw URG rerun included its one exploratory VDB and one prior baseline VDB (30 test VDBs total): line remained 3,190/3,796, condition 583/846, branch 440/637, toggle 86,951/104,478. This is no coverage gain, not evidence of unreachability. The two single-entry pop/push product bins remain OPEN.

Fresh VC Formal V-2023.12-SP2 on exact W=16/LANES=8 interpolator instances proves four assertions and reaches all four legal frame/queue covers. It also reports four exact covers as `uncoverable` with zero black boxes and zero setup violations:

| Semantic Bin ID | Product instance/path | Formal disposition | Raw treatment |
|---|---|---|---|
| `TXB-39a0a549d32bc9ef1e01` | Stage 1 `pop_head && q0_tail`; product ties `in_tail=0` | `PROVEN_UNREACHABLE`; no-input-tail assertion proven; cover uncoverable | Raw retained; no waiver |
| `TXB-603e97cceda8c0d4d0ed` | Stage 2 `tail_fire`; product sets `APPEND_TAIL_VECTOR=0` | `PROVEN_UNREACHABLE`; cover uncoverable | Raw retained; no waiver |
| `TXB-c79cdf2b9f5b4620688e` | Stage 2 append-tail arm; product sets `APPEND_TAIL_VECTOR=0` | `PROVEN_UNREACHABLE`; cover uncoverable | Raw retained; no waiver |
| `TXB-9141942b3f6f51689217`, `TXB-33db6d34081fd3b6ec60` | Stage 1/2 single-entry pop+push, q_count=1 | Formal covers reached at depth 2; product UVM has not hit them | `OPEN`; legal product stimulus still required |

Full formal run artifacts: `runs/thermo5_tx_final_interp_reachability_retry_20261030/`. Exact bin dispositions are reflected in the compressed open-bin ledger, task CSV, and summary JSON. The three proven-unreachable bins remain in Raw URG and the denominator; no `.el` directive has been added.

DPD Identity Formal remains unresolved. The fresh direct proof completed with 5/18 assertions proven and 13 inconclusive; all four covers were reached, assumptions were non-vacuous, and black-box count was zero. The staged auto-lemma rerun did not close payload identity: final report has 1/13 assertions proven and 12 inconclusive, with all four covers reached. No counterexample was produced; these results remain OPEN.

The prior 16-cycle AXI source gap is a real observed underflow while RUN stays active: the test generated two legal 32-beat packets, paused 16 source-clock cycles before beat 32, then matched all 112 expected words but its monitor counted 54 underflow events and the stream-contract checker failed. The AXI-stream interface does not currently declare a maximum inter-beat gap, while the continuous GT path cannot backpressure. Treat this as an unresolved product contract/risk, not a coverage waiver or a passing legal-environment exception.

## AXI-Lite, EF2 and counter Formal follow-up — 2026-10-30

The AXI-Lite reachability harness was rerun after removing its two previous reset-coupling assumptions, which VC Formal had classified as vacuous. The reviewed run has zero environment assumptions, zero formal setup violations and zero black boxes. Three assertions are non-vacuous; a legal coefficient-read transaction is covered. The matching default-arm, illegal-MAX_TAPS and `bvalid`/pending/take Covers are `uncoverable`. These proofs close three exact ledger dispositions only:

| Semantic Bin ID | Exact product bin | VC Formal result | Raw handling |
|---|---|---|---|
| `TXB-872eb98e51c3229e4c86` | AXI-Lite `write_fire` Condition, line 93 (`!bvalid=0`, pending/take groups true) | `a_line88_tuple_unreachable` proven; exact Cover uncoverable | `PROVEN_UNREACHABLE`; Raw retained |
| `TXB-74a3bacf0956921ac9bf` | AXI-Lite coefficient-read default Line, line 142 | exact default-arm Cover uncoverable; legal coefficient-read witness covered | `PROVEN_UNREACHABLE`; Raw retained |
| `TXB-054d97a87a8d74c36c8b` | AXI-Lite `MAX_TAPS` invalid-parameter Branch, line 348 | MAX_TAPS=1 guard assertion proven; invalid-parameter Cover uncoverable | `PROVEN_UNREACHABLE`; Raw retained |

Together with the three interpolator paths above, the ledger now has six exact formally unreachable bins and 18,587 OPEN bins. No waiver or `.el` exclusion is approved; the Raw denominator remains unchanged.

Additional fresh VC Formal results:

- EF2 production core: 6/6 safety, accepted-word and stall/state assertions proven; 3/3 input, transfer and stall Covers hit; zero black boxes and setup violations.
- Counter: 3/3 bounded properties proven, including `sample_count[31:12]==0` under an explicit 2,072-acceptance-per-reset-epoch assumption. Separately, 35/35 full-width transition properties and 4/4 shallow Covers pass without that budget. This finite budget is not a declared lifetime traffic contract, so no counter-high-bit URG Toggle is dispositioned.
- Product EF2 parameters: 2/2 assertions proven; `PAIR_LOOKAHEAD=1` and illegal-parameter Covers are uncoverable at the fixed product configuration.
- Identity DPD: direct proof remains 5/18 proven and 13 inconclusive; staged auto-lemma proof remains 1/13 proven and 12 inconclusive. Both hit their non-vacuity Covers, use zero black boxes and produce no counterexample. DPD arithmetic/saturation rows remain OPEN.

Targeted product UVM was not rerun after the two event-counter misses; no new product VDB was included. A fresh URG merge could not run in this WSL session: the installed VCS `-location` check rejects kernel `6.6.87.2-microsoft-standard-WSL2` as unsupported, so URG cannot resolve its VCS installation location. The reused raw report remains line 3,190/3,796, condition 583/846, branch 440/637, toggle 86,951/104,478. Raw equals Adjusted and the gate stays `RAW_100_OPEN`.

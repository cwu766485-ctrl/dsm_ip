# Thermo5 TX Round 14 — Targeted Coverage and Linux Signoff

**Decision: LINUX DV SIGNOFF OPEN.** Round 14 completed a fresh product regression set, a homogeneous 232-test Raw/Adjusted DUT URG run, separate legal and expected-negative functional reports, and current-source focused Formal. Legal-applicable functional coverage is closed at 218/218. DUT code coverage remains `RAW_100_OPEN`: 13,955 Raw bins remain, no Waiver has independent approval, and official Adjusted equals Raw. The full-chain DPD Identity and AXI outstanding-counter proofs remain open. This report does not claim FPGA, GT, RF, or physical signoff.

## 1. Integration and frozen baseline

PR #42 was merged into `thermo5` as `42960c12cc381a7c58dddc501d4a851bbead13ec`, then PR #43 was retargeted and merged as `253268f38783c37b3bbb19479654b236fff3f732`. Round 14 evidence was produced on `f22dad56f7cd56e94158cb86cdad04e3d11e489d` in the isolated review branch `codex/thermo5-round14-coverage-closure`. PR #44 is open as a Draft and targets `thermo5`; it has not been merged.

The product remains Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, DPD_MAX_TAPS=1 with Identity reset image, AXI-Lite, Generic FIFO. No product RTL or frozen algorithm was changed. The current compile records 95 repository sources, source fingerprint `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`, Product RTL SHA-256 `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`, filelist SHA-256 `3605407edad33e8f806a5c6c9a78f553df08f3f09551d18284194ef931aedc85`, and DUT coverage-hierarchy SHA-256 `1b01e3c9a7c86a189660dcb0529369dc8ef4d1ff535ebbdb619e5d7c5651c5fa`.

Tools: Rocky 8.10 / WSL2 kernel `6.6.87.2-microsoft-standard-WSL2`; VCS V-2023.12-SP1_Full64; URG V-2023.12-SP1; VC Formal V-2023.12-SP2; Python 3.12.13.

## 2. Regression and checker results

| Suite | Result | Details |
|---|---|---|
| Generic FIFO Centered-Cubic / EF2 product regression | PASS | Directed bit-true, reset, bubble/backpressure, FIFO boundary/empty, expected-negative frame, and STOP/restart cases. |
| AXI-Lite product regression | PASS | Register access, configuration, coefficient transport, nonlinear legal 1-tap DPD, graceful STOP, boundary phase, isolated negative cases, and parameter guard. |
| System random | PASS, 110/110 | 100 random plus 10 long streams; seed base 1044100. |
| DPD × Gain × Input Profile matrix | PASS, 60/60 | Legal one-tap matrix; seed base 930000; independent Python oracle comparisons. |
| Randomized Reset / COMMIT | PASS, 24 + 24 | Schedule seed 20261103 is the schedule in the formal 232-test coverage manifest. A separate schedule seed 20261107 also passed 24 + 24 and is supplemental. |
| COMMIT boundary with PA stall | PASS, 2/2 | Both configured COMMIT timing classes were observed and checked. |
| Reset while COMMIT pending | PASS, 8/8 | All four required reset-prefix / pending-coefficient crosses were hit. |
| Additional directed cases | PASS | Reset-release/source seed 610713; reset-sweep seed 610802; graceful-STOP seed 1046112; 2,072-sample EF2 corner seed 271031. |
| Python reference model / hardware utilities | PASS | 64/64 and 47/47. |
| Direct SystemVerilog Unified Scoreboard mutation | PASS, 6/6 | Lost, duplicate, reordered, wrong Frame ID, premature apply, and EF2 corruption were detected. |

The named system crosses were rechecked from current run summaries and packet audit records:

| Cross | Result |
|---|---:|
| DPD × Gain × Input Profile | 60/60 |
| COMMIT × Frame Boundary Apply × PA Stall | 2/2 |
| Reset × Pending COMMIT | 4/4 |
| STATUS × COMMIT × STOP | 1/1 |
| Source Gap × PA Stall × FIFO Full | 1/1 |
| RUN × Prefill × Source Gap | 1/1 |
| STOP < accepted TLAST < Drain | Hit; two packet records retained and integrity PASS |

The dedicated STOP/restart log reports `stop_tlast_drain=2`, two ordered packet records, and 112 four-plane output words matching the oracle. The semantic negative checks remain explicit: a source gap in a different packet cannot combine with FIFO-full/PA-stall, and TLAST before STOP cannot satisfy the STOP-before-TLAST cross. Both are checked as negative assertions, not inferred from a score percentage.

## 3. Fresh functional Covergroup coverage

The same 1 Design VDB and 232 Test VDBs were merged three ways with URG's functional-group report enabled: all tests, 230 legal tests, and the 2 expected-negative tests. All three URG invocations exited zero. The 16-group report is captured in [`thermo5_tx_r14_functional_group_coverage.csv`](data/thermo5-r14/thermo5_tx_r14_functional_group_coverage.csv).

| View | Covered / expected | Result |
|---|---:|---|
| All campaigns, including the two explicit negative tests | 220/220 across 16/16 groups | 100% |
| Legal-only set | 218/220 across 16 groups | 99.09% raw group score |
| Legal-applicable bins after separating negative-only bins | 218/218 | 100% |
| Negative-only bins in the isolated negative VDBs | 2/2 | Both expected negative scenarios observed |

The two legal-only misses are exact and expected-negative-only:

| Covergroup bin | Legal-only count | Negative-only count | Meaning |
|---|---:|---:|---|
| `source_cg.cp_packet_quanta.malformed_early` | 0 | 1 | Malformed early packet/frame stimulus; exercised only in the illegal-frame test. |
| `core_cg.cp_illegal.bad_frame` | 0 | 49 | Illegal frame classification; exercised only in the illegal-frame test. |

The denominator was not edited. The report keeps the legal 230-test and negative 2-test VDBs separate, and the combined report independently confirms all 220 bins were hit. The familiar historical 436/436 semantic-ledger figure is a different coverage model and is not substituted for these fresh URG Covergroup counts.

## 4. Raw and official Adjusted DUT Code Coverage

The code URG used one Design VDB and exactly 232 Test VDBs from the same current compile fingerprint. Raw and Adjusted used the same VDB input list; the official `.el` has only comments, with zero active exclusions and zero approved Waivers. The report manifest records `same_vdb_inputs_for_raw_and_adjusted=true`.

| Metric | Raw | Official Adjusted | Remaining Raw bins |
|---|---:|---:|---:|
| Branch | 524 / 637 (82.2606%) | 524 / 637 (82.2606%) | 113 |
| Condition | 657 / 849 (77.3852%) | 657 / 849 (77.3852%) | 192 |
| Line | 3,338 / 3,796 (87.9347%) | 3,338 / 3,796 (87.9347%) | 458 |
| Toggle | 91,288 / 104,480 (87.3737%) | 91,288 / 104,480 (87.3737%) | 13,192 |
| FSM states | 13 / 13 (100%) | 13 / 13 (100%) | 0 |
| FSM transitions | 22 / 22 (100%) | 22 / 22 (100%) | 0 |

Total remaining Raw code bins: **13,955** (113 Branch + 192 Condition + 458 Line + 13,192 Toggle). The exact source-linked ledger remains [`thermo5-tx-coverage-open-bins.csv.gz`](data/thermo5-r12/thermo5-tx-coverage-open-bins.csv.gz). Every source-file SHA on its 13,955 rows was rechecked against the current checkout: 11 unique source files, zero mismatches. The current VDB metrics match the ledger totals. The per-bin ledger is carried forward because the current product RTL source files and URG mapping are unchanged; it is not represented as a newly generated toggle-bin export.

There is no net Raw metric improvement versus the previous same-product coverage run. The targeted simulations passed but did not close a newly counted DUT code bin in the combined URG summary. This is why added tests are not reported as code-coverage closure by themselves.

### Current Raw bin disposition

The official run has no exclusions. The What-if candidate classes therefore remain analysis-only:

| Area | Current Raw open | What-if candidate handling | Current decision |
|---|---:|---|---|
| Branch | 113 | Historical 361-candidate What-if would leave 12 | All 113 remain in official Adjusted; exact hits or reviewed exclusions still required. |
| Condition | 192 | Historical 361-candidate What-if would leave 84 | All 192 remain in official Adjusted. |
| Line | 458 | Historical 361-candidate What-if would leave 306 | All 458 remain in official Adjusted. |
| Toggle | 13,192 | No What-if reduction | All remain open; candidate fixed-configuration arguments are not approvals. |

Toggle root-cause buckets still requiring proof or legal stimulus are 8,192 DPD Pair-1 bits, 120 Active-Tap bits, 640 sample-counter high bits, 848 saturation/arithmetic-related bits, 3,262 other data bits, and 130 CDC residual bits. The product's `MAX_TAPS=1` is a real configuration fact, but the pair-1 and active-tap inventories still need exact current-instance proof and independent approval before exclusion. The 2,072-sample Formal budget does not establish an unlimited product lifetime bound for counter high bits.

The Round 12 exact raw ledger plus current raw summaries are preserved alongside the current VDB manifest, URG report manifest, branch/line/denominator/assertion CSVs, and formal manifests under [`data/thermo5-r14/`](data/thermo5-r14/).

## 5. Waiver review

The repository waiver record has 371 entries; the local candidate ledger has 369. The two remote-only IDs, `W-75530ed17d5b396a4e9b` and `W-d7cb262894a5aae016b6`, are already Raw hits, so no exclusion is needed for them.

| Candidate class | Count | Round 14 status |
|---|---:|---|
| ELIGIBLE fixed-configuration analysis candidates | 361 | Still pending independent review; no automatic approval. |
| NEEDS_REPROOF | 4 | Current-source focused proofs are recorded; proof is not approval. |
| UNRESOLVED interpolator candidates | 4 | Remain open; no exclusion proposed. |
| Approved / rejected / active exclusions | 0 / 0 / 0 | No Reviewer or approval reference was invented. |

Round 14 reran the AXI-Lite configuration Formal candidate `W-9010fccd0889b46ea284`, mapped to `thermo5_dpd_axi_lite_cfg.sv:246`. Four assertions are proven, with zero assumptions, zero black boxes, and three non-vacuous assertion checks; the legal coefficient-read activity Cover is reached, while the default-arm Covers are uncoverable. This is strong current-source reachability evidence, but exact waiver mapping review and an independent reviewer decision are still pending. No `.el` exclusion was added.

## 6. Product RTL dead-code audit

The 21 RTL files in the product compile manifest were compared with the actual DUT hierarchy in the current URG report. A source file missing from this Generic/Centered-Cubic/EF2/AXI-Lite hierarchy is not thereby dead across other supported configurations. No source was deleted, and no denominator was reduced.

| RTL source | Current hierarchy disposition | Decision |
|---|---|---|
| `rtl/axis/dsm_async_fifo.sv` | Elaborated Generic FIFO | KEEP; required product FIFO. |
| `rtl/axis/dsm_axis14_to_core8_cdc.sv` | Elaborated | KEEP; active framing/gearbox path and defensive branches. |
| `rtl/axis/dsm_frame_power_ctrl.sv` | Not present in current DUT coverage hierarchy | CONFIGURATION_EXCLUDE for this product elaboration only; retain shared module pending supported-configuration audit. |
| `rtl/axis/dsm_reset_sync.sv` | Elaborated | KEEP; reset path. |
| `rtl/axis/dsm_xpm_async_fifo.sv` | Not elaborated; Generic selected | CONFIGURATION_EXCLUDE for this run only; retain the supported XPM backend. |
| `rtl/dpd/dpd_memory_poly.v` | Elaborated | KEEP; active one-tap DPD datapath. |
| `rtl/dpd/dpd_poly.v` | `dpd_sat_signed` is elaborated; scalar `dpd_poly` is not | KEEP; shared arithmetic helper is active and alternate DPD code is not proven removable. |
| `rtl/dpd/dpd_vector16_memory_poly.sv` | Elaborated | KEEP; active vector DPD path. |
| `rtl/dpd/dpd_vector_elastic_buffer.sv` | Not present in current DUT coverage hierarchy | CONFIGURATION_EXCLUDE for this elaboration only; retain pending cross-configuration audit. |
| `rtl/frontend/dsm_frame_gain_vector.sv` | Elaborated | KEEP; active frame gain path. |
| `rtl/gt/gt_tx_raw64_boundary.sv` | Elaborated | KEEP; active four-plane output boundary. |
| `rtl/gt/gt_tx_user_bridge.sv` | Elaborated | KEEP; active output bridge. |
| `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv` | Elaborated twice | KEEP; active interpolators and defensive tail logic. |
| `rtl/interp/dsm_interp_x2_polyphase_vector.sv` | Not elaborated; centered cubic selected | CONFIGURATION_EXCLUDE for this product only; retain alternate interpolation implementation. |
| `rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv` | Elaborated | KEEP; active register/mailbox logic and defensive decode. |
| `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv` | Elaborated | KEEP; active EF2 path. |
| `rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv` | Not selected by EF2 product | CONFIGURATION_EXCLUDE for this product only; retain non-EF2 variant. |
| `rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv` | Elaborated | KEEP; product top. |
| `rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv` | AXI-Lite wrapper is selected instead | CONFIGURATION_EXCLUDE for this product only; retain non-AXI-Lite top. |
| `rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv` | Elaborated | KEEP; active frontend. |
| `rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv` | Elaborated | KEEP; active four-plane wrapper. |

Machine-readable 21-file audit: [`thermo5_tx_r14_dead_code_audit.csv`](data/thermo5-r14/thermo5_tx_r14_dead_code_audit.csv). `CONFIGURATION_EXCLUDE` in that ledger means inactive in this one elaborated product configuration and retained in source; it is not a URG exclusion or permission to remove the file.

Formal proves the product EF2 `PAIR_LOOKAHEAD=0` and legal parameter guard inactive, with candidate-arm Covers uncoverable. This justifies classifying those arms as configuration-inactive for this product; it does not authorize source deletion. AXI-Lite guards, CDC defensive behavior, counter guards, and interpolator tail checks remain KEEP unless an exact, independently reviewed proof supports a waiver.

## 7. Formal and Assertion status

| Obligation | Round 14 result | Signoff disposition |
|---|---|---|
| AXI-Lite configuration default-branch candidate | PASS; 4 assertions proven, 0 assumptions, 0 black boxes; 3 non-vacuous checks | Waiver evidence only; exact mapping/reviewer pending. |
| DPD source-gap budget counter | PASS for the harness's maximum 2,072 accepted inputs per reset epoch; accept/change/stall/recovery Covers reached | Scoped bound only; not AXI outstanding-counter proof and not an unbounded operating-life contract. |
| EF2 product parameter guard / PAIR_LOOKAHEAD | PASS; product values proven; candidate-arm Covers uncoverable | Configuration evidence only; no source deletion or automatic exclusion. |
| Legal frame-tail metadata | PASS for two legal-context assertions and positive transfer Covers | Does not prove the production `q1_tail` assertions themselves. |
| Full-chain DPD Identity | FAIL aggregate gate: valid-latency property proven; payload and three saturation properties INCONCLUSIVE at depth 147; endpoint/recovery/stall Covers reached | OPEN; INCONCLUSIVE is not PROVEN. |
| AXI outstanding counter saturation/underflow | OPEN / INCONCLUSIVE in the prior dedicated proof; the current scoped `counter` job proves a different DPD gap counter | OPEN. |
| Production `q1_tail` at `u_interp_1`, `u_interp_2` | Legal-only URG: zero attempts for both; expected-negative suite intentionally triggers both | OPEN as legal properties; no waiver. |
| Legal assertion regression | 13 successful, zero failures; two product `q1_tail` uncovered, two UVM-library assertions without attempts | No unexpected legal assertion failure. |
| Expected-negative assertion regression | Three checker-confirmed expected failures: CDC underflow and the two interpolator tail assertions | Isolated from the legal regression. |

Formal summaries bind to source SHA `f22dad56f7cd56e94158cb86cdad04e3d11e489d`. The AXI-Lite focused proof and the broader scoped Formal jobs are stored under `data/thermo5-r14/`; the broader aggregate is marked FAIL because DPD Identity properties remain inconclusive.

## 8. Reproduction and evidence

Main product commands used the fixed Round 14 source and output under ignored `runs/thermo5_round14_253268f/`:

```bash
make -C dv/uvm/sim thermo5-centered-cubic-ef2-vcs-regression PYTHON=python3.12 \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 \
  THERMO5_STEP=5120 \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_round14_253268f/generic"

make -C dv/uvm/sim thermo5-axil-product-vcs-regression PYTHON=python3.12 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_round14_253268f/axil_product"

python3.12 dv/uvm/sim/run_thermo5_system_random.py \
  --out runs/thermo5_round14_253268f/system_random_round13_seedset \
  --random-seeds 100 --long-seeds 10 --seed-base 1044100

python3.12 dv/uvm/sim/run_thermo5_randomized_control.py \
  --out runs/thermo5_round14_253268f/randomized_control_round13_schedule \
  --seed-base 1045100 --reset-cases 24 --commit-cases 24 \
  --schedule-seed 20261103

python3.12 dv/uvm/formal/run_thermo5_axil_cfg_coverage.py \
  --out-dir runs/thermo5_round14_253268f/formal_axil_cfg

python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs counter identity frame_tail_legal_metadata ef2_product_params \
  --out-dir runs/thermo5_round14_253268f/formal_scoped
```

The complete coverage input paths and per-VDB tree hashes are in [`thermo5_tx_r14_vdb_manifest.json`](data/thermo5-r14/thermo5_tx_r14_vdb_manifest.json), SHA-256 `436edee82b59d3fd6bf2d82ba2f529c87623910f14109216c79075c259538443`. Raw/Adjusted URG command manifests and log hashes are in [`thermo5_tx_r14_code_coverage_report_manifest.json`](data/thermo5-r14/thermo5_tx_r14_code_coverage_report_manifest.json). The machine-readable decision/evidence index is [`thermo5_tx_r14_signoff_manifest.json`](data/thermo5-r14/thermo5_tx_r14_signoff_manifest.json).

## 9. Final decision and remaining work

- **Functional Coverage:** PASS for 218/218 legally applicable bins; all 16 groups are covered after expected-negative-only bins are reported separately. Both negative-only bins are hit by the isolated negative set.
- **Linux functional regression/checkers:** PASS for the tested Generic/AXI-Lite matrix, 110 system-random cases, 60 DPD/gain/profile cases, 48 randomized Reset/COMMIT cases, directed boundary/reset/STOP tests, 64 Python reference tests, and 6/6 direct SV scoreboard mutations.
- **DUT Code Coverage:** OPEN (`RAW_100_OPEN`). Raw and official Adjusted are identical; 113 Branch, 192 Condition, 458 Line, and 13,192 Toggle bins remain uncovered. No independent Waiver approval exists.
- **Formal / Assertions:** OPEN. DPD full-chain identity and AXI outstanding-counter guards are not proven; two legal `q1_tail` properties have no legal attempts.
- **Linux DV final signoff:** NOT SIGNED OFF until the remaining exact code bins, reviewed exclusions, and required Formal/Assertion obligations close or receive an approved alternative acceptance policy.
- **FPGA / Physical:** NOT RUN. Real XPM, GT Wizard, integrated CDC/RDC, Vivado timing/PPA, board/RF, and physical QAM256 validation are separate work.

No unsupported waiver, RTL deletion, denominator edit, or algorithm substitution was used to improve a reported score.

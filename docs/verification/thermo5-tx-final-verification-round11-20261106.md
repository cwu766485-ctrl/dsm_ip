# Thermo5 TX Final Verification Convergence — Round 11

- Date: 2026-11-06 (SGT)
- Repository: `cwu766485-ctrl/dsm_ip`
- Review branch: `codex/thermo5-final-verification-round11`
- Local simulation source commit: `d823654cba715e9093bb8cc08e6d819e8ae1365f`
- Published code commit: `cd9532a7d805f2f60250f2ef687a15711a9c485e` (same tree `244b49c4daf1561806d7f02d6dfb560227757571`)
- Published parent: `330815a5db5a26af50de81aff0c304dea714ead3`

## Decision

Round 11 closes the seven named Functional Coverage crosses and refreshes the
Linux regression and Raw/Adjusted coverage package. It does **not** close
Digital Verification signoff. Raw DUT code coverage remains below 100%, all
371 waiver candidates remain pending, two legal `q1_tail` assertions have no
attempts, and outstanding-counter Formal remains inconclusive. No waiver or
coverage exclusion was approved or applied. No product RTL, frozen TX
algorithm, RX, or AI-DPD source was changed.

## Baseline and PR review

The published Round 11 code commit is a direct child of PR #40 HEAD. Its Git tree exactly matches the local source tree used by the recorded VCS runs (`244b49c4daf1561806d7f02d6dfb560227757571`); the local simulation commit is `d823654cba715e9093bb8cc08e6d819e8ae1365f`.
The review branch was clean when this task began; the pre-existing stash was
left untouched. PR #40 is still Draft/Open, unmerged, and reported mergeable by
GitHub. Its final diff contains 266 paths. A path-set comparison of PRs #27–#39
found 255 unique changed paths, all present in PR #40's final diff. The other
11 paths are additional integration review material. This confirms path
retention; it does not merge or close PRs #27–#39.

The frozen product configuration is Centered-Cubic x2+x2, EF2 ORDER=2,
STEP=5120, 20-bit state, DPD_MAX_TAPS=1 with Identity reset image, AXI-Lite,
and Generic FIFO. The VCS top is `thermo5_sku_uvm_tb`; DUT-only coverage uses
`dv/uvm/sim/thermo5_product_dut_coverage.hier`.

The current 21-file Product RTL aggregate SHA-256 is
`c627e02758be102e379e5eb464590189f354894dc84fc967c8e408554be38fe8`. All 21
files match the retained source manifest. The 96-file VCS compile-input
content SHA-256 is
`08e62a87420ee9a9acce7724d2cca3c909f8cb7265dac22563522ac97a74b300`; each
listed compile input was byte-compared with the current source. Defines were:

```text
THERMO5_AXIL_CONTROL
THERMO5_CENTERED_CUBIC
THERMO5_TIDSM_ORDER=2
THERMO5_STEP=5120
THERMO5_DPD_MAX_TAPS=1
```

Tool versions: Python 3.12.13, VCS V-2023.12-SP1_Full64, URG V-2023.12-SP1,
and VC Formal V-2023.12-SP2_Full64.

The refreshed Raw/Adjusted package contains 449 test VDBs and one current
design VDB. It includes 231 retained test VDBs whose full compile-input
fingerprint matches the current 96-file source fingerprint, plus 218 test
VDBs from the fresh Round 11 System Random, DPD matrix, and Reset/COMMIT runs.
The VDB inventory and per-database tree hashes are in
[`thermo5-tx-vdb-merge-inventory.csv`](data/thermo5-r11/thermo5-tx-vdb-merge-inventory.csv).
The complete input manifest is in
[`thermo5-tx-vdb-input-manifest.json`](data/thermo5-r11/thermo5-tx-vdb-input-manifest.json).

The prior 195-path / 193-test discrepancy is resolved: 193 paths correspond
to URG test entries, and the remaining two are build `simv.vdb` design
databases, which URG correctly does not list as tests. All 193 test identifiers
are accounted for; see
[`thermo5-r11-round10-vdb-accounting.csv`](data/thermo5-r11-round10-vdb-accounting.csv).

## Regression matrix

All listed commands completed successfully. Full logs and VDB/URG output are
under the ignored `runs/thermo5_tx_final_verification_r11/` directory. Their
SHA-256 values are recorded in the JSON evidence file. Expected-negative
assertion failures are accounted separately from legal-test failures.

| Suite | Result | Coverage / scope |
|---|---|---|
| Generic FIFO core VCS | PASS | Seven directed scenarios: bit-true stream, bubble/backpressure, FIFO boundary/empty, reset/tail reset, reset sweep, and expected-negative frame handling |
| AXI-Lite product VCS | PASS | Register/configuration, COMMIT, DPD coefficient transport, STOP/drain, packet-cross semantics, and separate negative tests |
| System Random VCS | PASS | 100 randomized seeds plus 10 long-stream seeds; 110/110 completed |
| DPD × Gain × Input Profile | PASS | 60/60 legal tuples, including non-Identity one-tap coefficient images |
| Randomized Reset/COMMIT | PASS | 24 Reset and 24 COMMIT trials; seed base 1044100, schedule seed 20261106 |
| Python reference unit tests | PASS | 64/64 |

Reproduction commands (all outputs remain under `runs/`):

```bash
make -C dv/uvm/sim thermo5-vcs-regression PYTHON=python3.12 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_final_verification_r11/clean_generic" \
  THERMO5_VECTORS="$PWD/runs/thermo5_tx_final_verification_r11/baseline/vectors/product" \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_FIFO_IMPL=generic

make -C dv/uvm/sim thermo5-axil-product-vcs-regression PYTHON=python3.12 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_final_verification_r11/clean_axil" \
  THERMO5_VECTORS="$PWD/runs/thermo5_tx_final_verification_r11/baseline/vectors/product" \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_FIFO_IMPL=generic

python3.12 dv/uvm/sim/run_thermo5_system_random.py \
  --out "$PWD/runs/thermo5_tx_final_verification_r11/clean_system_random" \
  --random-seeds 100 --long-seeds 10 --seed-base 721100

python3.12 dv/uvm/sim/run_thermo5_product_dpd_matrix.py \
  --out "$PWD/runs/thermo5_tx_final_verification_r11/clean_dpd_matrix" \
  --seed-base 1043100

python3.12 dv/uvm/sim/run_thermo5_randomized_control.py \
  --out "$PWD/runs/thermo5_tx_final_verification_r11/clean_randomized_control" \
  --seed-base 1044100 --reset-cases 24 --commit-cases 24 \
  --schedule-seed 20261106

PYTHONPATH=dv/uvm/refmodel/python:matlab PYTHONDONTWRITEBYTECODE=1 \
  python3.12 -m unittest discover -s dv/uvm/refmodel/python/tests -v
```

## Seven Functional Coverage crosses

Each cross is sampled from DUT-observed events. Packet-scoped crosses key state
by `(Reset Epoch, Packet ID)`; a Reset clears all prior-epoch packet state.
STOP/TLAST/Drain only samples after observing the strict event sequence
`STOP < accepted TLAST < Drain`. The cross-packet negative test places the
source gap in one packet and FIFO-full/PA-stall in another and confirms no
false hit. The second negative test places TLAST before STOP and confirms it
does not increment the STOP-before-TLAST cross. Both tests include packet
integrity checks; the legal cross hits are not inferred from covergroup
percentages alone.

| Cross | Covered / expected bins | Result |
|---|---:|---|
| DPD × Gain × Input Profile | 60/60 | PASS |
| COMMIT × Frame Boundary × PA Stall | 2/2 | PASS |
| Reset × Pending COMMIT | 4/4 | PASS |
| STATUS × COMMIT × STOP | 1/1 | PASS |
| Source Gap × PA Stall × FIFO Full | 1/1 | PASS |
| RUN × Prefill × Source Gap | 1/1 | PASS |
| STOP × TLAST × Drain | 1/1 | PASS |

The AXI-Lite directed run logged `CROSS_PACKET_NEGATIVE_PASS`; the
TLAST-before-STOP test checked that the STOP/TLAST/Drain hit count stayed zero.
The positive STOP/restart test checked two same-packet ordered records.

## Unified Scoreboard audit

The Unified Scoreboard checks event IDs and Reset Epochs, AXIS/CDC sequence
indices, CDC sample/frame metadata, all 32 EF2 lanes against the independent
integer sidecar, and configuration causality through COMMIT request, Pending,
frame-boundary Apply, core ACK, and STATUS DONE. Sidecar accesses are
bounds-checked. Queue-drain checks run at the random-packet, boundary-phase,
and STOP/restart checkpoints. The separate PA checker retains four-plane
bit-true comparisons. Reset-truncated trace prefixes are checked by the
independent Python trace model.

The Python trace-oracle mutation suite passed for missing, duplicate and
reordered PA transactions, wrong source Frame ID, stage divergence, corrupted
reset-truncated prefix, and Apply-before-Pending order. **Direct fault
injection into the SystemVerilog Unified Scoreboard itself was not run.** That
remains OPEN; the Python mutation results are not reported as SV mutation
coverage.

## Functional and DUT code coverage

The current Raw and Adjusted URG reports were generated from the same 449 test
VDBs, same design VDB, and the same manifest SHA-256
`2dbdad75ac0a877381a30e46ece68ddef49cbdff1422943919a5585cc6faeb62`. The
post-run manifest SHA is identical. No Exclusion file entries were applied,
and no denominator was changed; therefore Adjusted equals Raw.

| DUT metric | Raw | Adjusted |
|---|---:|---:|
| Branch | 524/637 (82.26%) | 524/637 (82.26%) |
| Condition | 657/849 (77.39%) | 657/849 (77.39%) |
| Line | 3338/3796 (87.93%) | 3338/3796 (87.93%) |
| Toggle | 91112/104480 (87.21%) | 91112/104480 (87.21%) |
| FSM states | 13/13 (100%) | 13/13 (100%) |
| FSM transitions | 18/22 (81.82%) | 18/22 (81.82%) |

The gate remains `RAW_100_OPEN`. The Raw root-cause package contains 14,135
uncovered DUT code records in 416 grouped tasks: 113 Branch, 192 Condition,
458 Line, 13,368 Toggle, and 4 FSM transition records. All tasks remain OPEN;
their root-cause buckets are review hypotheses, not reachability decisions.
The exact records and grouped closure tasks are retained in
[`thermo5-tx-coverage-open-bins.csv.gz`](data/thermo5-r11/thermo5-tx-coverage-open-bins.csv.gz)
and
[`thermo5-tx-coverage-root-cause-tasks.csv`](data/thermo5-r11/thermo5-tx-coverage-root-cause-tasks.csv).

Functional Coverage has 16/16 groups at 100%. The audited scoreable Raw
functional bins are 440/440; 436/436 are legally applicable and covered. Four
negative-only semantic rows are covered by their dedicated tests. The 24 rows
marked unscoreable by URG remain documented separately; they are not manual
waivers or code-coverage exclusions.

Waiver status: 371 PENDING, 0 APPROVED, 0 REJECTED, 0 active exclusions. No
independent reviewer approval was available, so no waiver was applied.

## Assertion audit

Legal-only URG (447 VDBs): 13 DUT assertion successes, 0 failures, 2 uncovered,
and 2 without attempts. The two without-attempt properties are the centered
interpolator frame-tail assertion at
`rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310`, elaborated as:

- `thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1.unnamed$$_1`
- `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1`

They assert `q1_tail` under the `q_count == 2 && q0_end && !q1_start`
antecedent. The existing frame-marker Formal is scoped to a composed
two-interpolator model without the intervening elastic FIFOs and DPD pipeline;
the Raw assertion rows remain open and unwaived.

Expected-negative URG (2 VDBs) records exactly three RTL assertion failures,
each caught by the test's expected-failure/reset-recovery checker:

- `thermo5_sku_uvm_tb.dut.u_cdc.unnamed$$_1` at
  `rtl/axis/dsm_axis14_to_core8_cdc.sv:262` (one failure).
- The two `q1_tail` interpolator instances listed above (one failure each).

These expected-negative outcomes are reported separately. Legal tests had no
unexpected assertion failures.

## Formal status

| Obligation | Result | Disposition |
|---|---|---|
| AXI-Lite config leaf | PASS: 4/4 assertions proved, zero assumptions, zero black boxes; legal transaction Cover reached | Focused config proof only; not a full COMMIT lifecycle proof |
| Outstanding counter saturation/underflow | INCONCLUSIVE: all 5 assertions and both target guard Covers inconclusive; activity Covers reached | OPEN; neither guard is waived |
| `q1_tail` frame-tail | PASS_WITH_RAW_OPEN in retained scoped proof | Two-stage metadata model omits elastic FIFOs/DPD; legal assertion bins remain OPEN |
| DPD Identity | PASS_SCOPED_LEAF_ONLY in retained proof | Leaf datapath under stall only; full AXI shadow/COMMIT/mailbox/CDC/pending/active composition remains OPEN |
| Full COMMIT/Pending/Active lifecycle | OPEN | Simulation causality checker exists; no full-chain Formal proof |

The two Round 11 Formal manifests record a dirty worktree from when the
unrelated UVM changes were present. Every declared RTL/Formal source file hash
in those manifests was byte-checked against the current tree. These are
retained source-matched Formal results, not new Round 11 proof runs. No
INCONCLUSIVE result was promoted to PASS.

## Requirement traceability and remaining limits

| Task | Status | Evidence / remaining work |
|---|---|---|
| T1 Source and regression baseline | PASS with content-bound VDBs | PR path reconciliation, clean current-source runs, exact source fingerprints, 195/193 VDB accounting; VDBs remain in ignored `runs/` |
| T2 Functional Coverage semantics | PASS for the seven named crosses | Packet/Epoch scoping, ordered STOP/TLAST/Drain, two negative semantic checks, all named bins hit |
| T3 Unified Scoreboard | PARTIAL | Online stage/epoch/config checks and Python trace mutations pass; direct SV mutation injection remains OPEN |
| T4 Formal closure | OPEN | Counter guards inconclusive; DPD full-chain and COMMIT full-lifecycle proof remain open; scoped `q1_tail` proof does not disposition Raw bins |
| T5 Waiver audit | OPEN | 371 candidates pending independent review; zero approvals/exclusions |
| T6 Final Linux signoff | OPEN | `RAW_100_OPEN`; direct SV mutations, remaining code roots, full-chain Formal and final signoff traceability remain open |

Real XPM FIFO, GT Wizard, Vivado FPGA timing/PPA/power, and physical RF/QAM256
BER validation were not run. This report is Linux digital-verification
evidence only, not FPGA or physical signoff. Full logs and generated VDB/URG
trees remain local under ignored `runs/`; the machine-readable evidence index
records their paths and SHA-256 values in
[`thermo5-tx-final-verification-round11-20261106.json`](data/thermo5-r11/thermo5-tx-final-verification-round11-20261106.json).

# Thermo5 TX Linux DV Closure — Round 12

Date: 2026-11-06
Product evidence source commit: `a03c2ddf2b997a3aff7ea54acdd2f6e2f6cdcce0`
Integrated `thermo5` base: `73577475230a9c4e51273ac7071437f0a7373d48`
Branch: `codex/thermo5-linux-dv-signoff-closure`

## Decision

- **Gate 1 — Functional requirements and legal functional coverage: PASS.** The
  230 legal product VDBs pass, all 436 legal applicable functional bins and
  all 16 covergroups are covered, the seven named system crosses pass, the
  expected-negative cross tests do not create false hits, all expected queues
  drain, and all six direct SystemVerilog scoreboard mutations are detected.
- **Gate 2 — DUT code coverage closure: OPEN.** Raw and adjusted coverage are
  identical; the fail-closed gate reports `RAW_100_OPEN`.
- **Gate 3 — Waiver approval: OPEN.** There are 369 pending candidates, zero
  approved waivers, zero rejected waivers and zero active exclusions. The
  adjusted report therefore correctly equals Raw.
- **Gate 4 — Formal/assertion closure: OPEN.** The product outstanding-counter
  proof remains INCONCLUSIVE. Two legal `q1_tail` assertion instances have no
  attempts. DPD arithmetic is reported only at its proved local scope; it does
  not establish full-chain configuration/CDC equivalence. The complete
  COMMIT-to-STATUS lifecycle invariant remains open.
- **Overall:** Functional DV criteria in Gate 1 pass. **Full Linux DV Signoff is
  not granted** while code coverage, independent waiver review and the listed
  assertion/Formal obligations remain open. FPGA/physical signoff is separate
  and was not run.

## Source, product and tools

The latest integrated `thermo5` base is `73577475230a9c4e51273ac7071437f0a7373d48`.
The tested closure branch is three verification-only commits ahead of that
base. Its 21 product RTL file hashes match the integrated base exactly; the
source manifest binds the additional UVM/test changes used for this run. This
report does not claim that the three verification commits have already been
merged.

Product configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120,
20-bit state; DPD_MAX_TAPS=1 with Identity reset image; AXI-Lite; Generic FIFO.
No product algorithm, RX or AI-DPD change was made in this closure round.

| Item | Bound value |
|---|---|
| Source SHA | `a03c2ddf2b997a3aff7ea54acdd2f6e2f6cdcce0` |
| Product compile fingerprint | `9f5e2d49d42795bb4b38f62b909cc690dcb726f1217efcdc4cd50029a0d4184a` |
| VCS | V-2023.12-SP1_Full64 |
| URG | V-2023.12-SP1 |
| VC Formal | V-2023.12-SP2_Full64 |
| Python | 3.12.13 |
| Platform | WSL2, Rocky Linux 8.10 |

The product VDB manifest records 232 test VDBs: 230 legal and two expected
negative. They are bound to the product source SHA and defines. The VDB
manifest, source manifest, compile manifest, dual-URG manifest, per-test log
hashes, Raw/Adjusted summaries and gate result are in
`docs/verification/data/thermo5-r12/`. VDBs and full tool logs remain under the
ignored `runs/thermo5_linux_dv_signoff_gate1/source_a03c2/` tree.

## Gate 1 — Functional signoff evidence

### Regression matrix

| Product campaign | Result | Cases |
|---|---:|---:|
| System random | PASS | 110/110 |
| DPD × Gain × Input Profile | PASS | 60/60 |
| Randomized Reset | PASS | 24/24 |
| Randomized COMMIT | PASS | 24/24 |
| AXI-Lite directed | PASS | 7 legal + 2 expected-negative |
| AXI-Lite lifecycle | PASS | 5/5 |
| Python reference tests | PASS | 64/64 |
| Expected queues after product tests | PASS | 232/232 empty |

Generic FIFO core-only directed tests and the standalone parameter-guard
negative elaboration are retained as separate configurations, not merged into
the AXI-Lite product coverage denominator. The corrected EF2 corner run uses
`CORE_WORDS=2072`, seed `271031`; the earlier seed `271030` omitted this
precondition and is excluded from the product VDB set.

### Seven system crosses

| Cross | Coverage | Semantic check |
|---|---:|---|
| DPD × Gain × Input Profile | 60/60 | Full legal tuple matrix |
| COMMIT × Frame Boundary × PA Stall | 2/2 | Apply epoch checked at the boundary |
| Source Gap × FIFO Full × PA Stall | 1/1 | Events associated by Epoch and Packet ID |
| STOP × TLAST × Drain | 1/1 | Strict STOP < accepted TLAST < Drain |
| Reset × Pending COMMIT | 4/4 | Reset epoch clears old pending/config state |
| RUN × Prefill × Source Gap | 1/1 | Events associated by Epoch and Packet ID |
| STATUS × COMMIT × STOP | 1/1 | Status prediction is independent of DUT Core STATUS |

The cross-negative regression also verifies that Source Gap in one Packet
cannot pair with FIFO Full/PA Stall in another Packet, and that TLAST before
STOP cannot hit the STOP-before-TLAST bin. Both negative semantics passed.

### Functional bins and direct checker mutations

The product semantic ledger covers **436/436 legal applicable bins**; all 16
groups are 100%:

| Group | Bins | Group | Bins |
|---|---:|---|---:|
| `commit_boundary_stall_cg` | 12/12 | `core_cg` | 14/14 |
| `ef2_cg` | 68/68 | `plane_atomic_cg` | 16/16 |
| `random_cfg_cg` | 144/144 | `read_cg` | 22/22 |
| `reset_cg` | 4/4 | `reset_pending_cg` | 18/18 |
| `run_prefill_gap_cg` | 8/8 | `source_cg` | 38/38 |
| `source_gap_pa_fifo_cg` | 8/8 | `status_commit_stop_cg` | 8/8 |
| `stop_restart_cg` | 12/12 | `stop_tlast_drain_cg` | 8/8 |
| `transaction_event_cg` | 20/20 | `write_cg` | 36/36 |

The direct SV Unified Scoreboard mutation test passed six of six: lost CDC
transaction, duplicate source transaction, reordered transactions, wrong
Frame ID, Apply without prior COMMIT, and EF2 data corruption. Each mutation
produced its expected checker report; the isolated negative test ended with
zero uncaught UVM_ERROR/FATAL. Log SHA-256:
`e032fe3c2a64db1b9240396f15f9b486b6381465ef8469527461f935f7116294`.

Legal-only assertion regression has zero failures: 13 successful properties,
two uncovered properties and two properties without attempts. Both are the
`q1_tail` assertion in the stage-1 and stage-2 instances of
`dsm_interp_x2_centered_cubic_vector.sv`; this is an assertion-closure risk,
not a detected legal functional failure. The two expected-negative tests are
reported separately and have three checker-confirmed assertion failures.

## Gate 2 — Raw and adjusted DUT code coverage

The same 232 test VDBs plus the matching product DUT VDB were used to generate
Raw and Adjusted URG from the same command/input list. The generated `.el` has
zero active directives, so Adjusted equals Raw.

| Metric | Raw covered / total | Raw | Adjusted covered / total | Adjusted |
|---|---:|---:|---:|---:|
| Branch | 524/637 | 82.2606% | 524/637 | 82.2606% |
| Condition | 657/849 | 77.3852% | 657/849 | 77.3852% |
| Line | 3338/3796 | 87.9347% | 3338/3796 | 87.9347% |
| Toggle | 91288/104480 | 87.3737% | 91288/104480 | 87.3737% |
| FSM states | 13/13 | 100% | 13/13 | 100% |
| FSM transitions | 22/22 | 100% | 22/22 | 100% |

There are 13,955 exact uncovered code records: 113 Branch, 192 Condition,
458 Line and 13,192 Toggle. The current root-cause reducer groups them into
415 tasks: 44 Branch, 93 Condition, 110 Line and 168 Toggle; every task remains
OPEN pending a real hit or an accepted exact proof. The plan's historical
count is 416 tasks. The one-task discrepancy has not been explained and is
kept visible rather than assumed to be closed. The URG aggregate score is
86.94%; it does not replace the individual metric denominators.

## Gate 3 — Waiver audit

Two of the previous 371 candidates are now covered in the fresh Raw URG and
were archived as `RESOLVED_BY_RAW_HIT`, not excluded:

- `W-75530ed17d5b396a4e9b`: DPD config line 142, exact product instance;
- `W-d7cb262894a5aae016b6`: DPD config branch/case line 135, exact product instance.

The remaining 369 candidates are all **PENDING**: 361 categorized as
configuration-unreachable candidates, four as Formal-unreachable candidates,
and four unresolved because their Formal source context is stale. These
categories are audit findings, not approvals. There is no independent
reviewer approval recorded; therefore approved = 0, rejected = 0, active
Exclusions = 0. For every configuration candidate, its source context was
checked against the exact product compile manifest. The zero-directive `.el`
was generated by the pipeline and Raw/Adjusted URG was rerun over the same
ordered VDB list after binding the current waiver audit. The gate result is
`RAW_100_OPEN`.

The exact candidate ledger, prior Raw-hit archive, audit, pipeline output and
generated `.el` are kept in `docs/verification/data/thermo5-r12/`.

## Gate 4 — Formal and assertion status

| Obligation | Result | Scope / next action |
|---|---|---|
| DPD input counter budget | PASS, scoped | Three assertions proven; four activity Covers reached; 2/2 non-vacuous goals. This is not the AXI-Lite outstanding guard proof. |
| AXI-Lite outstanding saturation / underflow guards | INCONCLUSIVE | Fresh product-bound run: all five assertions and both exact guard Covers inconclusive at tool effort limit. Legal source bubbles and arbitrary per-plane PA readiness are retained; no gap/stall bound is assumed. Targets stay OPEN. |
| DPD Identity arithmetic with stalls | PASS, scoped | 41 compositional lemmas, four composed assertions and four activity Covers pass for the one-tap arithmetic/latency block. It does not include the product config mailbox, CDC or top-level commit lifecycle. |
| COMMIT → Pending → Apply → ACK → DONE | OPEN | Existing focused register properties do not prove the full product lifecycle ordering. |
| `q1_tail` preconditions / full data chain | OPEN | Two legal instances have no assertion attempts; scoped frame-tail evidence omits intervening elastic FIFO/complete DPD/config path and cannot close them. |
| Remaining FSM transitions | PASS for sampled Raw model | All 22 transitions are covered in product URG; this does not close the other uncovered code metrics. |

Formal INCONCLUSIVE is not converted to a waiver or PASS. Formal source,
configuration, assumption and non-vacuity details are recorded in the
Round 12 JSON evidence and the ignored run directory.

## Reproduction commands and evidence

The product campaign summaries preserve full make/compile arguments, every
seed, test ID, VDB tree digest, UVM/Oracle log digest and expected-queue state.
Representative commands:

```bash
make -C dv/uvm/sim thermo5-vcs THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_COVERAGE=1 \
  THERMO5_COV_HIER="$PWD/dv/uvm/sim/thermo5_product_dut_coverage.hier" \
  THERMO5_VECTORS="$PWD/runs/uvm_thermo5_i2_d1/vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_linux_dv_signoff_gate1/source_a03c2/replay"

python3.12 tools/hw/thermo5_tx_product_compile_manifest.py \
  --compile-log runs/thermo5_linux_dv_signoff_gate1/source_a03c2/dut_only_axil/compile.log \
  --source-manifest docs/verification/data/thermo5-r12/thermo5-tx-product-source-manifest.json \
  --product-filelist dv/uvm/sim/thermo5_sku_filelist.f \
  --coverage-hierarchy dv/uvm/sim/thermo5_product_dut_coverage.hier \
  --output docs/verification/data/thermo5-r12/thermo5-tx-product-compile-manifest.json

python3.12 -m unittest tools.hw.tests.test_thermo5_tx_waiver_candidate_audit \
  tools.hw.tests.test_thermo5_tx_coverage_gate

python3.12 tools/hw/thermo5_tx_waiver_candidate_audit.py \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --raw-gap-ledger docs/verification/data/thermo5-r12/thermo5-tx-coverage-open-bins.csv.gz \
  --compile-manifest docs/verification/data/thermo5-r12/thermo5-tx-product-compile-manifest.json \
  --report-manifest docs/verification/data/thermo5-r12/thermo5-tx-waiver-candidate-input-manifest.json \
  --vdb-manifest docs/verification/data/thermo5-r12/thermo5-tx-vdb-manifest.json \
  --formal-review docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-formal-review.json \
  --output docs/verification/data/thermo5-r12/thermo5-tx-waiver-candidate-audit.json \
  --snapshot-dir docs/verification/data/thermo5-r12/formal-snapshots

python3.12 tools/hw/thermo5_tx_waiver_pipeline.py \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --gap-ledger docs/verification/data/thermo5-r12/thermo5-tx-coverage-open-bins.csv.gz \
  --compile-manifest docs/verification/data/thermo5-r12/thermo5-tx-product-compile-manifest.json \
  --el-output docs/verification/data/thermo5-r12/thermo5-tx-approved.el \
  --audit-output docs/verification/data/thermo5-r12/thermo5-tx-waiver-pipeline-audit.json

PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_axil_outstanding_fpv.py \
  --out-dir runs/thermo5_linux_dv_signoff_gate1/source_a03c2/formal_round12_axil_outstanding \
  --timeout 900
```

The dual-URG manifest contains the exact Raw and Adjusted commands and all 233
VDB paths, including the design VDB. Key machine-readable evidence:

The final same-input Raw/Adjusted rerun used the 232 test VDBs from that
manifest and the matching design VDB. Its URG reports and wrapper transcript
are preserved under the ignored directory
`runs/thermo5_linux_dv_signoff_gate1/source_a03c2/final_waiver_rebind_20261106_final/`;
the three log SHA-256 values are indexed in the Round 12 closure JSON.

- `docs/verification/data/thermo5-r12/thermo5-tx-product-source-manifest.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-product-compile-manifest.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-vdb-manifest.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-waiver-candidate-input-manifest.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-raw-adjusted-report-manifest.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-coverage-open-bins.csv.gz`
- `docs/verification/data/thermo5-r12/thermo5-tx-coverage-root-cause-tasks.csv`
- `docs/verification/data/thermo5-r12/thermo5-tx-coverage-gate-result.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-waiver-candidate-audit.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-waiver-pipeline-audit.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-dpd-identity-formal.json`
- `docs/verification/data/thermo5-r12/thermo5-tx-linux-final-closure-round12-20261106.json`

Full VCS/URG/VC Formal logs and VDB payloads are not committed; their paths
and hashes are recorded in the manifests. The repository's final evidence
commit is reported by Git metadata; it does not change the tested product
source SHA above.

## Not covered by Linux signoff

Real XPM FIFO behavior, GT Wizard/IP simulation, integrated CDC/RDC signoff,
Vivado synthesis/routed timing/PPA/power, board-level tests and physical RF or
QAM256 BER were not run. Do not infer FPGA, board or tapeout readiness from
these Linux results.

# Thermo5 TX Coverage Closure — Linux Signoff Snapshot

**Disposition:** `LINUX_CLOSURE_OPEN; RAW_100_OPEN`

**Audited product source SHA:** `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b`

**Product configuration:** Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120,
20-bit state; 32 chronological lanes; `DPD_MAX_TAPS=1` identity; AXI-Lite
product parent and Generic FIFO model.

This report records the current Linux evidence without treating parameter
proofs as simulator coverage hits. The root-cause ledger and per-bin detail are
in [`thermo5-tx-coverage-root-cause-closure.md`](thermo5-tx-coverage-root-cause-closure.md),
with machine-readable formal dispositions in
[`thermo5-tx-formal-bin-dispositions.json`](thermo5-tx-formal-bin-dispositions.json).

## Coverage results

| Metric | Raw | Adjusted | Disposition |
|---|---:|---:|---|
| Line | 3,190/3,796 (84.0358%) | 3,190/3,796 (84.0358%) | 606 uncovered bins |
| Condition | 583/846 (68.9125%) | 583/846 (68.9125%) | 263 uncovered bins |
| Branch | 440/637 (69.0738%) | 440/637 (69.0738%) | 197 uncovered bins |
| Toggle | 86,951/104,478 (83.2242%) | 86,951/104,478 (83.2242%) | 17,527 uncovered bins |
| FSM state | 13/13 (100%) | 13/13 (100%) | all product states hit |
| FSM transition | 22/22 (100%) | 22/22 (100%) | all product transitions hit |
| DUT assertion status | 13/15 attempted (86.67%) | unchanged | 2 uncovered and 2 without attempts are retained in the URG status table |

There are no approved waivers and no active URG exclusions. Adjusted therefore
equals Raw. Six exact bins have a Formal `PROVEN_UNREACHABLE` disposition; they
remain visible in the Raw URG denominators. The ledger contains 18,587 OPEN
records out of 18,593. No adjusted score is used to claim closure.

The complete product URG Group Report has 214 denominator-eligible bin records
across covergroup-type and monitor-instance views: 210 hit and four zero-hit.
The earlier 170/174 tally omitted 40 generated EF2 cross-bin records (20 in
each report view) and is superseded by this full report extraction. No URG
database, bin definition, or denominator was changed to make this correction.

| Group | URG Group score | Raw hits / scoreable bin records | Uncovered |
|---|---:|---:|---:|
| `core_cg` | 87.50% | 14/16 | 2 |
| `source_cg` | 96.30% | 38/40 | 2 |
| `stop_restart_cg` | 100.00% | 12/12 | 0 |
| `ef2_cg` | 100.00% | 68/68 | 0 |
| `plane_atomic_cg` | 100.00% | 16/16 | 0 |
| `read_cg` | 100.00% | 22/22 | 0 |
| `write_cg` | 100.00% | 36/36 | 0 |
| `reset_cg` | 100.00% | 4/4 | 0 |
| **Total** | URG aggregate is the unweighted mean of group scores (97.97%) | **210/214** | **4** |

The per-bin count is a direct tally of eligible rows in the full group HTML;
the URG group score uses its own group weighting, so the displayed source-group
score is not the simple 38/40 ratio. The complete CSV contains 226 rows: 214
scoreable records plus 12 records that the existing URG model already labels
Illegal/Excluded. Those model bins are reported separately and are not new
waivers or `.el` exclusions.

The four zero-hit scoreable records are two semantic negative-only bins
repeated in type and instance views:

| Functional bin | Positive product hits | Separate expected-negative hits | Legal positive applicability |
|---|---:|---:|---|
| `source_cg.cp_packet_quanta.malformed_early` | 0 | 1 | Not applicable to legal frames |
| `core_cg.cp_illegal.bad_frame` | 0 | 49 | Not applicable to legal frames |

All 210/210 legally applicable positive scoreable records are covered. The
negative test is separate from the positive product VDB and intentionally
observes the RTL protocol assertions; the four illegal-frame records remain in
the Raw denominator. Neither this audit nor the signed functional score applies
waivers. [Complete group/bin detail](data/thermo5-tx-coverage-root-cause/thermo5-tx-functional-bin-detail.csv)
preserves both URG report views, every coverpoint and cross bin, counts,
existing URG model status, and the source-page SHA. The [negative-bin audit](data/thermo5-tx-coverage-root-cause/thermo5-tx-functional-bin-audit.csv)
retains exact semantic IDs and separate negative-test hits.

## Formal and mutation evidence

| Scope | Result | Limits |
|---|---|---|
| Centered interpolator product parameters | 6/6 assertions proven; 5/9 Covers hit, 4/9 uncoverable; 1 valid source-stability assumption is non-vacuous | Single-entry pop/push is formally reachable in both stages but still missed by targeted product UVM |
| AXI-Lite config defaults, `MAX_TAPS=1` | 5/5 assertions proven; legal coefficient read hit; three exact path Covers uncoverable; zero environment assumptions, setup violations, and black boxes | Closes only the three Bin IDs listed in the disposition JSON |
| EF2 arithmetic/state | 6/6 assertions proven; 3/3 Covers hit; zero setup violations and black boxes | Does not increase URG hits |
| Product EF2 parameter guards | 2/2 assertions proven; pair-look-ahead and invalid-parameter Covers uncoverable | Exact fixed-product elaboration only |
| DPD counter | bounded: 3/3 assertions and 4/4 Covers; unbounded: 35/35 bit-transition assertions and 4/4 Covers | The 2,072-acceptance bound is not a declared product lifetime contract; high-bit Toggle bins remain OPEN |
| Identity DPD arithmetic | direct: 5/18 proven, 13 inconclusive; staged auto-lemma: 1/13 proven, 12 inconclusive; Covers hit and no counterexample | `INCONCLUSIVE` is not a proof; DPD arithmetic/saturation remains OPEN |
| Checker mutation | `PASS_MUTATION_CAUGHT` | A one-bit PA0 oracle corruption raised UVM_FATAL at epoch 0 / word 0 / plane 0; VCS process exit alone is not the mutation oracle |

Exact bin dispositions, assertion/Cover names and source hashes are in the
disposition JSON. Additional run summaries are under `runs/`
(ignored, local evidence):
`thermo5_tx_final_formal_remaining_20261030/`,
`thermo5_tx_final_counter_bound_20261030/`, and
`thermo5_tx_final_interp_bin_dispositions_20261030/`. DPD Identity direct and
auto-lemma artifacts are under `thermo5_tx_dpd_identity_convergence_20261030/`
and `thermo5_tx_dpd_identity_auto_lemmas_20261030/`. The Formal tool was VC
Formal V-2023.12-SP2. Setup reports show no clock,
loop, glitch, or multidriver errors and all relevant Formal models have zero
black boxes. AXI-Lite reset assumptions that were previously vacuous were
removed before the accepted run.

## Verification disposition summary

| Verification item | Result | Exact interpretation |
|---|---|---|
| Existing positive product UVM campaign | `PASS_REUSED; NOT_RERUN` | The fixed-source Raw merge retains 29 product-scoped simulation VDBs plus the compile VDB. It is not a fresh regression from this closure branch. |
| Targeted single-entry interpolator pop/push tests | `FAIL_COVERAGE_REQUIREMENT; SOURCE_NOT_REPRODUCIBLE` | Seeds 716001 and 716002 completed the four-plane oracle but did not observe the required DUT event in either stage; both have an explicit UVM_FATAL and neither VDB was merged. Their named test source is absent from the tracked tree, so the attempt is diagnostic evidence only. |
| Expected-negative malformed-frame UVM | `PASS_NEGATIVE_CHECKER` | The separate test observes the expected protocol assertions and checker outcome; its VDB is not mixed into positive Raw. |
| Scoped Formal jobs | `PASS_FOR_SCOPED_PROPERTIES` | Exact assertion/Cover counts and assumptions are in the Formal table above; they do not count as URG hits. |
| Identity-DPD Formal | `OPEN_INCONCLUSIVE` | Direct 5/18 proven, 13 inconclusive; auto-lemma 1/13 proven, 12 inconclusive. No counterexample is not a proof. |
| Checker mutation | `PASS_MUTATION_CAUGHT` | One-bit PA0 oracle corruption was detected at epoch 0 / word 0 / plane 0. Other checker mutation classes remain untested. |

## Targeted stimulus and assertion status

The two targeted packetization runs attempted to hit
`q_count==1 && pop_head && push_input` with four contiguous frames and one
frame. Both runs completed the independent four-plane stream comparison, then
failed the explicit event-coverage requirement because neither interpolator
instance observed the event. They are failed diagnostic runs, not regression
PASS, and neither VDB was merged. Repeating random seeds is stopped until the
stimulus is re-root-caused. The run logs record the `simv` commands and UVM
fatal messages, but `dv/uvm/tests/thermo5/axil/thermo5_sku_axil_four_frame_coverage_test.svh`
is absent from the tracked source tree; the exact attempted test cannot be
rebuilt from this checkout. Its local log hashes and missing-source status are
recorded in the coverage evidence manifest. The module-level Formal witness at
depth 2 proves reachability but is not a product integration witness.

The separate illegal-frame assertion test has two expected assertion
failures, passes its UVM expected-negative checker, and is not merged into the
positive product coverage database. Product URG reports 13 DUT assertion
successes, 2 uncovered, and 2 without attempts; those statuses are preserved.

The observed 16-source-cycle pause while RUN remained active caused 54
underflow events across two 32-beat packets. All expected 112 output words
were present, but the continuous-stream contract checker failed. AXI-stream
currently declares no maximum legal source gap while the downstream GT path
cannot backpressure. This remains an interface/service-rate risk, not a
coverage waiver or an accepted passing environment assumption.

## Reproduction and tool limits

### Product source scope and Raw gate

The inherited run manifest hashes 89 local paths, including Formal-only
harnesses and integration files. The saved VCS transcript shows that the
product compile actually parsed 73 local HDL/UVM source files. The scoped
manifest hashes those sources plus the controlling filelist and coverage
hierarchy (75 entries total); all 75 match the captured run manifest and the
current checkout. The other 14 broad-manifest entries were not parsed by this
VCS compile and remain listed in the manifest for review.

The fail-closed zero-waiver Raw gate completed with `RAW_100_OPEN`, Raw equal
to Adjusted and no exclusions. Its ignored local output is
`runs/thermo5_tx_product_axil_reset_cov_20261030/coverage_gate_final_audit.json`
(SHA-256 `62f32d3c27baba959eb1302a3efc0875f8af4ea074d938664ded3e517501e6c2`).
The tracked scoped source manifest is
[`thermo5-tx-product-compile-manifest.json`](data/thermo5-tx-product-compile-manifest.json)
(SHA-256 `c1b4ec0219d5fbfe0d50c5a44b5332b06665cfd7521e8af6b1cdd115be07bc3c`);
the saved compile transcript SHA-256 is
`7475893ee8fc3cbba4d62b4916ec63f88ff69c9c3ef9b3e965c59fe3520b28eb`.
Fail-closed probes also passed: requiring closed coverage returns exit 2 with
`RAW_100_OPEN`; a nonempty waiver CSV, an active `.el` directive, or a changed
compiled-source hash is rejected. These checks demonstrate rejection behavior
only; they do not implement or validate a nonempty adjusted-URG flow.

```bash
python3.12 tools/hw/thermo5_tx_product_compile_manifest.py \
  --compile-log runs/thermo5_tx_product_axil_reset_cov_20261030/compile.log \
  --source-manifest runs/thermo5_tx_product_axil_reset_cov_20261030/source_manifest_after_current_sha.json \
  --product-filelist dv/uvm/sim/thermo5_sku_filelist.f \
  --coverage-hierarchy dv/uvm/sim/thermo5_tx_product_coverage.hier \
  --output docs/verification/data/thermo5-tx-product-compile-manifest.json
python3.12 tools/hw/thermo5_tx_coverage_gate.py \
  --raw-summary runs/thermo5_tx_product_axil_reset_cov_20261030/raw_code_coverage_after_source_gap_current_20261030/summary.json \
  --groups-html runs/thermo5_tx_product_axil_reset_cov_20261030/product_raw_after_source_gap_current_20261030/groups.html \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --el-file dv/uvm/sim/thermo5_tx_main.el \
  --source-manifest docs/verification/data/thermo5-tx-product-compile-manifest.json \
  --output runs/thermo5_tx_product_axil_reset_cov_20261030/coverage_gate_final_audit.json
```

Formal commands used:

```bash
export PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs frame_tail --out-dir runs/thermo5_tx_final_interp_bin_dispositions_20261030
python3.12 dv/uvm/formal/run_thermo5_axil_cfg_coverage.py \
  --out-dir runs/thermo5_tx_axil_cfg_coverage_harnessed_20261030
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs counter_unbounded ef2 ef2_product_params \
  --out-dir runs/thermo5_tx_final_formal_remaining_20261030
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs counter --out-dir runs/thermo5_tx_final_counter_bound_20261030
```

The product VCS/URG report was reused because no passing targeted product VDB
was added. A fresh VCS/URG attempt in this WSL environment was blocked before
simulation by the installed VCS location check: kernel
`6.6.87.2-microsoft-standard-WSL2` is rejected as unsupported. This is a
platform compatibility error, not a license checkout failure. Consequently,
the product Raw database was not regenerated. The Raw gate did run against the
existing product report and passed its audit checks while returning
`RAW_100_OPEN`. The adjusted-URG path for approved nonempty waivers is still
OPEN: the current gate accepts only an empty waiver ledger and comment-only
`.el`, and this environment could not validate a real URG exclusion template
or adjusted database. No synthetic or unreviewed exclusion was installed.

## Acceptance status and remaining work

- **Legal functional coverage:** 210/210 applicable scoreable records; negative-only bins reported separately. The complete report lists 214 scoreable records and 12 pre-existing URG model Illegal/Excluded records.
- **Reachable/applicable DUT code coverage:** not closed; 18,587 rows remain OPEN.
- **Raw 100% code coverage:** `RAW_100_OPEN`; not claimed.
- **Identity DPD Formal:** OPEN / inconclusive.
- **TX worst-case benchmark:** model-only evidence exists; product BER/BLER acceptance threshold is undefined, so product communication acceptance remains OPEN.
- **Checker mutation:** detected; expected-negative assertion run is separately classified.
- **Real XPM, GT Wizard, FPGA timing/PPA, routed signoff and physical QAM256 BER:** pending outside this Linux run.

No TX algorithm, RX, AI-DPD, or product DUT behavior was changed.

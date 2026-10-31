# Thermo5 TX Coverage Closure — Linux Signoff Snapshot


## Latest fixed-product Linux evidence — SHA `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea` (2026-10-31)

**Disposition:** `LINUX_CLOSURE_OPEN; RAW_100_OPEN`. Product RTL configuration: Centered-Cubic x2+x2; EF2 ORDER=2/STEP=5120; 20-bit state; 32 chronological lanes; DPD_MAX_TAPS=1 with identity reset image; AXI-Lite product frontend and Generic FIFO. No algorithm/RX/AI-DPD RTL changed.

### Results

| Area | Result | Acceptance |
|---|---|---|
| Legal Functional Coverage | 210/210 applicable positive records; 4 illegal-only zero-hit Raw records retained; 12 additional URG-model Illegal/Excluded records reported | Legal-positive goal PASS for this focused Raw |
| Raw DUT Branch | 520/637 = 81.6327%; 117 unhit | OPEN |
| Raw DUT Condition | 601/849 = 70.7892%; 248 unhit | OPEN |
| Raw DUT Line | 3,334/3,796 = 87.8293%; 462 unhit | OPEN |
| Raw DUT Toggle | 83,575/104,480 = 79.9914%; 20,905 unhit | OPEN |
| FSM | 13/13 states; 22/22 transitions | PASS for exercised frontend hierarchy |
| DUT Assertions | 13 success / 15 attempted; 2 uncovered; 2 without attempts | Partial |
| Waivers / `.el` exclusions | 0 / 0; Adjusted equals Raw | PASS, no adjustment applied |
| Fail-closed code gate | `RAW_100_OPEN` | OPEN; no 100% claim |
| Current-source gap ledger | 21,732 raw miss records grouped into 470 tasks; 354 `PROVEN_UNREACHABLE` retained in Raw (10 Formal + 344 exact static product elaboration); 21,378 OPEN across 374 tasks | OPEN |
| VCS/UVM | Fresh exact-profile compile and 13/13 focused positive tests PASS | Focused frontend scope only |
| Formal / reachability audit | Ten exact Formal records proven unreachable and retained in Raw; 344 EF2 PAIR_LOOKAHEAD bins separately proven disabled by exact product parameter elaboration; DPD payload equivalence INCONCLUSIVE at depth 252; tautological PAIR_LOOKAHEAD SVA rejected | Partial; remaining bins stay OPEN |
| Mutation | Baseline PASS; `late_gain` and `plane_swap` mutants detected by `[BITTRUE]` scoreboard | PASS for these two mutations only |
| TX source-gap test | 16-cycle gap has 54 underflows; checker fails although 112 output words are present | OPEN service-rate contract |
| Real XPM / GT Wizard | Not run in this Linux flow | OPEN |
| FPGA PPA / physical QAM256 BER | Not run | OPEN |

The 344-bin EF2 disposition is a source-bound static elaboration result, not a
claim that the rejected PAIR_LOOKAHEAD SVA goals passed. It covers 84 Branch,
108 Condition, and 152 Line records; all remain present in Raw. The tracked
product compile manifest was rebuilt from the saved exact 13-test VCS compile
log and parent source manifest (75 parsed HDL/UVM files; 77/77 source/control
entries match). No product RTL or Raw VDB changed in this audit step.

### Incremental two-frame CDC alignment Formal — 2026-10-31

VC Formal V-2023.12-SP2 proved that frame-start FIFO pops have zero residual
count for two consecutive legal 32-beat packets through the production 14:8
CDC and Generic FIFO. First/second frame-start, second frame-end, and second
output-frame-end Covers were reached; the exact misaligned-start target Cover
was uncoverable. There were no SVA environment assumptions, setup violations,
black boxes, or tautology warnings. The exact semantic Raw Bin
`TXB-158c42868bfe37061f07` at `dsm_axis14_to_core8_cdc.sv:224` is now
`PROVEN_UNREACHABLE` in the audit ledger and remains in Raw. The failed initial
6-bit harness attempt is preserved separately and not counted as evidence.
Raw coverage and denominator are unchanged; current ledger status is 354
proven-unreachable and 21,378 OPEN, with zero waivers and exclusions.

The ten source-bound Formal records are the three reviewed CDC branches, three AXI-Lite default Branch/Line bins, and four Centered-Cubic tail-only branches at `u_interp_1`/`u_interp_2`. All remain counted in Raw. The AXI-Lite tuple condition has no accepted non-vacuous proof and stays OPEN. The frame-tail proof uses W=16, stage 1 LANES=8/append=1, and stage 2 LANES=16/append=0; it proves local module reachability under product parameters, not full two-stage composition. Formal passed 6/6 assertions and 5/9 Covers, with the exact four tail-only Covers uncoverable, one non-vacuous source-stability assumption, zero setup violations, and zero black boxes.

The legal frame-replacement UVM run (seed 610900) passed its four-plane bit-true checker for 112 outputs over two frames, but its product URG union added no code hits. The two line-255 pop/push bins remain OPEN. The refreshed formal review and source-bound ledger are in [`thermo5-tx-focused-product-formal-review.json`](data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-formal-review.json) and [`thermo5-tx-focused-product-closure.md`](data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-closure.md).

The additional DPD saturation test wrote a legal non-identity one-tap Q2.14 image over AXI-Lite. Python-generated vectors and the independent UVM checker matched all four output planes for 56 output words; the run covered I/Q positive and negative saturation on each of 16 DPD lanes. It increased same-compile Raw by +80 Branch, +16 Condition, +144 Line, and +654 Toggle. The product Raw remains unadjusted.

### Exact evidence and commands

- Product VCS compile manifest: `runs/thermo5_cdc_resetready_repro_20261031/vcs_product_replay_13tests/product-source-manifest.json`.
- 13-test replay results and logs: `runs/thermo5_cdc_resetready_repro_20261031/vcs_product_replay_13tests/`.
- Raw URG: `runs/thermo5_cdc_resetready_repro_20261031/product_focused_urg_product_13tests/`; denominator summary and branch-arm export are in the sibling `_denominator/` directory.
- Fail-closed gate: `runs/thermo5_cdc_resetready_repro_20261031/current_coverage_gate_13tests/coverage-gate.json`.
- Closure ledger, grouped task table, functional audit, formal review, tool/log hashes, and commands: [`thermo5-tx-coverage-closure-index.json`](data/thermo5-tx-coverage-closure-index.json) and [`thermo5-tx-coverage-root-cause-closure.md`](thermo5-tx-coverage-root-cause-closure.md).
- VCS mutation manifest and logs: `runs/thermo5_cdc_resetready_repro_20261031/mutation_13tests_final/`.

The earlier source snapshots below are retained as history and are not the current metrics. Current evidence is not full product or physical signoff. Remaining Linux work includes reachable Branch/Condition/Line/Toggle closure, DPD identity Formal convergence, and resolving the legal-source gap/service-rate contract. Real XPM/GT Wizard, complete GT Parent payload checking, FPGA PPA, and physical QAM256 BER remain outside this Linux run.


**Historical snapshot below:** all prior SHA-specific reports are retained for traceability; use the latest section above for current status.

**Disposition:** `LINUX_CLOSURE_OPEN; RAW_100_OPEN`

**Historical audited product source SHA:** `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b`

**Product configuration:** Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120,
20-bit state; 32 chronological lanes; `DPD_MAX_TAPS=1` identity; AXI-Lite
product parent and Generic FIFO model.

## Latest licensed Linux refresh and source audit (2026-10-31)

VCS and URG are available again. A fresh product compile passed for checkout
`41691b675d4be63221f046e007aa9a37cb156e1e`; the product RTL/UVM source identity
is unchanged. Two focused tests passed: AXI-Lite reset sweep (seed 610802) and
AXI-Lite register access (seed 610830), both with zero UVM errors/fatals.
The refreshed URG database contains 29 product simulation VDBs (2 fresh, 27
retained exact-source VDBs) plus one compile VDB. A full regression was not
rerun.

The fresh URG `groups.html` and extracted Raw summary are byte-for-byte equal
to the initial fresh merge. Therefore these tests add functional execution
evidence, but do not improve code coverage. The report remains
`RAW_100_OPEN`, Raw equals Adjusted, with zero approved waivers and zero `.el`
exclusions. Exact commands, tool versions, log/report/gate hashes, metrics,
and zero-hit Functional Coverage records are in
[`thermo5-tx-final-vcs-refresh.json`](data/thermo5-tx-final-vcs-refresh.json).

This report records the current Linux evidence without treating parameter
proofs as simulator coverage hits. The root-cause ledger and per-bin detail are
in [`thermo5-tx-coverage-root-cause-closure.md`](thermo5-tx-coverage-root-cause-closure.md),
with machine-readable formal dispositions in
[`thermo5-tx-formal-bin-dispositions.json`](thermo5-tx-formal-bin-dispositions.json).

## Clean AXI-Lite Formal refresh (2026-10-31)

The current AXI-Lite coverage harness was rerun with VC Formal V-2023.12-SP2.
It passed with 4/4 assertions proven, one legal coefficient-read Cover hit,
and three exact path Covers uncoverable; it used no environment assumptions,
reported no setup violations or black boxes, and had three non-vacuous
assertions. A fresh current-source rerun also validates the coefficient-read
function default Branch at line 135 (and its line-142 default Line bin) using
the same exact non-vacuous assertion/Cover pair. The runner rejects
Tautological goals. The four AXI-Lite semantic bins now include the guarded
read default Branch, the corresponding default Line, the read-address tuple
Condition, and the write-address default Branch. All remain in Raw. The fresh
reproof is recorded under
`runs/thermo5_axil_cfg_final_closure_20261031/`; its manifest binds the clean
source SHA, Formal property/setup/console hashes, exact command, and tool
version.

The separate `MAX_TAPS=1` initialization-guard property and one interpolator
append-arm property were identified as tautologies and removed from the
accepted Formal disposition set. Both Raw code bins remain OPEN and in the
unmodified Raw denominator. The accepted ledger now has seven exact proven
bins and 18,586 OPEN records.

## Product 14:8 CDC immediate frame-end Branch (2026-10-31)

VC Formal V-2023.12-SP2 was run at clean source SHA
`bcf1f9a10b7a203e13cefb6fa64efcff0e588815` against the production 14:8 CDC
gearbox and Generic FIFO, with the fixed AXI-Lite product configuration and a
deterministic legal 32-beat AXIS source. The non-vacuous assertion proves the
line-210 immediate frame-end arm unreachable; the matching arm Cover is
uncoverable. Covers reached the enclosing product frame-end context at depth
59 and a completed legal frame at depth 63. The run used no environment
assumptions, had zero setup violations and zero black boxes, and passed its
fail-closed runner. Exact hashes and properties are in
`runs/thermo5_cdc_end_branch_20261031_bcf1f9a/`.

The disposition closes exactly one audit-ledger row as
`PROVEN_UNREACHABLE`; it does not remove or exclude the Raw URG Branch bin.
Raw coverage remains line 3,190/3,796, condition 583/846, branch 440/637,
toggle 86,951/104,478, FSM state 13/13 and transition 22/22. The ledger now
contains seven proven-unreachable rows and 18,586 OPEN rows out of 18,593.
Waivers and active `.el` exclusions remain zero.

## Product 14:8 CDC outer-case default Branch (2026-10-31)

The exact Raw bin `TXB-f787ff8f614d2d391c4c` maps to the `advance` path at
`dsm_axis14_to_core8_cdc.sv:136` followed by the outer `case (rem_count_q)`
default at line 149, in `thermo5_sku_uvm_tb.dut.u_cdc`. A product-bound VC
Formal harness uses the actual 14:8 gearbox and Generic FIFO with explicit
16-bit samples, FIFO depth 16, a deterministic legal aligned 32-beat source,
and the 14:8 clock ratio. It asserts the exact path is unreachable and that
the residual remains in `{0,2,4,6,8,10,12}`.

VC Formal V-2023.12-SP2 passed at clean verification SHA
`eff0c4169d40320ad8bb08e0fb78bc8ce72b2ed7`: 2/2 assertions proven; the exact
default-path Cover is uncoverable; normal advancement and a completed legal
frame Covers are reached (depths 2 and 63). There are no environment
assumptions, setup violations, black boxes, or tautological goals. The exact
command, properties, setup, console, source hashes, and manifest are under
`runs/thermo5_cdc_default_branch_20261031_eff0c41/`.

The source-bound ledger now classifies this one bin as
`PROVEN_UNREACHABLE`; the Raw URG bin and denominator are retained. There are
eight such audit rows and 18,585 OPEN rows out of 18,593. Raw code counters are
unchanged; no VDB merge, waiver, `.el`, denominator edit, or DUT RTL change was
made. A full VCS regression was not repeated because no VCS compile input or
product RTL changed.

An exploratory mailbox-stability assertion remains OPEN. Its full Formal run
was inconclusive; a selected-property trace attempt marked the AW/W stability
assumptions `not_run`, so that witness is not valid evidence under legal AXI
traffic. The temporary harness edits were reverted. A focused VCS config test
(seed 610931) passed with zero UVM warnings, errors, or fatals, but does not
resolve the Formal gap. No waiver or coverage disposition was applied.

The current-worktree coverage gate was also rerun against the retained Raw
summary and Group Report. It returned exit code 3,
`FAIL_CLOSED_SOURCE_HASH_MISMATCH`: the recorded compile manifest is pinned to
base commit `913be930bfcbbad0f78dbc90e06299db3d1bb337`, while three UVM compile
inputs have since changed for the separate frame diagnostic test. All product
RTL hashes and the coverage hierarchy match; the changed files are the SKU
interface, UVM package, and UVM top. The prior Raw report was not modified and
remains tied to its recorded baseline compile. This follow-up therefore does
not claim an exact-current-worktree Raw compile signoff. Exact expected/current
hashes, command, and failure log SHA are recorded in the root-cause audit
manifest and summary.

## Centered-Cubic frame-boundary Branch review (2026-10-31)

A reproducible AXI-Lite product test now sends two legal 32-beat packets and
checks all 112 four-plane output words against the independent bit-true
scoreboard. Nine legal source-start phases and seventeen RUN-start phase
placements passed with zero UVM errors/fatals. Each centered-cubic instance
reached a single-entry frame-end pop, but no same-edge input push occurred.
Therefore the two exact line-255 pop/push Branch bins remain OPEN and Raw URG
did not gain a hit. A diagnostic VDB was merged into a separate report; line,
condition, branch and toggle counters were unchanged. The standalone
interpolator Formal Cover witness shows the path is structurally reachable,
but does not establish reachability in the cascaded product schedule. The
product-bound cadence still needs analysis. See the
[machine-readable phase and URG evidence](data/thermo5-tx-frame-replacement-coverage-review.json).

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
equals Raw. Eight exact bins have a Formal `PROVEN_UNREACHABLE` disposition;
they remain visible in the Raw URG denominators. The ledger contains 18,585
OPEN records out of 18,593. No adjusted score is used to claim closure.

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
| Centered interpolator product parameters | VC Formal reports 6/6 assertions proven and 5/9 Covers hit, 4/9 uncoverable; one assertion is explicitly tautological; one source-stability assumption is non-vacuous | Two exact frame-tail dispositions are retained; the tautological append-arm candidate remains OPEN. Single-entry pop/push is formally reachable but still missed by targeted product UVM. |
| AXI-Lite configuration and address decode | 4/4 assertions proven; one legal coefficient-read Cover hit; three exact path Covers uncoverable; zero environment assumptions, setup violations, or black boxes; no tautological goals | Four exact Raw bins across Branch/Condition/Line are proven unreachable, including the read default Branch at line 135; mailbox stability and `MAX_TAPS=1` guard remain OPEN |
| Product 14:8 CDC outer-case default | 2/2 assertions proven; exact `advance && case-default` Cover uncoverable; normal advancement and completed-frame Covers hit; zero assumptions/setup violations/black boxes | Exact `TXB-f787ff8f614d2d391c4c` remains in Raw and is classified `PROVEN_UNREACHABLE`; denominator unchanged |
| AXI-Lite outstanding-word guards | Product-bound proof used legal source/AXI-Lite sequencers, arbitrary PA backpressure and no external assumptions; source/core/output Covers hit, both assertions non-vacuous | Both line-203 saturation and line-204 underflow assertions and exact guard Covers were INCONCLUSIVE (depths 142/102 and 141/103); both Raw Branch bins remain OPEN |
| EF2 arithmetic/state | 6/6 assertions proven; 3/3 Covers hit; zero setup violations and black boxes | Does not increase URG hits |
| Product EF2 parameter guards | The parameter guard assertion is proven and invalid-parameter Cover is uncoverable; pair-look-ahead-disabled assertion/Cover were reported as tautological | No ledger closure is credited from the tautological pair-look-ahead properties; parameter evidence remains configuration-bound |
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

The separate product-bound counter-guard attempt remains Inconclusive. It did
reach the legal source/core/output Covers and both assertions were non-vacuous,
but the saturation and underflow properties did not converge within the run
budget. See [`thermo5-tx-outstanding-counter-formal-evidence.json`](data/thermo5-tx-outstanding-counter-formal-evidence.json).

## Verification disposition summary

| Verification item | Result | Exact interpretation |
|---|---|---|
| Product VCS compile and targeted UVM | `PASS_TARGETED_REFRESH` | Two fresh tests pass with zero UVM errors/fatals; 27 exact-source VDBs were reused. This is not a full regression rerun. |
| Product Raw URG and fail-closed gate | `PASS_AUDIT; RAW_100_OPEN` | 29 product simulation VDBs plus the compile VDB; Raw report and Raw summary match the first fresh merge byte-for-byte. |
| Centered-Cubic product frame-replacement phase sweep | `PASS_STREAM; TARGET_BRANCH_OPEN` | Nine fixed-seed legal source-start phases pass the 112-word four-plane oracle; each instance observes one single-entry frame-end pop and zero same-edge pushes. One VDB was added to a diagnostic URG merge; Raw code counters and target-bin status are unchanged. |
| Expected-negative malformed-frame UVM | `PASS_NEGATIVE_CHECKER` | Current-source VCS test seed 420102 observes the early-TLAST assertions, sticky error and reset recovery; its separate URG hit on Branch `TXB-646dd03c99766d877d30` is not merged into positive Raw. |
| Scoped Formal jobs | `PASS_FOR_SCOPED_PROPERTIES` | Exact assertion/Cover counts and assumptions are in the Formal table above; they do not count as URG hits. |
| Identity-DPD Formal | `OPEN_INCONCLUSIVE` | Direct 5/18 proven, 13 inconclusive; auto-lemma 1/13 proven, 12 inconclusive. No counterexample is not a proof. |
| Checker mutation | `PASS_MUTATION_CAUGHT` | One-bit PA0 oracle corruption was detected at epoch 0 / word 0 / plane 0. Other checker mutation classes remain untested. |

## Targeted stimulus and assertion status

The new test observes the exact product-instance event
`q_count==1 && pop_head && push_input` directly. It also records the adjacent
state `q_count==1 && q0_end && pop_head`: both interpolator stages reached and
popped that state once in every phase, while `push_input` remained low on that
edge. The 9-phase sweep changes only the legal source-start phase; the vector
seed and packet contents remain fixed. There is no coverage credit for the
missing pop/push event. The test log and a diagnostic URG merge are hashed in
the linked review JSON. The module-only depth-2 Formal witness remains a
module-level result, not a product integration witness.

The separate current-source illegal-frame assertion test has two expected
assertion failures, passes its UVM expected-negative checker, and is not merged
into the positive product coverage database. Its separate URG report hits the
early-TLAST RTL Branch at line 141; the corresponding product Raw ledger row
remains OPEN because the legal-product VDB is unchanged. Product Raw URG
reports 13 DUT assertion successes, 2 uncovered, and 2 without attempts; those
statuses are preserved. Full commands and SHA-256 evidence are in
[`thermo5-tx-negative-assertion-evidence.json`](data/thermo5-tx-negative-assertion-evidence.json).

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
  --out-dir runs/thermo5_axil_cfg_coverage_clean_default_20261031
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs counter_unbounded ef2 ef2_product_params \
  --out-dir runs/thermo5_tx_final_formal_remaining_20261030
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs counter --out-dir runs/thermo5_tx_final_counter_bound_20261030
```

The current Product Raw database was regenerated after the VCS license was
restored. Two targeted VCS tests passed and URG merged their VDBs with 27
retained exact-source test VDBs plus the compile VDB. The fresh report SHA is
`d595b7fdd529ff1010b81e2d93a1a66e6cfeb9bf911615b5ad67b8dd12d69852`; the
fail-closed gate is `RAW_100_OPEN`, Raw equals Adjusted, with zero waivers and
zero exclusions. This refresh did not rerun the full regression and did not
change any Raw coverage counter.

The adjusted-URG path for approved nonempty waivers remains OPEN: the current
gate accepts only an empty waiver ledger and comment-only `.el`; no real
approved exclusion template or adjusted database has been validated. No
synthetic or unreviewed exclusion was installed.

## Acceptance status and remaining work

- **Legal functional coverage:** 210/210 applicable scoreable records; negative-only bins reported separately. The complete report lists 214 scoreable records and 12 pre-existing URG model Illegal/Excluded records.
- **Reachable/applicable DUT code coverage:** not closed; 18,585 rows remain OPEN after eight exact Formal-proven-unreachable dispositions.
- **Raw 100% code coverage:** `RAW_100_OPEN`; not claimed.
- **Identity DPD Formal:** OPEN / inconclusive.
- **TX worst-case benchmark:** model-only evidence exists; product BER/BLER acceptance threshold is undefined, so product communication acceptance remains OPEN.
- **Checker mutation:** detected; expected-negative assertion run is separately classified.
- **Real XPM, GT Wizard, FPGA timing/PPA, routed signoff and physical QAM256 BER:** pending outside this Linux run.

No TX algorithm, RX, AI-DPD, or product DUT behavior was changed.

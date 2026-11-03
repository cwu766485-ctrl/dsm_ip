Warning: truncated output (original token count: 105666)
Total output lines: 5894

## 2026-11-03 20:27 SGT - Extend outstanding-counter capacity Formal investigation

- Added a legal AXIS source-valid input with arbitrary source bubbles and the
  required hold-VALID-until-handshake assumption. PA stalls remain arbitrary;
  no maximum source-gap or PA-stall bound is imposed.
- Added candidate source-bound pipeline-capacity assertions and a bubble Cover.
  A prior generated-array EF2 hierarchical reference was diagnosed by VC Formal
  as UNDRIVEN and removed; it was a harness resolution defect, not evidence of
  a product counterexample.
- VC Formal V-2023.12-SP2 completed in 311.08 seconds with zero selected setup
  issues, zero black boxes, and a non-vacuous source-hold assumption. Source,
  core, output, and arbitrary-bubble Covers reached. All five assertions and
  both exact saturation/underflow Covers remain INCONCLUSIVE (depths 34-46).
  The two Raw Branch roots remain OPEN; no waiver is supported.
- Raw URG was not rerun because this Formal-only harness change does not create
  URG hits. Coverage is unchanged at Branch 525/637, Condition 658/849, Line
  3351/3796, Toggle 84340/104480, FSM 13/13 states and 17/22 transitions,
  Functional 392/392; zero approved waivers, zero exclusions, `RAW_100_OPEN`.
- Added exact run/source hashes and disposition in the outstanding capacity
  report/evidence JSON; updated the Linux signoff and execution frontier. No
  product RTL or algorithm changed.
- Checks: VC Formal ran to completion but closure result is INCONCLUSIVE;
  Python `py_compile`, evidence JSON parse, and `git diff --check` PASS. Full
  VCS/URG regression was not rerun. Remaining: prove component conservation
  contracts and compose them, otherwise keep both target bins OPEN.

## 2026-11-03 18:48 SGT - Prove one-tap Identity DPD output under backpressure

- Added a dedicated VC Formal harness and source-bound runner for the frozen
  one-tap Q14 Identity DPD profile. The flow proves 41 internal pipeline
  lemmas in the base model, checks their exact inventory, then promotes only
  those base-proven facts; the four final I/Q latency and saturation goals
  remain active in the composed proof.
- Fresh VC Formal V-2023.12-SP2 run on clean commit
  `e21c1ece205b633809e1dfd84d275936294b6378`: base 41/41 internal lemmas
  proven; composed 4/4 final assertions proven; 4/4 endpoint/stall/recovery
  Covers reached. The source-hold assumption is non-vacuous; setup violations
  and black boxes are zero. A fail-closed auditor binds reports, harness,
  runner, Tcl, RTL hashes, and run commit.
- Added the scoped Formal report and machine-readable evidence, and updated the
  Formal README, Linux signoff, and active execution frontier. No product RTL,
  simulation input, VDB, Raw URG, waiver, or exclusion changed. Raw remains
  Branch 525/637, Condition 658/849, Line 3351/3796, Toggle 84340/104480,
  FSM 13/13 states and 17/22 transitions, Functional 392/392;
  `RAW_100_OPEN` remains.
- Checks: VC Formal scoped flow PASS; Python syntax/JSON audit PASS;
  `git diff --check` PASS. Full VCS/URG and complete TX product regression were
  not rerun because no simulation sources or coverage inputs changed.
- Remaining: AXI Shadow/COMMIT, mailbox, CDC and active-epoch composition;
  outstanding-counter saturation/underflow remain INCONCLUSIVE/OPEN; the
  current open-bin snapshot has 20,891 code records OPEN, all 371 waiver
  candidates are pending, and there are no approved waivers. Vendor XPM/GT
  Wizard, FPGA PPA and physical RF/QAM256 remain outside Linux signoff.

## 2026-11-03 17:32 SGT - Prove Thermo5 DPD vector output hold under stall

- Added a reproducible VC Formal harness, Tcl flow, runner, and fail-closed
  auditor for the 16-lane `dpd_vector16_memory_poly` output stall-hold contract.
  The 512-bit I/Q payload is split into 16 lane assertions; metadata hold and
  all-lane valid lockstep are checked separately. MAX_TAPS=1 matches the
  product vector shape. Runtime taps, coefficients, payload, metadata, valid
  and ready are unconstrained; no environment assumptions were added.
- Re-ran the exact committed harness with VC Formal V-2023.12-SP2. Result:
  33/33 assertions proven, all 17 lane-payload/metadata properties
  non-vacuous, 3/3 Covers reached, zero black boxes, zero environment
  assumptions, one reset initialization constraint, and zero selected setup
  violations. The audited run took 102.63 seconds.
- The monolithic full-vector property previously remained INCONCLUSIVE at depth
  15 and a later aggregate run at depth 294. The lane decomposition now proves
  the vector leaf's stall-hold protocol; it does not prove Identity arithmetic
  or full-chain COMMIT/CDC/epoch behavior. Full-chain DPD Identity remains
  OPEN/INCONCLUSIVE. No RTL or algorithm changed.
- Raw/Adjusted URG was not rerun because simulation/VDB inputs did not change.
  Raw remains Branch 525/637, Condition 658/849, Line 3351/3796, Toggle
  84340/104480, FSM states 13/13 and transitions 17/22, Functional 392/392;
  zero approved waivers, zero exclusions, and `RAW_100_OPEN`. Formal creates no
  URG hits or denominator changes.
- Added the scoped report and JSON evidence, and updated the Linux signoff and
  execution frontier. Python `py_compile`, JSON parsing and `git diff --check`
  pass; VCS and URG were not rerun. Remaining Raw code bins, counter guards,
  full-chain DPD Identity, pending waiver approvals and vendor/physical signoff
  remain open.

## 2026-11-03 17:05 SGT - Prove two retained TX Raw Condition tuples unreachable

- Ran focused VC Formal V-2023.12-SP2 on the product one-tap DPD ready/valid
  relation and the AXI-Lite `write_fire` response relation. Both exact tuple
  Covers were reported uncoverable; the corresponding implications were
  proven non-vacuously with zero environment assumptions, zero black boxes,
  and zero selected setup violations.
- Bound each result to its exact Not Covered tuple in the same 247-test Raw
  URG report and recorded source, harness, Tcl, Formal log, report, and VDB
  hashes in separate fail-closed audit JSON and closure reports.
- Raw Condition remains 658/849; Raw equals Adjusted, with zero approved
  waivers and zero active `.el` exclusions. The gate remains `RAW_100_OPEN`.
  Two of the 20,893 records in the latest open-bin snapshot now have exact
  `PROVEN_UNREACHABLE` root-cause dispositions; the other 20,891 remain OPEN.
- Updated the active execution frontier and Linux signoff. No DUT RTL,
  algorithm, coverage denominator, or VDB was changed. The separate 512-bit
  DPD payload-hold property remains INCONCLUSIVE at depth 15.
- Checks: focused DPD and AXI-Lite Formal audits PASS; Python audit scripts
  compile and their JSON outputs parse; `git diff --check` PASS. The full UVM
  regression and Raw URG were not rerun because neither simulation inputs nor
  VDBs changed.
- Published as Draft PR #33 on `codex/thermo5-tx-focused-condition-formal-closure`,
  stacked on Draft PR #32 at its exact head; no PR was merged.

## 2026-11-03 16:30 SGT - Rebind TX waiver audit to the latest Formal review

- The current waiver CSV and Round 6 candidate audit were bound to an earlier
  focused Formal Review JSON. After adding the extended counter Formal result,
  reran the source-bound candidate audit against the latest review, product
  compile manifest, same-list 247-test Raw/Adjusted report and Raw open-bin
  ledger.
- Created waiver review Round 7. It rebinds all 371 exact candidate rows:
  361 `CONFIG_UNREACHABLE`, 10 `FORMAL_UNREACHABLE`; every row remains PENDING.
  The fail-closed pipeline reports zero approved, zero rejected, and zero
  active Exclusions. Its generated `.el` contains no directives. Raw remains
  unchanged.
- Added the Round 7 report and machine-readable pipeline audit; updated the
  waiver CSV pointers, Linux signoff, evidence JSON, and execution frontier.
  The latest 247-test Raw metrics remain Branch 525/637, Condition 658/849,
  Line 3351/3796, Toggle 84340/104480, FSM 13/13 states and 17/22
  transitions; functional 392/392. No new VDB was merged.
- Checks: Round 7 candidate audit PASS (371/371); waiver pipeline PASS (371
  pending; no exclusions); hardware utility tests 42/42 PASS; Python compile,
  JSON/hash validation and `git diff --check` PASS. Full UVM regression and Raw
  URG were not rerun because their inputs did not change.
- Remaining: no waiver has independent reviewer approval; 20,893 Raw code
  records remain OPEN in 457 groups; outstanding-counter Formal remains
  INCONCLUSIVE; legal frame-tail no-attempt properties and full-chain DPD
  Identity remain OPEN. Physical/vendor validation remains out of scope.

## 2026-11-03 16:24 SGT - Extend counter Formal and enforce expected-negative assertion checks

- Extended the product-bound outstanding-counter VC Formal effort limit to
  22 minutes (20 minutes per property). V-2023.12-SP2 completed in 1,364.76 s.
  Both guard assertions remain non-vacuous INCONCLUSIVE at depths 231/122;
  both exact guard Covers remain INCONCLUSIVE at depths 196/126. Source/core/
  output activity Covers were reached. There are zero environment assumptions,
  zero black boxes, and zero setup violations. The two Raw Branches remain
  OPEN; no waiver or Exclusion was created.
- Added the extended Formal report and machine-readable evidence index with
  exact property results, source hashes, tool version, run-manifest hash and
  console/property/setup/engine hashes.
- Connected a fail-closed checker to `thermo5-axil-vcs-negative`. The
  integrated target now requires exactly one CDC frame-alignment assertion
  and one frame-tail assertion in each Centered-Cubic stage, zero unexpected
  RTL assertion errors, zero UVM warning/error/fatal, and verified reset
  recovery. The target passed on a fresh compile with seed 420102.
- Updated the Linux system signoff, machine-readable signoff index, and active
  execution frontier. Raw/Adjusted URG inputs and metrics are unchanged;
  Functional Coverage remains 392/392, Branch 525/637, Condition 658/849,
  Line 3351/3796, Toggle 84340/104480, FSM 13/13 states and 17/22
  transitions. There are zero approved waivers and zero active Exclusions.
- Checks: hardware utility suite 42/42 PASS; exact negative VCS Make target
  PASS; Python compile checks PASS; signoff JSON validation PASS; final
  `git diff --check` PASS. No full regression,
  new random seed sweep, RX, AI-DPD, or Vivado run was made.
- Remaining: both outstanding-counter Raw Branches / Formal goals OPEN or
  INCONCLUSIVE; 20,893 code records remain OPEN in 457 groups; 371 waivers
  still PENDING with zero approvals. Full-chain DPD Identity, the two legal
  no-attempt frame-tail assertions, real XPM/GT Wizard, FPGA PPA, and physical
  RF/QAM256 remain outside completed Linux signoff.

## 2026-11-03 15:58 SGT - Separate Thermo5 TX assertion evidence and prove the DPD Identity leaf

- Re-audited the latest 247-test Raw/Adjusted URG inventory. All 247 VDB
  trees are unique: 243 legal-positive, two expected-negative, and two
  additional legal directed cases. The 16-point STATUS-mismatched sweep is
  absent. Raw and Adjusted remain equal with zero approvals/exclusions and
  `RAW_100_OPEN`; code coverage is unchanged from the 246-test checkpoint.
- Replayed the AXI-Lite illegal-frame case with the correct seed-specific
  vectors. It observed exactly one CDC frame-alignment assertion and one
  Centered-Cubic frame-tail assertion in each stage, then verified sticky
  protocol-error clearing by public reset. UVM warning/error/fatal counts
  were zero. Kept its expected assertion failures in a separate URG report
  from the 243-VDB legal-positive assertion report.
- Added a fail-closed expected-negative log checker, connected it to the
  AXI-Lite negative Make target, and added mutation-focused tests for a
  missing stage event, unexpected RTL assertion, and nonzero UVM error.
- Added a local DPD one-tap Identity/no-stall Formal harness. VC Formal proved
  5/5 properties and reached 3/3 Covers with zero black boxes and no
  environment assumptions. This is a datapath leaf result only; arbitrary
  stalls, AXI commit/epoch behavior, and full-chain Identity remain OPEN.
- Added the detailed assertion/DPD evidence report, machine-readable hash
  index, Formal README invocation, updated Linux signoff, and execution
  frontier. No product RTL or algorithm was changed.
- Checks: expected-negative checker PASS; checker unit tests 4/4 PASS;
  hardware utility tests 42/42 PASS; DPD Identity leaf Formal 5/5 assertions
  and 3/3 Covers PASS; 243-positive and one-test negative URG reports PASS.
  The integrated `thermo5-axil-vcs-negative` Make target also PASSed using the
  fresh compile and seed-specific vectors.
  The old misconfigured negative attempt is retained as
  `INVALID_NOT_COUNTED`. Full VCS regression was not rerun.
- Remaining: 20,893 Raw code records in 457 groups, five FSM transitions,
  371 pending waiver candidates, outstanding-counter Formal INCONCLUSIVE,
  and full-chain DPD Identity Formal INCONCLUSIVE. Real XPM/GT Wizard, FPGA
  PPA/routed timing, and physical RF/QAM256 are outside Linux signoff.

## 2026-11-03 14:56 SGT - Thermo5 TX interframe coverage and waiver audit refresh

- Recompiled the frozen Thermo5 AXI-Lite product with the explicit DUT-only
  coverage hierarchy and ran the directed 11-cycle interframe-gap test
  (VCS seed 930833). Both centered-cubic stage pop/push Branches were hit;
  all 112 four-plane output words matched the independent checker, with zero
  Underflow, STATUS mismatch, protocol error, or UVM error.
- Rebuilt Raw and Adjusted URG on the exact same 245-test VDB set. Coverage is
  Branch 525/637, Condition 658/849, Line 3351/3796, Toggle 84180/104480,
  FSM states 13/13 and transitions 17/22; legal applicable functional bins
  are 392/392. Raw and Adjusted match with zero active Exclusions. The ledger
  has 21,053 OPEN records in 457 groups; gate remains `RAW_100_OPEN`.
- Rebound the 371 waiver-candidate audit and zero-approval pipeline to the
  refreshed product configuration. All remain PENDING; zero approved and
  zero `.el` directives. Fixed the coverage-gate schema mismatch and removed
  the candidate-audit tool's hardcoded 244-VDB assumption.
- Rechecked the outstanding-counter Formal result: zero assumptions, zero
  black boxes, two non-vacuous assertions, but both assertions and both target
  Covers remain INCONCLUSIVE. No waiver was approved.
- Updated the Linux signoff report, waiver review round 2, machine-readable
  interframe evidence, and active execution frontier. Product RTL and frozen
  algorithm were not modified.
- Checks: VCS product-hierarchy compile and targeted UVM PASS; same-list
  Raw/Adjusted URG and fail-closed gate PASS; candidate audit PASS (371/371);
  waiver pipeline PASS (0 exclusions); hardware utility tests 38/38 PASS;
  Python reference tests 59/59 PASS; `py_compile` and `git diff --check` PASS.
  Full UVM regression was not run.
- Remaining: two counter-guard Branches and Formal goals OPEN/INCONCLUSIVE;
  21,053 OPEN code records; two frame-tail assertions without attempts; DPD
  Identity Formal inconclusive; no real XPM/GT Wizard, FPGA PPA, or physical
  RF/QAM256 signoff.

# 2026-11-03 12:53 SGT - Rebind and audit the 371 Thermo5 TX waiver candidates

- Started an independent waiver-review round on
  `codex/thermo5-tx-waiver-audit-round1`, based on Draft PR #30's exact head
  `08061386900e5ae2c9f692dcf7e85d849623f818`. No historical PR was merged.
- Rebound all 371 CSV candidates to unique current Raw Bin IDs, instances,
  source locations, source hashes, the exact product compile manifest, and the
  same-list Raw/Adjusted URG and VDB manifests. The audit classified 361 as
  fixed-configuration candidates and 10 against exact archived Formal proofs.
  No candidate was marked reachable or unresolved; this does not close any
  Raw bin or authorize exclusion.
- Re-derived each fixed-configuration proof from the present parameter chain
  (inclu…97666 tokens truncated…rejection is retained
  in the ignored audit run directory.
- Ledger status changed only for the 17 reviewed bins: 372 total
  `PROVEN_UNREACHABLE` (11 Formal + 344 EF2 pair-lookahead static + 17 fixed
  parameter) and 21,360 OPEN across 470 tasks (108 fully dispositioned, 362
  OPEN). Raw URG/VDB and denominators remain unchanged; Raw Branch 520/637,
  Condition 601/849, Line 3334/3796, Toggle 83575/104480; legal Functional
  Coverage 210/210; zero waivers/exclusions; gate remains `RAW_100_OPEN`.
- Updated final signoff, current-source closure report, formal review,
  root-cause summary/manifest, source-bound ledger/task table, execution
  frontier, and the dedicated fixed-parameter Branch audit report.
- Checks: `python3.12 -m unittest discover -s tools/hw/tests -v` 17/17 PASS;
  Python byte-compile PASS; disposition updater PASS; fail-closed Raw/Adjusted
  coverage gate PASS with `RAW_100_OPEN`; `git diff --check` PASS. Product VCS/
  URG was not rerun because no product RTL, compile inputs, or Raw VDB changed.
- Remaining: all other reachable/applicable code bins stay OPEN; DPD payload
  Formal and the source-gap/service-rate contract remain OPEN; real XPM/GT
  Wizard, FPGA PPA, and physical QAM256 BER remain outside Linux signoff. The
  Published as [Draft PR #22](https://github.com/cwu766485-ctrl/dsm_ip/pull/22), stacked on PR #21. The GitHub publication commit is `9bcbe5c829c4bd8d957949865da1009073fc7da6` (tree `0af067229fa54f6ce2e3ab887e05bcb50afb170f`), matching local submission commit `90be89937ca4110385c3d37d6e592ea45ddb6449` by tree. PR #22 is open and mergeable; no PR is merged and no branch is deleted.

## 2026-10-31 17:05 SGT - Refresh current TX code-union signoff and Linux checks

- Reconciled the current Product code-coverage union and replaced stale Step 1/2
  snapshot counts. The exact current Product SHA remains
  `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`; legal Functional Coverage is
  210/210. Raw code coverage is Branch 524/637, Condition 610/849, Line
  3350/3796, Toggle 83587/104480, FSM states 13/13 and transitions 22/22.
- Refreshed the ledger summary in the evidence index: 21,691 Raw misses, 371
  `PROVEN_UNREACHABLE` records retained in Raw, and 21,320 OPEN across 429
  tasks. Waivers=0, active `.el` exclusions=0, Adjusted=Raw, gate
  `RAW_100_OPEN`. Four illegal-only Functional rows remain visible in the
  scoreable union report and are separated from legal positive Functional
  scoring.
- Added saved Linux check logs under ignored
  `runs/thermo5_tx_final_closure_20261031/checks/`. Hardware tool tests
  passed 19/19; Python reference-model tests passed 44/44; Python byte-compile
  passed. A fresh static gate recheck returned `RAW_100_OPEN` with the above
  counters. No full VCS regression was rerun because Product RTL, compile
  inputs, and the exact-source VDB set were unchanged; 13/13 legal Product VCS
  results and targeted source-gap/negative runs remain source-linked evidence.
- Updated the current closure and final signoff snapshots, branch-consolidation
  audit, machine-readable final evidence, expected-negative evidence, evidence
  index, and execution frontier. The
  early-TLAST legal Formal run remains INCONCLUSIVE and does not disposition a
  bin. No TX algorithm, RX, or AI-DPD RTL changed.
- Remaining: 21,320 Raw misses are OPEN; DPD Identity and outstanding-word
  Formal, the 16-cycle source-gap contract, real XPM/GT Wizard, FPGA PPA, and
  physical QAM256 BER remain unclosed. The independent Integration PR is still
  to be published from the current PR #22 tree; no PR was merged or branch
  deleted.

## 2026-10-31 17:13 SGT - Publish the TX Linux closure Integration Review

- Published the reviewed 27-file Linux closure package as Draft PR #23 targeting
  `thermo5`, based on the exact PR #22 tree. GitHub reports the PR open, draft,
  mergeable, and unmerged. No PR was merged and no branch was deleted.
- Local reviewed commit `66676223e098b7eef258a681ea3e53fa2710f351` and initial
  GitHub publication commit `ad6a4016baea9f0abdaa5736067cd1aed007b6d5` have
  identical tree `2960653d7caab56de4f15bbcf3adf663d2930e9d`. The cumulative PR
  diff is 145 files (+68,521 / -1,323 lines).
- GitHub branch/PR audit after publication found 27 branches and 22 open PRs
  (#2-#23). The earlier PR chain remains intact.
- Updated the branch consolidation audit, execution frontier, final evidence,
  and closure index with the PR URL, refs, and current review status.
- Checks remain: hardware utility tests 19/19 PASS; reference-model tests
  44/44 PASS; Python byte-compile PASS; final coverage gate `RAW_100_OPEN`;
  evidence index SHA/size audit PASS. Current Product Raw metrics and OPEN bins
  are unchanged from the frozen Linux package.
- Remaining: 21,320 Raw code bins OPEN; physical/vendor XPM/GT Wizard, FPGA
  PPA, and QAM256 BER remain outside this Linux signoff.

## 2026-11-02 12:32 SGT - Thermo5 TX Dynamic Oracle Phase A

- Completed PR-A work on `codex/thermo5-tx-dynamic-oracle`, based on
  `thermo5` SHA `2d7a58df43f7bffecd3d34edd2f21bb3262abe2b`. No product RTL or
  frozen algorithm changed.
- Extended the independent Python trace oracle for sequence/epoch integrity,
  partial-frame reset causal prefixes, transaction-derived STATUS, and strict
  COMMIT/Pending/Frame Apply/ACK/completion order. Added checker mutations for
  PA data, STATUS, trace order, and commit ordering.
- Added source-valid gap length recording, replaced the UVM RUN_ACTIVE/DRAINING
  predictor's use of DUT core status outputs with accepted-transaction-derived
  lifecycle state, and extended the product reset sweep for partial DSP frames.
- Evidence report and machine-readable manifest:
  `docs/verification/thermo5-tx-phase-a-evidence.md` and
  `docs/verification/data/thermo5-tx-phase-a-evidence.json`. Detailed VCS logs,
  JSONL traces, Python suite log, and their SHA-256 values are retained under
  the ignored local `runs/thermo5_tx_system_phase_a/` directory.
- Checks: Python suite 57/57 PASS; Python byte compilation PASS; VCS
  V-2023.12-SP1 STOP/Restart seed 610215 PASS (112/112 PA words); one-cycle
  source-gap seed 610216 PASS (112/112, gap=1, underflow=0); reset sweep seed
  610802 PASS (4 partial-frame resets, 5 CDC residual resets, 56/56 replay,
  91 accepted PA words); all three dynamic trace replays PASS; `git diff
  --check` PASS.
- URG aggregation/Raw-Adjusted code-coverage review and VC Formal were not run. No FPGA, XPM/GT
  Wizard, RF, or BER signoff is claimed. Phase B/C random verification,
  Phase D coverage/formal closure, and Phase E benchmark review remain open.
## 2026-11-02 12:42 SGT - Thermo5 TX Phase B agent organization

- Added an active/passive PA sink agent as the only procedural `PA_READY`
  writer, an active Control agent for reset/direct-core enable, a virtual
  sequencer, and an AXIL packet RUN/STOP/drain smoke sequence. Migrated test PA
  backpressure requests to the PA agent API. Added a configuration guard around
  the AXIL-only outstanding-counter SVA bind after non-AXIL compile exposed
  references to signals absent from that DUT.
- Implementation source commit: `35115626a95c14db76e29ee36bf68f5d80132aba`.
  Product RTL, TX algorithm, and product defaults are unchanged.
- VCS V-2023.12-SP1 product tests passed: AXIL virtual-sequence seed 620301,
  graceful STOP/Drain seed 620304, and reset sweep seed 620305. All had 56
  post-reset/product PA words as applicable, zero PA/predictor mismatches,
  zero underflow, and zero UVM errors/fatals. The reset sweep included four
  partial-DSP-frame resets and five CDC residual resets.
- The legacy non-AXIL bubble test is retained as diagnostic only: its default
  80-cycle gap run recorded 361 underflow cycles (180 before final source
  acceptance) despite printing its existing PASS marker. With a one-cycle gap,
  early underflow was zero but the direct-core/no-drain test still recorded
  100 sticky underflow cycles after source completion. Neither run is counted
  as a legal product regression. Phase C must use the AXIL packet/drain path
  and reject unexpected underflow.
- Evidence commands and log SHA-256 values are recorded in
  `docs/verification/thermo5-tx-phase-b-evidence.md` and
  `docs/verification/data/thermo5-tx-phase-b-evidence.json`. Per-test coverage
  instrumentation was enabled, but no URG aggregation or Raw/Adjusted
  percentage was run. Dynamic clock fault control, Phase C randomization,
  Phase D Formal/coverage closure, and Phase E benchmarking remain open.
- Checks: AXIL VCS compile + virtual-sequence smoke, AXIL graceful STOP/Drain,
  AXIL reset sweep, non-AXIL compile and diagnostic bubble runs, SVA bind
  configuration check, direct `PA_READY` writer scan, `git diff --check`, and
  JSON manifest parse. No RTL/XSim, RX, AI-DPD, Vivado, or physical flow ran.

## 2026-11-02 13:01 SGT - Thermo5 TX Phase C minimum random qualification

- Completed the minimum runnable Phase C campaign on implementation source SHA
  `26a9f0482e952f70ed62c438aa9201e626bd103e`; the frozen product RTL and TX
  algorithm remain unchanged.
- Ran 100 56-word packet seeds and 10 112-word long-stream seeds. All 110 VCS
  UVM tests and 110 independent Python trace-oracle replays passed with exact
  four-plane PA comparison, zero unexpected underflow, and zero predictor,
  protocol, transaction-count, UVM error, or fatal failures. URG merge passed.
- Added the Phase C evidence report and machine-readable evidence/VDB manifests.
  Independently checked all 110 trace/UVM/oracle log hashes, 111 VDB file
  counts, byte totals and tree fingerprints, evidence hashes and JSON syntax.
  The canonical sorted-path/size/file-SHA algorithm is recorded in the VDB
  manifest.
- Updated the system-verification specification and execution frontier to
  distinguish the completed minimum random milestone from remaining Phase C
  work. The URG percentages are mixed-hierarchy exploratory results, not
  DUT-only Raw/Adjusted signoff.
- Checks: Python 3.12.13 reference suite 57/57 PASS; VCS V-2023.12-SP1 and URG
  campaign 110/110 PASS (run before this documentation-only follow-up); trace
  and evidence integrity checks PASS; JSON parse PASS; `git diff --check` PASS after documentation edits.
- Remaining OPEN: non-Identity runtime DPD randomization, randomized COMMIT
  and reset epochs, exact SV cross closure, Phase D DUT-only Code Coverage /
  Formal / Waiver signoff, Phase E Linux benchmark review, and separate XPM,
  GT Wizard, FPGA PPA and physical RF/QAM256 validation.

## 2026-11-02 13:06 SGT - Publish Thermo5 TX Phase C PR #29

- Published `codex/thermo5-tx-system-random` as PR #29 targeting the exact
  open PR #28 head `991591dca3bf710405e5cd3a35ea855f23248dfa`.
- GitHub head commit is `983c1a4ad217d0abf68b2e14a3ccb2d34f79b0b6`; its tree
  `22fa3cd65eec9869ff58f0dd9646104ba6228f74` matches local reviewed tree
  `22fa3cd65eec9869ff58f0dd9646104ba6228f74`. GitHub reports the PR open,
  mergeable, 17 files, and unmerged. PR #27 and PR #28 are also unmerged.
- No product RTL or frozen algorithm changed. Phase C remains a minimum random
  qualification; deferred DPD/COMMIT/reset dimensions, complete exact cross
  closure, Phase D/E, and FPGA/physical signoff remain open.

## 2026-11-03 10:18 SGT - Thermo5 TX Linux system verification closure

- Closed the previously open Phase C test dimensions with retained evidence:
  110 packet/long-stream seeds, a 60-tuple runtime DPD × gain × profile
  matrix, 48 randomized reset/COMMIT trials, directed reset/commit and source
  gap/PA-stall/FIFO-full crosses, and an expected-starvation test with an
  independent bit-true PA checker. The frozen product RTL and algorithm remain
  unchanged.
- Regenerated Raw and Adjusted URG from the same 243 test VDBs and current
  product design VDB. The 243-test provenance is mixed: 240 positive and two
  expected-negative prior test VDBs plus one additive starvation VDB. RTL
  sources are unchanged across the two source revisions. Raw and Adjusted
  remain equal; the gate is `RAW_100_OPEN`, with 21,078 open code records.
- Repaired waiver-pipeline handling so PENDING candidates can map to exact
  current OPEN Raw bins without producing exclusions. APPROVED candidates
  still require exact proof, source/configuration binding, reviewer and
  approval reference. The fresh audit reports 371 PENDING, zero approved and
  zero active exclusions.
- Legal applicable functional coverage is 392/392; 24 URG-model-excluded rows
  and the illegal-only frame bins remain in the audit artifacts. Positive
  assertion inventory has 13 successes, zero failures, two uncovered and two
  without attempts. Expected negative assertion failures are reported
  separately.
- VC Formal counter-guard run was non-vacuous but INCONCLUSIVE after 502 s;
  DPD Identity Formal remains inconclusive. Neither was waived. XPM, GT Wizard,
  Vivado PPA/routed timing and physical RF/QAM256 remain open.
- Updated `docs/verification/thermo5-tx-linux-system-verification-signoff.md`,
  its machine-readable evidence manifest, a superseding addendum to the Phase C
  report, and the active execution frontier. Committed the waiver-pipeline correction and tests as
  `52892f66b4fc80ac41557272a1434ac216ddd073` (local commit; not pushed or
  merged).
- Checks: Python reference tests 58/58 PASS; hardware utility tests 34/34
  PASS; Python compile and `git diff --check` PASS; starvation UVM/Python
  oracle PASS; Raw/Adjusted URG PASS; functional coverage gate 392/392 legal
  bins and `RAW_100_OPEN` code result. Counter Formal remains INCONCLUSIVE.
- Evidence, logs and VDBs are under ignored `runs/thermo5_tx_closure_current/`;
  generated data is SHA-indexed in
  `docs/verification/data/thermo5-tx-linux-system-verification-signoff.json`.

## 2026-11-03 16:10 SGT - Thermo5 TX outstanding-counter long-stream refresh

- Extended the public-interface outstanding-counter stress to 2,072 accepted
  samples across 37 legal 32-beat packets with source and PA backpressure. Seed
  930901 passed the independent four-plane bit-true checker for 2,072/2,072
  output words, observed maximum outstanding occupancy 28, and recorded zero
  saturation/underflow guard events or UVM warnings/errors/fatals. Product RTL
  and frozen algorithm remain unchanged.
- Refreshed Raw and Adjusted URG from the same 246-test VDB inventory plus one
  design VDB. Raw equals Adjusted with zero approved waivers and zero active
  Exclusions. Toggle increased by 160 hits to 84340/104480; Branch remains
  525/637, Condition 658/849, Line 3351/3796, FSM states 13/13 and transitions
  17/22. Applicable Functional Coverage remains 392/392. The gate remains
  `RAW_100_OPEN`; 20,893 code records in 457 root-cause groups remain OPEN.
- Rebound the 371 waiver candidates to the 246-test report and current compile
  manifest. 361 remain configuration-unreachable candidates and 10
  formal-unreachable candidates; all remain PENDING. No reviewer approval or
  Exclusion was fabricated.
- Both exact outstanding-counter Branch bins remain OPEN. The product-bound
  counter assertions and guard Covers remain INCONCLUSIVE; the long-stream
  maximum is simulation evidence, not a reachability proof.
- Added `thermo5-tx-outstanding-counter-stress-20261103.md` and its evidence
  JSON, plus the round-3 waiver audit review note. Updated the Linux system
  signoff, execution frontier, and current waiver status.
- Checks: VCS V-2023.12-SP1_Full64 targeted UVM PASS; Raw/Adjusted URG refresh
  and fail-closed gate PASS (`RAW_100_OPEN`); Python reference suite 59/59 PASS;
  hardware utility suite 38/38 PASS; Python compile checks PASS; `git diff
  --check` PASS before final documentation-only edits. Full regression was not
  rerun. Exact VCS/URG logs and VDBs remain under ignored `runs/` and are
  SHA-indexed in the evidence JSON.
- GitHub PR #27 → #28 → #29 → #30 → #31 dependency chain was checked; all are
  open and unmerged, with #30 and #31 drafts. No PR was merged in this step.

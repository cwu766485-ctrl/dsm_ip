Warning: truncated output (original token count: 86870)
Total output lines: 4818

## 2026-10-31 00:31 SGT - Classify and reproduce TX product cadence review

- Added read-only centered-cubic queue event probes and a two-packet AXI-Lite
  product UVM test. The same fixed waveform seed was exercised at nine legal
  source-start phases and seventeen RUN-start phases; all 112 four-plane
  outputs and DPD counters matched in every run.
- Each interpolation instance reached and popped `q_count==1 && q0_end`, but
  no same-edge `push_input` occurred. The two exact line-255 Branch bins remain
  OPEN; no Formal disposition, waiver, exclusion, or denominator change was
  made.
- Merged one passing phase VDB into a diagnostic URG report and ran the
  fail-closed gate. Raw code metrics were unchanged (line 3190/3796, condition
  583/846, branch 440/637, toggle 86951/104478); zero waivers/exclusions and
  `RAW_100_OPEN` remain.
- Classified the two exact bins as product-cadence alignment tasks (not
  structurally unreachable), bound diagnostic-only testbench changes to
  source hashes, and added all 26 run-log hashes plus exact VCS/URG commands to
  `docs/verification/data/thermo5-tx-frame-replacement-coverage-review.json`.
- Checks: current VCS compile PASS; 26/26 phase UVM runs PASS with 0 errors
  and 0 fatals; diagnostic URG PASS; coverage gate PASS (`RAW_100_OPEN`); raw
  coverage delta 0; no full regression or TX RTL change.
- Remaining: product-bound Formal/causality review for the missing two
  pop/push Branch events; 18,588 code-gap rows remain OPEN.

## 2026-10-31 00:10 SGT - Re-audit TX Formal dispositions and reject tautologies

- Reran the AXI-Lite configuration proof on current harness/DUT hashes with
  VC Formal V-2023.12-SP2. Clean run: 4/4 assertions proven, one legal read
  transaction Cover hit, three exact paths uncoverable, zero assumptions,
  zero black boxes, zero setup violations, three non-vacuous assertions, and
  no tautological goals. The write-address `default` Raw bin at line 246 now has
  exact current-source assertion/Cover evidence.
- Re-audited prior exact-bin dispositions. Removed two candidates whose exact
  assertions had VC Formal tautology warnings: the constant `MAX_TAPS=1` guard
  and an interpolator append-arm property. Both are restored to OPEN and remain
  in Raw; no waiver or exclusion was applied. Five valid exact dispositions
  remain and 18,588 of 18,593 code-gap rows are OPEN.
- Hardened the Formal runner/disposition utility to reject exact tautological
  goals, track reviewed OPEN candidates, and refresh counts without mutating
  Raw URG. Updated the formal ledger, root-cause report, signoff snapshot, and
  execution frontier.
- Checks: focused VC Formal run PASS; Formal disposition reconciliation PASS
  (5 `PROVEN_UNREACHABLE`, 18,588 OPEN, zero exclusions); root-cause and
  Formal utility tests PASS; Python compilation and `git diff --check` PASS.
- Limits unchanged: Raw DUT code coverage remains 84.0358% line, 68.9125%
  condition, 69.0738% branch, 83.2242% toggle; legal positive Functional
  Coverage is 210/210. DPD Identity remains inconclusive; source-gap underflow
  remains unresolved; actual XPM, GT Wizard, FPGA PPA/timing, and physical
  QAM256 BER remain outside Linux signoff.

## 2026-10-31 00:01 SGT - Refresh licensed TX Raw URG and source-bound closure

- Resumed the fixed Centered-Cubic / EF2 / identity-DPD product compile after
  VCS license recovery. Two focused AXI-Lite UVM tests passed (reset sweep and
  register access); merged their VDBs with 27 retained exact-source test VDBs
  and the compile VDB. The complete regression was not rerun.
- Refreshed Raw URG and the fail-closed gate. Raw and Adjusted remain identical
  with zero waivers/exclusions; all code metrics are unchanged. Functional
  coverage remains 210/214 scoreable records and 210/210 legal positive bins.
- Bound nested URG Branch predicates to exact RTL source lines, correcting the
  DPD saturation location mapping. The source-linked ledger remains 18,593
  records / 492 tasks, with six exact Formal-proven unreachable rows retained
  in Raw and 18,587 OPEN.
- Added a VCS refresh evidence JSON with exact commands, versions, log/report
  hashes, VDB reuse counts, coverage denominators and gate state. Updated the
  final signoff, root-cause closure, execution frontier and checked-in audit
  artifacts. No TX RTL, algorithm, RX, or AI-DPD source changed.
- Checks: VCS compile PASS; reset-sweep UVM PASS; register-access UVM PASS;
  URG merge PASS; Raw coverage gate PASS (`RAW_100_OPEN`); Python compile PASS;
  7 focused audit-tool unit tests PASS; exact report, summary, gate and
  root-cause inputs SHA-validated.
- Remaining: no code-coverage increase from the two new tests; 18,587 rows
  remain OPEN, DPD Identity Formal remains inconclusive, and the 16-cycle
  source-gap underflow contract remains unresolved. Real XPM, GT Wizard,
  FPGA PPA/timing and physical QAM256 BER remain outside Linux signoff.

## 2026-10-30 22:34 SGT - Reconcile TX product source scope and Raw gate

- Added a deterministic product compile-source manifest derived from the saved
  VCS transcript. It covers 73 local parsed sources plus the filelist and
  coverage hierarchy; all 75 hashes match the captured source manifest and
  current checkout. Fourteen unrelated broad-manifest entries are disclosed
  as not parsed by this product compile.
- Re-ran the zero-waiver coverage gate against the fixed Raw product URG data.
  Gate audit passed and reported `RAW_100_OPEN`; Raw and Adjusted remain
  identical with zero waivers/exclusions. The full functional audit remains
  210/210 legally applicable bins, with four negative-only Raw zero-hit rows.
- Checks: source-manifest derivation PASS; coverage gate audit PASS; the
  `--require-closed`, nonempty-waiver, active-`.el`, and stale-source probes
  all failed closed as expected. Replayed the Formal disposition updater on
  temporary copies: 18,593 rows reconciled, six exact proofs retained, 18,587
  OPEN. Python compilation, JSON/gzip integrity, bin/hash reconciliation, and
  `git diff --check` PASS.
- Limits: fresh VCS/URG remains blocked by WSL kernel support. Nonempty
  approved CSV → `.el` → adjusted URG is not exercised. 18,587 code gaps remain
  OPEN; Identity DPD is Formal-inconclusive; targeted product pop/push coverage
  remains unhit; source-gap underflow and real XPM/GT/PPA/physical QAM256 BER
  remain unresolved.

## 2026-10-30 22:21 SGT - Complete TX functional-bin audit and signoff correction

- Added a deterministic URG HTML exporter that inventories every current
  product Functional Coverage coverpoint and generated cross bin in both
  covergroup-type and monitor-instance views, with count, applicability,
  existing URG status, and source-page SHA.
- Full report audit: 226 rows total, 214 denominator-eligible records, 210
  hits, four negative-only misses, and 12 bins already marked Illegal/Excluded
  by the original URG model. The previous 170/174 tally omitted 40 generated
  EF2 cross-bin records. Corrected current reports to 210/214 and 210/210 legal
  positive records; no URG database, denominator, or exclusion was changed.
- Refreshed the deterministic root-cause audit summary and manifest, then
  reapplied the six exact source-bound `PROVEN_UNREACHABLE` dispositions.
  Raw code coverage remains unchanged: 18,593 gaps, 18,587 OPEN, six proven
  unreachable but retained in Raw; zero approved waivers/exclusions.
- Updated the final signoff, current coverage closure, baseline, checklist,
  command index, and execution frontier. No TX RTL or algorithm changed.
- Checks: Python 3.12 compilation PASS; full functional report parser PASS
  (all eight groups reconcile to 214 scoreable rows and the four exact misses);
  root-cause extractor PASS; Formal disposition validator PASS; JSON/gzip
  integrity and `git diff --check` PASS. No new VCS/URG regression was run:
  the installed VCS location check rejects the WSL kernel, so existing Raw URG
  is explicitly reused.
- Remaining: two targeted legal UVM packetizations still miss interpolator
  single-entry pop/push, and their test source is absent from the tracked tree;
  DPD Identity remains Formal-inconclusive; 18,587 code
  gaps remain OPEN; adjusted URG/wavier validation, source-gap contract, real
  XPM/GT, FPGA PPA, and physical link signoff remain OPEN.

## 2026-10-30 21:18 SGT - Audit TX functional bins and code-gap root causes

- Added a deterministic Linux/Python audit for the latest product-only
  VCS/URG evidence. It reports the four exact 170/174 Functional Coverage
  records, resolves them to two illegal-frame-only semantic bins, and confirms
  all 170 legal positive semantic bins are hit. Raw remains 170/174; no bin,
  group, or denominator was changed.
- Preserved and enriched all 18,593 Raw code-gap rows (197 Branch, 263
  Condition, 606 Line, 17,527 Toggle) into 492 location-rooted closure tasks.
  All rows remain OPEN; zero waivers/exclusions are applied. Raw and Adjusted
  coverage remain identical.
- Audited 17 duplicate historical Condition bin IDs. Each collision joins
  full-expression and subexpression bins on the same source line. Recovered
  expression identity from raw URG module pages and emitted unique semantic
  IDs without dropping rows or changing denominator.
- Recorded one source-manifest mismatch in the later AXI-Lite Formal harness.
  Product RTL/UVM simulation compile inputs match the recorded Raw evidence;
  Formal results from the changed harness are not represented as current and
  must be rerun in the final fixed-SHA package.
- Added the root-cause report, row/task CSVs, functional-bin audit, summary,
  input/output SHA manifest, execution command, and reproducibility section in
  docs/ai-native/commands.md. Updated the active execution frontier.
- Checks: Python 3.12 py_compile PASS; audit script PASS; consistency checks
  confirm 18,593 unique row IDs and expression-aware semantic IDs, 492 unique
  task IDs with 18,593 assigned bins, exactly four functional audit rows, and
  only OPEN code-gap dispositions. No VCS or Formal regression was rerun;
  existing fixed-source URG evidence was reused.
- Remaining: targeted legal Branch/Condition closure (Step 3 onward), Formal
  reachability and Identity-DPD resolution, source-gap contract disposition,
  waiver/exclusion gate validation, and fixed-SHA final signoff remain OPEN.

## 2026-10-30 17:02 SGT - Publish Phase 0/1 TX closure PR #8

- Opened draft PR #8, `Thermo5 TX: Phase 0/1 Linux design and verification
  closure`, stacked on PR #7; it remains open and unmerged.
- The locally tested implementation commit is
  `99c852dc46cbb9091c6099267535465acfac2d47`; the initial GitHub PR head was
  `3da1ab21142218ce795252bd62d8865176a9ffe5`. Their complete tree SHA matched
  at publication (`20a10962b1979349b15fcbf9a9b4807f78f26786`).
- Updated the active execution frontier to reflect the published PR and its
  review as the next action. No RTL, verification behavior, product coverage,
  or benchmark result changed in this publication bookkeeping. A docs-only
  follow-up commit synchronized the frontier on the PR branch.
- Checks: clean source state before this note; PR metadata confirms open,
  draft, unmerged, with PR #7 as base; updated documentation passed
  `git diff --check`.

## 2026-10-30 16:54 SGT - Complete TX Phase 0/1 Linux closure studies

- Reconciled PR #2–#7 ancestry and the current PR #7 base; recorded the frozen
  GT-parent product configuration, exact product-source identities, historical
  PR #5 manifest discrepancy, and reusable current coverage evidence.
- Added the four-cell QAM256 architecture A/B benchmark with shared stimulus,
  receiver, nominal/stress behavioral output assumptions, per-seed CSV/JSON,
  held-out spectrum and constellation figures. Kept first-order STEP=7168 as a
  separate sensitivity point.
- Added nominal behavioral-DPA ILA fitting for two-/four-tap signed Q2.14 DPD,
  held-out evaluation with BER confidence intervals, and PA/output-chain
  PAPR, compression count, modeled power, and adjacent-band proxy metrics.
  Both fitted DPD images passed standalone 93,184-sample VCS bit-true miters;
  neither was promoted over identity.
- Extended the PAIR_LOOKAHEAD equivalence test with an exact final-pair
  quantizer tie, both clamp polarities, output stalls, input bubbles, and a
  drained midstream reset. The 4,096-cycle VCS comparison passed for handshake,
  output data, and all four EF2 state registers.
- Added compact review artifacts and a SHA-256 evidence packager under
  `docs/verification/data/` and updated the architecture report, baseline,
  signoff checklist, command index, and execution frontier. Product RTL,
  defaults, coverage denominator, and product VDB merge are unchanged.
- Checks: Python 3.12 compile plus 44/44 unit tests PASS; fitted 2-tap and
  4-tap VCS bit-true miters PASS (93,184 I/Q samples each); PAIR_LOOKAHEAD VCS
  miter PASS (4,096 cycles; 103 negative ties, 408 positive clamps, 409
  negative clamps, 817 stall cycles, 616 input bubbles, one reset epoch);
  architecture and DPD held-out benchmarks PASS; evidence packager PASS with
  all referenced local run artifacts present. Product coverage is reused,
  not rerun: Raw 81.99%, functional 170/174 raw and 170/170 applicable
  positive, `RAW_100_OPEN`.
- Remaining: no approved BER/BLER/EVM/ACLR/power limits; model profiles are not
  calibrated; no measured pair-lookahead timing/PPA; raw DUT code coverage and
  DPD identity Formal remain open. XPM/GT Wizard, Vivado routed PPA, and
  physical QAM256 BER are NOT_RUN. Independent PR is pending; it is not merged.

## 2026-10-30 14:18 SGT - Prove AXI-Lite product tap guard reachability

- Extended the focused AXI-Lite Formal harness for the exact product
  `MAX_TAPS=1` setting. VC Formal V-2023.12-SP2 reported 5/5 assertions
  proven and 1/2 covers hit; the invalid-parameter guard cover is
  `uncoverable`. The new parameter assertion/cover are static tautologies,
  explicitly recorded as elaboration evidence rather than temporal proof.
- Setup reported zero clock, glitch, combinational-loop, oscillation, and
  multidriver violations; zero black boxes. The guard Raw bin at
  `thermo5_dpd_axi_lite_cfg.sv:348` remains in the denominator and has no
  waiver/exclusion.
- Added the exact command, console, property/setup report, source manifest,
  run tree hash, and source SHA/tree to the Linux closure evidence.
- Checks: VC Formal PASS; source SHA `36d88f41de20202bd42d98fa9b510cb8dc1bf0f7`
  was clean; evidence artifacts parsed and hashes validated; `git diff
  --check` PASS. No VCS Raw merge or full regression was repeated.
- Raw remains unchanged at 81.99%, with 170/174 raw functional bins and
  170/170 applicable positive bins. `RAW_100_OPEN` remains.
- Remaining: Task 4/5/6 are partial; identity-DPD Formal remains
  inconclusive; actual XPM/GT Wizard, routed FPGA PPA, product BER/BLER target,
  and physical QAM256 BER remain open.

## 2026-10-30 14:12 SGT - Prove EF2 product parameter reachability

- Added a focused VC Formal harness for the exact product EF2 parameters
  (`W=16`, `CHANNELS=32`, default `PAIR_LOOKAHEAD=0`) and invalid-parameter
  guard. The clean-source run at `f6956b9` proves 2/2 static assertions and
  confirms both corresponding covers are `uncoverable`; no black boxes or
  setup violations. These results are parameter reachability evidence, not
  URG hits or waivers.
- Ran the exact-product mailbox corruption fault test at seed 420103. VCS
  observed the expected `$error`, the test released the injection and checked
  public-reset recovery, and UVM warnings/errors/fatals were zero. Its VDB is
  reported only in the expected-negative URG report.
- Confirmed the legal AXI-Lite register-access test passes; its same-seed
  stimulus was already present in the positive product VDB set, so the
  diagnostic rerun is not added to the merge.
- Product Raw coverage did not change: 3,190/3,796 lines, 583/846 conditions,
  440/637 branches, 86,951/104,478 toggles, 13/13 FSM states, 22/22 FSM
  transitions, and 170/174 raw functional bins (170/170 applicable positive).
  Raw equals adjusted; zero waivers/exclusions; gate remains `RAW_100_OPEN`.
- Evidence commands, logs, VDB/report/formal hashes and the exact Formal source
  commit are indexed in `thermo5-tx-linux-coverage-closure-evidence.json`.
- Checks: focused VC Formal PASS; mailbox expected-negative check PASS;
  `python3.12 -m py_compile`, Formal runner `--help`, `git diff --check`, and
  evidence JSON/hash validation PASS. No VCS product Raw merge or full
  Gate 0–3 regression was repeated.
- Remaining: Task 4–6 remain partial; DPD identity Formal is inconclusive;
  Raw 100%, actual XPM/GT Wizard, routed FPGA PPA, product BER/BLER target and
  physical QAM256 BER remain open.

## 2026-10-30 13:44 SGT - Resume product coverage closure with restored licenses

- Recompiled the exact TX product VCS configuration at source commit
  `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b`; VCS completed all 20 modules.
  Simulation inputs remain the product filelist at `913be930`; the changed
  AXI-Lite Formal harness is not included in that simulation filelist.
- Ran a targeted two-frame source-gap sweep at 2/4/8/16 cycles (seeds
  610834–610837). Gaps 2/4/8 passed the independent four-plane checker with
  112/112 outputs and no early underflow or UVM errors/fatals. Gap 16 failed
  the stream-contract check with 54 underflow events despite 112/112 outputs,
  2/2 TLASTs, and zero protocol errors. The UVM_FATAL is the failure oracle
  (VCS exits 0 after `$finish`); its VDB was excluded from the positive merge.
  The four sample points do not define an exact starvation threshold.
- Refreshed product URG from 29 product-scoped simulation VDBs plus the compile
  VDB. Coverage numerators/denominators did not change: aggregate 81.99%, line
  3,190/3,796, condition 583/846, branch 440/637, toggle 86,951/104,478, FSM
  13/13 states and 22/22 transitions. Functional coverage is 170/174 raw bins,
  all 170 legal positive bins hit. Raw equals adjusted; zero waivers/exclusions;
  gate `RAW_100_OPEN`. The 18,593-row source-linked ledger remains open/review.
- Updated the Formal harness instance to `MAX_TAPS=1` and added a targeted
  coefficient-read default reachability assertion plus a legal-read cover.
  VC Formal PASS: 4/4 assertions, 1/1 cover, target non-vacuous, zero setup
  violations, and two vacuous reset assumptions. The raw branch bin remains
  included and no waiver is applied.
- A bounded identity-DPD helper-constraint Formal attempt completed in 131.33
  seconds with 1/13 assertions proven, 12/13 inconclusive, 4/4 covers hit, zero
  black boxes, and no counterexample. Identity payload and no-saturation remain
  OPEN; the harness and RTL were unchanged for this attempt.
- Refreshed the closure report, machine-readable evidence (including artifact
  hashes), Gate 3 coverage landing note, final signoff landing note, execution frontier, and this update log.
- Checks: product VCS compile PASS; three source-gap tests PASS and one FAIL as
  reported; exact-product AXI-Lite read-default Formal PASS; product URG/gate/
  ledger refresh PASS with `RAW_100_OPEN`; evidence JSON and tracked artifact
  hashes revalidated; `git diff --check` PASS; JSON parsing and selected current artifact hashes PASS; coverage gate re-evaluation matches the stored `RAW_100_OPEN` result.
- Remaining: Task 4–5 remain partial, Raw 100% remains open, identity DPD
  Formal and frame-tail reachability remain open. Real XPM, GT Wizard, FPGA
  PPA/routed timing, and physical QAM256 BER remain outside Linux signoff.

## 2026-10-30 13:32 SGT - Verify zero-gap continuous product frames

- Ran the two-frame one-tap identity product test with no source-clock bubble
  between frames, using the product-filtered simulator at seed 610823. The
  independent checker matched 112 words on all four planes, two TLASTs and
  114 DPD samples per lane; UVM warnings/errors/fatals were zero. The direct
  Generic wrapper's 71 post-source finite-tail diagnostic cycles and
  `early_underflow=0` are both recorded.
- Merged the scoped zero-gap VDB with the prior product VDB set and regenerated
  URG, Raw summary, gate, and source-linked ledger. Raw totals did not change:
  81.99% aggregate, 583/846 conditions, 440/637 branches, and 26 simulation
  VDBs plus the compile VDB. The ledger remains 18,593 open/review records;
  no waiver or exclusion was added.
- The exact command, logs, VDB/URG trees, and SHA-256 values are indexed in the
  closure evidence JSON. `git diff --check`, JSON validation, source manifest
  checks, coverage gate and artifact-hash checks pass. No full regression was
  rerun and no RTL/algorithm was changed.
- Remaining coverage, formal, vendor-XPM/GT, FPGA PPA, and physical QAM256
  limits are unchanged from the current closure report.

## 2026-10-30 13:26 SGT - Continue licensed TX Linux coverage closure

- Added a product-configured legal two-frame identity test with one source
  clock bubble at the frame boundary, plus a targeted 64-cycle all-plane PA
  backpressure run. RTL, RX, AI-DPD, and frozen TX algorithms are unchanged.
  Local source SHA `913be930bfcbbad0f78dbc90e06299db3d1bb337` was uploaded to
  PR #7 as equivalent tree/commit `09c2e082876801d79946787d71f78082c4983f62`
  (`7bbee88ea7d6fbd3e0db1a61c1106cde1753c9d5`).
- The two-frame VCS run passed at seed 610824: 64 source beats, two TLASTs,
  112 output words on all four planes, 114 identity-DPD samples per lane,
  zero DPD saturation and zero UVM warning/error/fatal. `early_underflow=0`;
  the direct Generic wrapper's post-source finite-tail diagnostic (71 cycles)
  remains reported. The scoped PA-stall run passed seed 610825 with 56
  four-plane words, 65 observed PA stall cycles, zero UVM warning/error/fatal,
  and no Raw code-coverage delta.
- Rebuilt URG from 25 product-hierarchy-scoped simulation VDBs plus the
  product compile VDB. Raw/Adjusted is 81.99% aggregate; line 3190/3796,
  condition 583/846, branch 440/637, toggle 86951/104478, FSM 13/13 states
  and 22/22 transitions. The gap ledger has 18,593 open/review records.
  Waivers and exclusions remain zero; gate remains `RAW_100_OPEN`.
- Re-ran the fail-closed coverage gate against the updated source manifest.
  Regenerated the source-linked gap ledger. VC Formal on the actual AXI-Lite
  configuration block proved 3/3 assertions, including non-vacuous proof that
  the legal write response cannot reach the `case default` at line 282; zero
  clock/glitch/loop/multidriver setup violations. The corresponding Raw bin
  remains included pending independent waiver review.
- Exact logs, commands, VDB/URG/formal tree hashes, source manifest, test counts,
  and remaining limits are recorded in `thermo5-tx-linux-coverage-closure.md`
  and its evidence JSON. `git diff --check`, JSON parse and coverage gate pass.
  Full Gate 0–3 regression was not rerun.
- Remaining: 606 lines, 263 condition vectors, 197 branches, 17,527 directional
  toggles and 2 uncovered/2 unattempted DUT assertions; 37 branch arms remain
  in general review. DPD identity arithmetic Formal remains inconclusive.
  Actual XPM/GT Wizard, Vivado FPGA PPA, physical QAM256 BER and product
  BER/BLER acceptance target remain open. No claim of Raw 100% is made.

# Update Log

## 2026-10-29 - Complete Linux TX Gate 2 model campaign

- Added reproducible held-out EF2/STEP/input-level/backoff/PAPR/state-width,
  fixed-image DPD A/B, and four-plane gain/skew/fault sensitivity campaigns.
  The campaigns use deterministic Python models and leave the product RTL and
  default configuration unchanged.
- Gate 2 selected the finite-set RMS 0.10 / STEP 5120 / 20-bit / no-clip
  point: 21/224,256 digital errors (BER 9.3643e-5), mean EVM 2.4640%, and
  SNDR 32.1675 dB. The modeled nominal/stress BERs are 1.4269e-4 / 7.7144e-4.
  No product communication target or calibrated RF model is available, so
  this is not a stable-link or physical BER signoff.
- The tested fixed 2/4-tap DPD images regress versus identity; the result
  rejects those images only. Pair-look-ahead remains an equivalence-proven
  experiment with no FPGA PPA and is not enabled in the product hierarchy.
- Exact commands, seeds, JSON/log SHA-256 values, assumptions, and limits are
  in `docs/verification/thermo5-tx-worst-case.md` and
  `docs/verification/thermo5-tx-gate2-evidence.json`. Python unit tests passed
  39/39. Full logs and JSON outputs remain under ignored `runs/`.
- Gate 2 model work is complete for the Linux scope; acceptance against a
  product BER/BLER/EVM/ACLR target and hardware PPA remain open. No RX or
  AI-DPD source changed.

## 2026-10-29 - Complete Linux TX Gate 3 coverage audit checkpoint

- Strengthened EF2 positive/negative saturation and stall checks on every
  thermometric branch; added an AXI-Lite EF2 qualification target, signed input
  endpoint checking, and a legal digital corner-vector generator. Corrected
  TLAST/backpressure coverage to correlate accepted packet output targets,
  rather than using cumulative TLAST counts.
- Re-ran the current Linux Generic and AXI-Lite VCS/UVM regressions, EF2
  saturation/rail/stall/reset qualifications, STOP/drain/restart, digital
  corner tests, scoped EF2 and pair-look-ahead VC Formal, and a negative
  one-LSB oracle mutation. Then reran current-source non-identity 2-tap and
  4-tap DPD bit-true cases for one and two packets; all four cases matched
  every output plane with zero UVM errors/fatals. Python tests passed 39/39.
- Applicable functional covergroups are 4/4 Generic and 8/8 AXI-Lite at
  100%. Raw project RTL URG remains 80.81% Generic and 84.59% AXI-Lite; AXI-Lite
  toggle coverage rose to 96.63% after the DPD VDB merge. The refreshed
  22,720-row source-mapped ledger preserves every miss as OPEN.
  No exclusions or denominator edits were made, and no adjusted score is
  claimed. Gate 3 code coverage is therefore not signed off at 100%.
- The coverage report records exact test commands, raw metric counts,
  assertions, limitations, and hashes. The complete CSV is tracked as a
  reproducible gzip artifact with its uncompressed SHA-256 in
  `docs/verification/thermo5-tx-gate3-evidence.json`.
- Linux environment audit found VCS and VC Formal installed but no Vivado,
  XSim, Yosys, Verilator, or real XPM source. Current GT Wizard/XPM
  simulation, VCU118/ZCU111 Vivado PPA, and physical QAM256 BER remain open.
  A tracked-RTL cross-reference inventory found no module with zero textual
  references; no source was removed or archived without a safe candidate.
  No RX or AI-DPD source changed.
- Published as Gate 3 PR #5 at code commit
  `459c69094f3353558321075305808d9712e6f335`, stacked on Gate 2 PR #4 at
  `d65ac3762d344c1001552890ae81cd9d243a4910`. The consolidated Gate 0–4
  status is in `docs/verification/thermo5-tx-final-signoff.md`.

## 2026-10-29 20:38 SGT - Complete Linux TX Gate 1 functional A/B evidence

- Added a four-tap non-identity DPD fixed-point coefficient image, Python vector profile, and AXI-Lite UVM bit-true case. Re-ran two-tap and four-tap centered-cubic + EF2 streams at `STEP=5120`: each passed one-frame (56-word) and two-frame (112-word) comparisons on all four output planes with zero UVM errors/fatals.
- Re-ran the EF2 pair-lookahead miter (4,096 cycles, 2,662 accepts, both clamp signs, stalls and bubbles); VC Formal passed 7/7 assertions and 4/4 covers with zero black boxes. Python reference suite passed 37/37.
- Merged the four exploratory DPD VCS VDBs with URG. Raw AXI-Lite hierarchy: line 3320/4241 (78.28%), condition 596/1183 (50.38%), toggle 96408/125344 (76.91%), FSM 15/22 (68.18%), branch 410/841 (48.75%), assertion 11/17 (64.71%), group 59.7958%. No exclusions or denominator changes. This exploratory run does not replace Gate 0 baseline URG.
- Report and evidence manifest: `docs/verification/thermo5-tx-algorithm-ab.md` and `thermo5-tx-gate1-evidence.json`. Source commit `dfb15a278657e4417b545fc138df0f0dd0399ac4`; logs/VDB/formal artifacts and SHA-256 values are under ignored `runs/thermo5_tx_gate1_dfb15a2/`.
- Gate 1 Linux functional/equivalence evidence passes. DPD QAM256 benefit from calibrated coefficients and FPGA LUT/FF/DSP/Fmax remain open; no candidate was promoted into the product GT parent. No RX or AI-DPD source changed. Next: Gate 2 worst-case TX model, then Gate 3 coverage closure.

## 2026-10-29 20:22 SGT - Complete Linux TX-only Gate 0 verification

- Re-ran the Gate 0 suite at clean verification source SHA `04550289e1ecb5fa0e38168869d4f2539929cb80`. The first VCS checkout was blocked before compile; after license access recovered, Generic VCS, full AXI-Lite VCS, STOP/drain/restart, 2,072-word EF2 qualification, and Generic/AXI-Lite URG merges all passed. Python unit tests passed 36/36; EF2 scoped VC Formal proved 6 assertions and covered 3 properties with zero black boxes.
- Fresh Generic raw URG is 76.12% (line 2969/3593, condition 594/949, toggle 81740/102612, FSM 22/22, branch 336/540, assertion 13/17, group 69.2592%). The 784-row ledger now links to this exact run. No denominator changes or exclusions were applied. One expected illegal-frame assertion failure and three unattempted assertions remain explicitly open.
- Updated the Gate 0 baseline, feature/testpoint matrix, execution frontier, closure plan, coverage entry points, and evidence manifest. Full outputs remain under ignored `runs/thermo5_tx_gate0_0455028_recheck/`; generated logs, VDBs, and tool caches are not committed.
- Gate 0 is accepted for Linux Generic/behavioral scope. Real XPM, XSim/Vivado, current GT Wizard simulation, routed FPGA PPA, and physical QAM256 BER remain unavailable or out of scope. No RX/AI-DPD/RTL behavior or main-chain configuration changed.
- Next: run Gates 1/2/3 as separate reviewable stages; keep the verified baseline frozen until independent candidate evidence supports promotion.

## 2026-10-29 20:22 SGT - Complete Linux TX-only Gate 0 verification

- Re-ran the Gate 0 suite at clean verification source SHA `04550289e1ecb5fa0e38168869d4f2539929cb80`. The first VCS checkout was blocked before compile; after license access recovered, Generic VCS, full AXI-Lite VCS, STOP/drain/restart, 2,072-word EF2 qualification, and Generic/AXI-Lite URG merges all passed. Python unit tests passed 36/36; EF2 scoped VC Formal proved 6 assertions and covered 3 properties with zero black boxes.
- Fresh Generic raw URG is 76.12% (line 2969/3593, condition 594/949, toggle 81740/102612, FSM 22/22, branch 336/540, assertion 13/17, group 69.2592%). The 784-row ledger now links to this exact run. No denominator changes or exclusions were applied. One expected illegal-frame assertion failure and three unattempted assertions remain explicitly open.
- Updated the Gate 0 baseline, feature/testpoint matrix, execution frontier, closure plan, coverage entry points, and evidence manifest. Full outputs remain under ignored `runs/thermo5_tx_gate0_0455028_recheck/`; generated logs, VDBs, and tool caches are not committed.
- Gate 0 is accepted for Linux Generic/behavioral scope. Real XPM, XSim/Vivado, current GT Wizard simulation, routed FPGA PPA, and physical QAM256 BER remain unavailable or out of scope. No RX/AI-DPD/RTL behavior or main-chain configuration changed.
- Next: run Gates 1/2/3 as separate reviewable stages; keep the verified baseline frozen until independent candidate evidence supports promotion.

## 2026-10-29 18:17 SGT - Thermo5 TX-only Gate 0 baseline audit

- Audited exact `thermo5` source HEAD `eb1081bc7607ba2e9825d9e9fb32bcfa1c6a270e`, active ZU15EG TX parent parameters, UVM top/filelist, reference model, and Linux tool availability. Compared with plan checkpoint `759fc8e77446046cb942e7939c53ca49d3bde882`; the intervening source change is documentation-only and does not alter RTL, DV, constraints, or build inputs.
- Added a TX baseline report, feature/testpoint/coverage matrix, evidence metadata, and the full 784-record source-linked raw URG inventory. Corrected unsupported 79.86% “current” statements: the latest traceable Generic raw URG is 76.12% (line 2969/3593, condition 594/949, toggle 81740/102612, FSM 22/22, branch 336/540, assertion 13/17, functional group 69.26%). The inventory contains 100 uncovered source lines, 214 condition vectors, 108 branch vectors, 292 signal-direction toggle records, three unattempted assertions, and one assertion failure requiring review. No DUT-only denominator adjustment was made.
- Current checks: Python reference suite PASS (36/36); 56-word centered-cubic/EF2 identity oracle-vector generation PASS. Generic VCS full regression and scoped EF2 VC Formal were attempted at current HEAD but blocked before compile/proof by Synopsys license-server connectivity. AXI-Lite STOP/restart and 2,072-word qualification were not rerun for the same reason. Vivado/XSim/MATLAB/real XPM remain unavailable on this Linux host.
- No RTL, RX, AI-DPD, architecture, or coverage denominator changes. Gate 0 remains PARTIAL / ACCEPTANCE OPEN until exact-HEAD licensed VCS/URG and VC Formal runs are completed. The one raw assertion failure from the intentionally malformed-frame negative test remains visible and requires explicit review.
- Files: `docs/exec-plans/active/thermo5-tx-only-closure-codex.md`, `docs/verification/thermo5-tx-baseline.md`, `docs/verification/thermo5-tx-feature-matrix.md`, `docs/verification/thermo5-tx-gate0-evidence.json`, `docs/verification/thermo5-tx-coverage-ledger.csv`, `docs/verification/thermo5-dv-portfolio.md`, `docs/verification/thermo5-uvm-coverage.md`, `docs/exec-plans/active/execution-frontier.md`, and this log.
- Remaining limitations: exact-HEAD licensed reruns, real XPM/vendor GT model, routed FPGA timing/resources, and physical RF/QAM256 BER. No Gate 1/2/3 work started.

## 2026-10-28 23:40 SGT - Publish and verify EF2 Linux signoff

- Published the EF2 look-ahead experiment, current-source signoff packager,
  workflow updates, and report changes to GitHub branch `thermo5` as three
  commits. The resulting source tree is identical to the locally reviewed
  signoff tree; the current authoritative revision is always recorded in the
  run manifest.
- Re-ran the clean Linux digital package on the uploaded source revision:
  Python reference tests 36/36; Generic EF2 UVM/URG; 112-word STOP/restart;
  three 2,072-word qualification scenarios with all four target crosses;
  4,096-cycle pair-look-ahead VCS miter; four-PA serializer loopback;
  GT-parent link-loss/reset recovery; EF2 safety and pair-equivalence VC
  Formal. The signoff packager passed with 79 SHA-256-indexed evidence files.
- The workflow's hosted syntax/whitespace and Python unit-test job passed for
  the uploaded revision. Its licensed EDA job is queued for the configured
  self-hosted Synopsys runner; the GitHub Actions artifact is not available
  until that job starts and uploads its evidence.
- Limits remain: raw code coverage is open (76.12% aggregate URG); no Linux
  Vivado/XSim, real XPM, or current GT Wizard model is installed. Routed FPGA
  timing/resources, calibrated RF behavior, and physical QAM256 BER remain
  open. The GT-parent test uses a controllable simulation replacement.

## 2026-10-28 23:05 SGT - Add exact EF2 pair look-ahead and Linux signoff packaging

- Added an opt-in two-sample EF2 look-ahead implementation behind
  `PAIR_LOOKAHEAD`; the product wrappers keep the parameter disabled. Added a
  32-sample VCS equivalence miter and a two-sample VC Formal relational proof.
- Extended the licensed GitHub Actions job to run current EF2 Generic,
  qualification, STOP/restart, pairwise look-ahead, serializer-loopback, and
  GT-parent fault/recovery checks, then upload SHA-named signoff evidence.
- Added a Linux signoff manifest that checks source/configuration consistency,
  required functional coverage crosses, test markers, vector hashes, logs,
  and formal properties. Added a job-ready baseline ledger and run commands.
- Python reference tests passed 36/36; workflow YAML parse, Python compile,
  and whitespace checks passed. The clean-tree run at source revision
  `b48512241e3df26f1d58123d67e1f90da4bcbf83` produced
  `runs/thermo5_linux_ef2_signoff_b485122/signoff_manifest.json` with
  `PASS_LINUX_DIGITAL_SCOPE` and 79 SHA256-indexed evidence files.
- Current-source VCS passed the six-case Generic suite and expected illegal
  frame control with zero UVM errors/fatals, plus URG merge. Raw aggregate URG
  is 76.12% (line 82.63%, condition 62.59%, toggle 79.66%, FSM 100%, branch
  62.22%, assertion 76.47%, group 69.26%); code coverage remains OPEN. The
  2,072-word EF2 qualification passed all three seeded scenarios and all four
  required saturation/stall/rail crosses. AXI-Lite STOP/restart passed with
  112 ordered four-plane outputs.
- VC Formal passed EF2 safety (6 assertions/3 covers) and pairwise transfer
  equivalence (7 assertions/4 covers), with zero black boxes. The 4,096-cycle
  32-sample VCS miter passed (2,662 accepts, 1,638 back-to-back accepts, 307
  positive clamps, 408 negative clamps, 818 output stalls, 616 input bubbles).
  Four-PA serializer loopback passed for 56 words / 3,584 bits per path; the
  GT-parent fault test passed immediate PA blanking, sticky fault, and reset
  recovery using its controllable simulation replacement.
- Limitations: Linux has no Vivado/XSim, real XPM sources, or current GT Wizard
  simulation model. Routed FPGA timing/resources and physical QAM256 BER remain
  open. The GT-parent VCS test uses a controllable simulation replacement.
- During closure, the first generic vectors had one frame start while UVM
  expected three. Correcting them to `1,15,36` with gains `16384,14336,12288`
  passed. The first packager attempt also found its parser expected markers at
  column zero while VCS prefixes them with `UVM_INFO`; exact substring marker
  checks and negative-control/URG gates were corrected before the clean pass.

## 2026-10-28 10:32 SGT - Linux EF2 formal safety closure

- Added `thermo5_ef2_stability_harness.sv` and a production-RTL monitor that
  recomputes every I/Q lane's EF2 quantizer input and raw error with one extra
  signed bit. Added formal checks for 32-lane no-wrap/bounds, accepted state
  updates, state hold without acceptance, output capture, and output stability
  during stalls. The monitor is not on the datapath and is optimized away when
  unused.
- Enabled the EF2 job in the Linux VC Formal runner and documented the command
  and proof scope. Fixed a pre-existing Tcl source-list syntax error in the
  convergence runner, allowing the centered-interpolator bounds job to execute.
- Corrected the VCS regression vector frame boundaries for the FIFO-empty
  test: it sends one 7-output-word frame, so the first generated frame must end
  after seven words. With starts at words 1, 8, and 29, the full current-source
  centered-cubic + EF2 UVM regression and the 112-word AXI-Lite STOP/restart
  test pass.
- Re-ran the longer held-out QAM256 software benchmark: six independent seeds,
  24 symbols/seed, 672,768 uncoded bits, 117 errors, BER 1.739e-4 with 95%
  Wilson interval [1.451e-4, 2.084e-4], mean EVM 2.517%, and no input/state
  saturation. This remains model-only evidence, not physical BER signoff.
- Checks: EF2 VC Formal PASS (6/6 assertions, 3/3 covers, zero black boxes);
  reset/counter/unbounded-counter/generic-CDC formal suite PASS; interpolator
  bounds PASS (16 assertions, five covers); EF2 long-frame/saturation VCS
  qualification PASS; full centered-cubic + EF2 VCS suite and STOP/restart
  PASS; AXI-Lite VCS integration suite PASS; four-path serializer loopback and
  GT-parent link-fault/reset recovery PASS; Python reference-model tests 36/36
  PASS.
- Exploratory DPD identity arithmetic formal run: the direct attempt proved six
  assertions and covered four bins; the staged-lemma attempt promoted five
  intermediate properties but still left twelve multiplier/saturation
  properties inconclusive at the configured depth/time limit. This is not a
  failure of the EF2 proof.
- Not available on Linux: XSim/Vivado, real XPM/GT Wizard simulation models,
  physical receiver/board BER. The Python held-out QAM256 BER remains model-only
  and nonzero. FPGA resource/timing/power remains deferred per user direction.
- Files: `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv`,
  `dv/uvm/formal/thermo5_ef2_stability_harness.sv`,
  `dv/uvm/formal/run_thermo5_gap_fpv.tcl`,
  `dv/uvm/formal/run_thermo5_convergence.tcl`,
  `dv/uvm/formal/run_thermo5_scoped_formal.py`,
  `dv/uvm/formal/README.md`, `docs/verification/thermo5-ef2-stability.md`,
  `docs/verification/thermo5-centered-cubic-ef2-status.md`,
  `docs/verification/thermo5-dv-portfolio.md`,
  `docs/ai-native/commands.md`, `docs/exec-plans/active/execution-frontier.md`,
  and `docs/UPDATE_LOG.md`.

## 2026-10-28 01:26 SGT - GT-parent active-packet loss response

- Added a sticky GT-health fault latch in the ZU15EG parent. Raw health still
  blanks PA immediately; an active-packet link loss now remains visible as
  `stream_fault` across the health-triggered application reset and keeps PA
  disabled through link recovery until external reset clears the fault.
- Added `FPGA_USE_XPM_FIFO` as a parent parameter with the existing FPGA default
  of `1`, so the Linux parent-level VCS test can select the generic FIFO while
  the hardware configuration remains on XPM.
- Added the VCS target `thermo5-gt-parent-link-fault-vcs` and a controllable GT
  Wizard substitute testbench. It injects loss while an AXI packet is open and
  checks immediate PA blanking, sticky fault, no early re-enable, and clean
  external-reset recovery. The model is not a GT Wizard/XPM or board test.
- Checks: parent link-fault VCS target PASS (`pa_immediate_blank=1`,
  `fault_sticky=1`, `reset_recovery=1`); current-source generic thermo5 VCS/UVM
  regression PASS; centered-cubic EF2 regression including the two-packet
  STOP/drain/restart test PASS (112 ordered four-plane outputs); Python
  reference-model unittest suite 36/36 PASS; `git diff --check` PASS.
- Not run: XSim/PowerShell remains unavailable. Real-XPM parent coverage,
  GT Wizard/TXP simulation, RX/CDR/deskew, EF2 formal proof, and physical link
  signoff remain open. FPGA resource/timing/power work remains deferred per
  user direction.
- Files: `fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv`,
  `dv/uvm/sim/Makefile`,
  `dv/verif/integration/gt_parent_fault/tb_thermo5_gt_parent_link_fault.sv`,
  `docs/ai-native/commands.md`,
  `docs/exec-plans/active/execution-frontier.md`,
  `docs/verification/thermo5-centered-cubic-ef2-status.md`,
  `docs/verification/thermo5-dv-portfolio.md`,
  `docs/verification/thermo5-test-level-matrix.md`,
  `docs/verification/thermo5-integration-cdc-contract.md`,
  `docs/verification/thermo5-ef2-stability.md`, and
  `docs/UPDATE_LOG.md`.

## 2026-10-28 01:01 SGT - EF2 main-chain stop/restart closure and report sync

- Completed the current-source centered-cubic + EF2 verification follow-up.
  The AXI-Lite wrapper now preserves source prefill before the first RUN and,
  after a completed STOP/drain, waits for two fresh FIFO beats before enabling
  the gearbox. The two-packet STOP/restart test now issues STOP while packet 2
  is open and checks all 112 ordered outputs across four planes.
- Updated current execution state and qualification/coverage reports to mark
  EF2 as the thermo5 main-chain default, record the new STOP/restart PASS,
  correct the generic raw URG score to 79.86%, and identify XSim/formal/XPM/GT
  vendor-model/physical limits. The EF2 report links to the current manifest
  at `runs/thermo5_ef2_qualification/vcs_current_final/`.
- Updated the EF2 qualification packager to locate the required coverage group
  in any `grp*.html` report instead of assuming that URG always names it
  `grp0.html`.
- Checks: current-source generic VCS/UVM regression and coverage merge PASS;
  AXI-Lite VCS/UVM regression PASS; focused two-packet STOP/drain/restart PASS
  (112 outputs, six event bins, zero underflow/protocol errors); EF2 long-frame,
  clamp/recovery qualification PASS; four-path behavioral serializer loopback
  PASS; Python reference-model unittest suite 36/36 PASS; packager
  `py_compile` PASS; `git diff --check` PASS.
- Not run: XSim/PowerShell is unavailable on this Linux host. EF2 formal proof,
  real-XPM coverage, EF2 GT Wizard/TXP rerun, and physical FPGA timing/resource
  work remain open or deferred. FPGA resource/timing/power were explicitly
  deferred by the user; no PPA or physical QAM256 claim is made.
- Files: `rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv`,
  `dv/uvm/tests/thermo5/axil/thermo5_sku_axil_stop_restart_test.svh`,
  `dv/uvm/sim/package_thermo5_ef2_qualification.py`,
  `docs/exec-plans/active/execution-frontier.md`,
  `docs/verification/thermo5-centered-cubic-ef2-status.md`,
  `docs/verification/thermo5-dv-portfolio.md`,
  `docs/verification/thermo5-ef2-stability.md`,
  `docs/verification/thermo5-uvm-coverage.md`,
  `docs/ai-native/commands.md`, and `docs/UPDATE_LOG.md`.

## 2026-10-27 - centered-cubic / EF2 roadmap checkpoint

- Re-ran the centered-cubic sustained-throughput XSim test: 1,024 ordered
  outputs with zero bubbles. Added a focused held-out EF2 benchmark runner and
  evaluated six new 24-symbol 256-QAM seeds at STEP=5120, 20-bit state, and
  RMS drive 0.08. Result: 117/672,768 uncoded errors, BER 1.739e-4 with 95%
  Wilson interval [1.451e-4, 2.084e-4], mean EVM 2.517%, and no input/state
  saturation. JSON is under the ignored `runs/` directory.
- Added six explicit event bins for AXI-Lite STOP/drain/restart and integrated
  the scenario into the optional centered-cubic + EF2 VCS candidate target.
  Correct 112-word EF2 vectors were generated, but VCS stopped before compile
  with `Cannot find license file`; do not count this scenario as PASS. The
  target dry-run confirms ORDER=2 / STEP=5120 is passed consistently.
- Checks: XSim sustained test PASS; Python reference-model tests 36/36 PASS;
  benchmark `py_compile` PASS and held-out run completed; candidate regression
  dry-run PASS; `git diff --check` PASS. The prior full generic/XPM candidate
  regression remains 2026-10-26 evidence, not a rerun in this checkpoint.
- Limits: EF2 is still a scalar 32-step nonlinear recurrence with no
  timing-qualified pipeline; candidate UVM STOP/restart remains blocked on
  VCS license; Windows host free memory was about 6.8 GiB, below the 12-14
  GiB route estimate, so no ZU15EG timing-driven route was launched. Keep
  causal/first-order as the frozen default and Centered-Cubic + EF2 as a
  research candidate. No commit or push was made.

## 2026-10-26 - centered-cubic + EF2 candidate throughput and DV

- Fixed centered-cubic FIR full-queue ready look-ahead so an accepted output
  pop can be paired with a replacement input push on the same clock edge.
- Added a sustained-throughput XSim test (1,024 contiguous output words,
  zero bubbles), full-chain XSim candidate options for centered cubic / EF2 /
  STEP, and a dedicated candidate VCS/UVM regression target. Added explicit
  partial four-plane-ready stress and atomicity cross coverage to the
  candidate bubble/backpressure test.
- Checks: standalone centered-cubic XSim PASS (`1024` outputs, `0` bubbles);
  centered-cubic + EF2 (`STEP=5120`) full-chain XSim PASS for generic and XPM
  FIFO; VCS/UVM candidate regression PASS for generic and XPM FIFO with zero
  UVM_ERROR/FATAL. Partial-ready stress hit 109 stalled cycles and reported
  100% plane-atomic cross coverage. `git diff --check` PASS (Git emitted only
  existing CRLF normalization warnings for two edited UVM files).
- OOC/timing: the ZU15EG candidate run generated `synthesized.dcp` (62,597,295
  bytes), utilization, and clock reports: 88,880 LUTs (26.04%), 58,909 FFs
  (8.63%), 2,108 DSP48E2 (59.75%), 6.5 BRAM tiles (0.87%), and modeled clocks
  of 4.571/10/8 ns for core/AXI-Lite/AXI-Stream. The Vivado launcher did not
  return a clean PASS marker; it reported failure to load `fpga_compiler`.
  No routed timing report exists. At recheck Windows host had 1.9 GiB free
  and WSL reported 11 GiB available, below the previous 12-14 GiB
  placement/routing requirement. Do not claim
  candidate timing closure.
- Additional checks: the AXI-Lite candidate regression passed for generic and
  XPM FIFO, including URG merge. Nonlinear DPD bit-true UVM passed for 56 and
  112 words on both FIFO builds. A new two-packet stop/drain/restart test and
  make target were added. VCS parsed/elaborated all 20 design modules for that
  test, then failed to obtain a license at final link. A later three-minute
  license-queue retry also expired without a token; runtime remains OPEN.
  The Python reference-model suite also passed all 36 tests.
- Limits: EF2 still has a 32-step serial combinational recurrence and is not
  timing-qualified. The 20-bit state clamp prevents arithmetic wrap but does
  not prove no clamp for arbitrary inputs. The held-out uncoded BER is a model
  metric; the project has no system BER/BLER target, and GT/board physical
  performance remains open. Details: `docs/verification/thermo5-centered-cubic-ef2-status.md`.

## 2026-10-25 23:16 SGT - add GT-parent pressure and error-frame scenarios

- Added selectable XSim scenarios for four AXIS payload patterns (signed ramp,
  zero I/Q, alternating signed extrema, and impulse) with a reproducible
  `0x5eed0000` source-gap seed. Each test exercises 32 accepted AXIS beats,
  56 output words per lane, and compares all 3,584 serial bits per lane against
  the GT user words at a modeled 14.0-Gb/s TX rate.
- Added negative-frame checks for early beat-15 `TLAST` (sticky
  `core_protocol_error`) and a 16-beat no-TLAST interruption (sticky
  serializer `stream_fault`, PA blanking, and GT idle word). A common reset
  clears each condition and legal replay frames pass the serial-bit checker.
- Added the runner/Tcl `-Scenario` and `-Pattern` options, bounded TX drain
  before pin comparison, and scenario-level logs. Full scope, commands, and
  limitations are documented in `docs/GT_PARENT_STRESS_AND_ERROR_TESTS.md`.
- Files: GT-parent testbench and runner/Tcl; integration README, GT verification
  note, execution frontier, and this log. No RTL datapath or algorithm changed.
- Checks: Vivado 2026.1 GT Wizard baseline XSim PASS; all four stress-pattern
  XSim runs PASS; bad-frame/reset/replay XSim PASS; generic-FIFO VCS
  `thermo5-vcs-regression` PASS (including expected alignment assertion);
  `git diff --check` and PowerShell syntax checks PASS. RX comparison remained
  skipped;
  physical GT and board signoff remain open.

## 2026-10-25 22:28 SGT - add four-lane GT serial TX full-chain simulation

- Added a self-contained XSim GT-parent flow that creates the ZU15EG four-GTH
  GT Wizard behavioral model at 14.0 Gb/s, 125-MHz refclk, RAW 64-bit TX width,
  then simulates AXI-Lite configuration and AXI-Stream frames through thermo5
  to the serial TX pins. The simulation no longer depends on a prior synthesis
  project; the runner defaults to the installed Vivado 2026.1 path.
- Extended the parent testbench to capture sampled TXP data at one configured
  line-rate UI, check 128 alternating idle bits and P/N polarity per lane, and
  bit-compare two 56-word frames per lane against words observed at the GT user
  interface. A frame candidate is accepted only after all 56 words match.
- Evidence: `runs/thermo5_gt14_e2e_clean_20261025_222945/`. PASS: 64 accepted
  AXI beats, 112 GT user words, two frames × 56 words × 64 bits on each of four
  lanes, modeled line rate 14.0 Gb/s / UI 71.428571 ps, zero serial payload
  mismatches. The test intentionally skips RX comparison; GT RX recovery,
  physical serial phase/deskew, eye/jitter/BER, GT-PMA routing, and board/RF
  output remain open.
- A full parent `synth_design` attempt did not finish after several minutes in
  Vivado constraint/timing initialization; it was stopped and is not counted
  as a synthesis pass. Standalone GT behavioral simulation does not require
  that synthesis step.
- Files: GT parent simulation runner/Tcl, GT parent testbench, integration and
  serializer-contract documentation, synthesis README, GT verification note,
  execution frontier, and this update log.
- Checks: clean-directory Vivado 2026.1 XSim GT Wizard regression PASS;
  runner PASS-marker check PASS; `git diff --check` PASS. No RTL datapath or
  fixed-point behavior changed.

## 2026-10-25 15:09 SGT - run EF2 long-frame QAM256 robustness sweep

- Added `benchmark_thermo5_ef2_robust.py` for a 12-symbol, multi-seed 256-QAM
  BER study covering EF2 STEP/input RMS, 18/19/20-bit model state rails, and
  joint 0/3/6-dB backoff with no/7/9-dB source-rate radial PAPR clipping. The
  development and held-out seed sets are disjoint. Output-chain thermal-noise
  power is adjusted from each seed's measured DPA/output RMS relative to its
  no-clipping, 0-dB reference.
- Generalized only the Python fixed-point model's EF2 state width knob; the
  Q1.15 input, bipolar quantizer, 2/-1 feedback, and chronological state order
  remain unchanged. Updated benchmark sorting to prioritize natural-binary
  uncoded QAM256 BER, added state-width/PAPR checks, and documented the run.
- Development winner: STEP=5120, RMS=0.10, 4/168,192 bit errors (BER
  2.378e-5), 2.459% mean EVM. Independent held-out confirmation: 23/168,192
  errors (BER 1.367e-4), 2.461% mean EVM, no saturation. A 19-bit state
  matched 20-bit results without clipping across six tested 12-symbol QAM
  waveforms; 18-bit clipped 54 times. Constant high-level input still clips
  at 19 bits, so RTL remains at 20 bits pending a formally defined operating
  envelope. No first-order default or RTL parameter was changed.
- No-PAPR-limit/0-dB-backoff was the best tested joint point in the current
  illustrative output-chain model. Its development nominal/stress BERs were
  1.249e-4/6.778e-4; the held-out baseline produced 33/129 analog-chain bit
  errors over 168,192 bits. These DPA/output-power/noise values are model
  sensitivities, not calibrated hardware results.
- Files: robust EF2 benchmark, fixed-point experiment model, DSM experiment
  tests, Python reference README, command index, EF2 boundedness/verification
  note, execution frontier, this log. Full JSON is under ignored
  `runs/thermo5_ef2_robust_20261025/summary.json`.
- Checks: `py_compile` PASS; 36 Python unit tests PASS; shortened 2-symbol
  end-to-end smoke PASS; full default 12-symbol sweep completed in 10m55s.
  Regenerated the 56-word centered-cubic EF2 oracle; VCS V-2023.12-SP1 focused
  UVM bit-true compile/runtime PASS (32 source / 56 output words, four planes
  matching, zero UVM_ERROR/FATAL). The held-out report deduplicates an
  identical no-CFR baseline rerun from the first script version. The full VCS
  regression, XSim, and FPGA resource/timing were not run. BER is uncoded
  natural-binary labeling; the output chain is not calibrated, and the
  selected candidate still has nonzero errors.

## 2026-10-24 23:40 SGT - add bounded fixed-point EF2 RTL candidate

- Added optional `TIDSM_ORDER=2` to the thermo5 four-branch transmitter and
  propagated it through parallel, AXIS, AXI-Lite, UVM, and source manifests.
  First-order behavior remains the default. The EF2 implementation uses the
  samplewise recurrence `u=x+2e1-e2`, signed Q1.15 input, signed Q4.15
  saturated state, and signed Q6.15 temporary arithmetic.
- Added the inductive no-wrap/state-bound proof at
  `docs/verification/thermo5-ef2-stability.md`, a fixed-point vector oracle,
  an independent integer-stream benchmark mode, EF2 vector generation, and
  qualitative FIR/drive/backoff/PAPR/STEP notes.
- Fixed-point 256-QAM A/B confirmation at STEP=5120 matches the prior floating
  EF2 result: 2.4724% mean / 2.4890% worst-seed digital EVM, 32.138-dB mean
  SNDR, 4 symbol errors / 5 natural-binary bit errors over 14,016 decisions.
  All three seeds had zero input/state saturation; nominal/stress sensitivity
  EVM is 2.6023%/3.0036% with 11/46 errors. These are Python model results,
  not a measured link or RTL simulation.
- Files: `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv`, thermo5 RTL
  wrappers, UVM filelist/testbench/Makefile, Python reference/benchmark/tests,
  XSim/OOC/FPGA source manifests, `dv/uvm/refmodel/python/README.md`,
  `docs/ai-native/commands.md`, the EF2 proof, execution frontier, and this log.
- Checks: Python unit tests; fixed-point word-vs-stream bit-true comparison;
  three-seed 8-symbol 256-QAM benchmark; 56-word centered-cubic EF2 vector
  generation; `py_compile`; and `git diff --check` all PASS. VCS candidate
  execution was attempted, but V-2023.12-SP1 refuses the WSL2 6.6.87.2 kernel.
  `make formal-check-tools` could not run because its referenced probe script
  is missing, and direct lookup found no formal engine. The required XSim
  command cannot start because `powershell`/XSim are unavailable here. No
  VCS/formal/XSim PASS is claimed. FPGA resource/timing remains intentionally
  unrun.
- Remaining: run the EF2 VCS UVM bit-true test and regression on a supported
  EDA host; then qualify FPGA timing/resources before considering a default
  change. Keep default order 1 and STEP 7168.

## 2026-10-24 23:04 SGT - complete STEP and DSM order benchmark for 256-QAM

- Added `benchmark_thermo5_step_ntf.py` and the Python-only TIDSM experiment
  model. The tested first-order RTL recurrence remains bit-checked against its
  scalar reference; second-order error-feedback modes are explicitly labeled
  floating-point prototypes. Added hard-decision SER and natural-binary
  uncoded BER metrics to the receiver screen, along with state/headroom
  diagnostics and summary flags that report RTL audit as not applicable for
  the non-RTL candidates.
- Swept current RTL STEP values 0..8192 and NTF/order candidates 1..3. In the
  three-seed, eight-symbol confirmation, current first-order STEP=7168 gave
  3.273% mean / 3.310% worst EVM, 29.702-dB mean SNDR, and 198 symbol errors
  among 14,016 decisions. EF2 STEP=5120 gave 2.472% / 2.489% EVM,
  32.138-dB mean SNDR, 4 symbol errors and 5 natural-binary bit errors; its
  largest observed state/input magnitudes were 4.976/5.976. EF2 STEP=6144 was
  slightly worse; EF2 STEP=7168 exceeded the finite-frame headroom check; EF3
  diverged on this workload. The first-order grid's best setting remains the
  existing STEP=7168.
- Matched nominal/stress output-chain runs (behavioral DPA, output FIR, and
  kTB/NF; illustrative, uncalibrated) gave EF2 STEP=5120 EVM 2.602%/3.004%
  and symbol errors 11/46. The current first-order STEP=7168 gave
  3.370%/3.685% and 234/359 errors. Thus EF2 clears the 3.5% stress EVM screen
  in this model but is not error-free. Reports are under
  `runs/thermo5_step_ntf_sweep_20261024/`.
- Changed files: `dv/uvm/refmodel/python/benchmark_thermo5_tid_receiver.py`,
  `benchmark_thermo5_step_ntf.py`,
  `dsm_refmodel/thermo5_experiments.py`, two Python test files,
  `dv/uvm/refmodel/python/README.md`, `docs/ai-native/commands.md`,
  `docs/exec-plans/active/execution-frontier.md`, and this log.
- Checks: three-seed STEP/order and finalist benchmarks; matched nominal/stress
  output-chain benchmarks; Python unit tests and `py_compile`; 56-word oracle
  vector generation; generic-FIFO VCS thermo5 regression with six positive
  tests and the expected illegal-frame assertion (zero UVM_ERROR/FATAL);
  `git diff --check`.
- Limits: EF2 is not fixed-point or RTL equivalent and has no global loop
  stability proof. Finite-frame error counts do not establish production BER.
  XSim is unavailable on this Linux host. No FPGA resource/timing analysis or
  RTL change was made; retain the current frozen first-order RTL until EF2 is
  fixed-point bounded, bit-true validated, and implementation-qualified.

## 2026-10-…56870 tokens truncated…ter thermo3 completes.
- Limitations: no ASIC final area/timing/power claim until the current real
  mapped runs emit reports; power is vectorless without SAIF.
- Fixed `syn/asic/parse_dc_reports.py` to run on Rocky's Python 3.6 (removed
  unsupported future annotations and newer union/generic type syntax).
- Project organization pass: physically migrated `verif/` to `dv/verif/` and
  `uvm_verif/` to `dv/uvm/` with `git mv`, updated root-relative filelists,
  Makefiles, formal/Tcl/Python/PowerShell consumers, and corrected the UVM
  include path. The migration map records the completed moves.
- Post-migration GT BERT XSim reached compile/elaboration but the existing
  Vivado Windows simulator returned `-1073741790` at run time; this is recorded
  as an unavailable simulator result, not a migration PASS.
- The active thermo3 DC session ended with `Process terminated by hangup` during
  compile mapping optimization. Intermediate checks exist, but no final ASIC
  area/timing/power/netlist result is claimed.
2026-09-24
- Audited the persistent bounded TSMC28 DC runs for thermo3 and thermo5. Both
  Rocky DC processes are still in standard-cell mapping after
  analyze/elaborate/link; no area, setup/hold, power, DDC, or mapped-netlist
  artifacts exist yet. ASIC signoff remains pending.
- Confirmed the physical verification migration is complete under `dv/verif/`
  and `dv/uvm/`; updated consumers remain the canonical flow boundary.
- Added ignore rules for DC shell runtime files and run PID files. Existing
  copies are retained locally; index cleanup requires a normal writable Git
  clone because this session cannot create `.git/index.lock`.
- Implemented the stage-1 FPGA low-power experiment as an opt-in
  frame-safe activity controller (`rtl/axis/dsm_frame_power_ctrl.sv`). It uses
  native clock-enable style qualifiers, waits for four AXI words (one
  56-sample superframe), and drains accepted core words before IDLE; it never
  gates a fabric clock or pauses an active recursive frame. Added thermo3/5
  low-power OOC variants and a focused XSim controller test. Baseline wrappers
  keep `ENABLE_LOW_POWER_CTRL=0`.
- Re-audited the persistent TSMC28 DC runs: both were still alive in mapping,
  but invalid because `gt_tx_raw64_boundary` was omitted from the ASIC source
  list and remained unresolved at link. Added the missing GT RTL sources to
  `syn/asic/dc_thermo_frontend.tcl`; the existing runs must not be used and
  need a clean restart before any ASIC result is reported.
- Attempted the corrected thermo3 restart in
  `runs/20260924_123132-dc-thermo3-tsmc28/`; DC exited before analyze with
  `DCSH-1 Design Compiler is not enabled`. The Rocky FlexNet log reports a
  license TCP-port open failure. No synthesis result is claimed until the
  license service is restored and the run is restarted.
- Rechecked the Rocky FlexNet service: `lmutil lmstat -a -c 27000@localhost`
  reports the server and `snpslmd` UP with the SSS feature available. Started
  a new thermo3 bounded run with an explicit `.db` and
  `27000@127.0.0.1`; it loaded all 17 source designs including the previously
  missing GT boundary and is still processing pre-compile checks. No ASIC
  result is claimed yet.
- Thermo3 bounded DC completed successfully in
  `runs/20260924_1240-dc-thermo3-tsmc28/` after restoring the license and GT
  source list. Generated DDC, mapped Verilog, area, setup/hold, power, QoR,
  and constraint reports. TT timing has zero violating paths (clk125 slack
  7.51 ns; clk218 slack 1.45 ns). Standard-cell-only cell area is
  1,623,296.698 library units; vectorless power is 181.0777 mW dynamic plus
  1.0081 mW leakage. These numbers are pre-layout and not multi-corner or
  SAIF signoff.
- The first thermo3 LP OOC completed synthesis/implementation but failed timing
  at WNS -10.281 ns (quick implementation). A concurrent thermo5 LP attempt
  hit Vivado's private realtime-helper crash (`rt-undefined`) before synthesis;
  removed the private `rt::*` calls from the OOC Tcl so subsequent LP runs use
  only the bounded thread settings and public Vivado flow.
- LP evidence audit: the subsequent thermo5 quick OOC aborted with Vivado
  `EXCEPTION_BREAKPOINT` during iterative area optimization. Its incomplete
  vectorless report is diagnostic only (`7.033 W` total on-chip, `0.756 W`
  device static). No LP timing or power PASS is claimed.
- Retried thermo3 LP with a fresh output directory and direct `vivado.bat
  -mode batch` invocation. RTL read and synthesis licensing succeeded, but
  Vivado 2024.1 again aborted in its realtime helper with `rt-undefined` before
  timing reports. This remains a tool/runtime blocker, not a new timing result.
2026-09-24
- Revised stage-1 low-power datapath control to use registered local CE at the
  gain and thermo frontend boundaries while leaving the AXI/CDC ready/valid
  network untouched. This targets the measured routing-dominated LP failure
  without changing active-frame DSM state evolution or the baseline branch.
- Added `syn/run_lp_power_compare.ps1` and SAIF provenance support in the OOC
  Tcl. Baseline and LP now have a reproducible same-device/full-route
  comparison entry point; reduction percentages remain unreported until both
  reports are present.
2026-09-24
- Re-tested the host Vivado 2024.1 outside the GUI with a minimal batch smoke
  (`puts [version -short]; exit`) and the LP RTL read/elaboration diagnostic.
  Both terminate with Windows status `-1073741790` and produce an empty log.
  This is a Vivado runtime/install failure before RTL parsing, not a project
  synthesis or timing result.
2026-09-26
- Exposed structural interpolation and memory-DPD tap parameters through the
  thermo3/thermo5 AXI and OOC tops.  Added 2/3/4-tap unity-DC-gain
  interpolation presets while retaining the 4-tap cubic default unchanged.
  Compile-time DPD SKU mode fixes the active tap count so unused memory taps
  can be synthesized away; the default remains runtime programmable.
- Corrected migrated `dv/verif` paths in the P0 and thermo frontend XSim
  launchers.  Default thermo3 and thermo5 frontend bit-true XSim pass after
  the parameter plumbing.  Started the first full routed timing run for the
  thermo5 2-interpolation-tap / 1-memory-tap SKU; no new PPA result is
  claimed while the implementation is running.
- Added a routed-checkpoint functional-netlist export and post-route XSim/SAIF
  activity launcher.  Thermo3's 55.6-MB netlist compiles and elaborates, and
  the launcher now resolves the escaped generated DUT hierarchy correctly.
  The bounded host could not complete full activity simulation of the
  2,030-DSP netlist (about 7.7 GB during elaboration), so no post-route SAIF
  coverage or revised power reduction is claimed.
- Added and executed `run_tid32_thermo_algorithm_ppa_screen.m` at 100 MHz and
  250 MHz with three isolated seeds, raw Fs/4 DDC, and the routed default
  thermo3/thermo5 PPA points.  At 250 MHz, only thermo5 meets the 256-QAM
  gate for all three seeds; the output CSV records EVM/SNDR/ACLR, stream
  mismatches, resource, and timing provenance.  No RTL numerical behavior was
  changed.
- Corrected `matlab/bittrue/p0_compare_rtl_xsim.m` to use the canonical
  migrated `dv/verif` vector and XSim-output locations.  Check:
  `scripts/run_matlab_p0_bittrue_check.cmd` PASS, seven 65,536-sample models
  with zero mismatches.
- Rechecked the thermo3 routed-DCP/RTL-SAIF hierarchy mapping with the
  recorded strip path. Vivado reproduced `19,984/293,705` direct net matches
  (7%). The SAIF includes the full DUT hierarchy, confirming that the limit is
  RTL-to-routed-netlist name/optimization mismatch rather than a strip-path
  error. No RTL behavior, timing, or prior power number changed.
- Created independent managed Vivado OOC projects under `fpga/thermo3_lp/` and
  `fpga/thermo5_lp/` for the complete low-power two-clock AXI frontends on
  `xczu15eg-ffvb1156-2-i`. Both projects preserve wide internal interfaces as
  OOC partition ports instead of consuming package I/O.
- Completed full synthesis, placement, physical optimization, and routing at
  218.75 MHz. Thermo3 LP passes with WNS/WHS `+0.147/+0.027 ns`; thermo5 LP
  passes with `+0.103/+0.026 ns`. Both have TNS/THS 0, zero route errors, and
  zero critical warnings. Routed checkpoints and timing/utilization/power
  reports are retained in each project's `reports/` directory.
- Routed utilization: thermo3 LP uses 60,094 CLB LUTs, 84,693 registers,
  6.5 BRAM tiles, and 2,032 DSPs; thermo5 LP uses 71,713 CLB LUTs, 97,796
  registers, 6.5 BRAM tiles, and 2,032 DSPs.
- Vectorless routed power is 6.040 W for thermo3 LP and 6.540 W for thermo5 LP
  (Medium confidence). No reduction percentage is claimed: the matched
  baseline/LP SAIF workload experiment is still required, and Vivado warned
  that vectorless reset activity is unrealistic.
- Fixed the managed-run completion check to use the routed DCP as the source of
  truth when `Performance_ExplorePostRoutePhysOpt` is intentionally stopped at
  `route_design`; this avoids falsely reporting a successful route as failed
  because the optional post-route phys-opt step is not started.
- Check: `dv/verif/scripts/run_xsim_frame_power_ctrl.ps1` PASS with
  `DSM_FRAME_POWER_CTRL_PASS`. Full frontend bit-true regression after the
  local-CE change remains pending.
- Low-power evidence audit: these routed projects prove timing closure, not a
  power-reduction percentage. Their OOC wrappers tie `core_enable` high, so
  vectorless power never models a normal IDLE/DRAIN workload, and the generated
  `lp_ingress_enable` is not yet connected to AXI/FIFO acceptance. Classify the
  implementation as frame-safe local activity gating pending full integration,
  transition regression, and matched baseline/LP SAIF measurements.
- Implemented the next low-power integration revision: OOC tops now expose a
  real `run_request`; LP ingress gates AXI acceptance; the controller owns CDC
  enable through DRAIN; and CDC has an explicit `core_drain` condition so a
  legal end-of-run empty FIFO is not reported as streaming underflow.
- Added `tb_tid32_thermo_axis_lp_power.sv`, its XSim/SAIF launcher, a routed-DCP
  SAIF power reporter, and `syn/run_lp_power_ab.ps1`. The flow uses identical
  useful transactions for baseline/LP continuous, burst, and long-idle cases,
  requires output-count/digest equality before power analysis, implements each
  mode once, reopens a clean DCP per workload, and reports SAIF matched-net
  coverage and dynamic-power reduction.
- Execution is pending rather than PASS: Windows `xvlog` currently terminates
  before RTL parsing with `-1073741790`, while Rocky WSL/VCS fallback could not
  be accessed because the host escalation service failed. The XSim controller
  launcher was hardened to check every tool exit status, exposing that its
  apparent earlier rerun had reused a stale PASS log. Existing LP routed DCPs
  are explicitly pre-revision evidence and must be rebuilt.
- Hardened the matched-SAIF experiment contract: the continuous case now sends
  512 no-bubble AXI beats; every baseline/LP pair uses the same fixed
  core-clock observation window; comparison includes accepted words, output
  words, output digest, and observation cycles; and the power flow rejects
  Vivado SAIF design-net coverage below 80%. PowerShell parsing and
  `git diff --check` pass. A fresh EDA run remains blocked because the current
  Windows tool process exits before emitting version or compile output and the
  external-execution approval service did not grant a runnable session.
- Diagnosed the thermo3/thermo5 `xelab` failure from the generated logs. It was
  a launcher file-handle collision, not an RTL elaboration error: PowerShell
  occupied `xelab.log` through `*> xelab.log` while Xilinx `xelab` attempted to
  open its own default log of the same name. Updated the activity launcher to
  use native `-log xelab.log` and `-log xsim.log` arguments with no shell
  redirection. The user's normal terminal must perform the post-fix smoke run
  because EDA executables still terminate before logging in the restricted
  agent process.

2026-09-27
- Added a sparse-TDD activity workload consisting of four frame-safe short
  grants separated by deterministic idle intervals. XSim/SAIF generation
  passes for thermo3 and thermo5 baseline/LP pairs with identical accepted
  words, output words, digest, and observation cycles; only LP completes with
  no underflow, as intended by the drain protocol. Routed power reporting is
  still running and no new reduction percentage is claimed yet.
- Added `run_tid32_thermo_sku_matrix.m` and
  `run_ooc_tid32_thermo_sku_matrix.ps1` for the fair 18-SKU
  thermo/interpolation/identity-DPD matrix. A thermo5/2-tap/1-tap algorithm
  smoke passed three held-out seeds with zero raw-word mismatches. Full MATLAB
  and independent full-routed OOC matrices were launched; pending rows remain
  pending rather than inferred from default PPA.

## 2026-10-07 10:44 SGT - Mapped ASIC result and equivalence retest

DC mapped synthesis completed PASS at runs/thermo5_asic_retest_20261006_2016:
unmapped_cells=0, zero macros/blackboxes, 544463 cells (170605 sequential),
cell area507779.648216 library units. Actual mapped Verilog/DDC/SDC/SVF and
reports exist. Original DC source before/after hashes match. Dual-domain
pre-layout TT setup slack: clk125 +6.79ns, clk218 +1.76ns; reported hold
minimum rounds to0.00ns, no setup/hold violating paths. check_timing reports
no missing input delays or unconstrained endpoints in its selected checks.
Electrical/constraint signoff is NOT PASS: one rd_bin_q[3] max-capacitance
violation and a zero max_leakage_power target violation remain. High-fanout
modeling/ideal clocks and assumed parent I/O budgets remain limitations.
Do not quote library area as square micrometres without the unit basis.
Architectural ideal limits:1.75G complex input samples/s,7G interpolated
samples/s,14G code bits/s per plane; these are not measured sustained rates.

Initial Formality failed before verification on unsupported read_verilog -sv.
Corrected syn/asic/fm_thermo5_frozen.tcl to read_sverilog -r and report_status
using installed command manuals; canonical RTL is unchanged. Preserved
fm_shell_initial_option_failure.log and flow_manifest_mapping_initial.json.
Fresh equivalence-only retest on2026-10-07 fails License Failure(-16):
Not authorized for feature Formality. No RTL/netlist equivalence result
exists; latest flow_manifest.json is FAIL for the equivalence-only attempt.
The restored-license DV CI37462007850 remains PASS at its recorded commit.
Next: restore permitted Formality feature authorization, rerun equivalence
against this mapped netlist/SVF, and close the cap/leakage constraint items.
Do not rerun the completed multi-hour synthesis just for the FM option fix.
## 2026-10-08 12:48 SGT — bounded XPM FWFT reset attempt

- Changed: added read-only FWFT state/reset observation and a plusarg-gated
  legal reset-phase target in `dv/uvm/agent/interfaces/thermo5_sku_if.sv`,
  `dv/uvm/tb/thermo5_sku_uvm_tb.sv`, and
  `dv/uvm/tests/thermo5/thermo5_sku_corner_tests.svh`.
- Reason: test whether a legal common public reset can hit the remaining XPM
  `stage1_valid->invalid` FSM transition without force/deposit.
- Checks: VCS XPM baseline bittrue PASS (56 words/four planes); directed common
  reset test PASS after observing `stage1_valid` with `rd_rst_i=0`, then complete
  56-word/four-plane replay; same-binary URG before/after PASS. Exact transition
  remained Not Covered (7/9 transitions before and after). Experiment-only
  total score 72.07% -> 72.24%; not a full regression score.
- Evidence: `runs/thermo5_xpm_fwft_reset_attempt_20261008/` and exact JSON delta.
  Frontier and exact-bin follow-up updated. No RTL/vendor source or waiver
  changed; FWFT target remains OPEN.

## 2026-10-08 12:58 SGT — latest-source frozen regression and exact XPM merge

- Checks: full frozen generic/XPM regression PASS and 131075-word four-plane
  gap closure PASS after the read-only FWFT observation edit. RTL/DV digest:
  `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`.
- Raw generic/XPM DUT scores: 87.49% / 80.27% after closure; final XPM is
  80.29% after core-first release. Core-first and FWFT-target resets both ran
  on the new baseline XPM `simv`; no VDB from another binary was merged.
- Exact same-binary results: wrapper line 52 tuple `1/0` changed Not Covered to
  Covered; line 57 tuple `1/1/1/0`, line 59 tuples `1/0/1/1` and `1/1/1/0`, and
  FWFT `stage1_valid->invalid` remain OPEN. FWFT remains 8/9 transitions.
- Evidence: `runs/thermo5_frozen_regression_fwftmon_20261008/manifest.json`,
  `runs/thermo5_gap_closure_fwftmon_20261008/closure.json`, and
  `runs/thermo5_gap_closure_fwftmon_20261008/exact_final_delta.json`.
  Adjusted score not recomputed; no waiver/exclusion added. Hosted current-source
  CI remains unrun.

## 2026-10-08 23:00 SGT - Graduate DV closure refresh and bit22 run

- Updated `docs/verification/thermo5-frozen-sku-signoff-plan.md` with the
  current-source raw/adjusted coverage, scope limits, package digest, and links
  to the exact bin ledger and four-fault detection record. Added a current
  status pointer in `dv/uvm/sim/README.md` so historical score tables are not
  mistaken for the latest result. Updated `execution-frontier.md` with this
  active experiment.
- Confirmed the local licensed one-command package report is PASS for current
  RTL/DV digest `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`
  (202 source files); this is a dirty-worktree local result, not hosted CI.
- Generated `runs/thermo5_bit22_oracle_20261008/` for 4,194,309 output words.
  Before generation, the independent integer model matched all eight files of
  the 2,097,158-word MATLAB-validated fixture. Generic/XPM VCS full-chain
  bit22 tests are running on the same-source compiled binaries with seeds
  610078/610079; their coverage is not credited until scoreboard, reset, and
  same-binary URG gates pass.
- Remaining limits: reachable high counter directions above bit22, four
  generic interpolation line/branch bins, XPM vendor/FWFT bins, and
  board/GT/system signoff remain open. No exclusions or RTL changes were made.

## 2026-10-08 23:47 SGT - Bit22 generic/XPM closure and report refresh

- Changed: added `tools/hw/thermo5_long_counter_delta.py` to expand same-source
  URG toggle ranges and require a both-direction hit for all 16 instances of a
  selected DPD sample-counter bit. Refreshed the frozen-SKU signoff matrix,
  reachability ledger, DV portfolio, simulation README, and execution frontier.
- Checks: generic seed610078 and real-XPM seed610079 passed 4,194,309 ordered
  four-plane words with zero UVM errors/fatals; both passed the public-reset
  check clearing all16 DPD counters. Same-source URG merges passed. Exact
  delta audit hit `sample_count[22]` both ways in 16/16 lanes for both FIFO
  models. Latest raw DUT coverage is generic87.16%, XPM80.12%; no exclusion was
  added. `python -m py_compile tools/hw/thermo5_long_counter_delta.py` passed.
- Evidence: `runs/thermo5_bit22_oracle_20261008/`,
  `runs/thermo5_frozen_regression_fwftmon_20261008/`, and
  `runs/thermo5_bit22_urg_20261008/`. Adjusted scores remain the reviewed
  bit21-only view and are not paired with the bit22 raw report.
- Remaining: bits31:23 (288 reachable directions/FIFO), four generic
  interpolation line/branch bins, XPM vendor/FWFT residual bins, hosted CI,
  and system/GT/board signoff remain open. No RTL or testbench behavior changed.

## 2026-10-10 14:27 SGT - Local build-artifact cleanup and Git hygiene

- Added ignore rules for local `runs/`, `syn/out/`, and root `verif/out_xsim_*`
  products. These paths contain generated databases and experiment outputs;
  reviewed summaries/reports and rerun scripts remain the shareable record.
- Inventory identified about 3.2 GiB of re-creatable simulator/project caches
  and old Vivado outputs. The environment rejected the recursive deletion
  command, so no local generated files were removed. All run-level reports,
  MATLAB vectors, routed checkpoints, ASIC netlists/LEC evidence, and the two
  report sets referenced by `docs/THERMO3_THERMO5_ROUTED_PPA.md` remain intact.
- Validation: path-scoped cleanup inventory and `git diff --check`; no RTL or
  testbench behavior changed. A project-wide regression was not rerun because
  only ignore rules and documentation changed.

## 2026-10-12 12:02 SGT - AXI-Lite UVM functional coverage closure

- Changed: expanded `thermo5_sku_axil_config_test` with PA backpressure,
  post-traffic common-reset/default readback, busy-commit rejection, DONE W1C,
  all coefficient shadow-register read/write paths, byte strobes, and unmapped
  address DECERR checks. Added an AXI-Lite illegal-frame negative test and the
  reusable `thermo5-axil-vcs-regression` Make target. Updated the UVM README and
  execution frontier.
- Checks: generic and real-XPM AXI-Lite VCS regression each passed the positive
  56-word/four-plane MATLAB bit-true test and expected illegal-frame assertion
  plus reset recovery; zero UVM warnings/errors/fatals. Both same-binary URG
  merges report 100.00% functional groups. Positive-test counters now report
  one public reset reassertion and five PA-stall cycles. `git diff --check` was
  run after edits.
- Raw code coverage is not 100% and is not represented as such. The AXI-Lite
  top-level instance reports generic score80.05 (line90.75, condition72.00,
  toggle74.48, FSM66.67, branch76.39) and XPM score77.16 (line80.07,
  condition66.38, toggle73.36, FSM78.79, branch64.39); XPM includes vendor
  hierarchy. The AXI-Lite config-register module line coverage is98.12%; its
  remaining source lines are a valid-parameter guard, an unreachable default
  selected by the coefficient-read helper's caller, and the intentional
  mailbox-corruption error guard. These are not blanket-waived or forced into
  the legal functional database. Run evidence is under
  `runs/thermo5_axil_covclose2_generic_20261012/` and
  `runs/thermo5_axil_covclose2_xpm_20261012/`.
- Remaining: raw code coverage100% is OPEN; VCS-UVM fault-injection, full frozen
  SKU code-coverage gaps, CDC/RDC, routed timing for the optional wrapper, and
  parent/GT/board signoff remain separate tasks.

## 2026-10-12 18:08 SGT - Generic bit23 long-stream coverage closure

- Checks: current-source generic VCS/UVM long-counter test seed610080 PASSed
  8,388,611 four-plane bit-true output words, signed endpoints, and reset of
  all16 lane counters; UVM_ERROR/UVM_FATAL=0. Same-binary URG before/after
  reports and the exact delta helper confirm `sample_count[23]` toggles both
  directions in all16 generic DPD lanes.
- XPM seed610081 is still running; no cross-FIFO merge was made. The per-bit
  audit reports bits24-31 still unhit in this run and open/reachable. Its narrow
  raw hierarchy percentage is not a full regression result. No bins were
  waived. Raw code coverage100% remains open.
- Evidence: `runs/thermo5_bit23_vcs_generic_20261012/` and
  `docs/verification/thermo5-bit23-counter-closure-20261012.md`.

## 2026-10-12 13:02 SGT - AXI-Lite exception coverage and synthesis retry

- Changed: added directed checks for zero-strobe CONTROL/STATUS writes, legal
  AR backpressure while R is stalled, the coefficient-read helper default,
  illegal `MAX_TAPS=0/5` elaborations, and a mailbox-corruption negative test.
  Updated the coverage ledger, UVM README, execution frontier, and closure
  record. No URG exclusions were applied.
- Checks: licensed VCS generic and real-XPM AXI-Lite focused regressions PASS;
  positive four-plane/56-word bit-true run, illegal-frame and mailbox-fault
  tests pass with expected RTL error detection; separate invalid-parameter
  test passes for both bounds. Merged functional covergroups are 100%.
  `git diff --check` passes (only existing line-ending warnings).
- Coverage: targeted three-test raw full-hierarchy URG is generic 74.54% and
  XPM 74.43%. In `thermo5_dpd_axi_lite_cfg`, line/condition/toggle/branch are
  99.38/95.95/33.50/97.50%. Reachable boundary tuple and coefficient-bank
  toggles remain open; fixed-parameter and protocol-invariant candidates are
  not blanket-waived. This is not 100% raw code coverage.
- Synthesis: repeated optional-wrapper OOC synthesis. Both runs wrote a
  synthesized checkpoint and utilization report, but the Vivado launcher
  returned nonzero with `Failed to load feature 'vivado'`. Independent Vivado
  reopen/report on the retry DCP exited 0. Resources: 71,537 LUTs, 52,255
  registers, 1,936 DSPs, 334.5 BRAM tiles. No routed checkpoint, WNS/WHS, or
  parent I/O signoff was produced; launcher exit handling remains open.

## 2026-10-13 10:42 SGT - Generic bit24 URG and XPM bit24 restart

- Checks: the saved generic seed610704 VDB was merged with its same-binary
  baseline and passing regression VDBs. URG and the exact `sample_count[24]`
  delta audit completed with exit0; all16 generic `.u_dpd` lane counters show
  both toggle directions. The merged raw generic hierarchy score is87.01%
  (line87.09, condition76.46, toggle85.50, FSM100, branch73, assertion100).
- XPM license: a fresh 56-word bit-true smoke on the existing XPM binary,
  seed610709, passed with four-plane bit-true output and zero UVM warnings,
  errors, or fatals. A new detached XPM long run is active with seed610708 and
  VDB `cov_thermo5_sku_long_counter_test_seed610708.vdb`; an automatic
  finalizer will run the separate XPM URG merge and 16-lane bit24 audit after
  the long test completes.
- Evidence and launch/status scripts are under ignored
  `runs/thermo5_bit24_oracle_20261012/` and the XPM run directory. Earlier
  XPM VDBs from seeds610705-610707 remain excluded. Bits25-31 and raw100% code
  coverage remain open. No RTL, MATLAB arithmetic, or test expectations
  changed.

## 2026-10-13 10:50 SGT - XPM bit24 local-input restart

- Diagnosis: the first fresh XPM attempt, seed610708, was blocked in WSL
  `p9_client_rpc` while streaming 2.5 GB of vectors from `/mnt/e`; after47 CPU
  seconds it was stopped (exit255), and its partial VDB is explicitly
  excluded. No functional failure was observed.
- Change/check: copied the eight unchanged oracle `.mem` inputs to
  `/tmp/thermo5_bit24_xpm_610710/vectors` on WSL ext4 and started seed610710
  with a new VDB. The simulator entered `thermo5_sku_long_counter_test`; the
  process was runnable with CPU time advancing, unlike the prior 9P-bound
  attempt. The detached finalizer will run XPM-only URG and the exact 16-lane
  bit24 toggle audit on a passing long stream.
- Remaining: seed610710 long-stream, URG, and per-lane audit are pending. No
  XPM bit24 PASS or overall100% raw coverage is claimed. The earlier short
  XPM smoke seed610709 and generic bit24 URG/audit remain PASS.

## 2026-10-13 20:15 SGT - AXI-Lite coverage and verification closeout

- Changed: refreshed the AXI-Lite verification closeout, frontier and control
  architecture status. Added exact waiver-ledger rows for the formally proven
  successful-write case default and the frozen `MAX_TAPS=4` elaboration guard;
  the existing line-88 waiver remains the only prior waiver. No functional RTL
  behavior or coverage database was altered. Corrected the simulation-only
  reset assertion to avoid checking stale pre-NBA state during asynchronous
  reset assertion on a clock edge.
- Checks: VCS generic and real-XPM tap4 identity tests passed (seeds610160 and
  610162); nonlinear memory-DPD coefficient tests passed (610161 and610163),
  each with 56 four-plane MATLAB bit-true words and zero UVM errors/fatals.
  AXI-Lite write/read/reset functional covergroups are100% for both builds.
  Current merged raw module URG is98.21% (line99.38, condition95.95,
  toggle100.00, branch97.50). Legal line315 tuple tests were separately
  confirmed; low16 coefficient payload toggles are closed. VC Formal proves
  3/3 assertions. Invalid `MAX_TAPS=0/5` tests observed their expected errors.
  Current-source XSim tap4 generic/XPM passed; required P0 is7/7 and IP smoke
  passed. `git diff --check` was run after the edits.
- Limitations: the integrated raw URG remains98.21%; supplemental standalone
  reset-window VDB cannot merge because its hierarchy differs. The high-
  coefficient nonlinear XSim run terminated with an XSim kernel exception at
  6.41us (not a DUT mismatch); VCS passes the same vector. Full Vivado OOC
  reached route but failed setup and stopped before CDC/report finalization;
  the timing-driven rerun is active. The 10ns bundled-data constraint is
  provisional. Integrated reset/CDC/RDC and
  routed STA are not signed off. No blanket coverage waiver or adjusted100%
  score is claimed.
- Evidence: `runs/thermo5_axil_final_vcs_{generic2,xpm2}_20261013/`,
  `runs/thermo5_axil_cfg_formal_final_20261013/`,
  `runs/thermo5_axil_cfg_unit_20261013/`, and
  `runs/thermo5_axil_close_ooc_full_20261013/`.

## 2026-10-14 15:34 SGT - AXI-Lite checkpoint OOC route attempt

- Changed: refreshed the active execution frontier and AXI-Lite architecture
  status with current implementation evidence. No RTL or verification behavior
  changed.
- Checks: resumed current-source `optimized.dcp` using
  `syn/run_route_ooc_thermo5_axil_from_checkpoint.ps1` in
  `runs/thermo5_axil_route_resume_20261014_1405/`. `place_design` completed
  with 0 errors/0 critical warnings and one high-congestion warning, saving
  `placed.dcp`. `phys_opt_design` completed with 0 errors/0 critical warnings
  and eight ordinary warnings, saving `physopt.dcp`. Pre-route DRC passed with
  zero errors. Placement WNS was -0.577 ns; phys-opt estimated WNS/TNS was
  -0.592/-19.509 ns; the intermediate routing summary was
  WNS/TNS/WHS/THS=-0.588/-13.508/-0.015/-0.060 ns. The router estimated
  congestion level 6 and entered rip-up/reroute Global Iteration 0.
- Limitations: the route was stopped when Windows available memory fell to
  about 0.60 GB. Memory recovered after stopping. `placed.dcp`, `physopt.dcp`,
  and the Vivado log are preserved; no routed checkpoint, final route status,
  or final WNS/WHS exists. OOC part-pin and parent I/O-delay constraints remain
  incomplete. This attempt is not a routed timing PASS or physical signoff.

## 2026-10-14 15:38 SGT - XPM counter bit24 coverage closure

- Changed: updated the current verification frontier and bit24 closure record.
  No RTL, oracle data, or coverage database was modified.
- Checks: existing licensed VCS/UVM XPM seed610710 completed with exit0 and
  PASSed 16,777,222 four-plane bit-true output words, all16 counter resets,
  signed endpoints, and zero UVM warnings/errors/fatals. Its same-binary XPM-
  only URG and exact 16-lane audit completed with exit0; all16 DPD lanes saw
  both sample-count bit24 directions. Raw XPM hierarchy score after merge is
  80.18% (line76.99, condition67.89, toggle82.91, FSM90.91, branch62.37,
  assertion100). Generic bit24 had already closed at87.01% raw score.
- Limitations: reachable bits25-31 remain OPEN (224 directional misses per
  FIFO). The XPM FWFT transition and unrelated generic/XPM code-coverage gaps
  remain open; this is not raw100% code-coverage closure.
- Evidence: `runs/thermo5_bit23_vcs_xpm_20261012/` and
  `runs/thermo5_bit24_oracle_20261012/finalizer_610710_launcher.log`.

## 2026-10-14 16:32 SGT - AXI-Lite routed OOC continuation

- Changed: extended the checkpoint route helper with an explicit `-NoPsir`
  option and refreshed the AXI-Lite physical-status notes. No RTL or functional
  behavior changed. PowerShell syntax parsing and `git diff --check` passed.
- Checks: two timing-driven continuations from the saved physopt checkpoint
  reached Phase 8.2; both were deliberately interrupted when available RAM
  reached 0.36 GB and 0.33 GB. Intermediate WNS/TNS/WHS/THS was
  -0.630/-23.610/+0.027/0.000 ns. A `Quick -no_psir` route then completed with
  zero routing errors; all 209,406 routable nets are fully routed and
  `routed.dcp`, timing, route-status, and utilization reports were generated.
- Result/limits: Quick-route WNS/WHS=-4.240/-0.019 ns (FAIL_SETUP). Because
  Quick is non-timing-driven, it is not timing signoff. The current wrapper
  lacks I/O delays on 527 inputs and 308 outputs; parent-level timing is open.
  The prior full timing-driven OOC also failed setup at WNS=-0.630 ns. Resume
  timing-driven route only with sufficient RAM headroom; no PASS is claimed.
- Evidence: `runs/thermo5_axil_route_resume_20261014_1405/`,
  `runs/thermo5_axil_route_resume_20261014_1545_runtimeopt/`,
  `runs/thermo5_axil_route_resume_20261014_160131_no_psir/`, and
  `runs/thermo5_axil_route_resume_20261014_161911_quick/`.

## 2026-10-14 22:41 SGT - DSP/TID timing optimization and OOC rerun

- Changed: retimed the existing memory-DPD gain reduction across s5/s6 in
  `rtl/dpd/dpd_memory_poly.v`, reusing s7 for complex products; replicated the
  TID I/Q feedback state into local four-row banks in
  `rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv`. Intended arithmetic,
  output ordering, and total pipeline latency are unchanged. Added optional
  timing report output to `syn/validate_thermo5_axil_checkpoint.tcl`.
- Verification: required P0 XSim 7/7, IP smoke, current-source 56-word generic
  and real-XPM AXIL tests, tap4 identity tests, and nonlinear DPD VCS/UVM tests
  on generic/XPM all passed; four-plane output matched MATLAB with zero UVM
  warnings/errors/fatals. `git diff --check` passed.
- OOC: `run_ooc_all_dsm.ps1 -Part xc7z020clg400-1` completed (launcher exit0),
  with 12/14 configurations PASS. `p0_ooc_mb_ef2` failed timing at WNS=-0.093 ns
  and `p0_ooc_mb_mash22` at WNS=-0.688 ns. These are separate small DSM tops.
  Full reports are in
  `syn/reports/ooc_xc7z020clg400_1_20261014_221303/summary_all.csv`.
- Thermo5 AXIL synthesis created and separately reopened a 56.3 MB DCP
  (83,557 LUT, 84,847 FF, 1,936 DSP48E2, 6.5 BRAM tiles); the original
  synthesis launcher returned nonzero after saving the DCP. The unplaced
  diagnostic WNS=-0.734 ns is not route timing. Placement saved only
  `runs/thermo5_axil_timing_opt_place_physopt_20261014/optimized.dcp` and was
  stopped at 1.24 GB available RAM. No placed/physopt checkpoint or timing-
  driven route exists for this RTL. After the small OOC suite, available host
  memory was about 8.3 GiB, below the observed need for a safe large-design
  placement/route retry.
- Limits: previous thermo5 routed baseline remains FAIL_SETUP at WNS=-0.630 ns;
  the modified RTL is not timing-signed off. Parent XDC still uses provisional
  budgets and omits delay on 527 inputs/308 outputs in the AXIL OOC report.
  Real parent I/O constraints remain OPEN pending actual clock source,
  producer Tco, receiver setup/hold/capture budgets, and SI5341 configuration.

## 2026-10-16 - Thermo5 DV tree organization

- Changed: grouped focused AXIS/FIFO, TID32, and raw64 tests under
  `dv/verif/block/`; grouped thermo5 full frontend, four-plane, and serializer
  loopback tests under `dv/verif/subsystem/tx_frontend/`. Updated runner paths,
  regression/readme navigation, reset/CDC evidence references, and the physical
  migration map. Added a missing standalone TID32 MATLAB vector generator so
  its existing block test is runnable; no RTL or bit-true arithmetic changed.
- Cleanup: removed obsolete non-thermo5 block/subsystem documentation and
  generated vectors from this focused branch; the multi-SKU source remains on
  `main`. Preserved ignored local simulator/build output by archiving it under
  `runs/local_dv_artifacts_20261016/`.
- Checks: generic/XPM AXIS CDC, frame-power, XPM FIFO reset, reset-release
  audit, TID32 Cartesian bit-true, thermo5 frontend, four-plane multi-PA,
  raw64 continuous TX, serializer loopback, and frozen 56-word full-chain XSim
  all PASS. Additional structural/path checks and `git diff --check` are part
  of final review.
- Limitations: these checks validate the reorganized directed-DV sources; they
  do not change the separately reported UVM coverage status or close parent
  CDC/RDC, physical GT/board, or parent I/O timing signoff.
# 2026-10-16 — Split thermo5 AXI-Lite register and integration tests

- Extracted AXI-Lite register-map/protocol checks from the full configuration
  stream test into `thermo5_sku_axil_register_access_test`; it exercises ID,
  STATUS, TAPS, all coefficient words, AW/W skew, WSTRB, DECERR/SLVERR, and
  response backpressure without sending AXI-Stream payload.
- Kept the commit/mailbox/frame-boundary/PA-stall/reset/bit-true scenario as a
  separate wrapper integration test. Existing coefficient-image, tap-4,
  nonlinear-image control-only, boundary-phase, mailbox-fault, and illegal
  frame scenarios remain individually named.
- Added `docs/verification/thermo5-test-level-matrix.md` to map each tested
  block and subsystem to stimulus, intent, expected result, and current limits.
- Checks: VCS compile PASS; full generic `thermo5-axil-vcs-regression` PASS,
  including register-only, default integration, coefficient transport,
  nonlinear-image control, tap-4 identity, boundary phase, expected negative
  frame/mailbox checks, parameter guard and URG merge. All UVM positive tests
  report zero UVM_ERROR/FATAL; negative RTL assertions are explicitly expected
  and the runners verify them. Run output is
  `runs/thermo5_axil_refactor_suite_retry_20261016/`. XPM has not been rerun
  after this UVM test extraction.
- Limits: nonlinear DPD arithmetic remains without a matching bit-true oracle;
  current tests do not close parent-level CDC/RDC, physical GT, or board output.

## 2026-10-18 - Thermo5 full-IP UVM scenario file split

- Changed: extracted shared setup/check helpers into
  `thermo5_sku_base_test.svh`, left the nominal test in
  `thermo5_sku_bittrue_test.svh`, and moved each of the ten full-IP corner UVM
  test classes from `thermo5_sku_corner_tests.svh` into its own source file
  under `tests/thermo5/full_ip/`. Retained the old corner file as an include
  hub; public test class names and regression targets are unchanged. Added a
  scenario README and updated `dv/uvm/README.md`.
- Checks: structural source/class/include-order check and `git diff --check`
  PASS. VCS compile was attempted from Rocky WSL but the license server
  connection failed before a simulator executable was produced; no VCS/UVM
  PASS is claimed.
- Limits: no RTL or test behavior changed. Re-run generic and XPM full-IP UVM
  regressions in a licensed environment to validate simulator preprocessing,
  compile, and runtime after the source split.

- RTL datapath and fixed-point behavior were not changed by this refactor.

- Simulation artifacts remain under ignored `runs/`; only source, runner,
  and documentation changes are part of this update.
# 2026-10-19 - Split thermo5 formal harnesses by proof topic

- Split combined formal wrappers into reset, DPD counter, generic CDC/gearbox,
  DPD identity, identity lemma, interpolator-bound, and XPM FIFO sources.
- Updated focused Tcl/Python runners, coverage-reason citations, formal README,
  and reset audit documentation to use the new topical sources.
- No RTL behavior changed. The first split identity run found obsolete s6
  product references left behind after the Oct15 datapath pipeline retiming;
  these are now aligned to the current s7 products and two redundant
  product-delay checks for the removed stage were dropped.
- Checks: fresh VCF PASS for reset, bounded/unbounded counter, generic CDC,
  interpolation bounds, XPM reset, and XPM residual. Identity has 5 proven and
  13 inconclusive assertions; FWFT state legality is proven, but its reset-
  transition cover is inconclusive. Manifests are under
  `runs/thermo5_formal_harness_split*20261019/`.
- Limitations: proof scope remains limited to the harness assumptions and
  parameters documented in each run; this does not sign off whole-chip CDC/RDC.

## 2026-10-25 - Add and run thermo5 VCU118 synthesis-only flow

- Added `syn/run_synth_thermo5_vcu118.ps1` and its Tcl flow for the frozen
  no-AXI-Lite AXI-Stream top on `xcvu9p-flga2104-2L-e`; documented its scope in
  `syn/README.md`.
- Checks: PowerShell parser and `git diff --check` PASS. Vivado 2026.1 synthesis
  PASS; 44,444 LUTs, 53,517 FFs, 496 DSP48E2, 6 RAMB36E2 + 1 RAMB18E2, 0 URAM.
  Synthesized timing estimate at 125/218.75 MHz: WNS +1.140 ns, WHS +0.039 ns.
  Vivado reported 201 warnings, 0 critical warnings, 0 errors. Full log,
  checkpoint, utilization, timing, and check-timing reports are in
  `runs/thermo5_vcu118_synth_retry2_20261025_2132/`.
- Limitations: this is synthesis-only OOC evidence; 570 inputs and 264 outputs
  have no I/O delays. It does not include placement/routing, VCU118 board I/O,
  or the ZU15EG-specific GT parent. The memory-inference and DPD set/reset
  warnings need review before promoting the mapping.

## 2026-10-30 00:23 SGT - Establish product-scoped Thermo5 TX coverage baseline

- Audited the stacked PR #2 → #3 → #4 → #5 dependency chain and the Gate 3
  source/artifact manifest. All 84 source hashes and 22 individually hashed
  artifacts match their PR #5 contents. Five of 12 historical directory-tree
  hashes do not reproduce; exact observed digests and limits are documented
  in `thermo5-tx-coverage-closure.md` and its evidence JSON.
- Scoped VCS coverage to `thermo5_sku_uvm_tb.dut`; added a test-only
  `DPD_MAX_TAPS` override and a one-tap identity configuration check matching
  the actual GT-parent settings. The RTL algorithm and RX/AI-DPD were not
  changed. Candidate 2/4-tap DPD and PAIR_LOOKAHEAD remain separate reports.
- Checks: five selected AXI-Lite product-config VCS tests PASS with zero UVM
  errors/fatals; VCS V-2023.12-SP1 / URG generated raw product coverage.
  Product raw score is 75.96% (line 3190/3796, condition 579/846, branch
  440/637, toggle 82919/104478, FSM 13/13 states and 15/22 transitions,
  assertion score 86.67%). Eight functional groups score 97.97%; no waiver
  or exclusion is applied. Python coverage-gate syntax and source-hash audit
  pass; strict mode correctly remains open (`RAW_100_OPEN`) and rejects an
  active exclusion directive.
- Evidence and commands: `docs/verification/thermo5-tx-coverage-closure.md`,
  `docs/verification/thermo5-tx-product-coverage-evidence.json`,
  `runs/thermo5_tx_product_axil_cov_20261030/` (ignored local VDB/log/report),
  and the separate candidate report under
  `runs/thermo5_tx_candidate_cov_20261030/`.
- Remaining: complete Functional Coverage and eligible code closure in Tasks
  4–6; audit the five historical directory digest mismatches without rerunning
  full regressions; real XPM, GT Wizard/raw64, and physical FPGA evidence are
  unavailable in this Linux baseline.

## 2026-10-30 12:22 SGT - Continue Thermo5 TX Linux coverage closure Tasks 4-6

- Added a legal AXI-Lite reset sweep that hits all five previously missing
  Generic CDC residual FSM transitions, with five public reset epochs and a
  post-reset four-plane identity replay. Added the test to the UVM package and
  Linux Make targets; RTL and frozen TX algorithms are unchanged.
- Reused the five selected product VDBs from PR #6 and merged the reset-sweep
  and one-tap coefficient-transport runs only. Product Raw URG is 81.95%
  aggregate; FSM is 13/13 states and 22/22 transitions. Functional URG is
  170/174 raw bins (97.97% average group score); adjusted code coverage equals
  raw, with zero approved waivers and exclusions. The fail-closed gate returns
  `RAW_100_OPEN`.
- Added a separate expected-negative AXI-Lite assertion report, EF2 Formal
  evidence, retained Generic CDC Formal evidence, and a PA0 bit-true scoreboard
  mutation run. DPD identity Formal and dedicated frame-tail reachability remain
  open; fresh CDC rerun was blocked by the license server. Candidate DPD and
  PAIR_LOOKAHEAD remain separate from the product coverage merge.
- Updated `thermo5-tx-linux-coverage-closure.md` and its evidence JSON,
  linked the current product result from the historical coverage signoff,
  refreshed the execution frontier, and recorded exact artifact hashes.
- Checks: reset-sweep UVM PASS (seed 610802; five resets, 56 post-reset
  four-plane words); one-tap coefficient transport UVM PASS (seed 610803; 56
  four-plane words); illegal-frame expected assertions observed separately
  (seed 610804); PA0 checker mutation caught (seed 610805); EF2 VC Formal PASS
  (6/6 assertions, 3/3 covers); prior exact Generic CDC proof retained (7/7,
  9/9); coverage gate `RAW_100_OPEN`; JSON parse and evidence-consistency checks pass,
  as do the fail-closed gate re-evaluation and `git diff --check`.
- Limits: line/branch/condition/toggle closure remains open; DPD identity
  arithmetic proof remains inconclusive; fresh CDC Formal rerun could not
  reach setup; real XPM/GT Wizard, routed FPGA PPA, and physical QAM256 BER are
  unavailable. The Python worst-case campaign is a model screen without a
  defined product BER/BLER acceptance target.

## 2026-10-30 12:29 SGT - Record blocked boundary-phase coverage attempt

- Attempted the legal AXI-Lite boundary-phase test at seed 610806 to continue
  Task 4 branch closure after opening PR #7.
- VCS exited 255 before UVM started because the license server could not be
  reached. No coverage result was produced and the attempt VDB was not merged.
- Preserved the invocation, simulator output, and exit status under the ignored
  `runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/` directory;
  indexed the log hashes in the machine-readable evidence.
- The product Raw coverage remains unchanged at 81.95% aggregate and the gate
  remains `RAW_100_OPEN`. Further VCS branch/condition/line/toggle closure
  requires a working license service.

## 2026-10-30 13:01 SGT - Resume licensed TX coverage closure

- After VCS/VC Formal license recovery, reran the blocked AXI-Lite boundary
  phase at seed 610806 and exercised offsets 1/2/4/8/16/32, RUN+COMMIT with
  AW/W skew, source gaps before beats 8 and 20, and six RUN-relative COMMIT
  delays. All 16 legal cases passed the four-plane bit-true checker with zero
  UVM errors/fatals. No RTL, RX, AI-DPD, or frozen TX algorithm changed.
- Added the six RUN-relative COMMIT VDBs to the positive product Raw merge
  and regenerated URG, the exact raw denominator/gate, and source-linked gap
  ledger. The merge contains 23 positive simulation VDBs plus the compile
  VDB. One condition bin was newly hit by RUN+COMMIT overlap; the later delay
  sweep did not change aggregate code counters. Current Raw is 81.97%:
  line 3,190/3,796, condition 582/846, branch 440/637, toggle
  86,951/104,478, FSM states 13/13 and transitions 22/22. Functional raw
  coverage remains 170/174 bins, with 170/170 applicable positive bins hit.
  Raw equals adjusted; zero approved waivers and exclusions; gate
  `RAW_100_OPEN`.
- Audited the EF2 `PAIR_LOOKAHEAD` branch against the actual GT-parent
  parameter chain. The four product instances inherit the module default 0;
  their unhit line-231 true-arm bins remain in the denominator as
  `OPEN_CONFIGURATION_REVIEW`. No exclusion or waiver was applied, and the
  candidate branch remains separately reported.
- Fresh Generic CDC VC Formal passes 7/7 assertions and 9/9 covers with zero
  black boxes in 56.67 seconds. Identity DPD Formal completed but remains
  inconclusive: 1/5 assertions proven, 4/5 inconclusive, 4/4 covers hit,
  zero black boxes. A second run with 2-minute per-property and 6-minute
  total effort limits reached max effort after 367.39 seconds with the same
  four assertions inconclusive and no counterexample. Identity remains OPEN;
  no DPD bins are waived.
- Refreshed `thermo5-tx-linux-coverage-closure.md` and its evidence JSON,
  updated the historical coverage-signoff landing note and execution frontier.
  Evidence hashes cover the latest URG report, gate, gap ledger, VDBs, and
  fresh formal reports.
- Checks: 16/16 boundary/traffic UVM tests PASS; refreshed URG/denominator and
  gap-ledger generation PASS; coverage gate reports `RAW_100_OPEN`; fresh CDC
  Formal PASS; identity Formal signoff gate fails to converge and remains
  explicitly OPEN; boundary/coverage/formal evidence consistency checks,
  JSON parse, and `git diff --check` PASS.
- Limits: line/branch/condition/toggle closure remains incomplete; identity
  arithmetic and frame-tail reachability remain open. Real XPM, GT Wizard,
  FPGA PPA/routed timing, and physical QAM256 BER remain outside Linux scope.

## 2026-10-30 13:09 SGT - Extend product PA backpressure stress

- Added a bounded `AXIL_PA_STALL_CYCLES` override to the existing AXI-Lite
  config test; its default remains the prior four-cycle stall. The test rejects
  values outside 4..4096 cycles.
- Recompiled the unchanged product configuration and ran seed 610822 with all
  four PA ready signals held low for 64 core cycles after output-valid. The
  56-word four-plane identity stream passed the independent bit-true checker;
  UVM warnings/errors/fatals were all zero.
- Merged that positive product VDB into the Raw URG report (24 simulation
  VDBs plus compile VDB). Code metrics, functional group scores, and the 18,594
  open/review ledger rows did not change. No waiver, exclusion, denominator,
  or DUT algorithm change was made.
- Checks: licensed VCS compile and targeted product run PASS; URG merge,
  denominator extraction, gap-ledger extraction, and coverage gate PASS with
  `RAW_100_OPEN`; source manifest and evidence hashes refreshed; JSON parse
  and `git diff --check` PASS.
- Limits: the longer PA hold did not hit additional DUT code bins. Coverage
  convergence, identity DPD proof, frame-tail formal reachability, vendor
  XPM/GT Wizard, FPGA PPA, and physical QAM256 BER remain open.

## 2026-10-30 13:59 SGT - Prove centered frame-tail parameter reachability

- Added a scoped VC Formal harness for the centered interpolator's two
  frontend parameter settings (`APPEND_TAIL_VECTOR=1` and `0`, W=16,
  LANES=8). Added the corresponding scoped Formal runner job and recorded the
  exact result in the TX closure evidence and signoff notes.
- VC Formal V-2023.12-SP2: 3/3 assertions proven; all three legal covers hit;
  the append-disabled tail cover is expected `uncoverable`; zero black boxes
  and zero clock/glitch/loop/multidriver setup violations. The source-stability
  assumption is non-vacuous. Repeated the proof from clean source SHA
  `23214fbe4b7a06bcf489e39ec9110d76885eda9e`; the manifest hashes the
  production interpolator RTL and reports a clean worktree.
- The proof is module-level parameter reachability, not end-to-end composition
  of the cascaded interpolators. It does not add URG hits, alter the coverage
  denominator, or approve a waiver.
- Rechecked the existing product Raw gate without rerunning VCS/URG:
  `RAW_100_OPEN`, Raw equals Adjusted, zero waivers/exclusions; line
  3,190/3,796, condition 583/846, branch 440/637, toggle 86,951/104,478,
  FSM states 13/13 and transitions 22/22.
- Checks: Formal proof PASS; coverage gate recheck PASS with `RAW_100_OPEN`;
  evidence JSON parses; `git diff --check` PASS.
- Remaining: product Raw code coverage and DPD identity arithmetic Formal
  remain open. The module-level proof does not qualify full-chain frame-tail
  composition. Real XPM, GT Wizard, FPGA PPA, and physical QAM256 BER remain
  outside this Linux signoff.
## 2026-10-30 22:04 SGT - Formal reachability closure for TX coverage bins

- Added exact product-configuration Formal Covers/assertions for the two
  centered-interpolator stage settings and AXI-Lite default/parameter paths.
  Removed two reset-coupling assumptions from the AXI-Lite harness after VC
  Formal reported them vacuous; the accepted harness run has no environment
  assumptions.
- Added a fail-closed AXI-Lite Formal runner and a formal-bin disposition
  updater. The updater validates exact semantic Bin IDs, instances, source
  positions and source-file hashes against the raw ledger, plus proof/Cover
  status, setup report, black-box count and non-vacuous assumptions. It changes
  ledger status only and cannot edit URG denominators or `.el` exclusions.
- Applied six exact `PROVEN_UNREACHABLE` dispositions: three interpolator
  product-parameter bins and three AXI-Lite default/parameter bins. Raw URG
  denominator and counters remain unchanged; 18,587 of 18,593 code-gap rows
  remain OPEN. No waiver or exclusion was approved.
- Added `thermo5-tx-coverage-final-signoff.md`, refreshed the root-cause
  closure report, evidence manifest, task table and execution frontier.
- Checks: VC Formal frame-tail 6/6 assertions, 5/9 Covers reached and 4/9
  uncoverable; AXI-Lite 5/5 assertions with exact three unreachable Covers,
  0 assumptions, 0 setup violations and 0 black boxes; EF2 6/6 assertions and
  3/3 Covers; product EF2 parameter 2/2 assertions and 2/2 expected
  uncoverable Covers; bounded counter 3/3 assertions and 4/4 Covers; unbounded
  counter 35/35 bit-transition assertions and 4/4 shallow Covers. Formal
  disposition script validated all six exact ledger mappings. JSON, gzip
  integrity and `git diff --check` were also checked.
- Limits: Identity DPD remains inconclusive (direct 5/18 proven, staged
  auto-lemma 1/13 proven). The 2,072-sample counter proof budget is not a
  product traffic contract. Targeted product UVM did not hit the interpolator
  pop/push branch and was not merged into URG. Fresh VCS/URG is blocked by the
  installed VCS platform check rejecting WSL kernel
  `6.6.87.2-microsoft-standard-WSL2`; product Raw remains reused, Adjusted is
  identical with zero waivers, and `RAW_100_OPEN` remains. The observed
  16-cycle source-gap underflow remains an interface/service-rate risk.
- 2026-10-30: Reconciled the active execution-frontier branch name with draft
  PR #10 (`codex/thermo5-tx-final-signoff`). No RTL, evidence database, coverage
  denominator, or verification result changed; `RAW_100_OPEN` remains.


## 2026-10-31 10:22 SGT - AXI-Lite coefficient-read Branch Formal closure

- Re-ran the committed AXI-Lite configuration Formal harness with VC Formal V-2023.12-SP2 after VCS license recovery. The exact current-source run passed 4/4 assertions; the legal coefficient-read Cover was hit; the exact default-arm Cover was uncoverable; assumptions=0, non-vacuous assertions=3, black boxes=0, setup violations=0.
- Added the exact coefficient-read `case (addr & 8'hf8)` default Branch bin `TXB-65f3dfeee7bc0b854f52` to the fail-closed Formal dispositions, bound to instance, line 135, RTL source SHA, Formal result hashes, and existing current Raw evidence. Corrected its root-cause note from write-address decode to coefficient-read decode. Raw URG and denominator are untouched.
- Updated the coverage closure/signoff and execution frontier. The audit now contains six `PROVEN_UNREACHABLE` bins and 18,587 OPEN rows; Raw code metrics are unchanged at line 3190/3796, condition 583/846, branch 440/637, toggle 86951/104478. Waivers=0, `.el` exclusions=0, `RAW_100_OPEN`.
- Checks: Formal runner PASS; Formal disposition updater PASS with the existing VCS/URG refresh evidence; focused VCS AXI-Lite config test seed 610931 PASS (0 UVM warnings/errors/fatals); no full regression or URG remerge was needed because product sources and Raw inputs did not change.
- Limitations: a temporary mailbox Formal check was inconclusive; its selected-property trace did not execute the AW/W assumptions and is not accepted as legal-protocol evidence. The focused VCS case does not resolve that gap. DPD Identity Formal and the 16-cycle source-gap underflow contract remain OPEN. No RTL or product algorithm changed.

- Current-worktree coverage-gate recheck returned exit 3, `FAIL_CLOSED_SOURCE_HASH_MISMATCH`. The baseline compile manifest is pinned to `913be930bfcbbad0f78dbc90e06299db3d1bb337`; exactly three compiled UVM files differ in the current tree. All product RTL hashes match. The Raw URG and denominator were not edited, and no full regression/remerge was run to paper over the source mismatch. The exact invocation, hashes, and log are captured under the local ignored `runs/thermo5_tx_final_closure_20261031/` evidence directory and summarized in the tracked audit JSON.

## 2026-10-31 10:31 SGT - Negative-only AXI-Lite assertion and Branch check

- With the restored VCS license, compiled and ran the current-source negative-only early-TLAST test (seed 420102) and generated a separate URG report. The independent UVM checker saw both expected protocol assertions, sticky error state, and reset recovery; UVM warning/error/fatal counts were 0/0/0. The separate URG report hit Branch `TXB-646dd03c99766d877d30` at RTL line 141.
- Kept the negative VDB separate from product Raw. Its legal-product Raw ledger row remains OPEN; no product Raw metric, denominator, waiver, or exclusion changed. The complete command, source/log/URG/VDB hashes, and observed outcomes are in `docs/verification/data/thermo5-tx-negative-assertion-evidence.json`.
- Remaining: current-worktree Raw source-manifest mismatch, legal-product pop/push cadence bins, mailbox-stability Formal, DPD Identity Formal, and source-gap service contract remain unresolved. The negative-only Branch hit is not positive-product coverage closure.

## 2026-10-31 10:47 SGT - Product-bound outstanding counter Formal attempt

- Added an exact-product Formal harness for the two outstanding-word guard Branches at RTL lines 203–204 (`TXB-e99262dd92665c3b9ea8`, `TXB-c16debdf7d9cbab220ac`). It uses the frozen Centered-Cubic/EF2/identity-DPD/Generic-FIFO configuration, legal 32-beat AXIS and AXI-Lite RUN sequencers, arbitrary PA backpressure, and exact scaled clock periods 35/28/16.
- VC Formal V-2023.12-SP2 ran 489.77 seconds with no external SVA assumptions, two non-vacuous assertions, source/core/output Covers reached, and zero clock/glitch/loop/multidriver setup issues. Saturation assertion/Cover were INCONCLUSIVE at depths 142/141; underflow assertion/Cover were INCONCLUSIVE at depths 102/103. There was no counterexample, but no proof; both ledger rows remain OPEN and no disposition was added.
- Saved the machine-readable status and hashes in `docs/verification/data/thermo5-tx-outstanding-counter-formal-evidence.json`; full local logs/properties/setup are in ignored `runs/thermo5_axil_outstanding_formal_20261031_retry/`. The fail-closed runner now classifies depth-limited outcomes as `INCONCLUSIVE` rather than a generic fail.
- Checks: formal result/source/log hashes cross-check; Python `py_compile` and JSON/ledger validation; `git diff --check`. Raw URG, denominator and product RTL are unchanged.

## 2026-10-31 10:54 SGT - Centered-Cubic test-scope audit

- Confirmed VCS V-2023.12-SP1 license recovery by compiling the fixed TX product profile: Centered-Cubic x2+x2, EF2 ORDER=2/STEP=5120, one-tap identity DPD, AXI-Lite parent and Generic FIFO.
- Ran `thermo5_sku_interp1_empty_blocked_test` at seed 620131 as a targeted coverage experiment. Compilation passed; the UVM run timed out at 10,000 core cycles with one fatal before its independent bit-true checker/pass marker. Root cause: the test waits for the causal-FIR-only `interp1_stall_window`, which the Centered-Cubic top explicitly ties to zero. Its stage-1 hit probe is also tied low under that product define.
- Kept the failed-test VDB separate; no URG merge, Raw coverage claim, denominator, waiver, or exclusion changed. Added machine-readable hashes and exact command in `docs/verification/data/thermo5-tx-centered-test-scope-evidence.json`; corrected the full-IP test README and execution frontier to state this scope boundary.
- Next: use only Centered-Cubic-specific legal events/checkers or non-vacuous product-bound Formal for product coverage. The earlier 26-phase product cadence sweep remains zero-delta; do not repeat causal tests or blind phase/seed sweeps.

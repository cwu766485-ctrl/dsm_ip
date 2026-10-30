## 2026-10-30 17:02 SGT - Publish Phase 0/1 TX closure PR #8

- Opened draft PR #8, `Thermo5 TX: Phase 0/1 Linux design and verification
  closure`, stacked on PR #7; it remains open and unmerged.
- The locally tested commit is `99c852dc46cbb9091c6099267535465acfac2d47`.
  The GitHub API-created PR head is `3da1ab21142218ce795252bd62d8865176a9ffe5`;
  both resolve to the same complete tree SHA
  `20a10962b1979349b15fcbf9a9b4807f78f26786`.
- Updated the active execution frontier to reflect the published PR and its
  review as the next action. No RTL, verification behavior, product coverage,
  or benchmark result changed in this publication bookkeeping.
- Checks: clean source state before this note; PR metadata confirms open,
  draft, unmerged, with PR #7 as base. A follow-up docs-only commit will keep
  this entry and the active frontier synchronized on the PR branch.

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

## 2026-10-24 22:16 SGT - close centered-cubic DPD, packet, and low-power checks

- Extended the Python fixed-point oracle with the RTL memory-polynomial
  arithmetic, including Q2.14 coefficients, temporal tap history, arithmetic
  shifts, and signed-16 saturation. Added a two-tap image with nonzero cubic
  terms strictly for directed verification; it is not a fitted DPD solution.
- Added an AXI-Lite centered-cubic UVM case that compares all four planes for
  one 32-beat/56-word packet and for two back-to-back 32-beat packets
  (64 beats/112 words) with one centered-FIR tail per frame. The same two-tap
  nonlinear DPD image is committed before the first DPD frame boundary.
- Added the repeated-TLAST source-sequence option and a centered-cubic
  low-power STOP case. The test revealed that RUN deassertion could close
  source ingress before the current packet's TLAST. The AXIS wrapper now keeps
  ingress open for that already-started centered packet, then blocks the next
  packet until RUN is requested again.
- Checks: 24 Python model tests PASS; the two nonlinear DPD UVM cases PASS
  with 0 UVM errors/fatals; centered-cubic low-power STOP/drain PASS with all
  56 words bit-true, no underflow/protocol error, zero outstanding work, and
  return to IDLE; generic-FIFO thermo5 VCS regression PASS across all seven
  tests with zero UVM errors/fatals and the expected negative frame assertion.
  Evidence is under `runs/thermo5_gap_closure_axil_vcs/`,
  `runs/thermo5_gap_closure_lowpower_vcs/`, and
  `runs/thermo5_gap_closure_baseline_vcs/`. XSim is not installed on this Linux
  host. FPGA resource/timing was not run per user direction.
- Benchmark status: the existing 450-case FIR/drive/PAPR sweep still ranks
  centered cubic first in corrected EVM for all 18 held-out configurations;
  the actual TID-plane receiver screen averages 3.273% digital EVM / 29.702 dB
  SNDR, 3.370% / 29.447 dB with the illustrative nominal output chain, and
  3.685% / 28.671 dB under its illustrative stress profile. Those output-chain
  parameters are sensitivity assumptions. Thermometric STEP and DSM NTF/order
  sweeps remain pending; no architecture setting was promoted to the default.
- `git diff --check` PASS. Remaining limits: nonlinear RTL arithmetic is
  bit-true checked for the directed two-tap coefficient image, not broadly
  swept across arbitrary coefficient banks; XSim and FPGA mapping/timing are
  pending on the FPGA host.

## 2026-10-24 21:37 SGT - implement optional centered-cubic streaming RTL

- Added `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv`, a ready/valid x2
  interpolator using Q14 `[-1, 9, 9, -1]/16`, round-away-from-zero, and
  W-bit saturation. The frontend selects two instances with
  `INTERP_CENTERED_CUBIC=1`; the existing causal path remains the default.
- Added frame-end handling to the parallel AXI path. `TLAST` crosses the 14:8
  gearbox and stays aligned through the ingress metadata FIFO, frame-gain
  pipeline, and DPD sideband. Stage 1 adds a tagged lookahead vector at the
  frame tail; stage 2 uses and drops it so no extra PA words are emitted.
- The first centered run timed out because frame end was connected directly
  across a multi-cycle frame-gain path. Carrying end metadata with the data
  fixed the stall. A default-build compile also caught a duplicate tie-off on
  the causal second-stage frame-start output; removing that tie-off preserved
  the interpolator's actual marker.
- The first AXI-Lite centered run exposed an over-eager hold assertion that
  compared the first cycle of a stall to the preceding invalid cycle. The
  assertion now checks stability only after a prior stalled cycle; the
  correctly configured AXI-Lite integration run then completed bit-true.
- Added Python oracle/vector mode, centered-cubic UVM selection and count
  checks, the `thermo5-centered-cubic-vcs` target, and the new RTL in simulation,
  formal, synthesis, and FPGA source manifests. Exposed the selector through
  the ZU15EG GT parent while keeping its default disabled. Updated the execution
  frontier, UVM architecture, Python model, and command documentation.
- Checks: centered-cubic VCS bit-true run PASS with stress PA backpressure
  (32 AXI beats, 56 four-plane output words, 3 frame starts, 1 accepted
  `TLAST`, 28 PA stall cycles, zero UVM errors/fatals); default causal
  `thermo5-vcs-regression` PASS across all seven tests, including the expected
  negative frame assertion; centered AXI-Lite config integration PASS (56
  bit-true words, one accepted `TLAST`, no assertion/UVM errors); AXI-Lite
  centered top compile PASS; Python unit suite PASS (22 tests) before the final
  RTL-only edits. Logs are under
  `runs/thermo5_centered_cubic_final2_20261024/`,
  `runs/thermo5_centered_cubic_baseline_regression_fix1_20261024/`, and
  `runs/thermo5_centered_cubic_axil_final_20261024/`. `git diff --check`
  passes; no XSim or FPGA resource/timing run was made on Linux.
- At this point in the earlier implementation record, valid `TLAST` had to
  align to a complete 56-sample group and only a 32-beat packet had been checked.
  The 22:12 entry above adds the short, consecutive-packet, nonlinear DPD, and
  low-power drain closure. XSim and FPGA resource/timing remain open; the
  centered path remains optional and is not the default FPGA preset.

## 2026-10-24 20:43 SGT - rerun thermo5 generic-FIFO UVM regression with VCS

- Retried `thermo5-vcs-regression` after the user started the Synopsys license
  service, using Python-generated four-plane vectors and a fresh output
  directory: `runs/thermo5_tid_receiver_vcs_retry_20261024/`.
- VCS V-2023.12-SP1 compiled successfully. The bit-true, bubble/backpressure,
  FIFO-boundary, FIFO-empty, reset, reset-sweep, and negative-frame tests all
  completed. All seven UVM reports had zero UVM errors/fatals; the negative
  test observed the expected RTL assertion and verified reset recovery.
- Updated the execution frontier to replace the prior license-blocked status
  with the successful retry result. No RTL, MATLAB, or FPGA resource/timing
  implementation changed.
- Check: `make -C dv/uvm/sim thermo5-vcs-regression PYTHON=python3
  THERMO5_VECTORS="$PWD/runs/thermo5_tid_receiver_vcs_vectors"
  THERMO5_OUT="$PWD/runs/thermo5_tid_receiver_vcs_retry_20261024"
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1` PASS (exit 0).
- Remaining limits: this verifies the frozen thermo5 RTL against the generic
  FIFO UVM configuration; it does not implement or verify centered-cubic
  interpolation RTL. XSim and FPGA resource/timing remain for the FPGA host.

## 2026-10-24 18:02 SGT - validate raw TID timing and receiver metrics

- Added `dsm_refmodel/thermo5_receiver.py` to decode the four serialized planes,
  audit TID branch timing against independent scalar EFM recurrences, separate
  interpolation from the TID boundary, and measure centered-FIR support,
  lookahead, and frame-tail flush.
- Added `benchmark_thermo5_tid_receiver.py`: actual plane sum, 3.5-GHz Fs/4
  DDC, 14-GHz reconstruction filtering, 7-GHz receive filtering, decimation,
  256-QAM OFDM EVM/SNDR, and illustrative nominal/stress DPA, output-network,
  and kTB/NF profiles. Fixed RMS drive to 0.10 so Python seeds 101/307/503 all
  remain below the 0.35 peak limit; seed 307 at RMS 0.11 exceeded the limit and
  was excluded from scoring.
- Audited RTL2 timing as exact `x[n]` on the even phase and the current/past
  average on the following odd phase. Three seeds each had zero scalar EFM
  mismatches across 1,335,296 branch/component samples per candidate. Mean
  centered-cubic digital EVM/SNDR was 3.273%/29.702 dB; nominal analog-model
  EVM/SNDR was 3.370%/29.447 dB; stress was 3.685%/28.671 dB. Frozen RTL2
  digital EVM/SNDR was 20.827%/13.628 dB. Reports are in
  `runs/thermo5_tid_receiver_20261024/`.
- Added centered-cascade support analysis: 2.25 source samples of maximum
  future dependency, three integer samples of stream lookahead, one additional
  8-lane transaction, and three zero samples to flush a known frame tail.
  No RTL, MATLAB reference, FPGA resource, or timing behavior was changed.
- Updated the Python model README, thermo5 verification architecture,
  execution frontier, command index, and this log.
- Checks: 19 Python unit tests PASS; Python bytecode compilation PASS; three
  8-symbol/three-seed end-to-end receiver runs PASS with zero EFM mismatches;
  Python oracle vector generation PASS; `git diff --check` PASS. The required
  Linux VCS regression was attempted but stopped at compile because the
  Synopsys license server was unreachable. XSim is unavailable on this Linux
  host. Neither unavailable result is marked PASS.
- Remaining limits: the DPA, output-network, thermal-noise power, and NF values
  are illustrative; three seeds and eight symbols are a screening set. The
  centered FIR is block-mode only; its RTL transaction timing and explicit
  frame-end handshake/flush remain unimplemented. FPGA PPA/timing were not run
  per user instruction.

## 2026-10-24 15:07 SGT - select Python FIR candidate and expand architecture A/B

- Selected the Q14 centered-cubic x2 interpolation candidate
  `[-1024, 9216, 9216, -1024]` (`[-1, 9, 9, -1]/16`) for the next Python
  architecture iteration. The frozen FPGA RTL configuration was not changed.
- Expanded `benchmark_thermo5_architecture.py` to use two development seeds and
  three held-out seeds. The completed 450-case sweep ranked centered cubic
  first in corrected EVM across all 18 held-out input-normalization/PAPR/
  backoff combinations and separately within each of the three held-out seeds.
- At fixed-average input power and no PAPR clipping, held-out mean corrected
  EVM at 0/6/12-dB backoff was 4.853/0.802/0.871%; assumed output power was
  -30.00/-35.66/-41.63 dBm. A 7-dB PAPR limit at 6-dB backoff increased mean
  corrected EVM to 2.233% and worsened the adjacent-band proxy from -49.00 to
  -37.41 dBc. The report and representative PSD are under
  `runs/thermo5_architecture_ab_20261024/`.
- The 36.8% corrected EVM measured for the delay-aligned RTL 2-tap baseline at
  6-dB backoff is unusually large. The even/odd sample-time convention must be
  checked against the intended waveform reference and an independent RTL /
  bit-true vector before treating the candidate gap as a hardware prediction.
- Updated the Python-model README, AI-native commands, execution frontier, and
  this log. Checks: 12 Python unit tests PASS; benchmark bytecode compilation
  PASS; complete 450-case architecture sweep PASS; `git diff --check` PASS.
  No RTL or fixed-point reference arithmetic changed, so RTL XSim/VCS and
  MATLAB oracle checks were not applicable.
- Remaining limits: the sweep uses a behavioral DPA/output FIR and assumed
  kTB/NF parameters, periodic symbol edges, one integer delay per candidate,
  and eight OFDM symbols per seed. It does not decode actual TID planes for
  EVM/SNDR, establish standard ACLR, or report FPGA PPA/timing. The selected
  FIR still needs streaming lookahead/frame-drain design and implementation
  checks before any RTL configuration change.

## 2026-10-23 22:21 SGT - separate GT bit errors from analog output noise

- Replaced the prior Q15-payload BER/jitter proxy with an independent BER
  injector for the Python thermo5 model's four 64-bit TID output planes.
  Digital bit flips are now reported as discrete errors, separate from noise.
- Refined the output-chain model into deterministic DPA AM/AM, AM/PM, and
  envelope memory, a separate complex FIR output network, and analog thermal
  noise calculated from `kTB + NF` at a declared observation-plane signal
  power. The example powers, bandwidths, noise figures, and DPA parameters
  remain sensitivity assumptions, not calibrated hardware data.
- Added `benchmark_thermo5_gt.py`; 56 output words at BER=1e-3 produced 14
  flips over 14,336 plane bits and 13 affected words. The 64-symbol link
  benchmark at seed 20261023 measured centered-cubic corrected EVM of 0.966%
  ideal, 1.699% nominal, and 3.404% stress, versus forward-linear 4.939%,
  5.039%, and 5.692%. Stress raw EVM was 6.337% cubic and 6.216% forward;
  the selected metric therefore affects the ranking. Stress noise-only EVM was
  about 1.3% at the assumed 37.95 dB SNR.
- Recorded centered cubic as the preferred FPGA algorithm candidate, while
  keeping the frozen 2-tap RTL unchanged. The centered kernel needs future
  samples and a frame-end/flush contract absent from the frontend interface;
  it cannot be enabled by changing a coefficient setting alone.
- Updated `dv/uvm/refmodel/python/README.md`,
  `docs/ai-native/commands.md`,
  `docs/verification/thermo5-uvm-architecture.md`, and the execution frontier.
- Checks: 12 Python unit tests PASS; 64-symbol analog-chain benchmark PASS;
  four-plane GT BER benchmark PASS; Python bytecode compilation and
  `git diff --check` PASS. No RTL or bit-true reference arithmetic changed,
  so the required RTL XSim/VCS and MATLAB-oracle checks were not applicable.
- Remaining limitations: no GT timing/CDR/electrical eye, phase-noise or
  measured analog noise model; DPA/output filter and physical observation
  values are uncalibrated. EVM remains sample-domain with a scalar per-symbol
  fit, and the adjacent-band result is not standard ACLR. Centered-cubic RTL
  framing, latency, throughput, PPA, and timing are open.

## 2026-10-23 19:44 SGT - add Python GT/DPA impairment benchmark

- Added `dv/uvm/refmodel/python/dsm_refmodel/link_models.py` and
  `benchmark_thermo5_link.py` to compare the five interpolation candidates
  through deterministic ideal, GT-only, DPA-only, nominal, and stress
  conditions. GT-like impairments are sample-payload BER, timing jitter and
  I/Q skew; DPA uses a complex-envelope compression/AM-PM model with memory;
  AWGN is selectable by scenario. The assumptions are intentionally explicit
  and replaceable.
- Reran the 64-symbol interpolation baseline after fixing the complex scalar
  least-squares equalizer coefficient conjugation in
  `benchmark_thermo5_interp.py`. The centered cubic result is 1.115% raw and
  0.970% corrected EVM, with 43.72 dB first-image rejection; its raw EVM and
  image/adjacent spectra were unchanged by the equalizer fix.
- Added three link-model tests. The 64-symbol link benchmark ranks centered
  cubic first in corrected EVM for the ideal, GT-only, DPA-only, and nominal
  combined scenarios. Under the arbitrary stress profile, cubic gives 8.75%
  corrected EVM and 28.7 dB image rejection versus forward-linear 9.94% and
  26.5 dB, although raw EVM is slightly worse (10.80% versus 10.57%). This
  promotes cubic as the leading research candidate, not as a frozen RTL change.
- Documented usage, assumptions, metric limits, results, and remaining work in
  `dv/uvm/refmodel/python/README.md`, `docs/ai-native/commands.md`, and the
  execution frontier. Reports are under ignored `runs/`.
- Checks: ten Python unit tests PASS; Python bytecode compilation PASS; 64-
  symbol interpolation and five-profile link benchmarks completed at seeds
  20261022/20261023; `git diff --check` PASS. No RTL, MATLAB fixed-point
  model, oracle vectors, or UVM contract changed, so no RTL/XSim/VCS regression
  was required for this behavior-only screening addition.
- Limitations: GT is Q15 I/Q payload error/jitter/skew, not the DUT's serialized
  four TID planes or electrical GT/CDR; the DPA parameters are not calibrated
  to ADS, transistor simulation, or measurements. The EVM and FFT-bin metrics
  use an oversampled waveform reference and scalar-per-symbol fit, without a
  receiver demodulator or subcarrier equalizer; they do not establish standard
  ACLR or physical RF performance. Cubic adds lookahead and estimated
  arithmetic cost, which have not been mapped or timed.

## 2026-10-22 00:54 SGT - align ASIC handoff, add Python thermo5 model and interpolation screen

- Rewrote the stale ASIC/PPA documentation to use the FPGA frozen thermo5
  settings as the primary configuration. Added a pre-run guard comparing the
  ASIC wrapper and FPGA OOC parameters plus the UVM identity-DPD tie-off. ASIC
  retains a generic async FIFO while FPGA uses XPM. The FPGA OOC still exposes
  runtime DPD pins, so its mapped PPA is not a controlled comparison with the
  constant-specialized ASIC map.
- Added the pure-standard-library Python model and generator for the frozen
  identity-DPD thermo5 chain. It writes the existing source, metadata, and four
  PA-plane `.mem` vectors. Fixed the Python package initializer so its absent
  legacy `bp_ef2.py` no longer blocks imports of available models.
- Added a deterministic 64-QAM OFDM interpolation benchmark comparing the RTL
  2/3/4-tap presets with forward-linear and centered-cubic candidates. Across
  64 symbols at seed 20261022, raw EVM was 72.01%, 86.25%, 97.02%, 6.23%,
  and 1.12%, respectively; after one common complex gain/phase fit per symbol,
  EVM was 70.29%, 79.75%, 84.47%, 4.96%, and 0.97%. The benchmark JSON is in
  the ignored `runs/` directory. Its adjacent-band value is a digital proxy,
  not standard ACLR.
- Corrected vector defaults to the 56-word UVM contract and aligned frame
  starts at words 1/15/36 after an initial 64-word attempt triggered the
  expected alignment assertion and UVM array truncation.
- Updated `syn/README.md`, `syn/asic/README.md`, `syn/asic/PPA_MATRIX.md`,
  `dv/uvm/README.md`, `dv/uvm/refmodel/python/README.md`, the thermo5 UVM architecture note,
  `docs/ai-native/commands.md`, and this frontier/log to match the current
  source of truth.
- Checks run: four Python unit tests PASS; Python bytecode compilation PASS;
  ASIC/FPGA parameter guard PASS; generic VCS thermo5 regression PASS using
  Python vectors (56-word bit-true, backpressure, FIFO boundary/empty, reset,
  reset sweep, expected illegal-frame assertion; zero UVM errors/fatals);
  `git diff --check` PASS.
- Not run: MATLAB comparison and required XSim smoke because MATLAB, Vivado/
  XSim, and PowerShell are unavailable. ASIC mapping was not run: no local
  standard-cell `.db` or Synopsys DC/Formality shell is visible. No RTL
  algorithm change was made. The interpolation screen suggests the current
  phase ordering should be reviewed before any candidate is promoted; the
  trial EVM excludes DPD/TID/PA/RF and does not establish system ACLR.
- The exact foundry/process flavor is not identified in this repository, and
  no AMS/RF model or IP views are visible. DAC/PLL/RF-front-end/PA support
  therefore remains unverified.

## 2026-10-21 - explicit AXI-Lite packet end and parent validation refresh

- Added `s_axis_tlast` to the optional AXI-Lite wrapper and ZU15EG four-GTH
  parent. The stop-safe packet contract is now explicit: packet lengths are
  positive multiples of 32 accepted 14-lane source beats; an early `TLAST`
  raises sticky protocol diagnostic without resetting gearbox alignment. The
  frozen parallel-config SKU is unchanged.
- Added a dedicated `thermo5-axil-long-frame-vcs-run` target and reproduction
  instructions. Generic VCS passed a 64-beat/two-quantum packet with 112
  four-plane output words; a real-XPM run of the same case passed. The parent
  reset-only XSim passed with the new signal connected; RX compare was skipped.
- Refreshed the parent XDC input group for `s_axis_tlast` and added synthesis
  timing, I/O, clock-interaction, exception and check-timing reports plus a
  routed WNS/WHS gate to the parent flow. AXIS/AXI-Lite/board min/max delays
  remain explicitly provisional because actual SoC and board timing contracts
  are not available.
- The current-source ZU15EG parent synthesis attempt under
  `runs/thermo5_parent_current_synth_20261021/` was interrupted when available
  system memory fell to about 0.7 GiB. Partial post-synth reports were written,
  but there is no checkpoint or clean exit, and the first report order placed
  clock-interaction analysis before asynchronous groups/RX output delay. The
  Tcl order was corrected; rerun before using timing reports. Route was not
  launched; the known requirement is 12-14 GiB free. No OOC timing PASS is
  claimed. CDC/RDC and physical GT/board signoff remain open.
- Checks already run: generic thermo5 and AXI-Lite regressions, generic and
  XPM 112-word graceful-stop tests, required frozen I2/D1 XSim, and parent
  reset-only XSim all PASS. `make -n` for the new long-frame target and
  `git diff --check` PASS.

## 2026-10-19 - AXI-Lite graceful RUN stop and drain

- Replaced the AXI-Lite wrapper's hardwired `core_drain=0` with a stop/drain
  controller. RUN low now closes AXI ingress at the configured 32-beat source
  frame boundary, keeps core and GT-user consumption active, and clears
  RUN_ACTIVE only after FIFO/gearbox/frontend/four-plane output drain. STATUS
  bits 3/4 expose RUN_ACTIVE and DRAINING. A true starvation while RUN remains
  asserted still sets the existing underflow diagnostic.
- Added a separate UVM scenario and ran generic and real-XPM AXI-Lite/URG
  regressions. Both pass the full 56-word four-plane MATLAB comparison with no
  underflow/protocol error and verify status clears after drain. The generic
  baseline and required directed I2/D1 XSim pass. Parent XSim passes graceful
  TX stop/drain, idle and common-reset recovery for 112 TX words; RX comparison
  was intentionally skipped.
- Updated the AXI-Lite architecture, GT-parent integration contract, test
  matrix, frozen-SKU STOP evidence, and execution frontier. The source AXI
  interface has no `TLAST`; the feature therefore assumes the documented fixed
  32-beat frame contract. Arbitrary-length frame stopping is not claimed.
- ZU15EG AXI-Lite OOC synthesis produced `synthesized.dcp`, clock and
  utilization reports (84,804 LUTs, 88,520 registers, 1,936 DSPs, 6 RAMB36,
  1 RAMB18). The repository checkpoint validator reopened the DCP and
  regenerated utilization successfully. The original PowerShell launcher
  returned nonzero with Vivado `[Common 17-217] Failed to load feature
  'vivado'`; report this as independently validated synthesis artifacts, not
  a clean launcher PASS. No routed timing run was performed. Parent routed
  CDC/RDC/STA, real I/O budgets, RX recovery and board output remain open. No
  commit or push made.

## 2026-10-19 - AXI-Lite in GT-parent global reset and regression repair

- Added the 100-MHz AXI-Lite bus/clock to the thermo5 four-GTH parent. Its
  reset is now released by the same qualified parent reset controller as the
  125-MHz AXI-Stream and GT-derived 218.75-MHz core resets, with an independent
  two-edge release synchronizer per domain. Preserved the frozen parent
  `DPD_MAX_TAPS=1` SKU and routed software RUN into the continuous GT-user
  boundary.
- Extended parent XSim for clock-stable qualification, reset defaults/ID,
  independent local release, AXIL RUN/COMMIT and frame-boundary application,
  GT-health commit cancellation, and multi-source reset/recovery. Reset-only
  XSim PASS with RX comparison skipped; full RX compare still fails because
  the behavioral RX user clock stays low and returns the known `0x55...`
  receive pattern. See `docs/verification/thermo5-reset-cdc-evidence.md`.
- `run_xsim_thermo5_i2_d1_axis.ps1` PASS. Generic VCS regression PASS across
  seven scenarios. Focused AXI-Lite VCS regression PASS, including register
  access/protocol, commit/mailbox integration, coefficients, negative/fault
  tests, parameter guard and URG merge. VCS compile found a missing UVM
  `(name,parent)` constructor in the extracted bit-true test class; added the
  forwarding constructor and reran successfully.
- ZU15EG parent synthesis generated a checkpoint, clock and utilization
  reports, but its launcher returned nonzero with `Failed to load feature
  'vivado'`; do not call this a clean synth PASS. No routed parent run was
  attempted because 8.9 GiB was free, below the known 12-14 GiB requirement.
  Parent routed CDC/RDC, actual SoC I/O budgets, RX recovery and board output
  remain open. No RTL arithmetic or fixed-point behavior changed.

## 2026-10-18 - separate frontend/backend flow-control subsystem tests

- Kept the existing MATLAB bit-true subsystem benches as simple always-ready
  baselines and added dedicated frontend bubble/PA-backpressure and backend
  four-plane common-backpressure tests. The new tests reuse the existing MATLAB
  vectors and compare every accepted output word against the same oracle.
- Frontend flow-control XSim PASS: frozen INTERP_TAPS=2 / DPD_MAX_TAPS=1,
  64 output words, 16 inserted source-bubble cycles and 28 observed PA stall
  cycles. Backend XSim PASS: 128 vectors, 32 inserted source-bubble cycles and
  86 observed partial-ready stall cycles; all four output words remained
  aligned/stable and matched the oracle.
- Existing baseline XSim reruns also PASSed: frontend parameterized runner
  (the inherited environment selected 4-tap interpolation / DPD_MAX_TAPS=4)
  and backend 128-vector oracle test. Baseline logs are under
  `runs/thermo5_frontend_tx_xsim/` and
  `runs/thermo5_fs4_multipa_tx_xsim/`.
- Updated subsystem READMEs, regression commands and test-level matrix. No RTL
  or UVM behavior changed; reset/replay and CDC remain covered at IP/system
  level rather than duplicated in these subsystem cases.

## 2026-10-16 - colocate directed verification runners

- Moved 11 focused XSim runners from the shared scripts directory into the
  corresponding AXIS/FIFO, interpolation, TID32, GT-user block, TX frontend,
  TX backend, or serializer-loopback integration directory.
- Retained the former dv/verif/scripts command paths as thin forwarding
  shims, preserving existing local workflows. Updated the regression guide,
  block/subsystem READMEs, migration map, and test-level explanations.
- Clarified that the raw64 GT-user test is a single-module block test, not a
  subsystem tier; the four-branch TID/Fs4 backend test and serializer
  behavioral loopback are separate scopes.
- Checks: PowerShell parser and root/source-path audit passed for 12 canonical
  runners and 11 compatibility shims. Isolated XSim passed for raw64 boundary,
  the 64-vector frontend subsystem at INTERP_TAPS=2/DPD_MAX_TAPS=1, and the
  128-vector four-plane backend. Evidence is in
  runs/dv_layout_verify_20261016/.
- Limitation: the full AXI-ingress IP test was not rerun because its default
  output directory already contains prior artifacts. Its canonical runner,
  testbench, and source paths resolved; no RTL or test behavior was changed.

## 2026-10-16 - classify AXI-Lite as a thermo5 block and document ingress sizing

- Added `dv/verif/block/axil/` as the control-block home for the standalone
  reset-overlap and illegal-parameter harnesses. Kept reusable UVM agents and
  AXI-Lite scenario classes under `dv/uvm/`; updated Makefile and documentation
  consumers to the new harness paths.
- Made the two signal-processing subsystem contracts explicit: frontend is
  AXIS/AFIFO/14:8 gearbox plus gain/interpolation/DPD; backend is four-plane
  TID/Fs4 plus the digital GT-user handoff. Test sources are indexed without
  duplicating the block-level raw-GT test or behavioral loopback.
- Added architecture notes documenting the current depth-16/465-bit FIFO,
  equal-rate throughput, optional low-power 4-beat prefill, finite stall capacity and the case
  where a whole-frame buffering requirement would need a deeper FIFO.
- Checks: relocated `thermo5-axil-cfg-unit-vcs` harness PASS (both reset-window
  tuples hit without active-payload change); `thermo5-axil-vcs-parameter-guard`
  PASS (expected MAX_TAPS=0/5 diagnostics); Makefile/source path audit, JSON
  validation, and `git diff --check` PASS. Logs are under
  `runs/thermo5_axil_block_reorg_20261016/`.
- Limits: the standalone harnesses are not the full generic/XPM AXI-Lite UVM
  regression, whole-design code-coverage closure, CDC/RDC signoff, or physical
  GT/board signoff.

## 2026-10-16 - clarify thermo5 block/subsystem/integration boundaries

- Kept the 14-lane AXI ingress, asynchronous FIFO implementation, and 14:8
  repacker documented as one public-interface block (`dsm_axis14_to_core8_cdc`);
  the internal FIFO choice is generic or AMD XPM, not a separate DUT interface.
- Reshaped the subsystem taxonomy to exactly two signal-processing groups:
  thermo5 frontend and four-plane TID/Fs4 backend. Moved the backend-focused
  four-plane bench to `subsystem/tx_backend/`; moved serializer behavioral
  loopback and GT-parent tests to `integration/`.
- Clarified that the DPD arithmetic datapath and its AXI-Lite config/mailbox are
  distinct blocks, while UVM wrapper tests verify their control-to-datapath
  integration. Updated runners and path records; ignored local XSim/VC Formal
  generated databases.
- Checks: source-path/reference audit, JSON validation and `git diff --check`
  PASS; moved four-plane backend XSim PASS (128 MATLAB vectors); moved
  behavioral serializer loopback XSim PASS (64 words / 4,096 bits per path).
  The generic AXI-Lite VCS regression was run earlier in this session before
  this path/documentation-only reorganization; XPM was not rerun after
  AXI-Lite test extraction.
- Limits: serializer loopback remains behavioral only; GT serial RX, deskew,
  parent I/O timing and board output remain open.

## 2026-10-16 - split thermo5 AXI-Lite scenarios into named UVM tests

- Separated AXI-Lite positive configurations (default, coefficient transport,
  nonlinear image transport, tap-4 identity) and boundary/fault/illegal-frame
  scenarios into dedicated test source files. Shared AXI access helpers and
  common commit/stream/reset checks remain in the default config base test.
- Removed mode-selection plusargs from the common config test; XSim and VCS now
  select the scenario with `UVM_TESTNAME`. Added focused Make targets and
  updated URG database naming for coefficient-transport runs.
- A first nonlinear-image run exposed that the identity MATLAB oracle cannot
  validate a non-identity DPD image. The test is now explicitly control-plane
  only for that image: it checks mailbox/pending/active payloads, all 56 output
  handshakes, source completion, and protocol health; it does not claim
  nonlinear arithmetic bit-true validation.
- Checks: AXI-Lite VCS compile PASS; generic AXI-Lite VCS regression PASS with
  URG merge; additional VCS runs PASS for nonlinear-image configuration,
  tap-4 identity (56-word oracle), and commit-boundary phase (56-word replay).
  The full regression and separate runs are under
  `runs/thermo5_axil_split_final_20261016/`.

## 2026-10-16 - isolate thermo5 AXI-Lite UVM tests

- Moved the optional thermo5 AXI-Lite test classes into
  `dv/uvm/tests/thermo5/axil/`; added the directory to the thermo5 UVM filelist
  include path and documented that the tests reuse the shared thermo5 env and
  bit-true scoreboard.
- No RTL, test behavior, or coverage criteria changed. Source closure and VCS
  compile passed with `THERMO5_USE_AXIL=1` in
  `runs/axil_test_move_compile_20261016/`. Existing VCS coverage reports are
  unchanged and were not regenerated by this source-only organization change.

## 2026-10-15 17:29 SGT - frozen thermo5 full AXI-Stream routed OOC PASS

- Ran the current no-AXI-Lite `tid32_thermo5_axis_frontend_tx` on
  `xczu15eg-ffvb1156-2-i` with XPM FIFO, 125 MHz AXIS, 218.75 MHz core,
  `INTERP_TAPS=2`, `DPD_MAX_TAPS=1`, and low-power control disabled. The run
  covers the ingress FIFO/14:8 gearbox through interpolation, identity DPD,
  thermo5 output logic, and all four PA-code planes.
- Routed all 98,546 routable nets with zero routing errors. Separately reopened
  `routed.dcp` and generated timing/check/utilization reports; Vivado exited 0.
  WNS/TNS/WHS/THS = +0.504/0.000/+0.027/0.000 ns, with zero failing endpoints
  among 149,172 modeled endpoints. Worst setup path is the memory-DPD DSP
  pipeline (3.765 ns data delay: 2.686 ns logic + 1.079 ns route). Resources:
  43,837 LUTs, 53,375 registers, 496 DSP48E2, 6.5 BRAM tiles. Vivado reported
  108 ordinary warnings, 0 critical warnings, and 0 errors.
- Evidence: `runs/thermo5_full_axis_ooc_20261015_retry2/`. No RTL changed.
  `check_timing.rpt` still reports 570 top-level inputs with no input delays
  and 264 outputs with no output delays. Therefore this is a routed internal
  OOC PASS only; parent I/O budgets, system CDC/RDC/reset, GT, and board output
  remain OPEN. Initial report generation was stopped for workstation memory
  headroom after the route; retry2 saved the routed checkpoint first and
  completed reports in a separate Vivado invocation.

## 2026-10-15 14:11 SGT - thermo5 focused branch source closure

- Scope: created `thermo5` from the pushed full-project `main`; removed 666
  tracked non-thermo5 source/build/verification files from this branch only.
  `main` remains the full-project source. Preserved shared CDC/FIFO, DPD,
  interpolation and TID dependencies required by the thermo5 tops, plus its
  XSim/VCS-UVM/formal, MATLAB reference, ZU15EG and OOC flows.
- Updated branch README, AGENTS navigation/check commands, execution frontier,
  repo-hygiene required file, and thermo5 CI branch trigger. No RTL behavior
  changed. The remaining `thermo5` source closure was checked against the UVM
  filelist and package includes.
- Verification: VCS/UVM frozen-SKU generic and real-XPM regressions PASSed;
  each includes six positive directed cases, an expected illegal-frame control,
  and three extra MATLAB payload seeds. Both URG merges exited 0; raw hierarchy
  code scores were 87.79% generic and 80.66% XPM (not a 100% coverage claim).
  Direct 56-word XSim full-chain bit-true test PASSed at seed 861015. Both staged
  and unstaged `git diff --check` returned 0.
- Reproducibility: local logs/VDBs are retained only under the ignored
  `runs/thermo5_branch_verify_20261015_e/`; no generated artifacts were added.
  Existing ZU15EG routed evidence remains applicable because RTL is unchanged;
  parent I/O, system CDC/RDC, and physical board output remain OPEN.

## 2026-10-15 12:04 SGT - Thermo5 AXI-Lite ZU15EG routed OOC PASS

- Scope: only the AXI-Lite thermo5 frontend SKU (`INTERP_TAPS=2`,
  `DPD_MAX_TAPS=4`, XPM FIFO) on `xczu15eg-ffvb1156-2-i`; resumed the current
  synthesis candidate through `opt_design`, placement, physical optimization,
  and default timing-driven `route_design`.
- Result: Vivado exited successfully. All 218,958 routable nets are fully
  routed and route verification passed with zero route errors. Final
  WNS/TNS/WHS/THS = +0.198/0.000/+0.018/0.000 ns; no setup or hold endpoints
  fail under the modeled constraints. AXI-Lite and AXIS clocks also have
  positive setup/hold slack. Vivado reported 103 ordinary warnings,
  0 critical warnings, and 0 errors; warnings concern OOC clock-source and
  part-pin metadata. Routed resources: 81,576 LUTs (71,041 LUT logic,
  10,535 LUTRAM), 88,407 CLB registers, 1,936 DSP48E2s, and 6.5 BRAM tiles.
- Worst path is now a memory-DPD DSP pipeline path from lane 8 `r4_full_s2`
  DSP register to a DSP A/B input register (4.067 ns data delay, including
  1.424 ns routed net delay); the former ready/CE fanout path is no longer the
  critical path.
- Evidence: `runs/thermo5_axil_readytree_route_20261015_20261015_114457/`;
  resumable implementation checkpoint: `runs/thermo5_axil_readytree_place_physopt_20261015_20261015_110018/`.
  The final timing summary reports zero unconstrained internal endpoints, but
  `check_timing.rpt` still lists 527 inputs without input delays and 308
  outputs without output delays, and OOC ports lack parent `HD.PARTPIN_LOCS`.
  This is an internal OOC timing PASS, not parent/board I/O signoff. Parent
  timing budgets and system-level CDC/RDC/reset review remain open.
- Functional regression evidence for this RTL iteration remains: generic and
  real-XPM 56-word four-plane bit-true PA-ready-stress tests pass (seeds
  420204/420205), P0 XSim 7/7, and IP smoke PASS. This entry changes status
  documentation only; no RTL changed in this route run.

## 2026-10-15 10:48 SGT - Thermo5 AXI-Lite ready-tree timing iteration

- Replaced the single-point ready cut with four two-entry word-atomic
  registered-ready queues at CDC/frame-gain, interp1/DPD, DPD/interp2, and
  interp2/TID boundaries. Frame-start and frame-gain metadata stay attached
  to their samples; the active AXI-Lite SKU configuration and arithmetic are
  unchanged. The extra ingress and final queues add two fixed core cycles.
- Current-source checks: generic and XPM thermo5 AXI-Lite 56-word bit-true
  regressions with PA-ready stress pass; required P0 XSim passes 7/7; IP smoke
  passes; `git diff --check` passes.
- Fresh ZU15EG synth checkpoint was separately reopened and report generation
  exited 0. Mapped resources are 84,771 LUT, 88,497 FF, 1,936 DSP48E2, and 6.5
  BRAM tiles. Unplaced diagnostic WNS/WHS are +1.143/+0.078 ns; the top path
  is now inside the memory-DPD DSP/ALU lane. This is not routed timing closure.
- The synth launcher returned nonzero after writing the DCP with
  `Failed to load feature 'vivado'`, matching the earlier launcher-exit issue.
  The separate checkpoint validation completed successfully. Timing-driven
  route remains pending: free physical memory was 11.68 GiB versus a prior
  10.7 GiB placement peak; waiting for safe workstation headroom. OOC ports
  still lack real parent I/O delay budgets.
- Evidence: `runs/thermo5_axil_readytree_synth_20261015/`; an earlier single
  ready-cut iteration with WNS=-0.339 ns is preserved in
  `runs/thermo5_axil_readycut_synth_20261015/` and is superseded.

## 2026-10-14 04:04 SGT - OOC route paused at workstation memory limit

- Relaunched Vivado with the required elevated Windows environment from the
  saved 55.0 MB `optimized.dcp`. It reopened the checkpoint, validated all
  three expected clocks, and progressed through placer initialization into
  `Phase 2 Global Placement` (`runs/thermo5_axil_route_resume_20261014_0405/`).
- At the Phase 2 boundary Vivado had peaked at 8.73 GB and Windows reported
  about 591 MB available physical memory. I interrupted the run before the
  workstation became unstable. It did not save `placed.dcp`; the original
  `optimized.dcp` remains intact. System memory recovered to about 8.8 GB.
- The prior unexplained placement exit still has no correlated Windows crash
  or resource-exhaustion event. The new run's stop was deliberate due to low
  available memory. PowerShell parsing and `git diff --check` pass; no routed
  STA result is available and no timing PASS is claimed.
- GitHub `main` contains commit `93faef8`. Route helper and current status
  updates are subsequent local changes and have not been pushed.

## 2026-10-14 03:49 SGT - Resume OOC placement from optimized checkpoint

- The first default-directive continuation successfully reopened the current
  synthesis DCP, completed `opt_design`, and saved
  `runs/thermo5_axil_route_resume_20261014_0110/optimized.dcp` (55.0 MB).
  Vivado exited during global placement/PBP before producing `placed.dcp`; the
  log contains no Tcl/Vivado error summary, and no correlated Windows
  Application Error or resource-exhaustion event was found. The exit cause is
  therefore unknown, not attributed to OOM.
- Extended the checkpoint-resume Tcl/PowerShell flow to accept
  `ResumeFrom=optimized`, so placement can restart directly from the saved
  optimized checkpoint. PowerShell parser validation and `git diff --check`
  pass. A placement retry from the saved checkpoint was attempted and stopped
  at low available workstation memory; see the 04:04 update above.
- The measured baseline remains FAIL_SETUP (WNS=-0.630 ns, TNS=-23.465 ns,
  WHS=+0.028 ns). No new routed result is claimed. Parent I/O constraints,
  CDC/RDC and bundled-data timing review remain open.
- GitHub `main` contains commit `93faef8`; the current route helper and status
  updates are subsequent local changes and have not been pushed.

## 2026-10-14 01:10 SGT - Resource-bounded OOC route continuation

- Timing-driven candidate3 was interrupted after extended placement/clock-region
  work when system commit headroom fell below 400 MB. It had no routed
  checkpoint, timing summary, or route status. Its current-source 56.9 MB
  `synthesized.dcp`, clocks, and synthesis utilization report remain intact in
  `runs/thermo5_axil_timing_candidate3_20261013/`.
- Added checkpoint-resumable OOC scripts under `syn/`. They save optimized,
  placed, and post-phys-opt checkpoints; use default implementation directives
  rather than the memory-intensive Explore/AggressiveExplore sequence; and save
  timing evidence before CDC. Scripts are added but the resume route has not yet
  been run.
- Baseline remains FAIL_SETUP (WNS=-0.630 ns, TNS=-23.465 ns, WHS=+0.028 ns).
  No new timing PASS is claimed; parent I/O budgets, CDC/RDC, and the detailed
  CDC report remain OPEN.
- GitHub `main` contains confirmed commit `93faef8`. The checkpoint-resume flow
  and this status update are later local changes and have not been pushed.

## 2026-10-13 22:15 SGT - AXI-Lite routed OOC timing diagnosis and rerun

- The full OOC implementation for `tid32_thermo5_axi_lite_axis_frontend_tx`
  reached routed timing analysis at 218.75-MHz core, 100-MHz AXI-Lite and
  125-MHz AXI-Stream. The result is FAIL_SETUP: WNS=-0.630 ns, TNS=-23.465 ns
  across116 endpoints; WHS=+0.028 ns with no failing hold endpoints. AXI-Lite
  and AXI-Stream intra-clock slack is positive.
- The worst path is a memory-DPD lane3 DSP cascade to a RAMB18 input, with
  4.888 ns data delay (2.634 ns logic, 2.254 ns routing). Other top failures
  include route-dominated TID recursive-state carry paths. This is not a
  CDC-path failure. Timing analysis also flags 527 inputs and308 outputs with
  no I/O-delay budget; no parent/board I/O signoff is implied.
- Vivado PID18420 was stopped after the routed FAIL_SETUP result was captured;
  it remained blocked in `report_cdc -details` and had not produced `routed.dcp`,
  `summary.csv`, or a completed CDC report. This is an incomplete OOC flow, not
  a timing PASS. The OOC Tcl saves timing/checkpoint artifacts before CDC.
- The first timing-driven candidate launch failed before Vivado emitted any
  log content (Windows process status `0xC0000022`, access denied); this is a
  tool-launch failure, not a DUT result. A fresh timing-driven OOC is now
  running in `runs/thermo5_axil_timing_candidate3_20261013/` after launching
  Vivado with the required Windows process environment. The previous synth
  checkpoint is not reused because `rtl/axis/dsm_reset_sync.sv` changed after
  it was generated.
- Checks: `git diff --check` PASS. Baseline remains FAIL_SETUP; candidate3 has
  no result yet. The 10-ns bundled-data max-delay is provisional and 527 input/
  308 output delays are absent, so no parent/board I/O signoff is implied.

## 2026-10-13 16:10 SGT - AXI-Lite generic/XPM VCS and URG closure update

- Reran the current AXI-Lite UVM/URG target in licensed Rocky for generic and
  real Vivado XPM FIFO builds. Both completed with
  `THERMO5_AXIL_COVERAGE_MERGE_PASS`; each covered positive configuration and
  coefficient-mailbox transfer with 56-word four-plane bit-true comparison,
  illegal-frame assertion/reset recovery, mailbox-corruption assertion/reset
  recovery, and `MAX_TAPS=0/5` guards. UVM reports had zero warnings/errors/
  fatals; negative tests checked their expected RTL assertion/`$error`.
- Added AXI-Lite monitor functional coverage for address/response/strobe,
  AW/W ordering, response backpressure, and reset assertion/release; added a
  read-only IP-ID write DECERR/readback-preservation check. Merged URG reports
  show 100% for `write_cg`, `read_cg`, and `reset_cg` in both FIFO builds.
- The RTL was not changed. The AXI-Lite RTL module's merged raw code score is
  93.74% (line99.38%, condition95.95%, toggle82.13%, branch97.50%). The line315
  `(0,1,1)` condition tuple, write-case default, and low16-bit coefficient
  slices in bundled-data images remain OPEN; only the reviewed line88 tuple is
  waived. No 100% raw code-coverage claim is made.
- Evidence: `runs/thermo5_axil_signoff2_generic_20261013/` and
  `runs/thermo5_axil_signoff2_xpm_20261013/`. Fresh Windows XSim still stopped
  before elaboration; no new synthesis/CDC/RDC/routed-STA result is claimed.

## 2026-10-13 15:43 SGT - AXI-Lite regression scope and status refreshed

- Extended `thermo5-axil-vcs-regression` to run the legal coefficient-payload
  mailbox test as a separate seed420104 VDB and include it in the URG merge.
  This reuses the already existing test; it does not alter RTL behavior.
- Corrected the AXI-Lite architecture/coverage records: functional covergroups
  are 100% in the saved four-scenario merge, while raw module code coverage is
  partial. The coefficient transport report is line98.12%, condition95.95%,
  branch95.00%, toggle78.49%; exact remaining AXIL items are still OPEN.
- Fresh Windows XSim seed610130 did not reach elaboration (`xvlog` exited
  nonzero; empty compile log). WSL launch returned `E_ACCESSDENIED`, so no fresh
  licensed VCS/URG run was possible. Prior 2026-10-12 generic/XPM evidence is
  preserved; this update does not claim a new PASS or synthesis/timing signoff.

## 2026-10-13 10:12 SGT - Bit24 URG blocked by missing coverage license

- Generic bit24 URG attempt exited1 with `URG-NLC No license key` and no report;
  its simulation VDB remains preserved for a later merge. XPM VCS retry seed610707
  exited255 before test start because the VCS license server could not be
  reached. Neither is a DUT failure or a coverage hit.
- Bit24 functionally PASSes generic only; its per-binary URG/lane audit is OPEN.
  XPM bit24 simulation is OPEN. Previously completed bit23 audits remain PASS.
- No raw 100% coverage claim or new waiver. Resume only after both VCS and URG
  license checks succeed in the execution shell.

## 2026-10-13 10:08 SGT - Generic bit24 URG active; XPM blocked by license connection

- Detached XPM seed610707 exited255 with `Cannot connect to the license
  server` before UVM test start. Its VDB is excluded; this is an EDA
  environment failure, not an RTL/UVM result. Earlier SIGHUP seed610706 and
  memory-terminated seed610705 partial VDBs also remain excluded.
- Started the generic-only same-binary URG merge for seed610704 and the exact
  bit24/16-lane toggle audit. XPM bit24 remains pending until licensed checkout
  works from the execution shell. No new bins are waived and code coverage is
  not100%.

## 2026-10-13 10:04 SGT - XPM bit24 foreground run interrupted; detached retry

- Serial XPM seed610706 received SIGHUP before any UVM completion marker. Its
  partial VDB is invalid for coverage and remains excluded. Generic seed610704
  PASS is unaffected.
- Confirmed an interactive Rocky login shell has VCS license environment
  available without exposing license values. Added ignored run helpers for a
  detached `nohup/setsid` seed610707 retry and an exit-status-gated URG
  finalizer. A fresh VDB avoids mixing with the interrupted attempt.
- XPM seed610707 and both matching URG audits are pending; raw code coverage
  remains OPEN and no bins were waived. See
  `docs/verification/thermo5-bit24-counter-closure-20261012.md`.

## 2026-10-12 22:55 SGT - Generic bit24 long-stream PASS; XPM retry active

- Generic seed610704 completed the16,777,222-word four-plane bit-true stream,
  checked signed endpoints, and verified all16 DPD lane counters clear after
  public reset. UVM_ERROR/FATAL=0; source coverage100%, core coverage87.5%; CPU
  time11512.180s. Generic URG and exact bit24 toggle audit are queued until the
  matching XPM run completes.
- Serial real-XPM seed610706 is active using the same oracle and an independent
  VDB. It must pass the same full-stream and reset checks before its separate
  URG. The incomplete concurrent seed610705 database remains excluded.
- Added `docs/verification/thermo5-bit24-counter-closure-20261012.md` and
  updated the execution frontier. Raw code coverage remains OPEN; bits25-31
  are reachable and no bins were waived.

## 2026-10-12 19:38 SGT - Bit24 oracle complete; generic/XPM long runs active

- Generated the 16,777,222-word independent integer oracle using the
  chunked writer. MATLAB fixture comparison, exact record-count checks, and
  re-computed SHA-256 checks for all eight vector files PASS; manifest is
  `runs/thermo5_bit24_oracle_20261012/oracle_manifest.json`.
- Started separate generic seed610704 and real-XPM seed610705
  `thermo5_sku_long_counter_test` runs using their existing same-binary builds.
  Each checks all four output planes, signed endpoints and post-stream reset.
  The two VCS simulations are still active; no bit24 functional or URG PASS is
  claimed yet. Their VDBs will be merged only with the matching FIFO build.
- Bit23 remains closed in 16/16 lanes for both directions on both binaries.
  Bits24-31 and the XPM `stage1_valid->invalid` FWFT transition remain OPEN;
  no waiver was added. Raw generic/XPM score is still 87.00%/80.17% until a
  completed, same-binary URG merge produces updated numbers.
- No RTL behavior changed. Checks completed: MATLAB fixture compare, eight-file
  length/hash validation, interactive licensed Rocky VCS launch.

## 2026-10-12 19:42 SGT - Serialize bit24 VCS runs after memory pressure

- Observed the concurrent generic/XPM VCS processes each grow to about5.0 GB
  RSS, leaving only about50 MB WSL MemAvailable and consuming about1.4 GB swap.
  Sent SIGTERM only to the verified XPM seed610705 process before any PASS
  marker; its partial log/VDB is not a valid test result and is excluded.
- Generic seed610704 remains active alone (about5.7 GB RSS); available WSL
  memory recovered to about5.7 GB. The XPM bit24 run will be retried after the
  generic run completes. This is resource scheduling only; no source/RTL change.

## 2026-10-12 19:11 SGT - Memory-bounded bit24 oracle generation

- The first 16,777,222-word whole-array oracle attempt was interrupted before
  creating an output directory when its working set reached8.99 GB. No partial
  vectors were used by simulation.
- Updated `tools/hw/thermo5_range_oracle.py` to preserve interpolation history
  and DSM recursive state across bounded 65,536-word chunks and stream each
  completed chunk to the ignored `runs/` vector files. The chunk implementation
  exactly matches the prior oracle for all eight files at 56 and 2,072 words
  across five chunk-size cases; Python compile and diff checks pass.
- The bit24 fixture was revalidated (`MATLAB_ALL_EIGHT_FILES_MATCH words=36`)
  and generation of 16,777,222 words is in progress under
  `runs/thermo5_bit24_oracle_20261012/`. Generic/XPM VCS has not started; only
  a completed manifest and output hashes will authorize the long runs.

## 2026-10-12 18:46 SGT - Reset-phase sweep audit

- Checks: same-binary generic seeds610501-610508 and XPM seeds610601-610608
  passed the full 56-word/four-plane reset-and-replay test for delays1-8;
  zero UVM errors/fatals. Their VDBs were explicitly merged with the accepted
  baseline/gain VDBs in `coverage_current_gain_reset_safe/` for each FIFO.
- Coverage result: no newly closed condition, branch, or toggle rows; raw DUT
  scores are unchanged at generic87.00% and XPM80.17%. Generic delay9 seed610509
  hit the early-FIFO-starvation guard and was excluded from the formal merge.
  The test currently accepts a requested delay up to11, although delay9 is not
  safe for the four-beat prefix; fix/clarify this test bound before a wider
  reset-phase sweep.
- Remaining code-coverage gaps stay open; no waiver was added and no RTL
  behavior changed. Evidence is under the two bit23 VCS run directories and
  `docs/verification/thermo5-bit23-counter-closure-20261012.md`.

## 2026-10-12 18:38 SGT - Gain-vector coverage follow-up

- Checks: replayed the existing 56-word `gain_saturation` and
  `gain_toggle_delivery` MATLAB vector sets on the already-built generic and
  real-XPM VCS/UVM binaries (seeds610300-610303). All four tests passed the
  four-plane bit-true oracle with signed-extreme and PA-ready stress enabled;
  UVM_ERROR/UVM_FATAL were zero.
- URG: rebuilt the same-binary merges from the explicit approved VDB list plus
  those four new runs, excluding exploratory XPM seed610192. Latest raw DUT
  scores are generic87.00% (line87.09, condition76.46, toggle85.46, FSM100,
  branch73.00, assertion100) and XPM80.17% (line76.99, condition67.89,
  toggle82.88, FSM90.91, branch62.37, assertion100). This does not close raw
  code coverage; denominator includes vendor XPM cells only in the XPM result.
- Remaining: bits24-31 are reachable/open (256 directions per FIFO); exact
  DPD saturation, parameter-inactive, interpolation/frame-marker, vendor and
  FWFT gaps need directed hits or item-specific proof/review. No waivers or RTL
  behavior changes were made.
- Evidence: `runs/thermo5_bit23_vcs_{generic,xpm}_20261012/` and
  `docs/verification/thermo5-bit23-counter-closure-20261012.md`.

## 2026-10-12 18:30 SGT - Bit23 closure and edge-observed XPM FWFT search

- Checks: generic seed610080 and real-XPM seed610081 each PASSed 8,388,611
  four-plane bit-true output words, signed endpoints, public reset of all16
  DPD counters, and zero UVM errors/fatals. Separate same-binary URG deltas
  confirm `sample_count[23]` both-direction toggle in all16 lanes for each
  FIFO. Current full test-set raw DUT scores: generic86.78%, XPM79.98%.
- Remaining: bits24-31 are 256 reachable toggle directions per FIFO. The
  current test-set URG is not 100%; no reachable counter bins were waived.
  Generic interpolation and XPM vendor code bins remain open.
- FWFT: added optional pre/post-edge observation to the reset-phase UVM test
  and a reusable 400-point phase/delay search runner. All400 tests passed,
  sampling5,464 `stage1_valid` edges but zero edges with `rd_rst_i=1` and zero
  `stage1_valid->invalid` transitions. This is not an unreachability proof;
  the exact vendor transition remains OPEN with no waiver.
- Evidence: `runs/thermo5_bit23_vcs_{generic,xpm}_20261012/`,
  `runs/thermo5_xpm_fwft_edge_observe_20261012/`, and the two verification
  records/frontier. No RTL or MATLAB behavior changed.

## 2026-10-12 16:49 SGT - Expanded XPM FWFT public-reset phase search

- Extended the same current-source XPM UVM binary's prefetch-only public-reset
  request grid from four phases to all 16 source phases and all 25 core-delay
  points (400 trials). Together with 16 post-stage1 trials and 48 full-prefix
  trials, all 464 reset trials plus the baseline completed their 56-word,
  four-plane oracle checks with zero UVM errors/fatals.
- Same-binary URG completed at
  `runs/thermo5_xpm_fwft_phase_sweep_20261012/coverage_all_16phase_reset_sweeps/`.
  `curr_fwft_state` remains 8/9 transitions: `both_stages_valid->invalid` is
  covered, while `stage1_valid->invalid` remains Not Covered and OPEN. No
  internal force/deposit or waiver was used.
- Generic bit23 seed610080 and real-XPM bit23 seed610081 remain active in
  separate VCS processes; neither has reached its PASS/URG closure gate yet.
- Checks: 464 public-reset phase trials and baseline PASS; expanded same-binary
  URG completed; no RTL or algorithm changes.

## 2026-10-12 16:40 SGT - Parallel generic/XPM bit23 long-stream launch

- Started the current-source generic long-counter UVM run with seed610080 and
  the XPM counterpart with seed610081 against the same MATLAB-fixture-validated
  8,388,611-word oracle set. Each FIFO implementation has a separate compiled
  VCS binary, output directory and coverage database. Both simulations are
  still running; no PASS, URG bit23 closure, or cross-binary merge is claimed.
- Current run outputs: `runs/thermo5_bit23_vcs_generic_20261012/` and
  `runs/thermo5_bit23_vcs_xpm_20261012/`. Expected wall time is about 100
  minutes per FIFO based on the prior measured 4.19M-word throughput.
- Generic source compiled and entered simulation; XPM source compiled and
  entered simulation. Current VCS process memory remains below the available
  Rocky WSL memory budget.

## 2026-10-12 16:30 SGT - Coefficient VCS/URG and XPM FWFT reset-phase follow-up

- Re-ran the AXI-Lite coefficient-transport UVM test in the interactive Rocky
  shell (the VCS license setup is sourced there; a non-interactive launch does
  not inherit it). Generic seed435509 and Vivado XPM seed435510 both PASS with
  zero UVM warnings/errors/fatals, exact mailbox/pending/active images, reset
  defaults, and 56 four-plane bit-true output words. Targeted module URG is
  line98.12%, condition95.95%, toggle78.49%, branch95.00% for both.
- Reviewed native coefficient toggle bins: the upper48-bit coefficient slices
  toggle in both directions, while the low16-bit tap0 slice is Not Covered in
  `cfg_mailbox_q`, `cfg_pending_core`, `cfg_active_core`, and `cfg_for_dpd`.
  Legal payload transfer is functionally verified, but full coefficient-toggle
  coverage stays OPEN; no waiver was added.
- Recompiled one current-source XPM VCS binary and ran 164 public-reset phase
  tests plus one bit-true baseline. All complete 56-word four-plane replay with
  zero UVM errors/fatals. Same-binary URG improved `curr_fwft_state` to8/9:
  `both_stages_valid->invalid` is Covered; `stage1_valid->invalid` remains
  Not Covered and OPEN. No internal force/deposit or waiver was used.
- Generated 8,388,611 bit23 oracle words from a 36-word MATLAB-validated
  fixture. The generator confirmed all eight fixture files match and wrote a
  source/output hash manifest. Current-source generic VCS long-counter UVM
  seed610080 is now running in
  `runs/thermo5_bit23_vcs_generic_20261012/`; no bit23 PASS or URG closure is
  claimed yet. The XPM long-stream run is pending the generic run.
- Documentation updated: execution frontier, AXI-Lite code-coverage record,
  XPM exact-followup record, and new bit23 closure status.
- Checks: generic/XPM coefficient VCS-UVM and URG completed PASS as above;
  164 XPM reset-phase tests and same-binary URG completed; oracle generation
  fixture validation PASS; generic bit23 compile PASS and simulation is still
  running. No synthesizable RTL changed.

## 2026-10-12 15:40 SGT - Legal AXI-Lite coverage closure and coefficient CDC exercise

- Closed the reachable AXI-Lite line315 tuple `(cfg_req_sync2,pending,boundary)=(1,0,1)` with legal public RUN/COMMIT stimulus: early BREADY, AW/W gap=1, and 20 AXI clock phases. The tuple was observed in 15/20 runs and the merged URG row is Covered. This brings the passing legal phase/bus matrix to 461 trials; all have zero UVM errors/fatals and 56 bit-true four-plane words. No DUT state was forced.
- Reviewed the matching-source VC Formal report: line88 tuple `(bvalid,aw_pending||aw_take,w_pending||w_take)=(0,1,1)` is proven unreachable and has one exact reviewed disposition in `docs/evidence/THERMO5_AXIL_COVERAGE_WAIVERS.csv`; raw URG remains unchanged. The distinct line315 `(0,1,1)` proof is inconclusive at depth10 and remains OPEN, with no waiver.
- Added `AXIL_COEFF_TRANSPORT` UVM mode. Legal AXI writes program nonzero coefficient values in inactive taps 1..3 while preserving the active one-tap identity transfer; the test checks exact mailbox, core-pending, core-active payloads, reset-default restoration, and the 56-word bit-true stream. Generic and XPM Vivado XSim runs passed (seeds 435505/435506), as did the normal AXI-Lite configuration runs (seeds 435507/435508). XSim functional PASS is not a VCS toggle-coverage result.
- Added the XSim-specific no-DPI `uvm_hdl_release` signature guard and `-CoefficientTransport` replay option. No synthesizable RTL changed.
- Coefficient transport VCS/URG toggle closure remains OPEN. The current Rocky WSL process has the VCS executable but no `LM_LICENSE_FILE` or `SNPSLMD_LICENSE_FILE`; a compile/run attempt stops at license discovery. Frozen-SKU `sample_count[31:23]` (288 reachable toggle directions/FIFO) and XPM FWFT `stage1_valid->invalid` (last report8/9) remain separate OPEN items, not waived.
- Evidence: AXI-Lite coverage record, waiver ledger, legal boundary sweep report, and four XSim run directories are listed in `docs/verification/thermo5-axil-code-coverage-closure-20261012.md`.
- Checks: generic/XPM AXI-Lite UVM in XSim PASS for normal and coefficient-transport modes; matching-source formal report rechecked; VCS run blocked by missing current-shell license environment; PowerShell and Bash script syntax checks PASS; `git diff --check` PASS (Git reports only existing line-ending normalization warnings).

## 2026-10-12 15:05 SGT - AXI-Lite boundary-bin external phase search

- Added a legal public-interface UVM test that phase-sweeps AXI-Lite RUN+COMMIT
  against accepted DPD frame boundaries. Extended the UVM testbench with
  optional AXI/source clock phase controls and added reproducible VCS/URG sweep
  scripts. No DUT state is forced and RTL arithmetic/latency is unchanged.
- Completed 441 named matrix trials: the initial 186 offset/AW-gap/phase runs,
  19 RUN-relative commit-delay runs, 16 source-clock phases, 20 early-commit
  AXI phases, and 200 fine AXI-phase points across offsets 9/10. All completed
  the 56-word four-plane bit-true check with zero UVM errors/fatals. Seven URG
  merges still report the line315 `(1,0,1)` target Not Covered.
- Added RUN-relative commit scheduling and a configurable legal source start
  point. A legal 16-cycle pause before beat 8 triggered the expected
  early-FIFO-starvation checker and is not counted as closure evidence.
- Result: target remains OPEN; no waiver. Finite simulation does not prove
  unreachability. VCF is available in Rocky WSL; a matching-source integrated
  proof has not yet been run. The line88 and line315 `(0,1,1)` candidates also
  remain unwaived pending proof. Coefficient toggle, bits31:23 counter bins,
  and XPM/FWFT gaps remain separate OPEN items.
- Evidence is under
  `runs/thermo5_axil_boundary_phase_generic_20261012/`; focused test and
  replay scripts are under `dv/uvm/tests/thermo5/` and `dv/uvm/sim/`.
- Checks: latest VCS compile PASS; phase matrices PASS bit-true; fine-phase
  URG merge completed but did not cover target; `git diff --check` pending.

## 2026-10-12 12:51 SGT - AXI-Lite exception coverage and checkpoint validation

- Added negative tests for invalid `MAX_TAPS=0/5`, VPI mailbox corruption,
  illegal frame, coefficient-read helper default, zero-strobe CONTROL/STATUS,
  and legal AR backpressure behind an outstanding R response. Generic and XPM
  AXI-Lite targeted VCS/URG runs passed; functional groups are 100%.
- Latest three-test merged code views are documented separately from the full
  frozen-SKU regression. `thermo5_dpd_axi_lite_cfg` is line99.38%,
  condition95.95%, toggle33.50%, branch97.50%; no waivers were applied.
  Two protocol-invariant candidate tuples remain unproven/unwaived, one
  request-boundary tuple remains OPEN as reachable, and coefficient toggles
  remain incomplete.
- Added a standalone parameter-guard TB and a read-only Vivado checkpoint
  validator. The 2026-10-12 synthesis emitted a 56,924,304-byte checkpoint and
  resource report (71,537 LUTs, 52,255 FFs, 1,936 DSP48E2, 334.5 BRAM tiles).
  Vivado reopened the checkpoint and regenerated utilization. The original
  wrapper command exited nonzero after checkpoint creation with a feature-load
  message; routed STA is still OPEN.
- Checks: generic/XPM AXI-Lite VCS regression targets PASS; parameter-guard
  negative test PASS; checkpoint open/report PASS; `git diff --check` pending.

## 2026-10-12 11:38 SGT - Licensed VCS and AXI-Lite wrapper status

- Restored Linux VCS V-2023.12-SP1 and ran the AXI-Lite configuration UVM test
  against generic FIFO (seed 420101) and Vivado XPM FIFO (seed 420102). Both
  runs PASS with zero UVM warnings/errors/fatals. The log confirms illegal tap
  rejection, configuration mailbox wait until a DPD frame boundary, legal
  identity-equivalent two-tap apply, and 56 four-plane bit-true output words.
  Logs/VDBs are under `runs/thermo5_axil_vcs_generic_20261012/` and
  `runs/thermo5_axil_vcs_xpm_20261012/`.
- The first VCS compile found a testbench multi-driver issue: `axil_rst_n` had
  both a declaration initializer and an `always_ff` reset synchronizer. Removed
  the initializer so the synchronizer is its sole procedural driver. This was
  a testbench compile issue, not a DUT functional failure. The first test-local
  report was `source_cg=100%`, `core_cg=75%`, and `reset_reassertions=0` (the
  latter is an event counter, not the reset coverpoint). This targeted pass was
  not complete SKU coverage closure.
- The latest completed wrapper synthesis remains
  `runs/thermo5_axil_ooc_full_20261011/`: `synthesized.dcp` plus utilization
  report for `xczu15eg-ffvb1156-2-i`, 218.75 MHz core, 100 MHz AXI-Lite,
  INTERP_TAPS=2, DPD_MAX_TAPS=4, XPM FIFO. Resources: 71,537 LUTs, 52,255
  registers, 1,936 DSPs, and 334.5 BRAM tiles. No routed checkpoint, timing
  summary, WNS/WHS, or implementation PASS exists for this wrapper yet.
- A clean full OOC rerun was started in
  `runs/thermo5_axil_ooc_full_20261012/` but manually stopped during synthesis
  after host free memory fell to about 0.26 GiB. It produced no new checkpoint
  or timing result. Re-run implementation when host memory is available.
  Parent-level I/O timing, CDC/RDC, mailbox bundled-data timing review, and
  independent reset stress remain OPEN.

## 2026-10-11 - Optional thermo5 AXI-Lite DPD control plane

- Added an optional AXI4-Lite thermo5 wrapper with shadow tap/coefficient
  registers, COMMIT snapshot, a bundled-data request/ack mailbox CDC, sticky
  status/W1C, and synchronized run control. The existing parallel-config SKU
  remains available. Configuration changes apply atomically on the next
  accepted DPD input vector carrying the frame-start marker.
- Carried the one-bit frame marker alongside valid data through the frame-gain
  stages, first x2 interpolation stages, and the DPD input elastic buffer; the
  payload math and legacy top-level interfaces remain unchanged.
- Added a reusable AXI-Lite UVM agent/access sequence/configuration test and
  `dv/uvm/sim/run_thermo5_axil_xsim.ps1`. Fixed the new test's early-exit race
  so it waits for both source sequence completion and configuration/scoreboard
  checks. The UVM top releases AXI-Lite reset synchronously in its own clock
  domain after the common reset assertion.
- Checks run: Windows XSim P0 regression 7/7 PASS; DSM IP smoke PASS; direct
  56-word four-plane MATLAB bit-true test PASS for generic and XPM FIFO builds;
  new Vivado UVM 1.2 test PASS for generic and XPM (seed 101, zero UVM
  errors/fatals). `git diff --check` PASS.
- VCS-UVM was initially blocked by unavailable license checkout; the focused
  AXI-Lite generic/XPM test was later rerun successfully as recorded above.
  Wrapper synthesis is complete, but implementation has not produced routed
  WNS/WHS. CDC/RDC analysis, bundled mailbox data timing constraint signoff,
  and calibrated nonlinear DPD oracle remain OPEN.

## 2026-10-10 - Remove two unreferenced standalone testbenches

- Removed `dv/verif/block/interp/tb/tb_interp_cic_polyphase_unit.sv` and
  `dv/verif/block/dpd/tb/tb_dpd_poly.sv` after checking all project source,
  filelists, scripts, and docs for consumers. Neither had a regression entry;
  the DPD bench also requires CSV inputs absent from the repository.
- Kept all RTL modules: the first-pass source/reference scan found no
  unreferenced RTL module definitions. Preserved generated `runs/` and root
  `verif/` artifacts, plus all current user changes.
- Checks: reference scan before/after; no RTL behavior changed. Full DV was not
  rerun because neither removed bench was part of any configured regression.

## 2026-10-09 14:12 SGT - Thermo5 fault-injection and CI resume

- Re-ran the existing isolated XSim fault-detection suite. Clean controls
  passed and four injected faults were detected: PA-plane swap, output-stall
  corruption, late gain activation, and stale FIFO data after reset.
- Added `dv/uvm/sim/run_thermo5_fault_detection_vcs.py` for isolated
  full-chain VCS-UVM mutations (baseline plus plane-swap, late-gain and
  interpolation-LSB faults). The first run stopped before compile because VCS
  could not connect to the license server; no VCS-UVM fault-detection PASS is
  claimed.
- Extended the clean-runner CI Python syntax list to include the VCS mutation
  runner and natural counter audit helper. A copied clean scratch workspace
  passed Python compilation/workflow-structure smoke checks. GitHub Actions and
  a clean licensed checkout regression remain OPEN.
- Updated the execution frontier and added
  `docs/verification/thermo5-coverage-resume-20261009.md`. Natural counter bits
  23-31, four generic interpolation clamp bins/arms, exact XPM reset tuples,
  XPM FWFT stage1-valid-to-invalid, and other unreviewed XPM bins remain OPEN.
- No canonical RTL, MATLAB arithmetic, golden vectors, or scoreboarding
  criteria were changed. Generated tool output stays under `runs/`.

## 2026-10-08 21:35 SGT - Thermo5 bit21 natural-counter closure

- Generated a 2,097,158-word independent integer oracle and checked its eight
  files against the 36-word MATLAB fixture. Generic and real Vivado XPM
  long-counter UVM tests both passed four-plane bit-true checking, reset all16
  DPD lane counters, and reported zero UVM errors/fatals. CPU times were
  1,434.900s / 1,444.450s.
- Same-binary URG explicitly included the nested `bit21/cov_bit21.vdb` in
  addition to all root coverage databases. An initial merge omitted that nested
  VDB and was not used. Correct raw scores are generic87.52% / XPM80.31%; both
  hit both directions through `sample_count[21:0]`. Bits31:22 remain320
  reachable toggle directions/FIFO OPEN.
- Regenerated exact exclusion files and reran adjusted URG with the same VDB
  inputs. Scores are generic99.66% / XPM96.71%, still partial rather than
  100%. Generic retains four interpolation lines/arms and320 reachable
  counter toggles. XPM retains14 vendor line,44 condition,46 branch,37 toggle
  bins and one FWFT transition;19 exact vendor branch candidates remain
  unmapped and OPEN, not excluded.
- Updated coverage/frontier docs. Evidence:
  `docs/verification/thermo5-reachability-closure-20261008.md`,
  `runs/thermo5_bit21_oracle_20261008/`,
  `runs/thermo5_bit21_urg_20261008/`, and
  `runs/thermo5_bit21_reviewed_exclusions_20261008/`.
- No RTL, MATLAB model, UVM testbench, or bit-true checker was changed.

## 2026-10-08 20:44 SGT - Thermo5 bit20 coverage and reviewed exclusions

- Generated an independent 1,048,579-word range-stress oracle; all eight
  outputs matched the MATLAB fixture. Generic and real Vivado XPM frozen-SKU
  VCS tests passed all four-plane comparisons, then verified all16 DPD counters
  clear on reset. Zero UVM errors/fatals.
- Same-binary raw URG is generic87.51% and XPM80.31%. The `sample_count[20:0]`
  group toggled both ways in all16 counters; bits31:21 remain352 reachable
  toggle directions per FIFO and are not waived.
- Generated exact exclusions only for current-source configuration/scoped
  evidence, reran URG with those `.el` files, and recorded adjusted scores
  generic99.66% / XPM96.71%. These are partial adjusted views, not100% or
  raw coverage. Generic interpolation payload bins, XPM vendor gaps, and the
  missing FWFT transition remain open. Nineteen XPM vendor candidate bins did
  not map to reviewed native signatures and were left unexcluded.
- Evidence: `docs/verification/thermo5-reachability-closure-20261008.md`;
  detailed raw/adjusted reports and manifests are under
  `runs/thermo5_bit20_urg_20261008/` and
  `runs/thermo5_bit20_reviewed_exclusions_20261008/`.
- Began a bit21 natural-toggle closure attempt after MATLAB fixture validation;
  its generic simulation is still running. No RTL, MATLAB fixed-point model,
  testbench, or scoreboard criterion was changed.
- Updated `docs/exec-plans/active/execution-frontier.md` to the current status.

## 2026-10-08 19:10 SGT - Thermo5 bit18 counter coverage closure

- Generated a 262150-word independent integer range-stress oracle after the
  long MATLAB call remained CPU-active for about four hours without emitting
  vectors. All eight oracle outputs matched the 36-word MATLAB fixture;
  fast/legacy MATLAB outputs matched across 18 short configurations (144
  `.mem` files), plus an extreme-gain/nondefault-step probe.
- Generic and real-XPM current-source VCS long-counter tests passed at seed
  610073 with 262150 four-plane words checked, 16-counter post-stream reset,
  and zero UVM errors/fatals. Exact same-binary final URG merges cover bit18
  in both directions in all 16 DPD counters/FIFO; bits 19 through 31 remain OPEN
  (416 directions/FIFO). Raw DUT scores: generic87.50%, XPM80.30%. No waivers.
- Required MATLAB P0 persisted result: `matlab/out/p0_bittrue_compare.csv`,
  seven designs x 65536 samples, zero mismatch; command is
  `scripts/run_matlab_p0_bittrue_check.cmd`.
- Evidence and remaining bins: `docs/verification/thermo5-bit18-counter-closure-20261008.md`.
- Updated source-matched raw per-bin ledger:
  `runs/thermo5_high_counter_xpm_bin_audit_after_bit18_20261008.json`.
- Changed `matlab/tx_bandpass_if/gen_tid32_thermo5_frontend_bittrue_vectors.m`
  to add a selectable generator-local fast TID engine while retaining the
  legacy oracle; fixed-point production models and RTL were not changed.
  The earlier 32-minute MATLAB attempt record remains unchanged and describes
  that separate attempt.

## 2026-10-08 13:58 SGT - Current-source licensed package and coverage resumption

- Ran a fresh Rocky licensed package at
  `runs/thermo5_current_source_dv_resume_20261008/dv_package.json`. Coverage,
  scoped formal, and historical bug-control jobs all PASS on RTL/DV digest
  `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`
  (202 source files). The independent 131075-word/four-plane closure measured
  raw generic87.49% and XPM80.27%; exact current-source details are in the
  coverage docs and run directory. Hosted current-source CI remains OPEN.
- Confirmed the earlier XPM final same-binary record is8/9 FWFT transitions;
  its earlier isolated experiment-only report was7/9. The remaining
  `stage1_valid->invalid` transition and XPM reset tuples stay OPEN.
- Re-audited adjusted-coverage ledger applicability. Raw denominators match,
  but4,358 project dispositions cite a changed UVM testbench hash and6,124
  vendor XPM records are unhashed. Adjusted URG is NOT_RECOMPUTED; no old
  candidate dispositions or exclusions were applied.
- Attempted one legal bit18 counter stream using
  `generate_thermo5_sku_vectors.ps1 -Profile range_stress -Words 262150
  -Seed 610073`. MATLAB remained CPU-active, but the process was stopped at
  after about32minutes near the agreed30-minute resource cap before producing vectors (launcher exit
  `MATLAB vector generation failed: -1`). No VCS test ran and no coverage hit
  is claimed. Exact attempt details are in
  `runs/thermo5_bit18_20261008/attempt.json`. This is NOT_RUN/OPEN, not a
  verification failure.
- Updated `docs/exec-plans/active/execution-frontier.md`,
  `docs/verification/thermo5-coverage100-assessment.md`, and
  `docs/verification/thermo5-uvm-coverage.md`, and
  `docs/verification/thermo5-xpm-exact-followup-20261007.md`; added the
  reviewed unique-run task in `tools/rocky-bridge.tasks.json`. No production
  RTL or numerical behavior changed. No commit was created.

## 2026-10-08 12:43 SGT - Modified-source UVM regression and XPM core-first release

- Added an optional core-first release to the common-reset UVM BFM and reset
  phase test. Both reset requests still assert together. The test now checks
  for source and PA handshakes throughout the common reset epoch, then checks
  a 56-word independent four-plane oracle replay.
- The modified-source generic/XPM frozen regression passed with digest
  `33a22d92726cd7a5f3c9681ed7687a049eede8fb628ecb86865120209e69b0fe` at
  `runs/thermo5_frozen_regression_20261008/manifest.json`. The 131075-word
  same-build closure passed at
  `runs/thermo5_modified_source_gap_closure_20261008/closure.json`. Final raw
  DUT scores are87.49% generic and80.29% XPM.
- The exact condition delta is
  `runs/thermo5_modified_source_gap_closure_20261008/xpm_coverage_core_first_final/exact_condition_delta.json`.
  Same-binary URG newly hit wrapper line52 tuple `1/0`; line57 tuple
  `1/1/0/1` was already covered in the frozen baseline. Line57 tuple
  `1/1/1/0` and line59 tuples `1/0/1/1`, `1/1/1/0` remain OPEN. The adjusted
  full-regression score was not recomputed. No RTL or vendor source changed.
- Corrected stale VHDX/license-blocker descriptions. Rocky and the license
  server responded; hosted CI for the dirty source remains unrun.

## 2026-10-07 23:38 SGT - Rocky restored; current-source DV blocked by license server

- Changed `tools/rocky-bridge.tasks.json`,
  `docs/exec-plans/active/execution-frontier.md`, and
  `docs/verification/thermo5-xpm-exact-followup-20261007.md` to record a
  source-bound licensed run and a redacted license-health check. No RTL,
  MATLAB, bit-true oracle or coverage database was changed.
- The Rocky/XPM preflight passed. The first package attempt used a 1008-word
  vector where 16387 words were required and stopped before coverage. The
  corrected unique run `runs/thermo5_current_source_dv_20261007_02/` matched
  source SHA256 `5257dffafaeddd7eb0b063b8e85faf00c68843927f52c4f2b9d98d4d43a0e979`
  but both VCS compiles failed with `Cannot connect to the license server`.
  No current-source VCS/URG/CI PASS was produced. A redacted `lmutil lmstat`
  check found a configured license variable but no server response.
- Reviewed parent reset RTL against the XPM missing conditions. Full-chain
  single-sided resets are outside the common parent reset epoch. A legal
  core-first release is a candidate test, not a coverage hit or proof.
  Remaining: restore licensed compile, run exact XPM directed tests and
  same-source package, preserve raw high-counter misses. Previous raw
  87.49%/80.27% and adjusted 99.64%/97.08% remain the latest complete run.

## 2026-10-07 22:53 SGT - Current-source CI preflight blocked; exact XPM triage

- Added `docs/verification/thermo5-xpm-exact-followup-20261007.md` and
  updated `docs/exec-plans/active/{execution-frontier,thermo5-gap-closure}.md`
  plus `docs/verification/{thermo5-uvm-coverage,thermo5-convergence-20261007}.md`.
  The latest adjusted
  XPM remainder is explicitly partitioned: 15 line, 32 condition, 461 toggle
  directions (448 high DPD counter directions plus 13 other directions), 50
  branch arms and one FWFT FSM transition. Source-only/core-only reset,
  stage1-valid reset, collision-window proof and exact vendor mappings are
  separate OPEN checks; no bulk vendor exclusion was applied.
- The reviewed `thermo5-xpm-preflight` Rocky bridge command exited 1 before
  tools: the registered distro's `F:\WSL\Rocky-8.10\ext4.vhdx` is missing and
  the F: drive is absent. `wsl --list --verbose`, `Get-PSDrive F` and
  `Test-Path` confirm the environment issue; the failure status is preserved at
  `runs/thermo5_current_source_ci_preflight_20261007/manifest.json`.
  No VCS/URG/SpyGlass or GitHub
  current-source CI result was generated by this attempt; no automatic retry.
- Checks: inspected exact same-build XPM remaining CSVs, production reset
  wrapper and UVM test, read-only Vivado 2024.1 XPM source, scoped reset-default
  and FWFT formal manifests. Fixed-clock half-period proof is limited to the
  exact 125/218.75-MHz testbench and has not been applied as a URG exclusion.
  Remaining: restore a licensed Rocky environment,
  run source-hash-bound DV CI, then measure each exact XPM candidate.

## 2026-10-07 22:45 SGT - Current thermo5 evidence synchronized before CI

- Updated `docs/exec-plans/active/execution-frontier.md` from the completed
  `runs/thermo5_followup_long_20261007/evidence_index.json` and same-build
  VCS/URG logs. Both FIFO variants passed an independent 131075-word,
  four-plane bit-true stream with 74900 accepted AXI beats. Raw coverage is
  87.49% generic / 80.27% XPM; scoped adjusted coverage is 99.64% / 97.08%.
  The remaining adjusted directions are 448 generic and 461 XPM toggles;
  neither raw nor adjusted coverage is 100%.
- Reason: the active frontier still cited the earlier 65541-word run and
  older XPM adjusted ledger. This change is documentation only; RTL, MATLAB,
  UVM behavior, synthesis scripts and constraints were not modified.
- Checks: read the follow-up evidence index, closure PASS manifest, both
  131075-word VCS logs (four-plane PASS; zero UVM errors/fatals), independent
  oracle manifest and adjusted remainder inventory. Current-source licensed
  CI is the next gate; the previous GitHub PASS belongs to an older commit.
- Limitations: XPM exact residual bins, high counter bits, scoped formal
  boundaries, physical RDC/GT/board timing and current-source CI remain OPEN.

## 2026-10-07 13:32 SGT - Actual coverage convergence and scoped proof delivery

- Added thermo5_convergence_harness.sv, run_thermo5_convergence.{py,tcl}, public
  UVM FIFO reset phase test0..11 and same-source baseline reuse in gap closure.
  Added tools/hw/thermo5_urg_exclusions.py, thermo5_xpm_bin_review.py; extended
  thermo5_gap_ledger.py for flat matching-baseline reports and portable paths.
- Generated MATLAB65541-word range_stress seed610701 oracle without changing
  arithmetic. Ran VCS fresh20-case baseline and24 legal directed cases PASS;
  both FIFOs checked four PA planes, all16 lane counts and post-stream reset.
  TID162 rows hit both directions; bit15/16 add64 directions per FIFO;
  remaining reachable directions544 ->480. No force/deposit/width/VDB edits.
- Actual same-binary URG raw87.01 ->87.49 generic,79.96 ->80.26 XPM. Strict
  native configuration/scoped exclusions give99.63%/96.40%; raw retained.
  Exact bin/instance/checksum/proof/vendor hashes recorded. Reviewed5845/5990
  vendor records;145 unreviewed. No blanket vendor/file/hierarchy exclusion.
- Final scoped formal: DPD19/20 assertions proven, no-saturation/count-zero
  closed, full identity inconclusive; valid interpolation16/5 PASS; actual
  XPM residual7/9 PASS; reset2 assertions/4 covers/2 unreachable reentries PASS.
  All exact finalized source hashes match, no blackboxes/setup violations.
  Qualified FWFT reset cover remains inconclusive; unqualified initial covers
  and failed phase12 are excluded. Valid-only interpolation lemma deliberately
  does not exclude invalid-slot clamp bins.
- LEC now actually PASS:170869 compare points equivalent, zero fail/abort/
  unmatched with original mapped netlist/SVF. Updated convergence record,
  execution-frontier and active closure plan to remove stale running-LEC and
  generating-oracle instructions. Evidence index under
  runs/thermo5_converge_long_20261007 links raw/adjusted/remaining artifacts.
- Checks: actual VCS/URG/formal above; source/binary/vendor/proof/exclusion and
  counter-delta gates PASS; Python compilation and selected diff checks.
  Remaining: generic4 line/0 condition/480 toggle/4 branch; XPM26/45/517/60,
  FWFT transition, full identity formal, current-source CI, physical lint/RDC,
  ASIC cap/leakage and GT/board boundaries. Full100% is NOT achieved. No new
  production RTL/MATLAB/synthesis edit; corresponding implementation checks
  were not repeated for this verification-only change.

## 2026-10-07 12:08 SGT - Execution-plan consolidation and cleanup

- Replaced docs/exec-plans/active/execution-frontier.md with one current
  status table, authoritative paths, exact live LEC inspection steps,
  residual limits and next priorities. Deleted obsolete/contradictory status
  paragraphs, repeated coverage scores and stale license/task assignments
  from the active frontier.
- Rewrote active/thermo5-gap-closure.md with remaining DV/DE work and explicit
  exit gates: LEC, incremental legal counter streams, exact XPM transitions,
  proof transfer/arithmetic, lint/RDC, cap/leakage, CI and board boundaries.
- Preserved byte-identical snapshots of the three old plans in inactive/;
  removed the already-delivered thermo5-dv-closure.md from active/ after
  archive hash verification. Added inactive/README.md and docs/README.md links.
- Corrected AGENTS.md migrated P0/IP-smoke paths and stale frozen-thermo5
  mapping status. Original raw run evidence, RTL/DV/MATLAB, vendor/PDK content
  and the live Formality process are retained.
- At12:08SGT actual Formality remains RUNNING in verify; no final PASS claimed.
  DV CI37462007850 PASS, raw87.48/80.26 and ASIC constraint/GT/board OPEN
  limits are preserved. Checks: archive hashes, local document links,
  navigation validation and git diff --check; no implementation rerun is
  needed for this documentation-only change. Archive hash/local link/migrated
  command-path checks, navigation validation and git diff --check PASS.

## 2026-10-07 11:25 SGT - Actual restored-feature LEC retry and source gaps

- Launched actual Formality V-2023.12-SP3 equivalence-only run at
  runs/thermo5_fm_restored_20261007_retry1 using the original DC mapped
  netlist/SVF. Reference RTL elaborated; implementation netlist is reading.
  Actual equivalence is RUNNING; no PASS or fresh license failure claimed.
- Updated execution-frontier.md, thermo5-dv-de-delivery.md and
  thermo5-coverage-reasons-20261007.md with current execution and concrete
  unhit source locations, counter thresholds and proof/configuration limits.
  Corrected stale mapping status and toggle-denominator wording.
- tools/hw/thermo5_coverage_reason_report.py now preserves actual saved
  URG statements/conditions/predicates/signals in reasons CSVs, including
  vendor records without inventing vendor source hashes; audit rerun PASS.
  Detailed URG FSM extraction additionally reconciles the three missing
  XPM transitions to the two original aggregate records and hashes reports.
- Exact reason/hash/denominator audit and Python syntax checks PASS;
  git diff --check PASS. Raw URG remains87.48/80.26%, no exclusions.
- Mandatory run_ooc_all_dsm.ps1 -Part xc7z020clg400-1 actually launched;
  completed reports under syn/reports/ooc_xc7z020clg400_1_20261007_112340.
  Actual summary12/14PASS; mb_ef2=-0.093ns and mb_mash22=-0.688ns
  FAIL_TIMING reproduced. Command process exit is not a full timing PASS.
- Canonical RTL/MATLAB unchanged. Counter544 directions per FIFO, XPM5990
  vendor/134 proof-transfer records and physical integration remain OPEN.
- At11:56 SGT actual FM still RUNNING in verify;170869 compare points
  matched,0 unmatched compare points,26148 SVF commands accepted/0 rejected.
  No DUT hierarchy paths in blackbox report. Kept process running; final
  status/failing/aborted reports and provenance manifest await completion.

## 2026-10-07 - Exact missing-bin reasons and restored Formality request

- Added tools/hw/thermo5_coverage_reason_report.py and corresponding
  verification document. Both FIFO reasons CSVs reconcile every missing
  line/condition/branch/toggle to original URG denominators and gate hashes.
  Candidate generic disposition line/cond/branch100%, toggle99.3461%;544
  reachable directions remain OPEN. Raw87.48/80.26 unchanged; no exclusions.
- Detailed parameter guards, external taps/history/pair1, identity/average
  bounds, reset/CDC scope and vendor proof limits. Corrected coefficient-port
  explanation and URG toggle-denominator note. XPM5990 vendor/134 transfer
  records remain OPEN, FSM detail aggregate only. Generated bit15..31 legal
  counter plan with measured simulation extrapolation (~16days for bit31).
- FM script/runner now supports separate mapped input and fresh outputs,
  checks DC provenance/library/RTL and mapped artifact hashes, exports
  blackbox report. Original mapped evidence is preserved.
- Python compile/help, actual local reason extraction/hash/denominator
  gates and git diff --check PASS. No canonical RTL/MATLAB change.
- WSL retest unavailable: sandbox E_ACCESSDENIED; auto-review403 model
  authorization error prevented escalation execution. User's latest
  Formality restoration not tested. Actual FM and required FPGA OOC after
  flow edits remain unrun pending execution-access recovery.

## 2026-10-06 20:22 SGT - Restored-license retest

- Fresh ordinary DC/Formality startup and checkout PASS. Actual frozen
  ASIC compile_ultra/max2 run is in progress; no mapped or equivalence
  PASS is claimed before reports exist.
- Actual GitHub Actions37462007850 at commit a9b0bc6f67f575e9bb98085b1e064f9eddc886f2
  passes hosted syntax and licensed VCS/UVM/URG, four scoped VC Formal jobs,
  four fixed/faulty bug controls and SpyGlass. Latest protocol-error reset
  test passes both FIFOs. Ephemeral runner auto-unregistered.
- Same-build raw generic87.01->87.48%, XPM79.96->80.26%; no exclusions.
  Fresh exact ledger/reports copied to runs/thermo5_real_ci_37462007850;
  no extraction gaps. Formal48 assertions proven across four jobs; raw
  high counters544 directional records per FIFO remain reachable/unhit.
  XPM vendor5990 records and134 generic-proof transfer records remain OPEN.
- Unified logs:12 expected negative controls,3 compiler warnings, zero
  unexpected checker/assertion diagnostics. SpyGlass39 warnings+4 synthesis
  warnings, zero errors; physical reset-use review remains OPEN.
- Updated frontier, DV/DE delivery, coverage, lint review and bug evidence.
  Fresh normalized-evidence validation and git diff --check PASS.
  No canonical RTL or MATLAB change in this retest; previous mandatory
  Windows check results and unrelated FPGA OOC failures are retained.

## 2026-10-06 20:01 SGT - Separate DV/DE delivery and actual CI

Final20:09SGT: Rocky recovered; DC ultra DCSH-1, valid license service
missing. Modified license-check preloads are not used. ASIC mapping/FM/area
blocked on valid permitted license. Follow-up CI37460826993 cancelled for
license failures and licensed CI variable disabled. Required OOC complete
12/14PASS; mb_ef2=-0.093ns and mb_mash22=-0.688ns FAIL_TIMING. Documentation
distinguishes last successful commit from later untested protocol-reset fix.

- Added explicit frozen thermo5 ASIC wrapper, dual-domain min/max SDC,
  DC/SVF and Formality scripts, reproducible hash/exit manifest runner and
  mapped area/architectural-rate summary. Fixed missing GT boundary sources
  in ASIC filelist; original configurable tops unchanged.
- Actual SpyGlass zero errors/blackboxes,39 warnings,4 synthesis warnings;
  individual review records retain two reset-use RDC items OPEN. Added
  machine-readable lint summary and exact coverage gap ledger; corrected
  omitted-cell-close URG parser, recovering24 vendor condition records.
- Real GitHub Actions37458132897 passed hosted syntax and licensed VCS,
  same-build URG, four scoped formal jobs, bug controls and SpyGlass on
  review branch; local evidence copied. Ephemeral runner auto-unregistered.
- Fresh VCS/XSim bug fixed/faulty controls pass; case-study interview table
  added. Expanded generic CDC formal7 assertions/9 covers PASS. Legal
  gain0/max/min closes33 generic toggle directions, raw87.48%; XPM80.25%.
- Added public-reset check after protocol-error negative control. Initial
  CI37459008266 failed on an old source transaction crossing reset epoch;
  corrected stimulus waits for source completion. This change still needs
  licensed CI retest after Rocky recovery; failure is retained.
- P0 XSim7/7 and IP smoke PASS; mandatory FPGA OOC reproduces mb_ef2
  WNS=-0.093ns (not thermo5 ASIC timing). Final OOC row still running.
- Classic DC mapping runs stopped without netlists; huge flattened mapping
  made WSL unresponsive. WSL restart returned HCS connection timeout;
  service restart unavailable to current process. ASIC mapping/FM/area
  remain OPEN, next attempt compile_ultra/max2 cores. No raw100% claim,
  no exclusions, no board/real-parent timing claim.

## 2026-10-06 17:59 SGT - Generic residual formal closure

- Replaced the large AXIS payload stability assumption with a constructed
  registered source and executable stability assertion. Corrected formal
  clocks to exact integral 7:4 periods; the rounded 4.572-ns clock made an
  unnecessarily expensive time grid. Added focused `--jobs` diagnosis.
- `runs/thermo5_coverage100_residual_exact_20261006/` passes four assertions,
  all nine covers, non-vacuous source stability, zero black boxes and selected
  setup checks, completing in 47.93 seconds. Earlier inconclusive experiments
  are retained. Generic residual default is unreachable within this modeled
  environment. No raw URG exclusion or vendor-XPM/metastability claim.
- Updated assessment, coverage record, gap plan, formal README and frontier.
  Raw generic/XPM scores remain 87.47/80.25; arithmetic formal and all
  previously stated hardware/vendor/high-counter URG limits remain OPEN.
- The intermediate registered-source run with rounded clocks at
  `runs/thermo5_coverage100_formal_driver_20261006/` was interrupted after
  the exact-ratio replacement passed; it has no completed summary and is
  not PASS evidence. Final syntax, whitespace and exact closure validation pass.

## 2026-10-06 17:52 SGT - Board-free coverage follow-up and 100% assessment

- Extended MATLAB vector generator with optional signed frame gains while
  preserving defaults. Added `-SaturatingGain`; generated independent legal
  endpoint/gain and 16,387-word plateau vectors. Required MATLAB P0 check
  passed seven x 65,536 samples, zero mismatches.
- Added pre-first-frame quiet-core UVM test and post-long-stream public reset
  count checks. Gap runner accepts configurable oracle length and gain set.
  Fresh baseline plus ten directed VCS runs pass; exact validation passes
  TID 162/162, all sixteen counter bits5:14 both directions and gain branches.
  Raw matching-build URG: generic 87.00 -> 87.47, XPM 79.96 -> 80.25.
- Fixed URG audit omission of single-instance shared sections and modules
  without condition coverage. Added complete denominator/line/branch/FSM/
  assertion exporter and strict exact-bin validator. Macro header aggregates
  and expanded dotted lines are counted once; split source pages included.
- Added unbounded full-width production counter proofs (35 assertions, four
  covers, zero black boxes). Optional identity/residual experiment is not
  PASS: identity latency proven but arithmetic inconclusive; residual three
  assertions prove, six of nine covers hit, remaining covers and assumption
  vacuity inconclusive. Retain failed experiment; no waivers follow from it.
- Extended package/Windows launcher flags, validated DRY_RUN and syntax;
  complete extended package not rerun as one job. GitHub CI not executed.
  Initial launcher tuple-list mutation failed during DRY_RUN and was fixed
  before successful validation. Canonical RTL not edited in this follow-up.
- Updated coverage assessment, portfolio, coverage record, gap plan, formal
  README and frontier. Raw all-DUT 100% cannot be claimed for this frozen SKU;
  no exclusions applied. Counter31:15, scoped reset timing, vendor bins,
  SpyGlass lint signoff, ASIC mapping, GT CDC-11/I/O/RX/physical board remain OPEN.

## 2026-10-06 17:05 SGT - Graduate-DV coverage closure and engineering package

- Changed the interpolation test to arm public PA backpressure from an
  observed empty-stage1/occupied-stage2+output state at a core falling edge,
  following 24 accepted beats and an 80-cycle legal source bubble. Fresh
  generic/XPM VCS tests observe 138/139 target cycles and independently
  check 32 beats / 56 four-plane MATLAB words. Generic exact line71 bin is
  newly Covered; XPM baseline already covers it.
- Added complete URG toggle row export and per-bit expansion in
  `tools/hw/thermo5_audit_reports.py` and
  `dv/uvm/sim/run_thermo5_gap_closure.py`. Same-build endpoint+plateau merge
  hits both directions for all 162 TID gaps per FIFO and counter bits5:10
  in all 16 lanes. Raw DUT scores: generic 87.00% -> 87.19%, XPM
  79.96% -> 80.06%; different hierarchy, not comparable to each other.
- Added `thermo5_gap_harness.sv`, `run_thermo5_gap_fpv.tcl` and
  `run_thermo5_scoped_formal.py`. Reset scope is runtime falling-edge
  assertion/release: three proven/non-vacuous assertions, four covered
  normal scenarios, exact collision cover uncoverable. Counter scope is
  <=2072 accepted samples/reset epoch: equality, budget and high-zero
  assertions proven; four acceptance/stall/recovery covers hit; assumptions
  non-vacuous. Review found missing saturation helper definitions; added
  production `dpd_poly.v` and a zero-black-box gate before accepting proof.
- Added Python and Windows/Rocky one-command package, automatic coverage
  summary and normalized checker/assertion/negative-control diagnostics.
  Source state, hashes, tool banners, seeds, commands, exit codes and VDBs
  are recorded. Missing vector/oracle/report/checker or unexpected diagnostic
  fails the package. Added compiler port-lint diagnostics to thermo5 VCS.
- Added `.github/workflows/thermo5-dv.yml` for hosted syntax and explicitly
  enabled trusted licensed CI simulation/formal. GitHub itself was not run;
  local package execution is the current evidence. Compiler diagnostics are
  not SpyGlass lint signoff. An optional SpyGlass probe is preserved under
  `runs/`; its first Tcl command was rejected. Its exploratory default-top
  run then completed with 3 errors and 49 warnings (missing XPM model and
  tool memory threshold among the errors), so no frozen-SKU lint PASS is
  inferred. The package uses VCS lint diagnostics and scoped formal gates.
- Added `thermo5-dv-portfolio.md` with both requested review tables and
  updated coverage, counter/reset/TID audits, handoff, UVM/formal READMEs,
  the active gap plan and frontier. Corrected an accidental literal newline
  marker in the frontier and Linux formal shell-script CRLF execution issue.
  Scoped formal uses absolute source paths while keeping its runtime and
  learned data under the selected `runs/` directory; older root-level
  learned data was preserved in its originating evidence directory.
- Checks: fresh complete VCS/URG baseline and directed follow-ups; scoped
  VC Formal; fixed/faulty historical commit VCS controls; Python compilation
  and package dry-run. The final package manifest is PASS with zero errors;
  reset/counter proofs have zero black boxes. CI YAML parsing, Windows
  launcher PowerShell parsing, and diagnostic negative controls pass (four
  expected negative lines and one deliberately unexpected BITTRUE fatal are
  correctly separated). The final real diagnostics contain only three
  known compile warnings and 12 expected negative-control lines. Scoped
  `git diff --check` passes. Evidence directory:
  `runs/thermo5_dv_package_delivery_20261006/`. No canonical RTL or MATLAB
  arithmetic changed. Raw reset/high-counter coverage, unrestricted counter
  and asynchronous reset timing, GT CDC-11, real I/O, RX, and physical board
  remain outside the completed scope.

## 2026-10-06 16:10 SGT - Commit bug evidence and long-stream DV

- Added `dv/uvm/tb/tb_dsm_commit_bug_repro.sv`,
  `dv/uvm/sim/run_commit_bug_repro.py`, and
  `docs/verification/commit-bug-case-studies.md`. XSim and VCS each pass two
  current-RTL cases and detect two isolated historical regressions. Legal
  AXI-Lite stimulus reproduces stale-rejection contamination and reset
  cancellation failure during a busy commit; source hashes are in manifests.
- Extended the thermo5 vector generator with an isolated `range_stress`
  profile and UVM source/oracle arrays with configurable word counts.
  MATLAB P0 passes 7/7 with zero mismatches. A fresh generic/XPM frozen VCS
  regression passes 14 cases and six payload runs; additional 2072-word
  runs pass all four golden planes and all 16 sample/saturation counters.
- Added the same-build gap closure runner and legal interpolation timing
  probes. The exact interpolation schedule is still being retargeted;
  no condition hit is claimed from failed probes. Focused reset VCS/URG
  succeeds, but both `1/0` condition bins remain unhit and OPEN.
- Updated the execution frontier. Remaining limits: URG per-direction
  toggle review, exact interpolation hit, scoped reset disposition, two
  GT CDC-11 paths, real parent timing provenance, RX loopback, and absent
  physical board. No canonical RTL was changed in this follow-up.

## 2026-10-06 - Instance-level thermo5 gap closure started

- Added `docs/exec-plans/active/thermo5-gap-closure.md` and linked it from
  the execution frontier. The priority is the exact full-chain interpolator
  condition, both reset-release condition bins, and both GT CDC-11 paths;
  then DPD branch/counter and TID input-range toggle rows. Each row requires
  a new instance-level hit, parameter/RTL proof, or an explicit OPEN result.
  No new coverage or CDC closure is claimed by the plan itself.

## 2026-10-06 - Frozen thermo5 DV traceability, endpoints, and fault detection

- Added `docs/verification/thermo5-frozen-sku-signoff-plan.md` and enhanced
  `tools/hw/thermo5_audit_reports.py` to inventory instance/source-level
  condition, branch, toggle, and assertion coverage for generic and XPM
  separately. Updated `docs/verification/thermo5-uvm-coverage.md`; the
  remaining reachable/uncertain bins are OPEN, not waived.
- Added accepted signed-min/max functional bins and an explicit test gate.
  Fresh licensed VCS runs passed generic seed 606101 and real-XPM seed
  606102: each observed 32 accepted beats, 56 golden-matched four-plane
  words, 32 min-hit and 32 max-hit beats, with zero UVM errors/fatals.
  These one-case VDBs were not merged into the earlier seven-case URG scores.
- Added the isolated XSim fault-detection runner and documented four
  compiled/detected mutants in `docs/verification/thermo5-fault-detection.md`:
  plane swap, PA-stall word drop, early gain, and stale FIFO after reset.
  Matching clean baselines passed; this is not a VCS-UVM mutation result.
  Review exposed a soft-error/PASS-marker risk; source/PA scoreboard
  mismatches now call `uvm_fatal` before incrementing checked counts.
- Added `dv/uvm/sim/run_thermo5_frozen_regression.py` and
  `docs/verification/thermo5-regression-handoff.md`. Dry-run and parser
  checks passed. The default WSL Python 3.6 stopped the first launch before
  simulation; Rocky Python 3.12 enabled a fresh full licensed PASS. The
  post-checker-hardening repeat also passed at
  `runs/thermo5_frozen_regression_hardened_20261006/manifest.json`: 14
  directed-case results, six independent-payload results, two separate URG
  merges, all ten commands exit zero, and zero launcher errors. Merged DUT
  hierarchy scores are 87.00% generic and 79.96% XPM, not comparable across
  vendor hierarchy. The new per-instance gap inventories remain OPEN where
  no hit or scoped proof exists.

## 2026-10-06 00:01 +08:00 - Thermo5 reset/CDC evidence inventory

- Added `docs/verification/thermo5-reset-cdc-evidence.md`, mapping the latest
  routed report's two XPM Gray-pointer CDC-6 rows, both reset-request paths,
  XPM common-reset propagation, and both GT TX-active CDC-11 rows to exact
  instances, source, directed checks, and remaining OPEN items.
- Reran `dv/verif/scripts/run_xsim_xpm_async_fifo_reset.ps1`; XSim exited 0
  and logged `DSM_XPM_ASYNC_FIFO_RESET_PASS` in
  `verif/out_xsim_xpm_async_fifo_reset/console_xsim.log`. No RTL, constraint,
  UVM, waiver, or false-path change was made for this evidence inventory.
- The parent reset-only GT test remains indirect evidence for the generated
  reset controller. Its RX comparison was skipped. No CDC/RDC or board-level
  signoff is claimed.

## 2026-10-05 - Thermo5 DV closure work packages opened

- Added `docs/exec-plans/active/thermo5-dv-closure.md` with five scoped work
  packages: requirement/test/checker/bin traceability, owned-RTL coverage
  audit, isolated fault-detection experiments, clock/reset and GT evidence,
  and reproducible generic/XPM regression handoff. The work is planned and
  in progress; this entry does not claim new tests or coverage hits.
- Updated `docs/exec-plans/active/execution-frontier.md` with the next DV
  action. Read-only baseline review covered the existing thermo5 filelist,
  seven-case Makefile regression, functional covergroups, scoreboard, and
  coverage record. The dirty worktree and unrelated user changes were left
  intact. No RTL, MATLAB, or tool output was changed in this planning step.

## 2026-10-05 22:28 +08:00 - Fresh direct parent route and GT CDC-11 audit

- Generated a new current-source parent `synthesized.dcp` and routed it in
  `runs/thermo5_parent_cleanroute_20261005_2117/`.  The direct end-of-route
  report is WNS `+0.264 ns`, WHS `+0.011 ns`, TNS/THS zero and zero failing
  setup/hold endpoints under provisional OOC I/O budgets.  This is a new
  direct-route result; it does not erase the earlier direct/reopened-report
  discrepancy, and the 11-ps hold margin is deliberately recorded as fragile.
  The synthesis wrapper again ended with a late Vivado feature-license error
  after writing the checkpoint, so no clean synthesis-wrapper PASS is claimed.
- Reran parent reset-only XSim in that same output directory.  It passed 64
  accepted AXI beats to 112 TX words, idle, power-good recovery, TX-active
  recovery and common-reset recovery.  RX comparison was intentionally
  skipped; four-lane RX recovery remains open.
- Audited both remaining CDC-11 paths without a false-path or waiver.  One is
  the parent `ASYNC_REG` TX-active two-flop synchronizer and is exercised by
  the directed active-loss/recovery test.  The other is the generated Wizard
  reset controller's explicit `bit_synchronizer`.  Both remain OPEN pending a
  supported GT reset/CDC disposition; source-side duplication is unsafe when
  the TX user clock stops on link loss.  Updated the active frontier and the
  integration CDC contract.

## 2026-10-05 21:02 +08:00 - Real-XPM UVM and current-source parent reroute

- Used the Windows Vivado 2024.1 XPM sources mounted at
  `/mnt/d/Xilinx/Vivado/2024.1` in licensed Rocky VCS. Seven thermo5 UVM
  cases and their URG merge passed; evidence is in
  `runs/uvm_thermo5_i2_d1_xpm_rerun2_20261005/`. XPM-inclusive score is
  81.38%; the separate generic regression reports 87.22%, and the hierarchy
  makes these percentages non-equivalent. Instance-level open bins remain.
- VCS exposed `ICPD_INIT` single-writer errors on the initialized reset-sync
  registers. In `rtl/axis/dsm_xpm_async_fifo.sv`, changed only three
  `always_ff` keywords to clocked `always`; no event control, assignment,
  reset/data behavior, or fixed-point arithmetic changed. Fresh focused XPM
  reset XSim, P0 XSim 7/7 (65,536 samples each, zero errors) and IP smoke
  passed. Source SHA256:
  `53C6143CA99AC2743A64C9C1CF09B1463EF51262D8FCD82E89362EEE70FA174B`.
- An independent route of the immediately preceding CDC-fix checkpoint
  completed at `runs/thermo5_parent_cdcfix_synth_retry_20261005/`: provisional
  OOC WNS +0.292 ns, WHS +0.012 ns, TNS/THS zero. Prior CDC-7/10 critical
  rows disappeared, but two GT TX-active CDC-11 critical rows remain OPEN.
- The new current-source synth wrote
  `runs/thermo5_parent_cdcfix_vcsfix_20261005_164803/synthesized.dcp`
  but its wrapper exited 1 due a late Vivado feature-license error; do not
  label synthesis clean PASS. Route from the **same output directory** opened
  that DCP and completed with exit 0. The direct end-of-route report gives
  WNS +0.301 ns/TNS 0 and WHS -0.106 ns/THS -0.106 ns at one short TID
  hold path; the route checkpoint reopened in a fresh Vivado process gives
  WNS +0.301 ns, WHS +0.011 ns, TNS/THS 0 and all specified timing met.
  `phys_opt_design -hold_fix` performed no modification because the reopened
  analysis was already positive. Both reports are retained; this is a report-
  state discrepancy, not a claimed physical hold repair.
- Updated `docs/verification/thermo5-uvm-coverage.md`, the CDC contract and
  active frontier. Added a reusable Rocky XPM source preflight task, but
  removed a one-off regression task that hard-coded a used output directory.
- Added `syn/holdfix_thermo5_qsfp_gt14_parent.{tcl,ps1}` as a reproducible
  post-route audit/hold-repair flow. On this checkpoint it made no physical
  modification because the freshly reopened timing state was already positive.
  Remaining: retain/reproduce the direct-route versus checkpoint-timing
  discrepancy, inspect critical CDC/RDC, obtain real parent I/O/clock/board
  data, resolve GT RX comparison and instance-level coverage bins. No board
  RF output claim.

## 2026-10-05 11:33 +08:00 - Retry licensed VCS environment access

- Retried the reviewed Rocky bridge's read-only `toolchain-doctor` after the
  user enabled the VCS license. The bridge failed while enumerating WSL
  distributions (exit code -1), before entering Rocky or invoking VCS.
- No generic/XPM UVM simulation or URG merge ran; prior coverage scores remain
  historical and unchanged. The next attempt requires a Codex WSL runtime or
  a user-opened licensed Rocky terminal.

## 2026-10-05 11:15 +08:00 - CDC fix candidate and rerun availability

- Routed CDC path review located the prior CDC-7/10 critical reset paths at
  the parent `tx_active` asynchronous-clear use. Added an unverified RTL
  candidate: synchronize TX-active in the free-running domain for link/reset
  qualification, preserve raw TX-active only in the immediate PA blanking
  gate, and synchronize reset release into the health controller.
- Required validation could not be rerun from this Windows agent: Vivado
  launchers returned exit 1 with empty stdout. P0 and IP smoke both stopped at
  `xvlog` before producing logs. WSL enumeration returned
  `Wsl/EnumerateDistros/Service/E_ACCESSDENIED`. No fresh simulation, synth,
  routed CDC/STA, VCS VDB, or URG result is claimed for the candidate.
- The actual SI5341 register table/lock procedure and real parent SoC clock
  launch/capture delays are not present in the repository. Existing 125-MHz
  reference and I/O min/max values remain assumptions; no guessed timing was
  written into the board constraints.
- Updated the execution frontier and CDC/UVM coverage notes to distinguish
  the unverified candidate and tool access boundary from measured evidence.

## 2026-10-05 10:40 +08:00 - Parent route/CDC audit and GT RX experiment

- Completed the detached four-GTH parent route at
  `runs/thermo5_qsfp_parent_route_retry_20261005_0015/`: WNS +0.278 ns,
  WHS +0.010 ns, TNS/THS 0, and no setup/hold failing endpoints against the
  currently applied provisional budgets. Utilization is 32,389 LUT logic,
  7,640 LUTRAM, 48,213 FF, 496 DSP, 6.5 BRAM tiles, four GTH channels.
  This is not board/system I/O signoff: actual clock sources, package pin
  locations, and measured I/O min/max delays are still missing.
- Routed CDC report no longer lists the previous eight XPM reset CDC-1 or two
  parent CDC-11 rows, but now reports four CDC-10 critical async-clear paths
  from `gtwiz_userclk_tx_active` to `health_meta_reg[4:7]/CLR` and one CDC-7
  critical path to `link_ready_q_reg/CLR`. CDC-15, CDC-26 and XPM CDC-6
  warnings remain open; no blanket waiver was added.
- GT parent reset-only XSim passes 64 accepted AXI beats / 112 TX words and
  power-good, TX-active and common-reset recovery. A PMA near-end loopback
  configuration synthesizes, but full RX comparison times out with no RX
  frame (`rx_done=1`, `rx_cdr=1`, `rx_clk=0`, data `55...`). Its reset-only
  diagnostic passes; neither proves RX data recovery or physical deskew.
- No new UVM/URG database was generated; coverage closure is unchanged.
- Updated the execution frontier, CDC contract and four-PA contract with the
  exact pass/fail boundary. `git diff --check` ran; all EDA output stays under
  the corresponding `runs/` directory. Remaining: CDC-7/10 root-cause work,
  real parent timing inputs, RX loopback recovery, and UVM coverage closure.

## 2026-10-04 22:12 +08:00 - Reset/CDC, parent I/O and loopback closure attempt

- Synchronized both XPM FIFO reset requests into `wr_clk`; either request now
  immediately blocks both public FIFO handshakes during synchronization.
  Remote reset guards asynchronously assert and synchronously release in the
  opposite clock domain. Added a focused supported-depth XSim for initial,
  read-only and write-only reset, stale data
  flush and recovery. Corrected the initial depth-4 test setup to XPM's
  supported minimum of 16. The focused XSim passes.
- Updated the four-GT parent health controller to remove its extra
  `tx_active` status synchronizer fanout; `tx_active` now asynchronously
  asserts readiness reset/PA blanking and recovery remains freerun-qualified.
  Added provisional min/max I/O delays to the parent XDC and expanded the
  parent TB source for three four-lane, 56-word RX loopback comparisons,
  power-good/TX-active loss, a deliberate mid-frame interruption, common
  reset and replay. The modified parent TB has not yet run.
- Added UVM observation/stimulus for the still-open interpolator stage-1
  empty/downstream-blocked condition and reset-with-enable. The stimulus has
  not been run; licensed VCS in Rocky WSL fails before compile with
  `Cannot find license file`. New related URG evidence does not exist.
- Added a reproducible route-from-synth-checkpoint command, preserving the
  fresh synthesis evidence while collecting routed timing, utilization, CDC,
  clock interaction, check_timing, methodology and DRC reports.
- Verification: raw-64 mid-frame/plane/health-loss XSim, XPM reset XSim,
  fresh P0 XSim 7/7 and IP smoke PASS. Final parent synth with recovered
  RX-word min/max delay is running in
  `runs/thermo5_qsfp_parent_closure_20261004_2216/`; no STA result yet.
  route, generated-GT RX-loopback simulation, P0 XSim, IP smoke, generic/XPM
  UVM and URG are pending. No updated parent CDC/RDC or routed STA closure is
  claimed. The prior eight XPM CDC-1 and two GT CDC-11 rows remain open until
  a fresh routed checkpoint is audited; the vendor-owned CDC-11 is not waived.
- Archived the previous long execution frontier at
  `docs/exec-plans/completed/execution-frontier-archive-20261004.md` and
  replaced the active frontier with a 100-150-line current-state handoff.

## 2026-10-04 20:07 +08:00 - Route and audit the four-GT parent revision

- Changed `fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv` to keep the
  continuous TX boundary's readiness in the 218.75-MHz domain and feed the
  two reset synchronizers from registered GT health. No arithmetic, vector,
  coefficient or lane-order behavior changed. Updated the parent verification
  contract and execution frontier with the exact routed evidence.
- Checks: generated-GT parent XSim PASS (32 AXI beats, 56 four-plane words,
  post-frame idle/stop/reset); P0 XSim 7/7 PASS; IP smoke PASS. The second
  parent implementation produced `routed.dcp` and formal internal routed
  WNS/WHS +0.257/+0.010 ns at 218.75 MHz, TNS/THS zero, four GTH, with
  40,027 LUT, 48,207 FF, 496 DSP and 6.5 BRAM tiles. Independent read-only
  DCP audit of methodology, DRC and worst setup/hold paths completed. CDC-1
  reduced 273 to eight; CDC-10 reduced two to zero.
- Tool caveat: the route wrapper surfaced a late Vivado feature-license
  failure despite completed route/reports/checkpoint and a normal Vivado exit
  marker; the DCP was independently reopened for audit. The eight XPM-reset
  CDC-1 and two GT-related CDC-11 critical rows remain open. There are 468
  inputs and six outputs without parent I/O delays, missing AXI/free-run
  `HD.CLK_SRC`, no dedicated RDC signoff, no proved serial phase alignment,
  no verified board 125-MHz reference or PA blanking timing. Hardware/RF
  output is not claimed. The required legacy xc7z020/100-MHz P0 OOC
  regression completed 12/14 PASS. `p0_ooc_mb_ef2` (-0.093 ns) and
  `p0_ooc_mb_mash22` (-0.688 ns) fail timing with identical status and
  slacks in the 2026-09-19 baseline report; this is not a new thermo5
  GT-parent regression. The complete CSV is
  `syn/reports/ooc_xc7z020clg400_1_20261004_200739/summary_all.csv`.

## 2026-10-04 15:50 +08:00 - Correct four-GT parent reset crossings and rerun integration

- Changed `rtl/axis/dsm_xpm_async_fifo.sv`,
  `rtl/axis/dsm_axis14_to_core8_cdc.sv`, and
  `fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv`: each XPM handshake is
  gated by its local reset, while the common FIFO reset still spans both
  domains; GT health is synchronized and stable-qualified before releasing
  source/core reset. Added explicit asynchronous AXI/free-run/GT clock
  groups in `syn/run_thermo5_qsfp_gt14_parent.tcl`. No sample arithmetic,
  coefficients, bit order or golden vectors changed.
- The first routed parent had WNS -1.336 ns, WHS +0.006 ns; read-only
  asynchronous-clock re-timing showed WNS +0.293 ns, WHS -0.011 ns. Its CDC
  report motivated the reset-control changes. Checks after the edits:
  generated-GT XSim PASS (32 AXI beats / 56 four-plane words), XPM full-chain
  bit-true PASS, continuous-boundary XSim PASS including link loss, P0 7/7
  PASS and IP smoke PASS. The GT simulation launcher now checks the PASS
  marker after Vivado exits because `simulate.log` is buffered in-process.
- The corrected run `runs/thermo5_qsfp_parent_20261004_141521/` has a
  synthesized checkpoint with a 4.571-ns GT user clock and four GTH
  channels; place/route is ongoing. No corrected routed WNS/WHS, final CDC
  disposition, physical lane phase alignment, programmed 125-MHz board
  reference, PA blanking calibration or RF output is claimed yet.

## 2026-10-03 23:15 +08:00 - Integrate frozen thermo5 with continuous four-GTH TX boundary

- Added the 14.000-Gb/s/125-MHz four-channel GT Wizard parent and its
  package-clock/pin constraints, a continuously consumed raw64 four-plane
  boundary, directed XSim tests, and reproducible GT simulation/OOC scripts.
  The boundary uses idle `0xAAAA...` words with `pa_enable=0`, detects
  partial plane-valid, mid-frame gaps, partial-frame stop and stopped
  residual payload, and permits idle only between 56-word superframes.
  Added `ASYNC_REG` to the existing two-flop reset synchronizer; no
  arithmetic, quantization, bit order, or golden vector was changed.
- Checks: continuous-boundary XSim PASS, including a complete-frame clean
  stop; generated-GT parent XSim PASS with 32 AXI beats/56 four-plane words,
  post-frame idle, clean stop, and common-reset recovery. P0 XSim 7/7 PASS;
  IP smoke PASS. `git diff --check` has no whitespace errors. A parent route
  attempt is still running; a previous attempt stopped during netlist
  optimization after Vivado reported loss of its `vivado` license feature.
- Remaining: no routed parent WNS/WHS, CDC/RDC disposition, full board I/O
  timing budgets, deterministic four-lane serial phase alignment, calibrated
  PA blanking, verified SI5341 125-MHz reference, or hardware/RF output.
  Generated GT IP and behavioral XSim are not physical output signoff.

## 2026-10-03 - Separate digital GT contract from board clock validation

- Changed `docs/exec-plans/active/execution-frontier.md` and
  `docs/verification/thermo5-integration-cdc-contract.md` to make the ideal
  125-MHz GT reference clock an explicit digital integration assumption.
  This unblocks digital verification planning without silently claiming a
  programmed SI5341 or measured 14.000-Gb/s board output.
- Checks: reviewed the existing four-lane GT Wizard feasibility probe and
  frozen thermo5 clock/reset contract. Re-ran
  `dv/verif/scripts/run_xsim_tid32_thermo5_serdes_loopback.ps1`: PASS, 64
  input words and 4,096 serial bits on each of four planes. Changed only the
  testbench coefficient declaration from 64 to 16 bits (the DUT port width
  for DPD1) to remove an XSim width warning; the identity value is unchanged.
  No transmitter RTL, MATLAB model or timing constraints changed.
- Remaining: parent CDC/RDC and routed STA; SI5341 configuration, power
  repair and physical output measurement are board-level gates.

## 2026-10-03 20:00 +08:00 - Audit four-lane QSFP parent feasibility

- Added read-only Vivado package-pin and GT Wizard feasibility probes;
  generated projects/logs are isolated under `runs/`. Updated the four-PA
  serializer contract, integration CDC contract and execution frontier.
  No transmitter RTL, bit-true arithmetic or frozen clock target changed.
- Checks: target `xczu15eg-ffvb1156-2-i` package audit confirms four QSFP
  TX/RX lanes at `GTHE4_CHANNEL_X0Y4..X0Y7` and bank-128 common refclk;
  schematic pages 8/19/25 show the connector and 156.25-MHz source.
  Four-channel GT Wizard rejects 14.0 Gb/s / 156.25 MHz, but generates
  14.0625 / 156.25 and 14.0 / 125 MHz configurations. IP generation is
  not synthesis, route or STA.
- Remaining: no verified 125-MHz SI5341 bank-128 output configuration or
  powered board. The exact-14.0-Gb/s parent, coordinated resets, CDC/RDC,
  constraints and routed STA cannot yet be signed off. Do not substitute
  14.0625 Gb/s without a new architecture decision.

## 2026-10-03 15:39 +08:00 - Recompile and merge thermo5 boundary coverage

- Changed `dv/uvm/sim/Makefile` to accept an explicit extra VDB in the
  thermo5 URG merge and refined `tools/hw/thermo5_audit_reports.py` so the
  remaining interpolation stage-1 bin stays open. Updated coverage/frontier
  documents. No DUT RTL, arithmetic, or latency changed.
- Checks: licensed generic and real-XPM seven-case VCS UVM regressions PASS;
  independent extreme seed 404 passes 32 source beats/56 words on all four
  planes in both configurations; both eight-VDB URG merges PASS. Generic
  overall/condition/toggle 87.20/79.79/84.20%, 69/216 condition bins unhit;
  XPM 80.16/69.68/81.56%, 74/228 unhit (vendor hierarchy included).
  Full-chain extreme 576/1,008 XSim passes generic/XPM with 16 DPD lane
  counters checked; exhaustive DPD1 VCS/XSim, two-tap interval proof,
  interpolator block reset/stall XSim, MATLAB P0 7/7, GT BERT and ideal
  serializer loopback pass. Generated reports remain in `runs/`.
- Remaining: one additional interpolation stage-1-empty condition, full-chain
  reset-with-enable, other per-instance condition/branch/toggle gaps, parent
  run-request/reset CDC/RDC, physical GT/board/RF verification. The board
  power fault is unresolved; no hardware output is claimed.

## 2026-10-03 15:19 +08:00 - Close directed thermo5 boundary stimuli; retain licensing/signoff gates

- Changed `dv/uvm/tests/thermo5/thermo5_sku_corner_tests.svh` to require both
  empty/backpressured interpolation states after legal AXI bubble/PA-stall
  phasing. Added a reproducible phase probe, exhaustive DPD1 RTL testbench,
  independent 16-bit arithmetic and two-tap interval checkers, an optional
  `extreme` MATLAB vector profile, XSim boundary runners, and corrected
  migrated GT/serializer runner paths. The ideal serializer test now uses
  frozen 2-tap/DPD1 rather than a default 4-tap frontend. DUT RTL unchanged.
- Checks: existing generic/XPM `simv` seed-2 targeted runs PASS and count
  empty/backpressured states 13/39 and 42/14, respectively; both extreme
  payload runs PASS 32/56 four-plane bit-true. XSim actual DPD1 pipeline
  exhausts 196,608 accepted/output complex samples with zero saturation;
  interpolator reset/bubble, GT BERT, and frozen four-plane ideal serializer
  loopback XSim PASS. MATLAB P0 7/7 and two arithmetic checkers PASS.
  Generated evidence stays under `runs/`.
- Remaining: the new DPD VCS compile attempt failed because no license
  environment was configured, so the changed UVM source was not recompiled;
  URG merge failed with `URG-NLC` missing coverage key. No new
  merged score or fresh instance/bin hit list is claimed. DPD counter bits
  above bit 17, TID toggle closure, full-chain reset/release bins, parent
  CDC/RDC/STA and physical four-lane GTH/board output remain open.

## 2026-10-03 - Exercise full-chain bubbles and independent payloads

- Changed thermo5 UVM source items/sequence/driver to insert legal AXI valid
  gaps, added observation-only interpolator/DPD backpressure probes and a
  seventh directed full-chain test, and made PA stall percentage configurable.
  Updated the UVM Makefile, MATLAB-vector launcher output selection, and
  added `dv/uvm/sim/run_thermo5_payload_matrix.sh`. No DUT RTL, golden model,
  fixed-point behavior, or interface changed.
- Checks: generic and real-XPM seven-case VCS regressions PASS with zero UVM
  errors/fatals (expected negative illegal-frame assertion); both final URG
  merges PASS sequentially. Generic total/condition 86.97%/78.72%, XPM
  80.14%/69.83% including vendor hierarchy. The targeted probes hit valid
  pipeline holds at i1 stage 0/1, i2 stage 1, both outputs, plus existing
  empty-blocked bubbles; two additional empty/backpressure condition probes
  remained at zero and were left open. MATLAB R2025a generated
  independent payloads 101/202/303; all six generic/XPM payload simulations
  PASS 32 AXI beats/56 four-plane bit-true words. Python audit parser and
  shell syntax checks pass; output and SHA-256 manifests remain under `runs/`.
- Remaining: 70 generic condition bins, 248 toggle gap rows, and 20 branch
  gap rows still need full-chain tests or exact proof; see the per-instance
  coverage CSV and `docs/verification/thermo5-uvm-coverage.md`. Parent-level
  request/reset CDC/RDC and GT boundary are not signed off.

## 2026-10-03 - Define thermo5 integration timing contract and inventory CDC/URG bins

- Added `syn/thermo5_integration_contract.tcl`,
  `tools/hw/thermo5_audit_reports.py`, and
  `docs/verification/thermo5-integration-cdc-contract.md`; updated the
  coverage record and execution frontier. No RTL, MATLAB, or golden vectors
  changed. The Tcl requires explicit parent I/O budgets and does not waive
  `run_request` or either reset.
- Reparsed the archived routed Vivado CDC report into 46,427 exact paths:
  four clock-to-clock XPM synchronizer paths and 46,423 OOC input-port-clock
  paths. Reparsed generic-FIFO URG into 216 condition bins in 30 DUT
  instances, with 88 uncovered, plus toggle-signal and branch-instance
  inventories. Generated CSV is under `runs/`, not committed.
- Checks: parser completed and counts match the Vivado CDC summary; Tcl
  contract syntax/control flow ran under `tclsh` with mock Vivado commands;
  Python syntax and `git diff --check` checked. No new place/route, UVM simulation,
  parent-level STA, SpyGlass CDC/RDC, or URG merge was run. CDC/RDC and code
  coverage signoff remain open, especially reset release, core-synchronous
  request integration, and full-chain reachable bins.

## 2026-10-03 09:19 +08:00 - Run frozen thermo5 UVM with real XPM and audit routed CDC

- Changed `dv/uvm/tb/thermo5_sku_uvm_tb.sv` and `dv/uvm/sim/Makefile` to
  select generic or vendor XPM FIFO at compile time, with separate run and
  coverage databases; MATLAB vectors and RTL numerical behavior are unchanged.
  Added `syn/report_thermo5_cdc.tcl` and updated UVM simulation/status docs.
- Checks: VCS V-2023.12-SP1 compiled Vivado 2024.1 XPM sources; six-case
  XPM UVM regression PASS, zero UVM errors/fatals (illegal-frame assertion
  intentionally expected); XPM URG merge PASS with 100% functional groups
  and 80.60% overall including vendor internals. The generic-FIFO six-case
  regression also reran PASS. XSim vendor-XPM seed 10 PASS: 32 input beats,
  56 four-plane bit-true words, 14 PA stalls.
- Vivado 2024.1 opened the frozen `thermo5_i2_d1_a1` routed checkpoint and
  produced CDC/clock-interaction/timing reports. Internal timing remains
  WNS/WHS +0.316/+0.027 ns. Real source/core clock-pair crossings include
  XPM Gray-pointer/reset synchronizers, but raw OOC `report_cdc` also emits
  24,512 CDC-1, 2,578 CDC-13, and 32 CDC-7 critical findings, dominated by
  unclocked reset/control interface paths. No blanket waiver or CDC/RDC
  signoff is claimed. The report notes 565 input and 264 output ports without
  delay constraints; integration-level interface assumptions remain open.
- Re-read URG source-level red lines and documented configuration-excluded
  versus still-open categories in `docs/verification/thermo5-uvm-coverage.md`.
  Per-instance condition/branch/toggle closure and SpyGlass lint/CDC/RDC
  remain to be done; XPM's overall URG score is not compared numerically
  against the generic-FIFO score because vendor internals are included.

## 2026-10-01 20:31 +08:00 - Separate UVM DUT targets and repair migrated vector paths

- Moved 47 unchanged UVM class/package files into target-specific
  `env/{axi_ip,thermo5}`, `sequences/{axi_ip,thermo5}`, and
  `tests/{axi_ip,thermo5}` directories. Reusable interface agents, formal
  files, Python model logic, and both testbench tops remain at their existing
  canonical homes. Updated both VCS filelists and role READMEs. Added
  `docs/verification/thermo5-uvm-architecture.md` with the DUT port, RTL
  hierarchy, MATLAB reference, and UVM ownership contract.
- Corrected post-migration `uvm_verif` references in the Python vector
  generator/regression controller, XSim/board helper paths, and MATLAB
  export/compare paths. The seven files accidentally generated under
  `dv/uvm_verif/` were SHA-256 identical to the canonical vectors and were
  moved, not deleted, to `runs/uvm_legacy_generated_duplicate_20261001/`.
- Checks: licensed thermo5 six-case VCS regression PASS, URG merge PASS
  (overall 86.59%), AXI-IP VCS compile plus `dsm_bp_test` PASS, corrected
  one-case Python regression PASS, regenerated Python vectors identical to
  archived copies, Python refmodel unit tests 8/8 PASS from their documented
  working directory, MATLAB P0 7/7 PASS, `git diff --check` no whitespace error.
  A targeted before/after `dv/uvm` inventory found all 47 moved source files
  unchanged and no missing source artifact; modified manifests/docs/scripts
  are intentional. No RTL arithmetic, fixed-point behavior, or UVM checker
  semantics were changed.
- Limits: the repository-wide legacy migration-map verifier cannot validate
  wildcard/historical entries against the target-scoped snapshots; this is
  not a full repository-migration signoff. The corrected older XSim/board
  helper scripts were path-checked but not all individually rerun. XPM FIFO
  UVM, physical GT/PA, and uncovered configuration modes remain outside this
  layout change.

## 2026-10-01 16:23 +08:00 - Target reachable thermo5 coverage leads

- Added independent 2-tap vector interpolator and one-tap programmable-DPD
  directed VCS tests plus a reproducible coverage runner under
  `dv/verif/block/`. Interpolator test covers a blocked output behind an empty
  stage-2 slot, reset with enable high, and checked 12-word half-sample data.
  DPD test covers empty-pipeline backpressure, positive/negative I/Q
  saturation, ordered six-word output, counts, and stalls.
- Checks: licensed VCS simulation PASS for both tests; separate URG reports
  confirm the named line-70, line-140 and valid-output I/Q saturation rows.
  Frozen thermo5 `thermo5_sku_bittrue_test` seed 1 with PA stalls reran PASS
  (32 source beats, 56 four-plane words, zero UVM errors/fatals).
  No RTL or MATLAB source changed. Fixed-SKU thermo5 UVM code coverage remains
  86.59%; block VDBs were not merged into it.
- Limits: low-power-off and identity/DPD1 configuration pins are statically
  fixed in the UVM top, not bulk-waived. DPD invalid-slot saturation and other
  unreviewed URG holes remain open. XPM, GT and RF hardware are outside these
  block-level tests.

## 2026-10-01 16:06 +08:00 - Refactor thermo5 UVM ownership and extend verification

- Added the thermo5 source item, sequencer, monitor, and active agent under
  `dv/uvm/agent/axis/`; moved vector generation into
  `dv/uvm/sequences/thermo5_source_sequence.svh`. Added a SKU configuration
  and control BFM under `dv/uvm/env/`. The scoreboard now receives source
  and four-plane monitor transactions and resets its own index per reset
  epoch. Tests no longer write DUT pins or scoreboard state. Updated the UVM
  package/filelist, Makefile, READMEs, and coverage map.
- Added an XPM-model option to the existing full-chain thermo5 XSim testbench
  and launcher. No DUT RTL, fixed-point arithmetic, MATLAB vector, or PA
  comparison result was changed.
- Checks: licensed VCS six-case thermo5 regression PASS; URG merge PASS
  (functional groups 100%, overall 86.59%, CDC FSM 7/7 states and 12/12
  transitions); 20 additional VCS simulations across seeds 11-20 PASS;
  full-chain vendor-XPM XSim with PA stalls seeds 7/8/9 PASS; generic FIFO
  full-chain XSim seed 1 PASS. Old AXI-IP `make vcs` and `dsm_bp_test` PASS
  with zero UVM errors/fatals. `git diff --check` reports no whitespace errors.
- Remaining: VCS UVM still uses generic FIFO; XPM has directed full-chain
  XSim evidence but no UVM coverage. Condition/branch/toggle holes are not
  waived or closed, physical GT/PA and hardware are outside this result.

## 2026-10-01 13:46 +08:00 - Organize UVM targets and restore AXI-IP compilation

- Moved 14 AXI-IP virtual-sequence files from `dv/uvm/env/` to
  `dv/uvm/sequences/`, and restored one stranded long-run sequence plus two
  bit-true tests from `dv/verif/uvm/` to the canonical UVM tree. Updated
  `dv/uvm/sim/uvm_filelist.f`, role READMEs, and the physical migration map.
  The moved files are Git R100 renames; no DUT RTL or numerical behavior changed.
- Reason: distinguish the old AXI-IP target from thermo5 and remove misplaced
  sequence/test files from the environment and directed-DV trees.
- Checks: both source filelists and all legacy package includes resolve;
  licensed VCS `thermo5-vcs-regression` passes six cases; `make vcs PYTHON=python3`
  compiles the AXI-IP target; `dsm_bp_test` passes with zero UVM errors/fatals.
  `git diff --check` reports no whitespace errors.
- Limits: full old AXI-IP regression was not rerun; thermo5 source and PA
  components are not yet full `uvm_agent` wrappers; generic-FIFO UVM does not
  cover XPM FIFO or physical GT behavior.

## 2026-10-01 12:14 +08:00 - Licensed thermo5 UVM regression and coverage

- The running local Synopsys license service was discovered without recording
  its path, key, or address in the repository. VCS V-2023.12-SP1 compiled the
  frozen thermo5/2-tap/DPD1 UVM testbench after a scoreboard portability fix:
  `$readmemh` now loads each plane through a one-dimensional memory.
- Clarified the finite-stream contract: downstream drain may set sticky CDC
  underflow after all 32 source beats have arrived; normal tests reject only
  earlier starvation. The reset test now interrupts after 24 source beats and
  proves a clean 32-beat/56-word replay without early underflow.
- `make -C dv/uvm/sim thermo5-vcs-regression` passed six tests (positive
  bit-true/PA stalls, FIFO full, FIFO empty, reset/replay, and expected
  illegal-frame assertion, plus reset sweep at residuals 2/4/6/10/12).
  Positive tests report zero UVM errors/fatals;
  the negative test observed the precise RTL assertion and sticky error.
- Fixed URG merge to include the compiled design VDB and fail on error text
  even when URG exits zero. The six-test merge passes: functional groups
  100%, overall 87.30%, DUT hierarchy 86.76%, CDC FSM 100%. Reports are under
  `runs/uvm_thermo5_i2_d1/coverage/`.
- Remaining: triage unhit RTL condition/branch/toggle bins and distinguish intentional
  configuration exclusions from missing stimulus; XPM FIFO UVM and physical
  GT/board checks are not covered by this generic-FIFO UVM regression.

## 2026-10-01 00:40 +08:00 - Add thermo5 UVM corner and coverage regression

- Extended the existing thermo5 UVM source driver, monitor, scoreboard, test
  package, and Makefile with FIFO full/backpressure, FIFO empty/underflow,
  midstream reset/replay, illegal-frame negative assertion, functional event
  coverage, VCS code coverage, and a guarded URG merge target. DUT RTL and
  MATLAB numerical behavior were not changed.
- Checks: `xvlog -sv -L uvm` parsed the complete updated thermo5 filelist;
  the directed full-chain XSim with seed-2 PA stalls passed 32 source beats
  and 56 four-plane words; Makefile regression dry-run resolved all targets;
  `git diff --check` passed. VCS V-2023.12-SP1 was retried on Rocky Linux but
  stopped before HDL parsing with `Cannot find license file`. No UVM runtime
  or coverage PASS is claimed. The repository login wrapper was also tried;
  it selected a `VCS_HOME` directory missing `vcs1`, so it likewise never
  reached HDL parsing.
- Remaining: obtain an authorized licensed shell, run the five-case UVM suite,
  review any errors and URG coverage, then close uncovered bins.

## 2026-09-30 21:15 +08:00 - Integrate thermo5 UVM into canonical tree

- Moved the new thermo5 UVM top, filelist, and MATLAB vector launcher from a
  parallel `dv/uvm/thermo5_sku/` subtree into the existing `agent/`, `env/`,
  `tests/`, `tb/`, and `sim/` roles. The original monolithic top was split
  into interface, driver, monitor, scoreboard, environment, test, and DUT top.
  Removed the redundant local Makefile/README; the existing UVM Makefile now
  has `thermo5-vcs` and `thermo5-vcs-run` targets. The older AXI-IP UVM target
  remains intact because it instantiates a different DUT.
- The post-stall-fix ZU15EG route produced WNS +0.346 ns, WHS +0.026 ns,
  39,512 LUT, 50,181 FF, 6.5 BRAM, and 496 DSP. Its Tcl exited nonzero after
  writing routed timing/resource reports due to an escaped-quote error in the
  power-provenance line; fixed that line. A clean end-to-end rerun remains due.
- Post-move checks: thermo5 filelist paths resolve; both old and new Make
  targets produce correct VCS commands in dry-run; `xvlog -sv -L uvm` parses
  the split RTL/UVM source; the relocated MATLAB launcher regenerates 32
  source beats/56 core words; directed full-chain XSim with seed-2 randomized
  PA stalls passes. `git diff --check` passes. The prior VCS license and
  Windows UVM DPI blockers remain unchanged, so UVM simulation is not PASS.

## 2026-09-30 20:16 +08:00 - Begin frozen thermo5 subsystem UVM

- Added `dv/uvm/thermo5_sku/` with an isolated two-clock UVM source driver,
  four-plane monitor, MATLAB-vector scoreboard, ready-stall checks, and a VCS
  filelist/Makefile. The old UVM top continues to target a different AXI IP.
- Extended `gen_tid32_thermo5_frontend_bittrue_vectors.m` with optional legal
  frame-start positions while preserving its existing defaults. Generated
  448 complex samples, 32 packed 14-lane AXI beats, and 56 four-plane output
  references with frame starts at core words 1, 15, and 36.
- Checks: MATLAB P0 7/7 PASS with 65,536 samples and zero mismatches each;
  frozen thermo5/2-tap/DPD1 frontend XSim PASS for 64 words / 2,048 samples;
  `git diff --check` PASS. Vivado xvlog parsed the UVM and RTL source. XSim
  elaboration failed while linking UVM DPI symbols, so the new UVM test has
  no simulation PASS yet. Rocky WSL VCS V-2023.12-SP1 was also attempted;
  compilation stopped before HDL parsing because no license file was
  configured. A licensed VCS run and coverage are next.
- The UVM smoke uses the generic asynchronous FIFO for simulator portability;
  XPM FIFO behavior remains separately covered by directed XSim. Full reset,
  drain/burst, negative-protocol, and coverage closure remain open.
- A new directed full-axis test exposed output corruption when the four PA
  planes stalled. `tid32_cartesian_fs4_gt_tx.sv` now holds its payload, valid,
  and recursive state when the raw-word boundary cannot advance. The CDC's
  simulation-only stability assertion now checks the cycle after a stall.
  Both continuous-ready and randomized-stall 32-beat/56-word MATLAB-to-XSim
  four-plane comparisons pass; three stall seeds exercised 8/35/20 stalled
  cycles. Required post-RTL checks: P0 XSim 7/7 PASS and
  IP smoke 5/5 PASS; frozen core XSim PASS. The first OOC retry stopped in a
  known Vivado realtime-helper crash before HDL synthesis. A fresh full route
  is running under `runs/uvm_thermo5_i2_d1/ooc_stallfix_retry1/`; routed STA
  for the revised RTL is not yet signed off.

## 2026-09-29 - 18-SKU routed OOC matrix closure and UVM target freeze

- Completed all 18 independent ZU15EG full OOC implementations spanning
  thermo3/thermo5, 2/3/4-tap interpolation, and 1/2/4-tap compile-time
  identity memory-DPD wrappers. Every row passes 218.75-MHz setup and hold.
- The 250-MHz, three-seed, fair-RMS numerical gate selects thermo5 with
  two-tap interpolation. The DPD1 identity-wrapper SKU is frozen because it
  passes with zero raw-word mismatches and the best qualified PPA:
  WNS/WHS +0.316/+0.027 ns, 39,512 LUT, 50,181 FF, 6.5 BRAM, and 496 DSP.
- Evidence: `runs/thermo_sku_matrix/ooc_20260927_111823/` and
  `runs/thermo_sku_matrix/algorithm_full_20260927_111823/`.
- Next action: implement and regress UVM on this frozen SKU, then obtain
  formal lint/CDC/RDC and mapped 28-nm DC reports before making any ASIC or
  static-signoff claim.

## 2026-09-26 - Read-only FPGA JTAG discovery

- Vivado 2024.1 Hardware Manager connected to local `hw_server` at
  `127.0.0.1:3121` and enumerated target
  `xilinx_tcf/Xilinx/15051A`.
- Opening the target reported no JTAG devices. The host-to-cable path is
  present, but the powered FPGA/JTAG chain is not detectable; no FPGA part,
  bitstream status, ILA core, GT link, or board validation conclusion exists.
- The probe used `fpga/zu15eg/scripts/vivado_list_hw_targets.tcl`; it did not
  program, reset, or otherwise change board state. Log:
  `runs/hw_scan_20260926_234032/vivado_hw_scan.log`.

## 2026-09-26 - Matched-SAIF low-power A/B closure

- Fixed the XSim launcher to use native `xelab -log`/`xsim -log`, fixed
  Windows generic/testplusarg handling with fixed top wrappers, normalized
  escaped SAIF hierarchy, and connected the real `run_request`/ingress
  strategy through the LP controller and CDC boundary.
- Added state-hold behavior for LP burst/idle gaps so recursive gain and
  interpolation history is preserved while invalid pipeline activity is
  stopped. Baseline and LP remain bit-true equivalent.
- Thermo3 and thermo5 each passed continuous, burst, and long-idle activity
  simulations with matching accepted words, output words, digest, and cycle
  count. Fresh routed baseline and LP DCPs both pass 218.75 MHz setup/hold.
- Thermo3 matched-SAIF dynamic reduction: 1.14% continuous, 5.45% burst,
  4.01% idle. Thermo5: 1.76% continuous, 6.02% burst, 4.63% idle.
- Thermo5 timing: baseline `WNS/WHS=+0.089/+0.023 ns`; LP
  `+0.139/+0.017 ns`. SAIF direct net matching is 7% for all workloads with
  zero baseline/LP coverage delta. Vivado FPGA power confidence is Medium
  (RTL-SAIF direct match plus Vivado propagation); this is not ASIC or silicon
  signoff.
- Artifacts: `runs/lp_power_ab/20260926_121341_thermo3/` and
  `runs/lp_power_ab/20260926_152500_thermo5/`, including
  `power_comparison.csv`, routed DCPs, timing logs, and per-workload reports.

## 2026-09-22 - ASIC tool/library environment audit

- Rocky-8.10 WSL contains Synopsys DC V-2023.12-SP1 at
  `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`; `dc_shell -version` runs.
- No usable 28nm standard-cell `.db` was found in the available WSL/project
  paths, and the earlier `/tmp/lumen28/std_ss.db` path is absent.  The DSM
  ASIC flow remains blocked until a licensed, readable 28nm mapping library
  with matching max/min corners is supplied.

## 2026-09-23 - Rocky TSMC28 standard-cell probe confirmation

- The active Rocky terminal successfully ran the DSM standard-cell probe with
  the TSMC28 RVT TT library.  DC loaded the library and reported 839 cells
  with 15 inverter-name matches; this is valid mapping-library evidence.
- The previously referenced SRAM macro `.db` under
  `/home/ray/ic/CIMForge/syn/out/pdk_cache/` was not found.  Full macro-aware
  synthesis remains blocked; standard-cell-only synthesis can proceed now.

## 2026-09-21 23:58 SGT - Thermo5 routed closure and CDC/serializer verification

- Completed the thermo5 full AXI/FIFO/frontend routed OOC on
  `xczu15eg-ffvb1156-2-i` at 125/218.75 MHz.  The full
  `opt_design -> place_design -> phys_opt_design -> route_design` flow passed
  with WNS/WHS `+0.308/+0.027 ns`, TNS/THS `0/0`, zero errors, and zero
  critical warnings.  Utilization is 71,869 total LUTs, 97,249 registers, 6.5
  BRAM tiles, and 2,032 DSP48E2.
- Froze the thermo3/thermo5 routed PPA, timing, pipeline-depth, and fanout
  comparison in `docs/THERMO3_THERMO5_ROUTED_PPA.md`.  Relative to thermo3,
  thermo5 adds 11,948 total LUTs, 13,452 registers, and 2 DSPs.  Both now have
  the same fixed core pipeline depth and positive 218.75 MHz timing margin.
- Added simulation-only assertions for reset release, generic-FIFO Gray-pointer
  transitions, prohibited full/empty transactions, legal gearbox residual
  counts, frame-boundary alignment, and stable backpressured output.  The CDC
  test now explicitly requires four accepted source words before core enable
  and rejects any pre-enable core output.  Generic and XPM CDC tests both pass.
- Fixed the thermo5 serializer-loopback file list to include the frontend's
  elastic-buffer dependency.  The four-path ideal behavioral serializer test
  passes 64 recovered words / 4,096 bits per path against MATLAB golden data.
  This is not a GT primitive, electrical channel, BERT, or board result.
- Required checks after the RTL/assertion changes: project P0 XSim `7/7` PASS;
  IP smoke PASS; generic CDC XSim PASS; XPM CDC XSim PASS.  The thermo5 full
  routed OOC and four-path behavioral serializer loopback also PASS.
- Added `docs/GT_VERIFICATION_WITHOUT_HARDWARE.md` to separate simulation and
  implementation evidence from measurements that require physical hardware.

## 2026-09-22 - Vendor-neutral raw-link PRBS31/BERT endpoint

- Added `rtl/gt/gt_link_bringup_bist.sv`, a synthesizable 64-bit user-word
  endpoint above the physical GT.  It provides known-word training, PRBS31
  generator/checker, ready filtering, link/reset FSM, sticky error and error
  counters, clear/retrain recovery, and deterministic error injection.
- Added executable protocol assertions for TX valid/ready state ownership,
  link-up versus enable, and error-counter/sticky-status consistency.
- Added `dv/verif/block/gt/tb_gt_link_bringup_bist.sv` and
  `dv/verif/scripts/run_xsim_gt_link_bringup_bist.ps1`.  XSim passes the clean
  PRBS31 loopback, injected-error detection, sticky status, clear/retrain, and
  known-word recovery sequence:
  `GT_LINK_BRINGUP_BIST_PASS prbs_words=49 errors_detected=0`.
- The endpoint is vendor-neutral and attaches to the existing 64-bit raw user
  boundary.  This evidence does not claim GTH PLL/CDR lock, electrical BER,
  eye/jitter, package/channel behavior, or board loopback.

## 2026-09-22 - ZU15EG GT Wizard generation probe

- Ran `fpga/zu15eg/scripts/generate_ti64_raw_gt14_ip.tcl` with Vivado 2024.1
  for part `xczu15eg-ffvb1156-2-i`.  The generated configuration is GTH
  `X1Y12`, TX/RX 14.0 Gb/s, 125 MHz refclk, 64-bit RAW user data, and both
  synthesis and simulation targets.  Vivado accepted the IP and wrote the XCI
  and generated HDL under `tmp/gt_wizard_probe_20260922/` outside the source
  RTL tree.
- This is an IP-generation/configuration PASS only.  Vendor behavioral GT
  simulation, package-constrained implementation, PLL/CDR lock, physical
  loopback, BER/BERT, eye, and jitter remain separate gates.
  Changed source/check files are `rtl/axis/dsm_reset_sync.sv`,
  `rtl/axis/dsm_async_fifo.sv`, `rtl/axis/dsm_axis14_to_core8_cdc.sv`,
  `dv/verif/block/axis/tb_dsm_axis14_to_core8_cdc.sv`, and
  `dv/verif/scripts/run_xsim_tid32_thermo5_serdes_loopback.ps1`.

## 2026-09-21 - Refresh active execution frontier

- Replaced the stale and partially encoded active execution frontier with a concise English source of truth. It records the passing full thermo3 OOC, the active AXI/FIFO/identity-DPD architecture, checked functional evidence, RF-model limits, and the thermo5/CDC/low-power/PPA next steps.
- No RTL, algorithm, constraints, or generated implementation artifact changed in this documentation-only update.

## 2026-09-21 - Close full thermo3 AXI/FIFO/frontend routed OOC

- Completed the full timing-driven implementation of `tid32_thermo3_axis_frontend_tx_ooc` on `xczu15eg-ffvb1156-2-i` at the unchanged 218.75 MHz core clock and 125 MHz AXI clock.  The result is `PASS`: WNS `+0.290 ns`, WHS `+0.027 ns`, TNS/THS zero, 0 errors, and 0 critical warnings.  This used `opt_design -> place_design -> phys_opt_design -> route_design`, not the earlier Quick diagnostic flow.
- The final core clock has 208,286 setup and hold endpoints with no failures; the AXI clock has 145 setup/hold endpoints with WNS/WHS `+4.966/+0.047 ns`.  Post-route utilization is 59,921 LUT (17.56%), 83,797 registers (12.28%), 6.5 BRAM tiles (0.87%), and 2,030 DSPs (57.54%).
- The word-atomic pre/post-DPD elastic slices remain functionally covered by targeted thermo3/thermo5 bit-true XSim (64 words / 2,048 output complex samples, zero mismatch), project P0 7/7, and IP smoke 5/5.  The full passing OOC is fabric-only: it does not prove GTH target timing, physical serializer/PA paths, board loopback, or RF performance.
- Remaining warnings include OOC `HD.CLK_SRC`/`HD.PARTPIN_LOCS` estimation warnings and synthesis trimming messages.  They are non-critical in this OOC run, but actual board/GT integration must supply real clock and boundary constraints.  Next action: run the equivalent full thermo5 OOC rather than extrapolating from thermo3.

## 2026-09-21 - Runtime identity-DPD input route isolation

- The last complete thermo3 AXI/FIFO/frontend routed OOC (`20260920_230344`) is `FAIL_SETUP`: WNS `-1.524 ns`, WHS `-0.019 ns`, with 0 errors and 0 critical warnings.  The limiting path is an inter-module route from first-x2 output to a memory-DPD DSP input: `5.809 ns`, of which `5.732 ns` is routing (fanout 173).  It is not a DSP arithmetic path.
- Added a word-atomic elastic buffer before the 16-lane runtime identity memory-DPD; the existing post-DPD buffer is retained.  The change preserves all fixed-point data and DPD-history semantics and adds only fixed latency.  Fresh targeted thermo3/thermo5 XSim both pass 64 words / 2,048 complex output samples with zero mismatch (940 ns / 970 ns respectively).  Required P0 runs 7/7 and the five IP-smoke tests complete without errors.
- Vivado 2024.1 then reproduced two optional realtime-helper failures while opening vendor `unimacro_vhdl.tcl` and `unimacro_verilog.tcl`; both files exist and are SHA-256 readable.  Updated the OOC Tcl to unset `BUILTIN_SYNTH` before `synth_design`, disabling only the helper pre-spawn path while retaining normal synth/place/route/STA.  A new thermo3 routed OOC is in progress; no new WNS/WHS is claimed until its `summary.csv` exists.
- The rerun completed routed implementation with 0 errors and 0 critical warnings but remains `FAIL_SETUP`: WNS `-1.392 ns`, WHS `-0.019 ns`.  The input elastic buffer is preserved in the netlist, but the worst setup path is still its packed-data register to a memory-DPD DSP input (`5.656 ns`, `5.578 ns` routing, fanout 173).  This is a `+0.132 ns` setup improvement over the preceding `-1.524 ns`, not closure.  Vivado reports that timing-driven physical synthesis was skipped in the current `place_design -directive Quick` flow; a full timing-driven implementation is required for a fair comparison to the earlier single-clock passing OOC.
- Added explicit `quick|full` implementation selection to the OOC scripts.  The `full` mode retains the same RTL and clock targets but runs `opt_design -> place_design -> phys_opt_design -> route_design`.  A direct environment-variable workaround did not reliably suppress Vivado's internal helper; the OOC Tcl now restores the vendor realtime database and explicitly sets `enableParallelHelperSpawn=false`.  The resulting full thermo3 run passes the previous helper-startup point and is in synthesis; no full-flow WNS/WHS is available yet.

## 2026-09-20 - OOC rerun helper failure

- The first routed-OOC retry after adding the accumulation stage did not reach HDL elaboration or STA: Vivado 2024.1 failed during `synth_design` because its realtime helper reported `retarget_vhdl.tcl` unreadable.  The referenced vendor file exists at the reported path; this is an intermittent tool/helper failure rather than RTL, DRC, or timing evidence.
- Retried the identical isolated thermo3 OOC in a new Vivado process.  The prior valid routed result remains WNS `-0.397 ns`, WHS `+0.001 ns`; no substitute timing conclusion is made from the failed retry.
- A second fresh process repeated a missing helper-Tcl error; a third passed helper startup and RTL component statistics but terminated with `EXCEPTION_BREAKPOINT` before placement.  Vendor Tcl files were independently verified present and hash-readable, and no stale Vivado process or memory exhaustion was found.  Further timing closure is blocked on a stable Vivado execution, not a reproducible RTL failure.

## 2026-09-20 - Pipeline second-interpolator accumulation

- The routed thermo3 OOC after removing the DSP clock-enable fanout completed with WNS `-0.397 ns` and WHS `+0.001 ns`.  Setup is improved by `+1.598 ns` over the preceding run and hold is now closed, but the design remains `FAIL_SETUP`.
- The worst path is now arithmetic-only: second-x2-interpolator DSP product register through four-term ACC_W addition and signed round/saturate to an output register (`4.918 ns`, 12 logic levels).  The former valid/CE route is no longer the limiting path.
- Added a third elastic stage between accumulation and round/saturate.  Its accumulator uses the exact legacy ACC_W procedural sum; valid remains word-atomic and datapath writes stay unconditional for invalid slots.  Thus the change adds one fixed core cycle only.
- Thermo3/thermo5 bit-true XSim pass after the change (64 words / 2,048 output complex samples).  Project P0 completes 7/7 PASS and IP smoke completes 5/5 PASS.  A new complete thermo3 routed OOC is running at the unchanged 218.75 MHz target.

## 2026-09-20 - Remove second-interpolator valid clock-enable fanout

- The third full thermo3 routed OOC completed at WNS `-1.995 ns`, WHS `-0.019 ns`, with 0 errors and 0 critical warnings.  It improved setup by `+0.219 ns` over the frame-gain-pipelined run but remains unclosed.
- Root cause moved to the second x2 interpolator: elastic occupancy `full_reg` drove the stage-1 multiplier DSP `CEA2` enable through a fanout-672 control net (`6.219 ns` route in a `6.386 ns` path).  It is a control-distribution path, not a multiplier arithmetic limit.
- Changed the two elastic interpolator stages to write payload datapath registers whenever their slot advances.  Invalid payload values are explicitly don't-care and remain blocked by the separately pipelined word-valid bit; history still changes only for an accepted valid input word.  This preserves coefficient, fixed-point, ordering, state, and latency contracts.
- Targeted thermo3 and thermo5 bit-true XSim pass (64 words / 2,048 output complex samples).  Project P0 completes 7/7 PASS and IP smoke completes all five tests PASS.  A new thermo3 routed OOC is running; no timing-pass claim is made before its final WNS/WHS are available.

## 2026-09-20 - Localize runtime-DPD valid control for frontend timing closure

- Replaced the thermo TID's single enable with eight registered lane-bank enables per TID plane.  A single accepted packed word is first captured in a fixed one-core-cycle input register; each bank then updates only its local four-lane state slice.  This preserves the temporal state transition, quantization, raw-bit ordering, and only adds fixed latency.
- Changed the post-DPD elastic slice so a valid DPD word controls only its one-bit occupancy state; when the slice is writable it captures the wide payload unconditionally.  This removes the `in_valid` clock-enable fanout to 512 payload registers without changing valid/ready semantics.
- Targeted thermo3/thermo5 MATLAB-to-XSim vectors pass (64 words / 2,048 output complex samples, zero raw mismatch).  The required P0 regression is 7/7 PASS and the DSM IP smoke suite is PASS.
- A fresh full ZU15EG thermo3 routed OOC after the lane-bank change completed with WNS `-3.052 ns`, WHS `-0.019 ns`, 0 errors, and 0 critical warnings.  This is an improvement from `-7.183 ns`; its new limiting net is the DPD output-valid to the elastic payload CE (fanout 513, 7.439 ns route), confirming the remaining control-fanout root cause.
- The follow-up implementation with the elastic-payload CE removal is currently running.  No 218.75 MHz timing-pass or GTH/board claim is made until that routed STA completes.

## 2026-09-20 - Move thermo3 frontend bottleneck from control to frame-gain datapath

- The routed thermo3 OOC with the elastic-payload CE removal completed at WNS `-2.214 ns`, WHS `-0.019 ns`.  This is a further `+0.838 ns` setup improvement.  The DPD-valid fanout is no longer the worst path.
- The new worst path is `dsm_frame_gain_vector`: Q2.14 gain register to output vector register through one DSP48E2 multiply, signed round/saturate logic, and 13 logic levels (`6.768 ns`, including `4.359 ns` route).  This is an arithmetic-pipeline issue, not a CDC or FIFO failure.
- Split gain multiply and round/saturate into separate elastic stages.  The change adds one fixed core-clock latency without changing Q2.14 arithmetic, frame-start gain selection, sample ordering, or backpressure behavior.  Thermo5 bit-true XSim, P0 7/7, and IP smoke all pass after the change.
- A third full ZU15EG thermo3 routed OOC is running to measure this datapath-pipeline change.  Timing remains unclosed until it produces a positive setup and hold result.

## 2026-09-19 - Close ZU15EG CDC gearbox routed STA

- Replaced the optional 14:8 CDC gearbox's dynamic residual part-select/mux network with the equivalent fixed seven-state sequence (`0, 6, 12, 4, 10, 2, 8` residual samples).  This preserves 14-complex AXI beats to 8-complex core words, lane-0-first ordering, frame/gain rules, and the exact 1.75 GS/s average rate while producing a regular synthesis network.
- The generic Gray FIFO and FPGA XPM FIFO asynchronous XSim tests both passed after the change: 112 contiguous complex samples, 14 core words, zero order/frame/gain mismatches, no bubbles, no underflow, and no protocol error.
- Routed the complete XPM CDC wrapper on `xczu15eg-ffvb1156-2-i` with 125 MHz and 218.75 MHz asynchronous clock groups.  The result passes: WNS `+1.807 ns`, WHS `+0.042 ns`, TNS/THS zero, 896 LUT, 749 FF, 6.5 BRAM tiles, and 0 DSP.  This supersedes the earlier tool-crash-only CDC status; it is fabric/CDC PPA evidence, not a thermo5 frontend or GTH target signoff.
- Re-ran required project regressions: P0 XSim 7/7 PASS and IP smoke (top, AXI, active reset, BP AXI, DPD v1.1) PASS.  The required baseline DSM OOC run on `xc7z020clg400-1` found 12/14 PASS; `p0_ooc_mb_ef2` fails 100 MHz setup by `-0.093 ns`, and `p0_ooc_mb_mash22` by `-0.688 ns`.  These two independent base-IP timing risks are recorded for follow-up and are not attributed to the CDC wrapper.
- Remaining limitation: no four-GTH target STA, board loopback/BERT, or physical PA evidence exists.  The next implementation action is the distinct DPD-free thermo5 frontend routed OOC, then the main-path PPA comparison.

## 2026-09-19 - Add FPGA XPM CDC implementation and reproduce tool failure

- Added an FPGA-only `xpm_fifo_async` implementation for the optional `125 MHz / 14-complex AXI-S -> 218.75 MHz / 8-complex` ingress, while retaining the existing Gray-pointer FIFO as the generic RTL reference.  XPM uses a common reset, so source traffic begins only after both clock domains leave reset and the FIFO prefill contract is satisfied.
- Added an XPM-specific asynchronous-clock XSim and updated the existing CDC test to prefill before enabling the recursive core.  Both generic and XPM tests pass 112 contiguous complex samples through the 14:8 gearbox with no order, frame/gain, bubble, underflow, or protocol mismatch.
- Repeated the ZU15EG CDC OOC with XPM block memory and the same `AreaOptimized_high` directive as the known-good thermo5 core.  RTL parsing and `synth_design` completed, but Vivado 2024.1 crashed with `EXCEPTION_ACCESS_VIOLATION` while loading part/timing information before checkpoint, utilization, placement, or STA.  No CDC WNS/WHS/resource result is claimed.
- Added isolated routed XPM probes to distinguish the FIFO primitive from the full wrapper.  Both pass on `xczu15eg-ffvb1156-2-i`: 32-bit FIFO WNS/WHS `+3.250/+0.041 ns`, 0.5 BRAM tile; production-width 465-bit FIFO WNS/WHS `+2.907/+0.039 ns`.  This is valid FIFO PPA evidence, but not full CDC-wrapper timing.
- Revised the FPGA XPM branch to use the AXI/system reset as its single FIFO reset; `core_aresetn` separately resets the gearbox/consumer, and integration must assert both resets together.  The XPM CDC test remains bit-true.
- Full CDC OOC remains blocked by intermittent Vivado realtime-helper failures (`rtSynthCleanup.tcl`/`unimacro_vhdl.tcl` reported absent despite existing on disk) or `EXCEPTION_ACCESS_VIOLATION`.  Checks: CDC generic XSim PASS; CDC XPM XSim PASS; project P0 XSim 7/7 PASS; DSM IP smoke (top, AXI, active reset, BP AXI, DPD v1.1) PASS.  Next action is to rerun full CDC OOC in a stable Vivado process or repaired installation before recording full PPA.

## 2026-09-19 - Make thermo5 primary path DPD-free

- Set `tid32_thermo5_frontend_tx` to `BYPASS_DPD=1` by default.  The selected generate branch directly joins the two x2 interpolators, so no memory-DPD module is instantiated or synthesized; coefficient ports remain only as a stable compatibility boundary.
- Updated the MATLAB oracle and XSim compilation list to exclude the identity-DPD stage and all DPD RTL.  The DPD-free frontend XSim passed 64 ingress words, 2,048 final complex samples, and all four raw planes with zero mismatch.
- Two fresh ZU15EG OOC attempts failed before HDL elaboration in the Vivado realtime helper (`missing realtime Tcl`, then `rt-undefined`).  No new WNS/WHS or resource result is claimed; the older identity-DPD OOC remains historical evidence only.
- Next action: repair or isolate the Vivado helper environment, rerun routed DPD-free OOC, then compare thermo3/thermo5 and interpolation choices for PPA.

## 2026-09-19 - Retire unclosed temporal BP/SMASH experiments

- Removed the CRFB-SMASH temporal8/temporal64 prototype and the TID32 MASH1-1 experiment, including their dedicated MATLAB models, vectors, XSim testbenches, and OOC scripts.  They had useful research evidence but did not constitute a deployable 64-lane streaming implementation.
- Retained scalar BP/EFDSM/MASH IP, the P0 regression set, and the thermo5 frontend.  The behavioural screening script no longer advertises the removed CRFB candidate.
- Rationale: keep the repository focused on the bit-true, routed thermo5 digital frontend and prevent unclosed experimental temporal chains from being mistaken for a 218.75-MHz implementation.
- Checks after removal: MATLAB P0 passed all seven designs at 65,536 samples with zero mismatch; XSim P0 passed 7/7; IP smoke passed top, AXI, active-reset, BP-AXI, and DPD-v1.1.
- Remaining limitation: this cleanup does not create four physical GTH or PA paths; serializer/PA evidence remains simulation-only until board resources exist.

## 2026-09-19 - Four-path raw serializer loopback contract

- Added a simulation-only four-path raw-64 serializer/receiver model and a full thermo5 frontend loopback test.  Each path serializes `TXDATA[0]` first at a 64x serial clock, and all paths share reset and word cadence.
- Corrected the initial model so the launch edge emits bit 0.  The prior version consumed 65 serial edges per word and reinterpreted a level-valid word as repeated requests; the toggle-based launch contract now consumes each user handshake exactly once.
- The full frontend serializer loopback passed: 64 ingress words recovered on all four paths, 4,096 serial bits per path, zero word mismatches.  This is functional digital evidence only; it is not a GT analog, channel, PA, or board-loopback result.
- Added `fpga/zu15eg/THERMO5_FOUR_PA_SERIALIZER_CONTRACT.md`.  The current public board mapping remains dual-SFP only, so four physical GT/PA pin assignments are deliberately left pending actual board resources.

## 2026-09-18 - Five-level streaming frontend RTL and routed OOC

- Added the Q2.14 `dsm_frame_gain_vector` streaming contract and the complete `8-lane -> x2 polyphase -> identity memory-DPD -> x2 polyphase -> thermo5` frontend wrapper.  Frame gain is accepted with its frame-start word, is applied to that word, and remains active until the next accepted frame start; reset initializes unity gain.  The deployed memory-DPD coefficients remain identity because the held-out qualification gate remains rejected.
- Added a MATLAB vector generator, a four-plane XSim testbench, and a ZU15EG OOC flow for the wrapper.  The new frontend XSim passed 64 ingress words / 2,048 final complex samples with zero mismatches on all four raw planes, including three frame-gain changes.
- Routed `xczu15eg-ffvb1156-2-i` OOC at 218.75 MHz passed: WNS `+0.178 ns`, WHS `+0.027 ns`, TNS/THS zero, 0 critical warnings, and 0 errors.  Post-route utilization is 70,233 LUT, 88,839 FF, 2,064 DSP48E2, and 0 BRAM.  The OOC timing report warns that `HD.CLK_SRC` is unset and some OOC boundary ports have no `HD.PARTPIN_LOCS`; this is a fabric result, not a board/GTH clock-skew or serializer signoff.
- Re-ran the required checks: MATLAB P0 (seven designs, 65,536 samples each, zero mismatch), project XSim P0 (7/7 pass), and IP smoke (top, AXI, active-reset, BP-AXI, and DPD-v1.1 pass).

## 2026-09-18 - Strict five-level 250-MHz fair-RMS gate

- Upgraded `entry_tid32_thermo5_fullchain_250_mild_three_seed.m` from an insufficient 2/2/3-symbol smoke to isolated 12/10/12-symbol fit/validation/held-out frames.  The fixed fair-RMS drive remains `0.095`; its worst measured PAPR over the nine fixed frames is `3.6673`, so it remains below the explicit 0.35 peak contract.
- The full two-x2-interpolator, four-branch behavioural DPA/BPF/DDC chain has zero raw-word mismatches for all three seed sets, but only the first set passes: `3.2241%` EVM / `29.8318 dB` SNDR.  The second and third are `4.5765%` / `26.7894 dB` and `4.5525%` / `26.8350 dB`.  Therefore 250 MHz is not qualified under a constant-RMS drive policy.
- Added a separate peak-normalized 12/10/12-symbol entrypoint.  It is an explicitly different, unclipped per-frame drive policy and will be reported separately from fair-RMS; it is not a replacement for the failed constant-average-power gate.

## 2026-09-18 - Peak-normalized five-level 250-MHz identity baseline

- The new full-chain peak-normalized gate uses the same mild behavioural DPA/BPF/DDC profile, two x2 interpolators, four code planes, BPF/DDC receiver, independent 12/10/12-symbol frames, and three seed sets as the strict fair-RMS run.  It scales each input frame without clipping to the fixed 0.35 peak contract; consequently the average drive is PAPR dependent and this result is intentionally not comparable as a constant-power result.
- All three identity cases pass with zero raw-word mismatches: `2.8221%` / `30.9884 dB`, `3.0846%` / `30.2161 dB`, and `3.1831%` / `29.9432 dB` (EVM / SNDR).  This is the first accepted 250-MHz **parameterized behavioural** point for the complete digital/DPA/BPF/DDC model, not a PA measurement, GTH target result, physical four-serializer result, or board result.
- Added the matching four-tap Q2.14 memory-DPD three-seed qualification entrypoint.  Its validation and held-out results must both improve before any coefficient replaces the identity RTL deployment.

## 2026-09-18 - Peak-normalized 250-MHz memory-DPD gate

- Ran the four-tap Q2.14 1/3/5 memory-polynomial indirect-learning candidate against the accepted peak-normalized identity baseline, using the identical mild four-branch DPA/BPF/DDC profile and isolated 12/10/12-symbol seed sets.  All six identity/candidate endpoints retained zero raw-word mismatches.
- The candidate is not deployable: seed 101 regressed from `2.8221%` / `30.9884 dB` to `2.9352%` / `30.6472 dB`; seed 307 regressed from `3.0846%` / `30.2161 dB` to `3.1281%` / `30.0945 dB`; only seed 503 improved marginally from `3.1830%` / `29.9432 dB` to `3.1796%` / `29.9525 dB`.  The first two validation gates also regressed, so `HeldOutDeploymentAccepted=0` and the Q2.14 RTL coefficients remain identity.
- This is a generalization decision, not a statement that DPD cannot help another PA profile.  Further DPD work must follow a demonstrated frontend/drive improvement and retain the same isolated train/validation/held-out gate.
- Re-ran `scripts/run_matlab_p0_bittrue_check.cmd`: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, and MASH22 all passed 65,536 samples with zero mismatch.

## 2026-09-17 - Five-level full-frontend 250-MHz isolation

- Parameterized `run_tid32_thermo3_frontend_pa_dpd.m` for an explicitly selected three- or five-level thermometric TID while retaining its default three-level behavior.  The five-level wrapper reuses the same two x2 interpolators, Q2.14 memory-DPD interface, DPA/BPF, DDC, OFDM receiver, and acceptance rules; it does not fork a second, drifting behavioral chain.
- Added five-level full-chain/profile entrypoints.  Four-plane raw-word sanity at 250 MHz passed with zero mismatches; ideal RF/DDC NMSE was `1.0981e-4`.
- The complete 250-MHz frontend does not yet qualify: even ideal four-path PA/BPF returned `5.4454%` EVM / `25.2794 dB` SNDR.  Nominal DPA/BPF identity returned `3.7758%` / `28.4598 dB`; four-tap memory-polynomial DPD returned `3.8513%` / `28.2878 dB` and was rejected by validation and held-out gates.  The synthetic mild profile failed all three isolated seeds, worst case `4.1122%` / `27.7185 dB`.
- The evidence isolates the current limit to the two-stage frontend/TID working point before DPA compensation.  Next work is polyphase image-rejection and drive/threshold co-optimization, followed by the same three-seed DPA/BPF/DDC gate.  No 250-MHz full-system, GTH, PA, or board claim is made.
- A six-tap causal Lagrange x2 exploration improved ideal-PA EVM from `5.4454%` to `5.0474%` but did not meet the gate.  A 31-tap windowed-sinc exploratory mode produced `5.7814%`; its group delay is not yet represented by the OFDM crop/equalizer contract.  It is MATLAB-only and deliberately not promoted to RTL.  The default four-tap MATLAB/RTL contract is unchanged.

## 2026-09-17 - Five-level thermometric RTL milestone

- Added the conservative four-branch `tid32_thermo5_fs4_multipa_tx` RTL, its MATLAB fixed-point vector generator, bit-true XSim testbench, and a ZU15EG 218.75-MHz OOC flow.  The four branch thresholds are `{+3, +1, -1, -3} * STEP`, producing four aligned raw code planes for a five-level thermometric switching-PA architecture.
- Corrected only the testbench memory loading topology after `$readmemh` failed to load a selected row of an unpacked two-dimensional memory reliably.  The testbench now uses four one-dimensional memories; RTL arithmetic, state update order, quantization, and vector contents are unchanged.
- Checks: five-level MATLAB-to-XSim PASS for 128 continuous words / 4,096 complex samples with zero mismatches on all four raw streams.  Routed ZU15EG OOC at 218.75 MHz PASS: WNS `+2.894 ns`, WHS `+0.030 ns`, estimated Fmax `596.15 MHz`, 22,699 LUT, 21,464 FF, 0 BRAM, 0 DSP.  Required P0 regression PASS: 7/7 designs, 65,536 samples each, zero errors.  Required IP smoke completed and passed its top, AXI, active-reset, BP-AXI, and DPD-v1.1 tests.
- Limitation: the result verifies only the four-code-plane fabric.  It is not a four-GTH target STA, physical four-PA implementation, board loopback/BERT result, full DPA/BPF/DDC qualification, or a 250-MHz system claim.

## 2026-09-17 - Five-level 250-MHz digital receiver gate

- Added `entry_tid32_thermo5_250mhz_three_seed_rawddc.m` to make the five-level raw-Fs/4 acceptance reproducible.  It uses `STEP=7168`, three isolated seeds (`101/307/503`), eight OFDM symbols per seed, fair-RMS drive `0.11`, the physical raw Fs/4 DDC receiver, and a 0.35 peak-drive ceiling.
- The initial fair-RMS `0.13` trial correctly stopped at the input peak assertion: the 250-MHz OFDM waveform exceeded the configured 0.35 peak drive.  This is an explicit back-off constraint, not a timing or bit-order failure.
- At RMS `0.11`, actual occupied bandwidth `249.51171875 MHz` / OSR `28.055`, all three seeds passed with zero raw-stream mismatches.  Worst case was `3.2249%` EVM and `29.8298 dB` SNDR; maximum input peak was `0.3220`.
- This is a digital raw-TID/Fs/4/DDC receiver gate.  The current result excludes both x2 interpolators, the memory-DPD deployment path, behavioral DPA/BPF, four-GTH target STA, and board verification; it must not be presented as a full 250-MHz transmitter signoff.

## 2026-09-17 - ASIC synthesis preflight

- Added the reviewed `asic-dc-preflight` Rocky bridge task and ran it through the audited Windows-to-Rocky bridge.  Rocky 8.10 resolves `dc_shell` at `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`.
- The preflight stopped before synthesis because `DSM_ASIC_STDCELL_DB` is unset.  No standard-cell `.db`, mapped netlist, PPA number, or ASIC timing claim was generated.  A permitted nominal logic-cell `.db` is required before probing the library and running the existing pre-layout DC flow.

## 2026-09-17 - Readable DPD deltas and five-level TID feasibility screen

- Updated `plot_tid32_thermo3_dpd_four_way_delta.m` to give every non-identity DPD its own `DeltaPSD` panel (negative is lower BPF-side emission).  It makes explicit that the four-tap candidate is best only on one held-out EVM/SNDR point, not on ACLR; no visual inference of deployment quality is made.
- Added a behavioral four-branch five-level thermometric TID oracle and an offset-step screen.  Every screened point had zero temporal32/scalar raw mismatch.  The original screen used an I/Q shortcut that bypassed the raw Fs/4 sequence and produced a false low-bandwidth failure.  After replacing it with direct 14-GS/s Fs/4 DDC, fixed-RMS/seed-101 smoke passes at 17.09 MHz: thermo3 `3.0637%` / `30.275 dB`, and thermo5/step-6144 `3.0613%` / `30.282 dB`; the corresponding 99.12-MHz values are `1.4275%` / `36.909 dB` and `1.2639%` / `37.966 dB`.  These are single-seed behavioral screens only; no five-level RTL, serializer, or wideband deployment claim is made.
- Re-ran the existing two-stage MASH TID XSim: PASS for 128 words / 4,096 samples on both code planes.  Its previously recorded routed OOC remains timing-clean, but the independent OFDM qualification remains failed; more MASH stages are frozen pending a corrected transfer equation.
- Added input RMS/peak reporting, fixed-RMS mode, and selectable raw-Fs/4 DDC receiver mode to the OFDM screen.  The current sweep defaults to the raw DDC path; the I/Q shortcut is retained only to reproduce legacy data.
- In the same raw-DDC, fixed-RMS, seed-101, four-symbol smoke, thermo5/step-6144 also passes 157.23/198.24/239.26/259.77/276.86 MHz occupied bandwidth (OSR `44.52/35.31/29.26/26.95/25.28`).  The 276.86-MHz edge point is `3.4209%` EVM and `29.3171 dB` SNDR.  This is a single-seed behavioral feasibility boundary, not a DPA/BPF/full-frontend or RTL/FPGA qualification.

## 2026-09-17 - Four-way thermo3 DPD stress comparison

- Added `plot_tid32_thermo3_dpd_four_way_stress.m` plus a non-interactive entrypoint.  The comparison holds the exact thermo3 frontend, two switching-PA paths, BPF/DDC, 17.09-MHz OFDM frame, seeds, and synthetic memory-stress profile constant while changing only the DPD: identity, 1/3/5 memoryless polynomial, 16-bin LUT, or four-tap 1/3/5 memory polynomial.
- Held-out results were identity `2.0065% / 33.9512 dB`, memoryless `1.9927% / 34.0111 dB`, LUT `21.8888% / 13.1956 dB`, and four-tap memory polynomial `1.9664% / 34.1266 dB` (EVM / SNDR).  The LUT candidate fails 256-QAM.  All four raw-word checks were zero mismatch.
- None of the candidates met the existing validation/held-out deployment gate, so the vector16 RTL coefficient table remains identity.  The comparison is behavioral; LUT and memoryless candidates are not current vector16 RTL integrations.
- Exported PNG, PDF, metrics CSV, PSD CSV, and profile CSV under `matlab/out/tid32_thermo3_dpd_four_way_stress/`.  Checks: MATLAB P0 bit-true PASS (7/7 designs, 65,536 samples each, zero mismatch); no RTL changed.

## 2026-09-17 - Full-seed qualification and DPD spectrum export

- Added: `matlab/tx_bandpass_if/plot_tid32_thermo3_dpd_spectra.m`; updated the endpoint result to export diagnostic identity/candidate waveforms and made the MATLAB DPD model configurable for one to four active taps.
- Full 12/10/12-symbol, three-seed identity qualification passed for all three synthetic profiles at 17.08984375 and 19.6533203125 MHz.  Worst qualified case was mild/19.6533203125 MHz: 3.4734% EVM and 29.1849 dB SNDR.
- Exported nominal 17.09-MHz ideal/identity/candidate spectra plus EVM, SNDR and model-only ACLR CSV/PDF/PNG.  The candidate is diagnostic only: held-out EVM/SNDR regress versus identity, so deployment remains rejected.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).

## 2026-09-17 - Corrected severe-profile interpretation

- Corrected: `docs/exec-plans/active/execution-frontier.md`.
- The synthetic severe profile uses `Q=60`, which is a wider (not narrower) second-order BPF than nominal `Q=100` and mild `Q=140`.  Its preliminary 99.9755859375-MHz pass is therefore retained only as a coupled-model result; no single-parameter mechanism or physical-PA inference is claimed.

## 2026-09-17 - Parameterized profile/bandwidth screen

- Added: `matlab/tx_bandpass_if/run_tid32_thermo3_profile_bandwidth_sweep.m`.
- Added a reproducible synthetic mild/nominal/severe switching-DPA/BPF profile sweep around the unchanged full digital frontend.  OSR is explicitly evaluated at the 7-GS/s complex DDC interface, consistent with the baseline.
- Identity screen (4/4/4 OFDM symbols, one isolated seed triplet) passed through 19.6533203125 MHz for mild and nominal profiles and through 99.9755859375 MHz for the synthetic severe profile.  The severe result is attributed to its narrow behavioural BPF and is not a physical-PA claim.
- Memory-DPD candidate screen (2/2/2 symbols, same isolated seed triplet) accepted no candidate on held-out data; the RTL deployment table remains identity.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch); profile sweep raw-word checks were 0 mismatch.  No RTL changed, so XSim, OOC, and GTH STA were not rerun.

## 2026-09-17 - Digital/FPGA simulation scope

- Changed: `docs/exec-plans/active/execution-frontier.md`.
- Confirmed that this project is scoped to digital IC/FPGA implementation and parameterized PA/BPF/DDC simulation.  Physical PA characterization, coupler feedback capture, and measured-RF signoff are explicitly out of scope.
- Replaced the feedback-capture dependency with reproducible mild/nominal/severe behavioral-DPA profiles, isolated train/validation/held-out OFDM datasets, robust memory-DPD acceptance gates, and a complete 20-to-200 MHz simulated bandwidth sweep.
- No RTL, fixed-point behavior, simulation result, or hardware evidence changed.  No regression was required for this documentation-only scope decision.

## 2026-09-17 - Execution-frontier consolidation

- Changed: `docs/exec-plans/active/execution-frontier.md`, `docs/exec-plans/completed/20260917-152449-completed-history.md`.
- Moved completed implementation and verification milestones out of the active execution frontier.  The active document now records only the current architecture, signed evidence, acceptance gates, active risks, and dependency-ordered next actions.
- No RTL, fixed-point behavior, simulation vector, synthesis result, or board state changed.  `docs/exec-plans/completed/20260917-152449-completed-history.md` preserves the completed-history summary.
- Checks: `git diff --check` PASS.

## 2026-09-17 - Parameterized switching-DPA model and held-out DPD decision

- Changed: `matlab/tx_bandpass_if/run_tid32_thermo3_frontend_pa_dpd.m`, `docs/exec-plans/active/execution-frontier.md`.
- Replaced the gain-mismatch/linear-FIR PA surrogate with `behavioral_switching_dpa_v1`: per-branch pulse-density AM-AM thermal memory, polarity asymmetry, finite output FIR memory, analytic-signal AM-PM, and a causal second-order RLC-equivalent BPF (`Q=100`, `0.6 dB` insertion loss).  Every profile parameter is exported as `tid32_thermo3_frontend_pa_profile.csv`; the profile is configurable, not a measured PA calibration.
- Corrected the Fs/4 receiver to search both 14-to-7-GS/s timing phases rather than hard-code a phase.  The raw-word sanity gate remains 0 mismatches; the ideal BPF/DDC numerical gate is `1.8799e-6` NMSE at phase 0.
- Ran 12/10/12-symbol fit/validation/held-out 256-QAM OFDM DPD experiment.  The Q2.14 4-tap 1/3/5-order candidate improved validation from `2.5254 %` / `31.9535 dB` to `2.5122 %` / `31.9990 dB`, but regressed held-out test from `2.3917 %` / `32.4257 dB` to `2.3980 %` / `32.4032 dB`.  Deployment is rejected and the exported deployment table remains identity; the candidate table is retained for diagnosis.
- The identity DPA endpoint remains 256-QAM-decodable at 17.08984375 MHz occupied bandwidth / OSR 409.6.  Its model-only PA-side ACLR is `-24.0769 dBc` and causal-BPF-side ACLR is `-30.6297 dBc`; neither is physical-RF signoff.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).  No RTL changed, so no XSim, Vivado OOC, or GTH timing result was rerun.

## 2026-09-16 - TID32 frontend RF/DDC gate and memory-DPD hold

- Changed: `matlab/tx_bandpass_if/run_tid32_thermo3_frontend_pa_dpd.m`, `docs/exec-plans/active/execution-frontier.md`.
- Added a raw-word receiver gate. The two thermometric PA words decode to the independent scalar thermo3 reference with 0 mismatches after the fixed 1,056-sample latency. Ideal equal-weight PA combining, ideal BPF, Fs/4 DDC, LPF and the required 14-to-7-GS/s odd-phase selection reproduce that decoded reference with normalized MSE `4.6754e-7`; this finite numerical value is from floating-point FFT filters, not a bit-order error.
- Corrected the end-to-end receiver's DDC decimation order and FFT/CP parameterization. The two causal x2 interpolators introduce a deterministic per-subcarrier response, so a separately generated validation OFDM frame now estimates one pilot channel coefficient per active subcarrier. At 17.08984375 MHz occupied bandwidth (OSR 409.6), ideal equal PA paths and no DPD give held-out EVM `2.1503 %` and SNDR `33.3501 dB`; the deliberately stricter single-complex-gain diagnostic is `4.3397 %` / `27.2507 dB`.
- Exercised Q2.14, four-tap, 1/3/5-order indirect-learning memory DPD on the current gain-mismatch/linear-memory PA model. The validation candidate marginally reduced rate-MSE (`0.99008` to `0.98747`) but failed the held-out OFDM test (`8.3732 %` EVM / `21.5422 dB`) versus identity (`1.1380 %` / `38.8773 dB`). The script now writes identity as the deployment coefficient table and preserves the rejected candidate separately; no memory-DPD coefficient is authorized for RTL programming.
- Checks: frontend RF/DDC raw-word gate PASS; ideal endpoint 256-QAM pilot-EQ gate PASS; nonideal-model DPD candidate held-out gate FAIL/rejected; `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).
- Limitation: the present PA branches are gain-mismatched linear FIRs, not a calibrated nonlinear DPA. Their ideal brick-wall BPF drives filtered ACLR to a numerical floor, so neither the reported filtered ACLR nor the rejected DPD candidate is RF-signoff evidence. A calibrated nonlinear PA/feedback model or measured feedback capture is required before another DPD-training attempt.

## 2026-09-15 — TID32 OFDM-domain qualification correction

- Changed: `matlab/tx_bandpass_if/tid_pipelined_first_order_step.m`, `matlab/tx_bandpass_if/run_256qam_tid32_ofdm_demod.m`, `docs/exec-plans/active/execution-frontier.md`.
- Corrected TID32 EFM signed-input handling to 16-bit offset binary and restored adjacent-MSB XOR at the output.  The initial time-domain pointwise OFDM score is retained only as historical debug data: it is not a QAM demodulation EVM.
- Added an OFDM receiver qualification path with startup/tail guards, CP removal, FFT and active-carrier EVM.  At 14 GS/s and Fs/4 = 3.5 GHz, occupied BW 17.08984375 MHz (OSR 409.6), scalar EFM is 3.3545 % / 29.487 dB and TID32 is 3.3658 % / 29.458 dB (EVM / SNDR); the TID32 de-interleaved stream has zero mismatches to scalar after its fixed 1,056-sample latency.
- Checks: `run_tid_pipelined_scalar_contract` PASS (8,192 samples, 0 mismatch); TID32 16-symbol OFDM demodulation PASS for EVM/SNDR.  RTL XSim, rerun OOC and GTH payload integration remain pending.

## 2026-09-15 — TID32 RTL word-level contract

- Added: `matlab/tx_bandpass_if/gen_tid32_bittrue_vectors.m`, `dv/verif/block/bp_dsm/tb/tb_tid32_cartesian_fs4_gt_tx_bittrue.sv`, `dv/verif/scripts/run_xsim_tid32_cartesian_fs4_gt_tx.ps1`.
- Added the payload-target board top and build Tcl.  SFP0 receives the actual TID32 raw word; SFP1 retains a distinct known word.  Its local source is explicitly a board smoke pattern, not a substitution for the future 256-QAM sample feeder.
- Checks: `run_xsim_tid32_cartesian_fs4_gt_tx.ps1` PASS — 128 words / 4,096 samples, MATLAB-to-RTL 64-bit GT word 0 mismatch.

## 2026-09-15 — TID32 routed OOC closure

- Check: `syn/run_ooc_tid32_cartesian_fs4_gt_tx.ps1` PASS on `xczu15eg-ffvb1156-2-i` at 218.75 MHz: WNS +3.045 ns, WHS +0.034 ns, TNS/THS 0, estimated Fmax 655.12 MHz; implementation completed with 0 critical warnings and 0 errors.
- Limitation: This is an OOC fabric result.  It does not replace the pending payload-plus-GTH target STA or physical SFP loopback.

## 2026-09-16 — TID32 20-MHz-class qualification boundary

- Check: The OFDM-domain TID32 screen at the next 4096-point grid point, 20.5078125 MHz occupied BW / OSR 341.33, returned EVM 3.8036 % and SNDR 28.396 dB.  This fails the fixed 256-QAM gate.
- Decision: Retain 17.08984375 MHz / OSR 409.6 as the only currently verified 256-QAM operating point for the single-bit first-order TID32.  Do not characterize it as a 20-MHz-qualified transmitter.

## 2026-09-16 — GTH timing target decoupled from ILA

- The ILA-bearing payload build stalled before main synthesis because its ILA OOC child terminated without an end marker; GT Wizard synthesis did complete.  No GTH payload STA result was produced.
- Added `USE_ILA` to the payload top and a no-ILA payload STA Tcl.  This preserves the ILA build for board bring-up while preventing a debug-core failure from blocking TID32+GTH timing signoff.

## 2026-09-16 — TID32 dual-SFP GTH payload closure

- Check: The no-ILA target routed on `xczu15eg-ffvb1156-2-i` with the real TID32 SFP0 payload and independent SFP1 known word.  Post-route detailed STA: WNS +0.480 ns, WHS +0.014 ns, TNS/THS 0.  Bitstream generation completed with 0 warnings, 0 critical warnings and 0 errors.
- Artifact: `D:/TraeTemp/tid32_cartesian_gt14_dual_sfp_sta_20260916/tid32_cartesian_gt14_dual_sfp_sta.bit`.
- Limitation: The local board source is deterministic payload smoke data.  Hardware loopback/BERT and a verified board 256-QAM sample feeder remain required.

## 2026-09-16 — Regression after TID32/GTH integration

- Checks: `dv/verif/scripts/run_xsim_p0_all.ps1` PASS — 7/7 configurations, 65,536 samples each, Failed=0. `dv/verif/scripts/run_xsim_ip_smoke.ps1` PASS, including BP AXI route and DPD v1.1 smoke.

## 2026-09-15 20:55 - Seven DSM scalar reference/temporal64 contracts

- Changed files: `matlab/tx_bandpass_if/dsm_scalar_transition.m`, `matlab/tx_bandpass_if/run_all7_scalar_reference_equivalence.m`, `matlab/tx_bandpass_if/run_all7_temporal64_contract.m`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: freeze observable sample phase and PA-branch outputs against the behavioral models that generate the EVM evidence before starting temporal64 RTL.
- Checks run: `run_all7_scalar_reference_equivalence('samples',16384)` and `run_all7_temporal64_contract('words',256)`; all seven candidates reported zero mismatch, and every packed word-end state matched the serial reference.
- Remaining limitation: these are MATLAB reference contracts only; no candidate has temporal64 RTL/XSim/OOC/GTH qualification yet.

## 2026-09-15 21:15 - Dual-SFP GTH CDC correction in progress

- Changed files: `fpga/zu15eg/rtl/ti64_raw_gt14_dual_sfp_loopback_top.sv`, `fpga/zu15eg/constraints/ti64_raw_gt14_dual_sfp_loopback.xdc`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: the clock-port target met WNS/WHS but methodology reported TIMING-7 because an RX-clocked ILA sampled `tx_ready` directly. TX and recovered RX user clocks are asynchronous domains.
- Change: added a marked two-flop TX-to-RX status synchronizer and an explicit asynchronous clock group.
- Checks run: P0 XSim 7/7 PASS; IP smoke 5 checks PASS. The corrected physical target build is still running; no board or final GTH claim is made.

## 2026-09-15 21:30 - Dual-SFP GTH CDC target timing closure

- Changed files: `fpga/zu15eg/rtl/ti64_raw_gt14_dual_sfp_loopback_top.sv`, `fpga/zu15eg/constraints/ti64_raw_gt14_dual_sfp_loopback.xdc`, `docs/exec-plans/active/execution-frontier.md`.
- Checks run: xczu15eg-ffvb1156-2-i dual-SFP `cdcfix` target route. Detailed STA: WNS +1.355 ns, WHS +0.014 ns, TNS/THS 0; methodology has zero critical warnings.
- Remaining limitation: TIMING-28 is a non-critical warning on auto-derived clocks used by the async group. Hardware loopback/BERT remains unrun; the result qualifies only the generic serializer platform, not DSM payloads.

## 2026-09-15 21:32 - CRFB-SMASH2 exact temporal8 RTL prototype

- Changed files: `rtl/tx_bandpass_if/crfb_smash2_temporal8.sv`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: start the bounded 8-step transition-composition proof before attempting 16/64 samples.
- Checks run: `xvlog -sv rtl/tx_bandpass_if/crfb_smash2_temporal8.sv` PASS.
- Remaining limitation: MATLAB-vector XSim, state/stream bit comparison, and 218.75-MHz OOC are not yet run; the design is an exact serial composition prototype, not a timing-safe lookahead implementation.

## 2026-09-14 18:37 +08:00 — Cartesian x4/TI64 timing closure

- Replaced the unpipelined x4 vector polyphase FIR with a five-stage elastic
  implementation. Fixed-point arithmetic, rounding, saturation, history and
  lane ordering are preserved; latency increased.
- The final ZU15EG `TXUSRCLK2=218.75 MHz` routed build completed with zero
  errors and zero critical warnings: WNS `+0.387 ns`, WHS `+0.010 ns`, TNS/THS
  `0`, 20,835 LUTs, 21,203 FFs, 385 DSPs and 4 BRAM tiles.
- Checks: independent x4 bit-true XSim PASS; P0 XSim 7/7 PASS, 65,536 samples
  per test; five IP-smoke tests PASS.
- Remaining boundary: timing closure does not prove an SFP0 physical link,
  serialized word order, RF quality, or a 14 GHz RF carrier.

## 2026-09-14 18:45 +08:00 — Documentation consolidation and verification-first decision

- Consolidated current x4/TI64 design and implementation facts into `SPEC.md`
  and its required verification gates into `VPLAN.md`.
- Removed obsolete prototype, interview, resume, notebook, bridge, timing and
  duplicate evidence-index documents. `docs/exec-plans/` is deliberately
  unchanged.
- The next project milestone is digital verification closure before FPGA
  loopback or ASIC implementation.

## 2026-09-14 19:00 +08:00 - Stale experiment and generated-artifact cleanup

- Removed the unreferenced BP-EFDSM2 parallel/look-ahead/map-compose experiment family, its dedicated OOC launchers, testbenches/refmodels, raw-playback experiment, and RF7G MATLAB generator.
- Retained every static EDA task and its current source dependency: P0, IP smoke, TI64 core/frontend/x4 frontend, OOC, GT generation, and ZU15EG build flows.
- Removed explicitly scoped ignored Vivado/XSim/VCS caches, generated vectors, crash dumps, logs, and temporary PDF text; `.gitignore` now prevents their reintroduction.
- Checks: P0 XSim 7/7 PASS, IP smoke PASS, and Cartesian x4/TI64 frontend XSim PASS after cleanup. Restricted `fpga/hardware/`, `ads/`, and `data/` content was intentionally left untouched.

## 2026-09-14 22:55 +08:00 - Rocky VCS and board-connectivity preflight

- Added reviewed Rocky bridge tasks for a read-only VCS installation audit and linux64 compiler-launch probe.
- The VCS compiler exists at `V-2023.12-SP1/linux64/bin/vcs1`, but it explicitly rejects the active WSL2 kernel. The QAM-OFDM UVM task therefore fails before RTL compilation; no UVM or coverage result is claimed.
- Vivado 2024.1 Hardware Manager and local hw_server start correctly, but no JTAG target is visible at `127.0.0.1:3121`; no bitstream was programmed.
- Next action: connect and power the ZU15EG USB-JTAG path (or provide a reachable remote hw_server), then repeat target discovery before programming the x4/TI64 bitstream.

## 2026-09-14 23:10 +08:00 - Correct TI64 Fs/4 translation ownership

- Confirmed and fixed a duplicate Fs/4 translation in the Cartesian x4/TI64 path. The frontend now sends `[I,Q,I,Q]` to the TI lanes; TI64 alone applies the one-bit `+,+,-,-` translation.
- The prior x4 bitstream is invalid for 3.5 GHz IF/RF metric claims because the two sign translations cancel under odd-symmetric lane quantization.
- Checks: x4 frontend bit-true XSim PASS; P0 XSim 7/7 PASS; IP smoke PASS.
- Remaining: implement the vector memory-polynomial state chain and a waveform-level RF metric oracle before rebuilding/programming the corrected board image.

## 2026-09-15 08:45 +08:00 - Experimental BP-EFDSM4 candidate and 256-QAM screen

- Added an explicitly experimental, one-bit Fs/4 BP-EFDSM4 core with
  `v=x-2e[n-2]-e[n-4]`, its Python integer golden model, direct-input XSim
  bit-true test, and MATLAB screen candidate. Its linearized NTF is
  `(1+z^-2)^2`; this does not establish a usable stability range by itself.
- Checks: BP-EFDSM4 Python-to-RTL XSim PASS for 2,048 random/boundary samples;
  P0 XSim 7/7 PASS; IP smoke PASS. At 39.31 MHz occupied bandwidth and
  drive 0.15, the idealized 256-QAM screen reports 3.725% EVM, 28.578 dB SNDR,
  and -32.888 dBc ACLR. It improves the second-order candidates but misses the
  frozen 3.5% / 29.12 dB gate and is not a board, PA, or RF result.
- Corrected the x128/x256 ingress-rate planning contract: fixed 16-sample
  words arrive once per 32/64 output clocks respectively, not through a
  superficial x4-style data interface.

## 2026-09-15 09:00 +08:00 - EFDSM4 feasibility boundary and x128 cadence contract

- Parameterized the experimental BP-EFDSM4 feedback terms and ran an integer
  coefficient plus drive sweep. The only non-divergent nearby combination was
  the original `C2=-2, C4=-1`; high-resolution 39.31-MHz results over drive
  0.08--0.20 remain 3.724--3.727% EVM and 28.573--28.579 dB SNDR. No point
  meets the frozen 256-QAM gate.
- Added `dsm_interp_word_cadence16`, a synthesizable x128/x256 ingress timing
  contract. With x128 it accepts one 16-sample source word every 32 output
  words and records underflow; it intentionally contains no FIR arithmetic.
- Checks: BP-EFDSM4 Python-to-RTL XSim PASS (2,048 samples); interpolator
  cadence XSim PASS; P0 XSim 7/7 PASS; IP smoke 5/5 PASS. The x128/x256
  polyphase FIR and SMASH multi-output implementation remain active work.

## 2026-09-15 09:10 +08:00 - MASH multi-PA interface reset correction

- Added a research-only MASH1-1 multi-PA/serializer boundary which exposes the
  two quantizer bitstreams and the uncompressed four-level combiner result.
  It is explicitly not the paper-derived CRFB-SMASH candidate.
- Fixed `dsm_core_mash11` reset state for its delayed stage-2 sign from zero to
  positive one, matching its MATLAB model and preventing an illegal initial
  combiner level of zero or plus/minus two.
- Checks: multi-PA interface XSim PASS (128 samples); P0 XSim 7/7 PASS.

## 2026-09-15 16:55 +08:00 - Packed BP2 and MASH feasibility screen

- Added the exact temporal packed-BP2 oracle and the existing BP-MASH1-1
  multilevel combiner to the identical 256-QAM IF screen. At 39.31 MHz
  occupied bandwidth and drive 0.15, packed BP2 is exactly BP-EFDSM2:
  4.409% EVM / 27.114 dB SNDR / -22.543 dBc ACLR. BP-MASH1-1 reports 4.410%
  / 27.112 dB / -22.518 dBc. Neither meets the frozen 3.5% / 29.12 dB gate.
- The initial CRFB-SMASH2 oracle reports 99.892% EVM and is declared invalid
  pending a verified state-equation derivation; it is not used to judge the
  referenced CRFB-SMASH architecture and has no RTL implementation.
- Check: `run_256qam_dsm_if_screen` completed at Fs=14 GS/s, Fc=3.5 GHz with
  identical BPF/DDC/synchronization/demodulation settings for every candidate.

## 2026-09-15 17:00 +08:00 - MASH11 reset-contract correction

- MATLAB P0 comparison reproduced one MASH11 mismatch at sample 2 after an
  attempted reset change. The source-of-truth fixed-point model initializes
  the cancellation-delay state to zero, so RTL was restored to that contract.
  The multi-PA interface test now permits only the resulting first-sample
  +/-2 transient; all later values must be normal four-level codes.
- Checks after restoration: P0 XSim 7/7 PASS; MATLAB-to-RTL P0 comparison
  7/7 with zero mismatches over 65,536 samples each; IP smoke PASS; multi-PA
  interface XSim PASS (128 samples).

## 2026-09-15 17:10 +08:00 - CRFB-SMASH paper transfer-function audit

- Added `crfb_smash2_transfer_audit.m` from Xu et al. Fig. 2 and equations
  (7), (10), and (14). It reports per-stage and two-stage NTF polynomials,
  zeros, poles, stability, Fs/4 notch depth, and the three-level PA-code
  contract without pretending to be a fixed-point state model.
- Checks: at 14 GS/s and 3.5 GHz, `g=[2,2]`, `a=[-1,-1]` is stable with the
  expected `-(1+z^-2)^2` total NTF; `a=[-0.5,-0.5]` is also stable. The
  next required artifact is the Fig. 2 state-equation derivation and its
  independent fixed-point oracle, before RTL or 256-QAM qualification.

## 2026-09-15 17:20 +08:00 - Three-level BP DSM feasibility screen

- Added fixed-point three-level BP-EFDSM2 and BP-EFDSM4 behavioral models.
  The {-1,0,+1} output maps to two one-bit PA branches with fixed gain
  normalization; it does not alter the final 14-GS/s OSR.
- At the frozen 39.31-MHz/drive-0.15 256-QAM point, three-level BP2 reports
  4.371% EVM / 27.189 dB SNDR and three-level BP4 reports 3.726% / 28.575 dB.
  Neither meets the gate; quantizer level count alone is therefore not the
  acceptance path. Check: `run_256qam_dsm_if_screen` completed.

## 2026-09-15 17:30 +08:00 - Final-rate OSR and channel-bandwidth screen

- Swept requested 5/10/20/40 MHz channels at the fixed final interleaved
  rate of 14 GS/s and Fc=3.5 GHz. OSR is therefore Fs/(2B), not a function of
  the 218.75-MHz fabric clock or an ingress interpolation factor.
- At actual 9.40 MHz (OSR 744.7) and 19.65 MHz (OSR 356.2), BPDSM2,
  BP-EFDSM2, BP-EFDSM4, packed TI64-BP2 and the existing BP-MASH1-1 pass the
  frozen EVM/SNDR gate. BP-EFDSM4 at 19.65 MHz reports 2.078% EVM, 33.649 dB
  SNDR and -34.180 dBc ACLR. No candidate passes at actual 39.31 MHz (OSR
  178.1). The 5-MHz run has too few occupied tones/BPF FFT bins and is marked
  as an oracle-resolution issue pending a longer-vector rerun.

## 2026-09-15 17:40 +08:00 - CRFB-SMASH temporal-64 architecture constraint

- Verified Xu et al. equation (15), `v1=y1-y2` for two stages, and its stated
  de-interlacing/parallel-DSM/interlacing implementation with delay-register
  state propagation. The project CRFB route is consequently constrained to an
  exact 64-step state composition per word, not 64 independent DSM lanes.
- The scalar CRFB state transition remains the required predecessor; no
  temporal-64 RTL or timing claim is made yet.

## 2026-09-15 17:55 +08:00 - Causal CRFB transition and temporal-64 oracle

- Added the causal fixed-point scalar transition derived from the audited
  CRFB transfer functions, plus a 64-step composition contract. At
  `g=[2,2]`, `a=[-1,-1]`, scalar and temporal-64 agree on y1, y2, v1 and final
  state for 256 words / 16,384 random samples with zero mismatches.
- The checked CRFB transition replaces the invalid initial CRFB candidate in
  the common screen. It passes at 19.65 MHz: 2.075% EVM / 33.659 dB SNDR /
  -34.837 dBc ACLR; it fails at 39.31 MHz: 3.725% / 28.578 dB / -33.492 dBc.
- This is behavioral evidence only. A naive 64-way unroll is a 64-deep
  data-dependent chain and cannot inherit 203.125/218.75-MHz closure from a
  single scalar core. State-map lookahead/prefix composition is now the next
  implementation gate before RTL/OOC/serializer work.

## 2026-09-15 18:05 +08:00 - 256-QAM candidate consolidation

- Consolidated all behavioral-pass candidates at the actual 19.65-MHz,
  OSR-356.2 point. The two implementation branches are BP-EFDSM4 (single
  one-bit serializer) and CRFB-SMASH2 (two one-bit serializer/PA branches);
  other passing models remain comparison baselines.
- Existing 100-MHz AXI-IP OOC matrix has reached 48/70 rows, but contains
  neither exact-temporal64 BP-EFDSM4 nor CRFB-SMASH2. It is not evidence of
  timing closure for either selected branch.

## 2026-09-15 18:15 +08:00 - Unified temporal64 qualification scope

- Clarified the active rate as 64 lanes at 218.75 MHz = 14 GS/s (3.5-GHz
  Fs/4 IF). The 203.125-MHz figure belongs only to an alternate 13-GS/s rate.
- Every behavioral-pass candidate now has the same required qualification:
  scalar fixed-point, scalar-vs-temporal64 word/state equality, temporal64
  RTL, 218.75-MHz OOC STA, and raw-serializer ordering. One-bit candidates
  need one stream; CRFB/three-level candidates need two phase-aligned streams.

## 2026-09-15 18:20 +08:00 - GT serializer is a mandatory timing gate

- Expanded the qualification contract: 218.75-MHz fabric OOC proves only the
  raw-GT user-word boundary. Each candidate must also use a real 14-Gb/s GTH
  target-routed build, pass TXUSRCLK2/reset/clock timing, and demonstrate
  serialized-loopback/BERT recovered-word and bit-order equality. Multi-PA
  candidates require every phase-aligned serializer branch to pass.

## 2026-09-15 18:30 +08:00 - Two-PA GTH collateral audit

- Confirmed that the checked board integration supports one physical 14-Gb/s
  RAW GTH stream on SFP0/X1Y12, including its GT Wizard, 218.75-MHz user clock,
  target build and recovered-word observability. No checked second GTH/SFP
  channel constraints or clock/routing data are in the repository.
- CRFB/two-PA physical serializer work is blocked on that board collateral;
  pin assignment will not be guessed. Single-stream candidate integration can
  proceed independently after temporal64 RTL closure.

## 2026-09-15 19:25 +08:00 - Seven-candidate scope and SFP1 collateral recovery

- Replaced the active frontier with the concise seven-candidate qualification
  matrix requested for BPDSM2, BP-EFDSM2, BP-EFDSM4, both three-level BP
  variants, BP-MASH1-1, and CRFB-SMASH2. All seven now require the identical
  scalar-to-temporal64-to-GTH-to-loopback acceptance chain; no branch is a
  baseline-only exception.
- Inspected the repository's restricted ZU15EG schematic and vendor UCF
  without copying board collateral into project sources. They identify SFP1
  TX `D6/D5`, RX `C4/C3`, and the same quad-230 reference clock `C8/C7` used
  by SFP0. The adjacent GT site still requires a Vivado device-site query
  before a dual-channel Wizard or XDC is generated.
- Reviewed the verified 19.65-MHz screen data from
  `crfb_smash2_verified_screen/screen.csv`; it remains behavioral evidence
  only. The older OSR-sweep CRFB rows are retained as historical invalid-model
  output and must not be used for decisions.

## 2026-09-15 19:35 +08:00 - Seven scalar temporal64 contracts

- Added the common scalar fixed-point transition and exact 64-step composition
  harness for all seven requested candidates. The BP-MASH transition explicitly
  follows its behavioral bandpass reference rather than reusing the existing
  low-pass MASH RTL under a misleading name.
- Check: `run_all7_temporal64_contract('words',256)` PASS. Every candidate
  has zero mismatches across all emitted one-bit/level streams and an equal
  word-end state after 16,384 random samples.
- This is reference-model evidence only; the temporal64 RTL, 218.75-MHz STA,
  GTH route and board loopback gates remain open for all seven candidates.

## 2026-09-15 20:05 +08:00 - Dual-SFP GTH timing-root cause

- Added the two-channel SFP0/SFP1 RAW GTH infrastructure, including the
  `X1Y12 X1Y13` Wizard configuration, dual-channel wrapper, dual-SFP known
  word ILA top, and the board-derived SFP1 pins.
- The first target-routed build produced a bitstream with WNS `+1.419 ns` and
  WHS `+0.013 ns` at the real 218.75-MHz user-clock rate. Detailed STA still
  raised TIMING-3/6/7/14 critical warnings because manually created user
  clocks duplicated the Wizard's generated clocks. This build is explicitly
  not accepted.
- Removed the duplicate primary user-clock constraints while retaining the
  primary clock at the GT reference-buffer output. The next identical build
  must show the Wizard-derived 218.75-MHz clocks and zero critical warnings.

## 2026-09-15 21:49 +08:00 - CRFB temporal8 functional baseline and timing limit

- Added MATLAB-vector generation and XSim comparison for the exact eight-step
  CRFB-SMASH2 transition. The test now compares both two one-bit output words
  and all nine word-end state registers. Check:
  `run_xsim_crfb_temporal8.ps1 -Words 256` PASS, zero mismatches across 2,048
  samples.
- During bring-up every word mismatched. The RTL implemented quantization
  error as `u-q`; the audited scalar reference uses `q-u`. Correcting that
  sign restored bit-true output and state equality. The runner now requires
  an explicit XSim PASS marker instead of trusting the simulator exit code.
- Check: routed ZU15EG OOC at 218.75 MHz FAIL, WNS `-12.088 ns`, WHS
  `+0.453 ns`; implementation completed without critical warnings or routing
  failures. The causal eight-transition combinational chain is therefore a
  functional reference baseline, not a timing-safe lookahead or a 64-lane
  implementation. A finite state-map/branch-prediction representation is now
  required before further exact temporal64 RTL expansion.

## 2026-09-15 22:24 +08:00 - Exact CRFB scalar timing boundary

- Added a `STEPS` synthesis knob to the temporal8 prototype so the routed
  OOC flow can measure causal-chain depth without changing arithmetic,
  latency, or the normal eight-step functional contract.
- Check: at 218.75 MHz on `xczu15eg-ffvb1156-2-i`, `STEPS=1` fails routed
  STA: WNS `-0.909 ns`, WHS `+0.074 ns`. Explore placement/routing plus
  pre/post-route `AggressiveExplore` physical optimization improved it only
  to WNS `-0.827 ns`, WHS `+0.084 ns`.
- The failing path is 5.461 ns from `e1d2_r` to `e2d1_r`, including 31 logic
  levels (21 CARRY8) and 2.726 ns routing. The blocker is therefore the
  exact scalar fixed-point transition, not merely its 8/64-way unroll.
- The OOC runner now fails its PowerShell invocation when `summary.csv`
  reports timing `FAIL`; `-AllowTimingFail` is an explicit measurement-only
  override. Vivado's successful implementation exit code can no longer be
  mistaken for a timing pass.
- Regression checks after the RTL update: P0 XSim 7/7 PASS, IP smoke 5/5
  PASS, and the serial MATLAB-to-RTL P0 comparison 7/7 PASS (65,536 samples
  per design, zero mismatches). A first parallel MATLAB launch correctly
  failed because its P0 dump had not yet been generated; the final serial
  result is the valid evidence. The updated default `STEPS=8` temporal test
  also passes MATLAB-vector XSim for 256 words / 2,048 samples, including all
  two-branch output bits and nine word-end state registers.

## 2026-09-15 23:10 +08:00 - 14-Gb/s 256-QAM architecture correction

- Audited the Firmansyah MASc thesis equations for the pipelined first-order
  TIDSM and the MGS serializer. At `Fc=3.5 GHz`, its DSM sample rate is
  `2Fc=7 GS/s` and its MGS line rate is `4Fc=14 Gb/s`. With this project's
  fixed `218.75 MHz` fabric and 64-bit GTH user word, the matching topology
  is `L=32` polyphase channels per I and per Q path, not 64 independent
  real-valued LP1 lanes.
- The thesis-derived pre-summation / feedback / XOR architecture has a
  one-adder critical path independent of `L`; this is architecturally distinct
  from the exact 28-bit CRFB transition that failed at 218.75 MHz. The active
  implementation path is therefore a new fixed-point-reference pipelined Cartesian TIDSM,
  followed by payload GTH integration and loopback, rather than further CRFB
  unrolling.
- Corrected the active project scope after review: this is a fully digital
  `3.5 GHz` `Fs/4` transmitter with `14 GS/s` equivalent sample rate and a
  `14 Gb/s` raw-GTH line rate. It has no external LO/mixer. The number `14`
  must not be described as a 14-GHz RF carrier.

## 2026-09-15 23:28 +08:00 - Pipelined Cartesian TIDSM routed timing

- Added `tid32_cartesian_fs4_gt_tx`, its MATLAB fixed-point transition model,
  a ZU15EG OOC wrapper and a routed OOC script. The design implements 32
  polyphase channels per I/Q path and emits a 64-bit raw-GT word.
- Check: routed OOC on `xczu15eg-ffvb1156-2-i` at 218.75 MHz PASS, WNS
  `+3.053 ns`, WHS `+0.032 ns`, estimated Fmax `658.58 MHz`.
- `xvlog` compiled the RTL/wrapper and a 64-word MATLAB model smoke test
  passed. MATLAB-to-XSim vectors, 256-QAM metrics, GTH payload target-route
  and physical loopback remain open; this result alone is not a bit-true or
  transmitter-system acceptance claim.

## 2026-09-15 23:35 +08:00 - First TIDSM 256-QAM screen failure

- Added a standalone 256-QAM screen that drives the new 32-channel-per-I/Q
  fixed-point TIDSM at 7 GS/s, applies its deterministic 14-GS/s Fs/4 word
  ordering, and evaluates EVM/SNDR/ACLR.
- Check: the first run requested 19.65 MHz and used the nearest 4096-point
  OFDM occupied bandwidth of 17.08984375 MHz. Its equivalent OSR was 409.6,
  yet EVM was `99.420 %`, SNDR `0.050 dB` and ACLR `-7.857 dBc` (FAIL).
- The timing-clean TIDSM is therefore not accepted for any QAM modulation.
  The next investigation is the EFM input representation, STF/NTF and I/Q
  serializer sequence; MATLAB-to-XSim bit-true verification is intentionally
  deferred until those behavioral invariants pass.
- Regression check: `scripts/run_matlab_p0_bittrue_check.cmd` PASS for all
  seven retained legacy P0 designs, each with 65,536 samples and zero
  mismatches. This guards existing IP only; it does not validate the new
  TIDSM candidate.

## 2026-09-16 09:18 +08:00 - Two-stage Cartesian TID-MASH prototype

- Added a new `tid32_mash11_fs4_multipa_tx` architecture with two cascaded
  `L=32` first-order Cartesian TIDSM stages. Stage 2 receives the aligned,
  saturated stage-1 `x-q1` residual. The two raw stage streams remain separate
  64-bit PA/serializer branches; no lossy one-bit recombination is applied.
- Added the corresponding MATLAB fixed-point oracle, deterministic vector
  generator, XSim bit-true testbench, and ZU15EG routed OOC flow. The reset
  token and registered inter-stage handoff are explicit parts of the oracle.
- Checks: MATLAB-to-XSim PASS for 128 words / 4,096 I/Q samples with zero
  mismatches on both PA branches. Routed OOC on `xczu15eg-ffvb1156-2-i` at
  218.75 MHz PASS: WNS `+1.315 ns`, WHS `+0.029 ns`, TNS/THS `0`, estimated
  Fmax `307.08 MHz`; 14,276 LUT, 13,439 FF, 0 DSP, 0 BRAM.
- Regression checks: `run_xsim_p0_all.ps1` PASS, 7/7 tests at 65,536 samples;
  `run_xsim_ip_smoke.ps1` PASS.
- Limitation: this proves only fixed-point/RTL equivalence and fabric timing.
  The two PA branches are not yet connected to the dual-SFP GTH payload top,
  and no 256-QAM OFDM EVM/SNDR/ACLR qualification has been claimed.

## 2026-09-16 09:23 +08:00 - TID-MASH OFDM qualification failure

- Added a corrected OFDM-domain screen for the two-stage TID-MASH. It models
  the required MASH cancellation `y1 + y2 - z^-1 y2` as two 1-bit PA code
  planes with ideal 1:2 analog combining; direct equal-weight stage outputs
  are explicitly rejected as an invalid MASH realization.
- At 17.08984375 MHz occupied bandwidth and OSR 409.6, drive values
  `0.05/0.10/0.20/0.35` produced EVM `32.380/32.316/32.338/32.362 %` and
  SNDR `9.794/9.812/9.806/9.799 dB`. None meets the 256-QAM gates.
- Root cause: the current aligned `x-q1` inter-stage recurrence/cancellation
  does not have the required STF. This is algorithmic; routed TID timing and
  PA backoff cannot repair it. The prototype remains a functional/timing
  research baseline and is excluded from GTH payload integration.

## 2026-09-16 09:36 +08:00 - Three-level BP behavioral OFDM gate

- Extended `run_256qam_tid32_ofdm_demod.m` with a common OFDM/DDC receiver
  path for the fixed-point three-level BP-EFDSM2 and BP-EFDSM4 feasibility
  models. This is a scalar behavioral comparison only; it is not a TID RTL
  or serializer implementation.
- At 19.6533203125 MHz occupied bandwidth (OSR `356.17`), three-level
  BP-EFDSM2 measured EVM `1.5327 %`, SNDR `36.291 dB`, ACLR `-31.627 dBc`;
  BP-EFDSM4 measured EVM `1.5261 %`, SNDR `36.328 dB`, ACLR `-32.246 dBc`.
  Both pass the project 256-QAM EVM/SNDR gate in this ideal digital model.
- At 99.9755859375 MHz (OSR `70.017`), BP-EFDSM2 measured `2.2725 %` /
  `32.870 dB`, while BP-EFDSM4 measured `0.60936 %` / `44.302 dB`; both pass
  the same ideal-digital gate. At 999.755859375 MHz (OSR `7.0017`),
  BP-EFDSM4 fails: EVM `13.527 %`, SNDR `17.376 dB`.
- Consequence: three-level output is a credible bandwidth path, but it must
  first receive a derived scalar-vs-pipelined-TID state/output contract. No
  GTH, PA, or FPGA-ready claim follows from these behavioral results.

## 2026-09-16 10:32 +08:00 - Two-PA three-level Cartesian TID prototype

- Added `tid32_thermo3_fs4_multipa_tx`: two threshold-symmetric, `L=32`
  first-order Cartesian TID branches. The branches share acceptance and output
  readiness, so their 64-bit raw-GT words remain locked for two equal-weight
  1-bit serializer/PA paths. This is a thermometer-coded three-level TID
  implementation, not BP-EFDSM2/4.
- Added a MATLAB fixed-point transition/vector source, a 128-word two-branch
  XSim test, and a ZU15EG routed OOC flow. Checks: MATLAB-to-XSim PASS for
  128 words / 4,096 I/Q samples, zero bit mismatches on both raw streams and
  no valid-alignment failure.
- Routed OOC on `xczu15eg-ffvb1156-2-i` at 218.75 MHz PASS: WNS `+2.953 ns`,
  WHS `+0.033 ns`, TNS/THS `0`, estimated Fmax `617.88 MHz`; 11,170 LUT,
  10,732 FF, 0 BRAM, 0 DSP. Standard OOC clock-source/port warnings remain
  non-signoff limitations of OOC, not errors or critical warnings.
- The same RTL’s required regressions passed: P0 `7/7` (65,536 samples each)
  and IP smoke (top, AXI, active-reset, BP AXI, DPD v1.1).
- The ideal equal-weight combined OFDM model passes 256-QAM at actual
  19.6533203125 MHz / OSR `356.17`: EVM `1.5283 %`, SNDR `36.316 dB`, ACLR
  `-32.094 dBc`; at 99.9755859375 MHz / OSR `70.017`: EVM `1.0781 %`, SNDR
  `39.347 dB`, ACLR `-26.414 dBc`. A dual-SFP GTH payload target build,
  physical PA-combiner calibration, and board loopback/BERT are still open.

## 2026-09-16 10:54 +08:00 - Dual-SFP 14-Gb/s target closure

- Added `tid32_thermo3_gt14_dual_sfp_payload_top`: the two locked 64-bit
  thermometer code planes feed GTH `X1Y12` and `X1Y13`, sharing the 125-MHz
  reference, generated 218.75-MHz TXUSRCLK2, reset, and deterministic
  lane-distinct bring-up stimulus. This is a target-STA build, not an OFDM
  sample feeder.
- The first target build reproduced five hierarchy-specific clock-group
  critical warnings and was rejected. A payload-specific XDC with identical
  physical pins/primary clocks and no nonexistent TX/RX data crossing fixed it.
- Acceptance build `D:/TraeTemp/tid32_thermo3_gt14_dual_sfp_sta_20260916_104432/`
  produced the bitstream. Post-route STA: WNS `+0.324 ns`, WHS `+0.013 ns`,
  TNS/THS `0`; link, opt, place, phys-opt, route, and bitstream all reported
  0 critical warnings and 0 errors.
- Board loopback, physical two-PA equal-gain/phase alignment, BPF/DDC and RF
  EVM/SNDR/ACLR measurement remain required.

## 2026-09-16 - Repeatable OFDM bandwidth screen for thermo3 TID

- Ran the same ideal two-PA thermo3 TID receiver contract at 14 GS/s with
  `NFFT=16384`, `NCP=2048`, eight OFDM symbols, drive `0.35`, and five
  independent seeds (`11/29/47/71/101`).  The 229.86 MHz occupied point
  (OSR `30.454`) passed all five; the 234.99 MHz point (OSR `29.789`) also
  passed all five with EVM `3.188--3.246 %` and SNDR `29.772--29.930 dB`.
- At 237.55 MHz (OSR `29.468`) every completed seed failed the 256-QAM
  EVM/SNDR gate; 240 MHz showed mixed failures and 259.77 MHz failed all five.
  The highest repeatably tested passing point is therefore about 235 MHz;
  230 MHz is the current margin-bearing digital recommendation.  This is not
  an RF signoff because PA, clock/GT jitter, board loss, and physical filtering
  are not modeled.

## 2026-09-16 - Vector x4 interpolation and memory-DPD frontend

- Added a synthesizable ingress chain: eight complex samples per 218.75-MHz
  word, causal x2 polyphase interpolation, 16-lane shared-history 4-tap
  complex memory polynomial DPD, a second causal x2 stage, and the existing
  32-lane thermometer Cartesian TID output. The DPD supports Q1.15 complex
  coefficients for orders 1/3/5 and provides explicit cross-word tap windows.
- Added a matching fixed-point MATLAB vector generator and full-chain XSim.
  With nonzero test coefficients, 64 ingress words / 2,048 final complex
  samples produced zero mismatches on both PA raw bitstreams.
- Corrected `tid32_cartesian_fs4_gt_tx` valid handling: a bubble no longer
  repeats stale raw-GT data. Continuous raw-GT transmission remains a system
  contract; an upstream feeder FIFO must detect underflow rather than insert a
  bubble into a running RF stream.
- Checks passed: full-chain frontend XSim, P0 XSim `7/7`, IP smoke, and MATLAB
  P0 bit-true check. The ZU15EG frontend OOC has completed synthesis with zero
  errors/critical warnings and 2,064 DSP48E2; routed STA is still running, so
  no timing-closure claim is made in this entry.
- The first placed OOC result was not accepted: post-placement WNS was
  `-0.850 ns`. The four-tap DPD reduction is now a registered balanced tree;
  it preserves numerical results and adds one cycle of latency. The full-chain
  bit-true test, P0 `7/7`, and IP smoke were rerun successfully. A fresh OOC
  implementation is in progress; the interrupted prior run also reproduced a
  transient Vivado realtime-helper Tcl-file failure before HDL elaboration.

## 2026-09-16 - Frontend timing closure and RF-model boundary

- The revised `tid32_thermo3_frontend_tx_ooc` routed implementation on
  `xczu15eg-ffvb1156-2-i` now passes 218.75 MHz detailed STA: WNS `+0.255 ns`,
  WHS `+0.027 ns`, TNS/THS `0`. The implementation reported 0 errors and 0
  critical warnings. This closes the fabric OOC boundary only; it does not
  include GTH payload integration or board loopback.
- Added `run_tid32_thermo3_frontend_pa_dpd.m`, a behavioral endpoint scaffold
  for the exact `8 -> x2 -> 16-lane memory DPD -> x2 -> 32-lane thermo3 TID`
  path, two switching-PA paths, equal-weight combining, BPF/DDC, and Q2.14
  indirect-learning DPD fitting. Its first RF/DDC reconstruction fails its
  mandatory sanity check even with ideal PA paths. Consequently its present
  EVM/SNDR/ACLR values are not accepted as PA/DPD results: Fs/4 receiver
  phase, latency and reconstruction must first match the established digital
  TID receiver on the same raw-word vectors. An ideal brick-wall BPF also
  makes post-filter ACLR unsuitable as an ACLR claim.
- Re-ran the required MATLAB P0 fixed-point regression after adding the
  behavioral model: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111 and MASH22
  each passed 65,536 samples with zero mismatches. The new RF model is outside
  that P0 scope and remains blocked by its independent receiver sanity check.
- Added a separately runnable raw-word gate to the same model. It decodes both
  generated 64-bit PA words into Cartesian I/Q and compares them with an
  independently stepped scalar thermo3 reference after the known 1,056-sample
  TID latency. The gate passed with 0 mismatches, which eliminates raw-word
  order, branch polarity, and TID latency as causes of the RF-model mismatch.
# 2026-09-19 - Add optional 125-MHz AXI-stream CDC ingress

- Added `dsm_async_fifo`, per-domain reset synchronizers, and the exact 14-complex-to-8-complex CDC gearbox.
- Added the optional `tid32_thermo5_axis_frontend_tx` integration wrapper.  The existing 218.75-MHz 8-lane frontend remains unchanged.
- The ingress contract is 14 complex samples at 125 MHz and word-aligned frame starts every 56 samples.  This preserves 1.75 GS/s complex throughput and the core's frame-granular state contract.
- `run_xsim_axis14_to_core8_cdc.ps1` passed: 8 source words became 14 ordered core words without frame/gain mismatch, bubble, or underflow.
- Project RTL P0 regression passed 7/7; IP smoke passed 5/5.
- Added a two-clock CDC OOC flow.  The first Vivado run ended in `EXCEPTION_ACCESS_VIOLATION` before a timing/resource report; no CDC timing result is claimed.
- A second isolated CDC OOC reproduced the same Vivado access violation after successful `synth_design`, while loading ZU15EG timing/device information.  It also reported that the generic asynchronous-read FIFO cannot infer BRAM and is implemented in registers; this is a future PPA decision, not a functional failure.

# 2026-09-20 - Full AXI/FIFO frontend OOC baseline

- Added the thermo3 AXI/FIFO frontend wrapper and a shared ZU15EG OOC flow for thermo3 and thermo5.  Both flows include the 125-MHz AXI ingress, XPM asynchronous FIFO, 14:8 gearbox, frame gain, two x2 interpolators, and a structurally instantiated four-tap memory-polynomial DPD configured with runtime identity coefficients.
- Thermo5 identity-DPD frontend XSim passed 64 words / 2,048 complex output samples with zero raw-plane mismatches; the existing thermo3 frontend bit-true XSim also passed.  A composition XSim for the new thermo3 AXI wrapper remains pending.
- The first fully routed thermo3 AXI frontend run completed without errors or critical warnings but failed 218.75-MHz setup: WNS `-4.407 ns`, WHS `+0.001 ns`, 5,159 setup endpoints.  The worst path is the high-fanout `dpd_vector16_memory_poly` valid reduction into the second interpolator enable, with 8.416 ns of routing delay in an 8.796 ns data path.  This is a real full-chain timing failure, not a functional failure; runtime DPD coefficient ports also create OOC part-pin/clock-source warnings that must not be treated as board constraints.

# 2026-09-22 - ZU15EG GT/BERT integration entry points

- Added `ti64_raw_gt14_sfp0_bert_top.sv`, connecting the vendor GT Wizard user
  port to the PRBS31/known-word endpoint through an asynchronous RX-word FIFO.
- Added RAW RXSLIDE alignment and repeat-seed acquisition hooks, plus vendor
  behavioral simulation and implementation Tcl scripts.
- The vendor model reaches TX/RX active/done, power-good, and CDR-stable.  The
  current model still exposes variable-latency PRBS acquisition; no vendor
  BERT PASS or routed GT timing claim is made yet.
- The ZU15EG BERT top implementation then completed with 0 DRC errors and
  constrained setup/hold slack of +1.844/+0.052 ns.  This is not board BER
  evidence.

# 2026-09-22 - GT BERT training boundary and regression hardening

- Added an explicit run-arm/drain state in `gt_link_bringup_bist.sv` so the
  one-word loopback latency cannot shift the first PRBS31 word.
- Corrected the training-aware protocol assertion and hardened the XSim
  launcher to require the PASS marker and reject fatal/error diagnostics.
- Checks: GT BERT XSim PASS, P0 regression 7/7 PASS, IP smoke PASS.

# 2026-09-20 - Word-atomic DPD control and elastic timing cut

- Replaced the vector-DPD AND reductions with lane-0 word-transaction control
  and executable simulation assertions that every lane's `valid` and `ready`
  remains lockstep.  The data, history update, coefficient interface, Q2.14
  arithmetic, rounding, saturation, and temporal lane order are unchanged.
- Added `dpd_vector_elastic_buffer` between the memory-DPD and the second x2
  interpolator.  It holds one complete complex word and adds exactly one core
  clock of latency, preventing the DPD output-valid pipeline from directly
  driving the interpolator enable network.
- Replicated the second-stage interpolator's internal valid state per lane,
  with `KEEP`/`MAX_FANOUT` guidance and simulation assertions.  Lane 0 remains
  the word-level handshake, while local replicas gate their corresponding lane
  datapaths.
- Checks passed after the change: thermo3 frontend XSim and thermo5 frontend
  XSim each matched 64 input words / 2,048 final complex samples bit-for-bit;
  all new control assertions passed.  Project P0 regression passed 7/7.
- The replacement thermo3 full AXI/FIFO frontend OOC completed synthesis with
  0 errors and 0 critical warnings (2,058 DSP48E2) and is currently in
  placement/routing.  Final WNS/WHS are not yet available; the prior thermo3
  `-4.407 ns` and thermo5 `-3.968 ns` reports are explicitly pre-fix baselines.

- The replacement thermo3 routed OOC completed: 0 errors and 0 critical
  warnings, but it failed 218.75-MHz timing with WNS `-7.183 ns` and WHS
  `-0.019 ns`.  The DPD reduction path is absent from the worst path.  The new
  critical net is `u_interp_2/out_valid_reg -> u_tid/u_p/in_valid`, with
  14,294 routed loads and 11.569 ns of routing delay (zero combinational logic).
  Therefore this change is functionally correct but not a timing fix; the next
  implementation must distribute registered valid/ready at the TID plane
  boundary before rerunning thermo3 and thermo5.
2026-09-23
- Added `eda.yaml`, ASIC thermo3/thermo5 DC wrappers, source list, dual-clock SDC,
  and reproducible TSMC28 DC launcher under `syn/asic`.
- Fixed the existing 8-lane vector width declarations in the AXI thermo wrappers;
  DC elaboration had exposed the mismatch against the CDC and frame-gain ports.
- Checks: Rocky-8.10 DC V-2023.12-SP1 invoked with TSMC28 RVT TT DB; thermo3
  mapping run is active, thermo5 baseline launch previously completed only with
  the pre-fix empty/unmapped result and must be rerun after thermo3 completes.
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

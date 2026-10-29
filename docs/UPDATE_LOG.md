Warning: truncated output (original token count: 76339)
Total output lines: 4235

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
- Refreshed the PR #5 evidence head to
  `7314feeea1f4810ebb360a10ab83601dea91dc2a` after adding current-source
  non-identity 2/4-tap VDBs and regenerating the AXI-Lite URG and source-mapped
  gap ledger. This is an evidence refresh, not a new coverage-closure claim.

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
- Re-ran the longer held-out QAM256 software benc…68339 tokens truncated…ne and passing regression VDBs. URG and the exact `sample_count[24]`
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

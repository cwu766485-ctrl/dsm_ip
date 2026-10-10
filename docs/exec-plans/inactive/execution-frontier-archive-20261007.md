# Execution frontier

Latest2026-10-07 11:56 SGT: restored Formality retest actually launched at
`runs/thermo5_fm_restored_20261007_retry1/`, using the original mapped DC
netlist/SVF and matching RTL/SDC/library hashes. Formality V-2023.12-SP3
has entered verify:170869 compare points matched,0 unmatched compare
points,26148 SVF commands accepted/0 rejected. Blackbox report has no
DUT hierarchy instance paths (library-internal models only). Equivalence
is RUNNING, not PASS. Prior execution-access failure is historical. Mandatory
FPGA OOC rerun completed12/14PASS, mb_ef2=-0.093ns and mb_mash22=-0.688ns
FAIL_TIMING at `syn/reports/ooc_xc7z020clg400_1_20261007_112340/`.
Exact-bin audit reran and passes:
`runs/thermo5_coverage_reasons_20261007/`. Generic candidate disposition
line/cond/branch100%, toggle99.3461% with544 reachable directions OPEN;
raw URG stays87.48/80.26. XPM vendor5990 and proof-transfer134 remain OPEN.
See `docs/verification/thermo5-coverage-reasons-20261007.md` for bin/source/
hash reasons and measured high-counter runtime estimate. No full100% claim
or URG exclusions. FM runner supports new-output `--mapped-run` provenance;
static checks pass; await actual FM verification.
The process remains running (fm_shell_exec PID1208, parent Python PID864).
Resume by inspecting fm_shell.log/flow_manifest.json and fm_status/failing/
aborted reports; do not launch duplicate synthesis or overwrite this run.
`execution_progress.json` is an intermediate snapshot, not a PASS manifest.

Date: 2026-10-06 (Asia/Singapore)
Status: active thermo5 parent-integration closure. Current direct-route OOC
STA is positive, but its 11-ps hold margin, two GT CDC-11 paths, real I/O
timing, RX loopback, and board output remain open.

## Frozen digital target

- SKU: thermo5, two-tap interpolation, one-tap identity memory-DPD wrapper
  (`c1=1`; nonlinear and delayed coefficients are zero), real XPM FIFO.
- AXI ingress: 125 MHz, 14 complex samples per accepted beat. Core/GT TX
  user clock target: 218.75 MHz; four raw output planes are 64 bits each.
- GT target: four GTH lanes at 14.000 Gb/s/lane using an *assumed* ideal
  125-MHz dedicated MGT reference; intended IF is 3.5 GHz. SI5341 setup,
  actual board clock, analog PA, serial phase, and RF output are unverified.
- The continuous serializer emits a defined idle word between completed
  56-word frames and has no GT-side ready. PA blanking is mandatory outside
  the qualified payload interval. Parallel equality does not prove serial
  lane phase/deskew.

## Latest evidence

- Completed generic CDC residual proof at
  `runs/thermo5_coverage100_residual_exact_20261006/`: four assertions proven,
  nine covers covered, legal source stability non-vacuous, zero black boxes
  and zero selected setup issues. Constructed registered AXIS source avoids
  the large payload assumption; exact scaled 7:4 clock periods replace
  rounded 4.572 ns. Generic residual default is unreachable within this
  clock/reset model; raw URG unchanged. Earlier partial experiments retained.

- Board-free coverage follow-up: `runs/thermo5_coverage100_closure_final_20261006/`
  is PASS: fresh generic/XPM baseline plus five directed cases per FIFO,
  raw score generic 87.00% -> 87.47%, XPM 79.96% -> 80.25%. Independent
  16,387-word MATLAB stream (9,364 AXIS beats), all sixteen lane counts and
  post-stream public reset checks pass. Counter bits5:14 and all 162 prior
  TID sign rows have both directions; bits31:15 remain reachable/unhit.
  Legal signed gains close both frame-gain saturation arms; pre-first-frame
  enabled empty-core test closes generic line190 `0/1/1` and checks quietness.
- Complete raw denominators include single-instance shared reports, modules
  without condition sections, expanded XPM macros and split source pages.
  `closure_validation.json` passes exact-bin/count/hash/denominator gates.
  No coverage exclusions: frozen alternate taps, identity saturation,
  constant ports, legal-parameter errors and vendor model paths prevent raw
  full-DUT 100%. See `docs/verification/thermo5-coverage100-assessment.md`.
- Full-width counter proof with production external-tap identity configuration
  and no acceptance budget proves 35 assertions, all 35 non-vacuous, four
  covers, zero black boxes. Additional arithmetic/residual experiment is
  strict-gate FAIL: identity latency proven, four arithmetic assertions
  inconclusive; three residual invariants proven, six/nine covers hit and
  assumption vacuity inconclusive. Completed residual repeat is recorded above;
  arithmetic remains inconclusive. No raw URG exclusions are applied.
  MATLAB P0 passes seven designs x 65,536 samples with zero mismatch.
  No canonical RTL change in this follow-up. GT/I/O/RX/board remain OPEN.
- Next actions: review per-bin frozen-SKU exclusions and remaining vendor
  FIFO transitions with checker evidence; complete formal vacuity/arithmetic
  decomposition; run a correctly scoped frozen-top SpyGlass lint review.
  For RTL recruitment, finish mapped ASIC synthesis and equivalence evidence.

- Graduate-DV follow-up at `runs/thermo5_dv_package_delivery_20261006/`:
  same-build generic 87.00% -> 87.19%, XPM 79.96% -> 80.06%. Generic
  interpolation line71 `1/0` is newly covered (138 observed cycles); XPM
  baseline already covers it, with 139 directed hits. All 162 previous TID
  bit15 rows per implementation have both toggle directions. All 16 DPD
  counter bits5:10 gain both directions; bit11 gains rising only.
- Scoped production-RTL VC Formal proves stable falling-edge reset behavior
  (three non-vacuous assertions, four normal covers, collision cover
  uncoverable) and counter bounds/equality/high-zero for <=2072 accepted
  inputs (three assertions, four covers, two non-vacuous assumptions).
  Black boxes are gated to zero. Raw reset/high-counter URG gaps remain
  visible; off-model reset timing and unlimited counters remain OPEN.
- `docs/verification/thermo5-dv-portfolio.md` contains the coverage and two
  real-bug review tables. A Windows/Rocky one-command package, normalized
  diagnostics, automatic coverage summary, and CI workflow are added.
  GitHub execution requires an explicitly enabled trusted licensed runner;
  hosted CI runs syntax only. VCS compiler lint diagnostics are not a
  SpyGlass lint signoff. GT CDC-11, real I/O, RX and board remain OPEN.

- 2026-10-06 follow-up: two historical AXI-Lite commit failure mechanisms
  have passing fixed baselines and detected faulty variants in both XSim
  and VCS. See `docs/verification/commit-bug-case-studies.md`. These are
  reconstructed historical regressions on isolated current-wrapper copies,
  not modifications to canonical RTL.
- Fresh VCS baseline `runs/thermo5_gap_baseline_20261006_v1/manifest.json`
  passes all 14 directed and six independent-payload runs. Additional
  generic/XPM legal range-stress runs pass 1184 accepted beats and 2072
  independent four-plane golden words, including all 16 DPD counters.
  Same-build URG gap review is in progress; this test PASS alone closes no
  toggle row. The focused reset VCS audit passes two reset epochs/domain
  and two-edge release, with zero `1/0` samples. Both exact bins remain OPEN.

- A fresh current-source checkpoint was generated and independently routed at
  `runs/thermo5_parent_cleanroute_20261005_2117/`. Its direct end-of-route
  report is WNS `+0.264 ns`, WHS `+0.011 ns`, TNS/THS `0`, with zero setup or
  hold failing endpoints under provisional OOC I/O budgets. This is direct
  route evidence, not merely a reopened-checkpoint audit.
- The corresponding synthesis wrapper still ends nonzero on a late Vivado
  feature-license error after writing `synthesized.dcp`; it is therefore not a
  clean synthesis PASS. The independent route completed normally. The prior
  current-source run had direct WHS `-0.106 ns` but a reopened value of
  `+0.011 ns`; no `phys_opt -hold_fix` repair was inserted. Preserve that
  history; the fresh direct result is positive but its 11-ps margin is fragile.
- Fresh reset-only parent XSim in the new run directory passes 64 accepted
  AXI beats to 112 TX words, post-frame idle, power-good loss/recovery,
  TX-active loss/recovery, and common-reset recovery. RX comparison is
  intentionally skipped in that diagnostic. Full behavioral RX loopback
  remains open (`rx_clk` static/no recovered frame); PMA-loopback did not fix
  it.
- Routed CDC removes the earlier CDC-7/10 reset paths but is **not closed**:
  two critical CDC-11 paths remain from Wizard TX-active to (1) the parent
  two-flop free-run status synchronizer and (2) the generated Wizard reset
  controller. The first has directed loss/recovery evidence; the second is
  an explicit vendor `bit_synchronizer` in generated source. Neither is
  waived, false-pathed, or claimed closed. CDC-6/CDC-26 warnings remain open.
- The instance-level reset/CDC inventory is in
  `docs/verification/thermo5-reset-cdc-evidence.md`. A fresh focused real-XPM
  reset XSim passes both remote reset directions and stale-data flush. Its
  interface checks do not prove metastability or close the reported CDC rows.
- `check_timing` reports no internal unconstrained endpoints, no no-clock
  endpoints, and one expected no-input-delay asynchronous `reset_n`. The
  design still lacks real parent launch/capture min/max budgets, actual clock
  source/pin constraints, and `HD.PARTPIN_LOCS`; OOC external timing is not
  board/system STA.
- Licensed VCS UVM passes frozen thermo5 seven-case regressions for generic
  FIFO and real Vivado-XPM FIFO. Generic URG: 87.22% overall; XPM URG:
  81.38% overall (vendor hierarchy makes them non-comparable). Remaining
  instance bins are tracked in `docs/verification/thermo5-uvm-coverage.md`.
- A thermo5-specific test/checker/bin plan and separate generic/XPM
  instance-level URG inventories now exist. Fresh signed-endpoint VCS tests
  passed for both FIFOs: 32 accepted beats, 56 four-plane golden words,
  32 min-hit and 32 max-hit beats each, zero UVM errors/fatals. These are
  one-case VDBs, not a merged seven-case coverage update; residual bins stay
  OPEN as classified in the coverage record.
- Isolated XSim fault injection compiled and detected four faults (plane
  swap, PA-stall word drop, early gain, stale FIFO post-reset), each against
  a passing clean baseline; this is not a VCS-UVM mutation campaign. The
  UVM source/PA scoreboard is now fail-fast on mismatch and its complete
  generic/XPM baseline regression passed after the checker-only change.
- The one-command licensed Rocky regression in
  `runs/thermo5_frozen_regression_hardened_20261006/` passed 14 directed
  UVM cases, six independent-payload runs, and two separate URG merges,
  with zero launcher errors. New DUT hierarchy scores are 87.00% generic
  and 79.96% XPM (different hierarchy; not comparable). The fresh
  instance-level audit and OPEN gaps are in the coverage record.
- After the VCS-compatible FIFO syntax edit, focused XPM reset XSim, P0 XSim
  7/7, IP smoke, four-plane MATLAB checking, and raw-64 boundary tests pass.
  The edit only changed three reset-synchronizer `always_ff` keywords to
  clocked `always`; fixed-point and reset/data behavior did not change.

- RX timing review found a concrete diagnostic mismatch: generated GT reset HDL
  `P_CDR_TIMEOUT_FREERUN_CYC` is about 528,571 cycles at 200 MHz and 14 Gb/s
  (2.643 ms), while the parent TB times out after 5,000 cycles (25 us) and
  starts its frame without waiting for RX readiness. This is a testbench
  timing limitation, not RX closure. Extend the diagnostic wait from the
  vendor parameter and gate frame comparison on recovered RX readiness before
  deciding whether PMA loopback/data alignment is still failing. Do not claim
  RX or board output until that run passes.

## Current implementation facts

- `rtl/axis/dsm_xpm_async_fifo.sv` synchronizes write/read reset requests
  into the XPM write clock before using its common reset. Public handshakes
  remain blocked through the reset epoch and until XPM busy clears.
- `thermo5_qsfp_gt14_parent.sv` synchronizes TX-active into the 200-MHz
  free-run health domain. Raw TX-active still requests immediate PA blanking;
  synchronized loss resets the FIFO/core path. Do not add a source-side
  duplicate register: the TX user clock can stop on link loss and hide the
  falling transition.
- The generated Wizard reset controller independently synchronizes TX-active
  into its free-run reset clock and waits for it before TX reset release. It
  is a vendor-IP CDC-11 path requiring path-specific review, not a blanket
  vendor waiver.
- Current source SHA256 for `rtl/axis/dsm_xpm_async_fifo.sv` is
  `53C6143CA99AC2743A64C9C1CF09B1463EF51262D8FCD82E89362EEE70FA174B`.

## Open signoff items

2026-10-06 20:16 +08 license-restoration retest: fresh ordinary DC and
Formality startup/checkout preflight PASS at
`runs/thermo5_retest_preflight_20261006/`. Actual frozen ASIC compile_ultra
is running at `runs/thermo5_asic_retest_20261006_2016/` with two cores;
mapped synthesis/equivalence are pending. Licensed GitHub Actions retest
37462007850 completed PASS at commit a9b0bc6f67f575e9bb98085b1e064f9eddc886f2,
including the latest protocol-error reset test. Raw generic87.01->87.48%,
XPM79.96->80.26%; four formal jobs, bug controls and SpyGlass pass their
explicit gates. Lint retains39 warnings+4 synthesis warnings. Fresh exact
ledger: generic remaining reachable high-counter directions544; XPM also
retains5990 vendor records and134 generic-proof transfer records. No
exclusions/extraction gaps; configuration/arithmetic proofs are separate
from raw hits. Disposable runner has automatically unregistered. Checkout alone is not
synthesis, verification, or timing PASS. Earlier failed evidence remains.

2026-10-06 19:49 +08 DV/DE milestone: real GitHub Actions licensed DV run
37458132897 passed on review branch `dv-de-portfolio-20261006`, commit
12004bed955bdb42690ade2afe6ffce2d8dd911a. Includes same-build generic/XPM
coverage, scoped reset/bounded/unbounded counter/expanded CDC formal,
both bug negative controls, and actual SpyGlass. Ephemeral runner removed
itself after job. Local normalized evidence: `runs/thermo5_real_ci_37458132897/`.
SpyGlass zero errors/blackboxes, 39 warnings and four synthesis warnings;
two reset-use warnings remain physical RDC review items. See lint review.
Expanded generic CDC proof additionally closes marker/valid and unused
residual bits; raw URG percentages unchanged by proofs. Exact ledger keeps
reachable high counters and vendor/XPM proof transfer OPEN. ASIC frozen
2/1 identity top/dual-domain min/max SDC delivered; mapping rerun flattens
hierarchy before compile to propagate constant coefficients. Earlier
bottom-up run was stopped with no mapped result; ASIC/FM still in execution,
not PASS. Required FPGA OOC smoke is running independently.

2026-10-06 20:00 +08: gain0/max/min same-build generic test closed33
directional records (87.48%; XPM80.25%). Latest added protocol-error reset
test initially failed because old source sequence resumed into a new epoch;
test now waits for source completion before reset. CI37459008266 is FAIL,
not superseding the previous full CI PASS. Retest required. Large flattened
classic DC mapping exhausted responsiveness; Rocky WSL restart hit
HCS_E_CONNECTION_TIMEOUT. No mapped netlist/area/equivalence result yet.
Next DC attempt uses compile_ultra/max2 cores after environment recovery.
P0 XSim7/7 and IP smoke PASS. Required FPGA OOC has reproduced independent
mb_ef2 setup WNS=-0.093ns; remaining final row still running.

2026-10-06 20:09 +08 final state: Rocky recovered, but DC ultra run fails
DCSH-1 (Design Compiler not enabled), no valid license service running.
Modified license-check startup preloads are not used. ASIC mapped netlist,
Formality and numeric area remain OPEN; valid permitted license service is
the next prerequisite. Follow-up CI37460826993 cancelled after license
failures; THERMO5_LICENSED_CI disabled until service restoration. Last full
licensed CI PASS is37458132897 at its recorded commit only. Latest source
has protocol-reset driver/test correction and requires licensed retest.
Required OOC completed12/14PASS: mb_ef2=-0.093ns, mb_mash22=-0.688ns
FAIL_TIMING; never infer report PASS from command exit0. See separate
DV/DE delivery doc for delivered checks and limitations.

The DV closure sequence and exit gates are in
`docs/exec-plans/active/thermo5-dv-closure.md`. The verification matrix,
coverage inventory, four XSim mutation checks, reset/CDC evidence table,
and fresh generic/XPM regression manifest are delivered. This is a DV
milestone, not full coverage, GT, or board signoff.
The instance-by-instance follow-up order and closure rule are in
`docs/exec-plans/active/thermo5-gap-closure.md`.
The 2026-10-06 review proves the 16 fixed-identity DPD saturation arms
unreachable. The exact interpolation bin and all selected TID bit15 rows
are covered in the current same-build package. Reset and high-counter raw
URG gaps have scoped formal dispositions; behavior outside those contracts
and both GT CDC-11 paths remain OPEN. No bulk URG exclusions are applied.
Directed XSim and path audits do not substitute for matching-build URG,
formal disposition, actual parent I/O budgets, or physical GT RX recovery.

1. Keep both GT CDC-11 paths open. Obtain an AMD-supported reset/CDC
   disposition or verify a generated-IP configuration change; do not suppress
   either path. Review residual CDC-6/CDC-26 by instance and clock/reset use.
2. Obtain actual source clocks, clock-generator configuration, package pins,
   and launch/capture min/max delays. Apply them at the parent and rerun
   route, `check_timing`, clock interaction, CDC/RDC, and recovery/removal.
3. Resolve GT RX user-clock/data recovery, then require all 56 words on four
   lanes across normal, loss/recovery, and reset replay. Define deskew and PA
   blanking latency from board/PA data before hardware/RF claims.
4. Close UVM bins one by one with a hit, configuration proof, or explicit
   `OPEN` disposition. Keep generic and vendor-XPM coverage databases apart.
5. Do not claim board output until board power, MGT reference configuration,
   and physical four-lane connectivity are verified.

## Reproducible commands

Run from repository root and preserve a unique output directory.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_thermo5_qsfp_gt14_parent.ps1 -Stage synth -OutDir .\runs\thermo5_parent_<id>
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\route_thermo5_qsfp_gt14_parent_from_synth.ps1 -OutDir .\runs\thermo5_parent_<same-id>
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_thermo5_qsfp_gt14_parent_sim.ps1 -OutDir .\runs\thermo5_parent_<same-id> -SkipRxCompare
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_xpm_async_fifo_reset.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_ip_smoke.ps1
```

For licensed Rocky/VCS generic/XPM UVM commands, use `dv/uvm/sim/README.md`.
XPM requires `THERMO5_XPM_ROOT` pointing to the Windows Vivado 2024.1 mount.

## Handoff discipline

- Update this file, the CDC contract, coverage record, and `UPDATE_LOG.md`
  after each material pass/fail or next-action change.
- Preserve logs/DCPs and do not commit generated artifacts, PDK/vendor
  collateral, licenses, or board secrets.

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

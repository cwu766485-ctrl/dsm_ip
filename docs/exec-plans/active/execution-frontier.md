# Execution frontier

Updated: 2026-10-09 14:12 SGT. Status: active, board-free graduate DV/DE closure.
This is the source of truth for current execution state. Detailed next actions
and exit gates are in [the closure plan](thermo5-gap-closure.md).

## Target and source of truth

- Digital DUT: `tid32_thermo5_axis_frontend_tx`, W16, INTERP_TAPS2,
  DPD_MAX_TAPS1, identity coefficients, low-power control disabled.
- DV: generic and real XPM FIFO compiled/reported separately. Filelist:
  `dv/uvm/sim/thermo5_sku_filelist.f`; MATLAB is the independent bit-true oracle.
- ASIC: `syn/rtl/thermo5_frozen_asic.sv`, generic FIFO; sources and constraints:
  `syn/asic/thermo_frontend_dc_sources.f`, `syn/asic/thermo5_frozen.sdc`.
  The default `eda.yaml` thermo3 top is a different configuration.
- Clocks: AXI125 MHz, core218.75 MHz. One32-beat frame yields56 ordered
  four-plane64-bit words. Preserve widths, signedness, reset, latency and oracle.
- Canonical paths: RTL `rtl/`, directed DV `dv/verif/`, UVM/formal `dv/uvm/`,
  ASIC flows `syn/asic/`, vendor/board boundary `fpga/`. No board is available.

## Current evidence

| Workstream | Actual result | Evidence / remaining limit |
| --- | --- | --- |
| Licensed DV and hosted CI | Local current-source package PASS; hosted CI OPEN | Fresh Rocky package `runs/thermo5_current_source_dv_resume_20261008/dv_package.json`: coverage, formal and bug jobs PASS for digest `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8` (202 RTL/DV files). GitHub Actions37462007850 applies only to commit `a9b0bc6f67f575e9bb98085b1e064f9eddc886f2`; no hosted result covers the dirty source. |
| UVM/scoreboard and coverage | Same-source bit22 long-stream PASS; full coverage OPEN | Generic/XPM each passed 4,194,309 output words bit-true; all16 DPD counters reset; zero UVM errors/fatals. Raw URG is87.16%/80.12%. `sample_count[22]` both directions hit in all16 lanes for both FIFOs; adjusted report remains bit21-only. |
| Exact XPM reset bins | Core-first test complete; exact residual rows remain OPEN | Latest same-binary report and exact deltas: `runs/thermo5_gap_closure_fwftmon_20261008/exact_final_delta.json`. Line52 tuple `1/0` changed Not Covered -> Covered; line57 tuple `1/1/1/0` and line59 tuples `1/0/1/1`, `1/1/1/0` stay OPEN. |
| Counter and other coverage gaps | Partial coverage remains OPEN | Bit22 raw URG covers both directions for `sample_count[22:0]` in all16 instances. Bits31:23 remain288 reachable directions/FIFO OPEN; never waive these. Generic has four interpolation lines/arms open. XPM has vendor line/condition/branch/toggle gaps and `stage1_valid->invalid` OPEN (8/9). |
| Scoped VC Formal | Scoped milestones proven; full payload OPEN | Oct7 DPD19/20 assertions proven including no-saturation/count-zero; full identity payload inconclusive. Valid interpolation16 assertions/5 covers PASS; actual XPM residual7/9 PASS; legal XPM reset2 assertions/4 covers/2 unreachable reentries PASS. Qualified FWFT cover inconclusive. Exact matching-source manifests in convergence record. |
| Exact missing-bin audit | AUDITED_OPEN | `runs/thermo5_coverage_reasons_20261007/`: every missing code/condition/signal and reason; exact XPM FSM transitions. Not an URG exclusion/signoff report. |
| SpyGlass | Zero errors/blackboxes; review OPEN |39 warnings +4 synthesis warnings; two physical reset-use/RDC items remain. See lint review. |
| Two real bug reconstructions | Fixed/faulty controls PASS | Both XSim and VCS reproduce historical AXI-Lite commit mechanisms on isolated copies. See bug walkthrough. |
| Fault injection | Four XSim mutants detected; VCS-UVM attempt blocked before compile | Fresh XSim evidence `runs/thermo5_fault_detection_xsim_20261009/summary.txt`: PA-plane swap, stall corruption, late gain and stale FIFO reset all detected. New runner `dv/uvm/sim/run_thermo5_fault_detection_vcs.py`; first compile attempt could not connect to VCS license server, so VCS mutation status remains OPEN. |
| Clean local CI syntax | PASS; hosted current-source CI OPEN | New clean scratch-copy syntax check `runs/thermo5_clean_ci_syntax_20261009/`; it is not a clean licensed regression nor a GitHub Actions result. Workflow syntax list includes the new runner/helper. |
| ASIC DC mapping | PASS | `runs/thermo5_asic_retest_20261006_2016/`: mapped Verilog/DDC/SDC/SVF, zero unmapped cells,544463 cells,170605 sequential; area507779.648216 library units. |
| ASIC pre-layout timing | Partial; constraints OPEN | Setup slack clk125 +6.79ns / clk218 +1.76ns; minimum reported hold0.00ns. Max-capacitance and zero leakage-target violations remain. TT/ideal clocks/assumed I/O budgets are not physical signoff. |
| RTL/netlist Formality LEC | PASS | `runs/thermo5_fm_restored_20261007_retry1/`:170869 matched compare points,0 unmatched,26148 SVF commands accepted/0 rejected. No DUT hierarchy blackbox paths. All170869 compare points equivalent, zero failing/aborted; PASS manifest and unchanged mapped artifacts. |
| Required Windows checks | Existing P0/IP smoke PASS; OOC12/14 | P0 XSim7/7 and IP smoke recorded PASS. Fresh Oct7 OOC reproduces mb_ef2 -0.093ns / mb_mash22 -0.688ns FAIL_TIMING; `syn/reports/ooc_xc7z020clg400_1_20261007_112340/summary_all.csv`. |
| FPGA parent/GT/board | OPEN | Direct route WNS +0.264ns / WHS +0.011ns under provisional budgets; two GT CDC-11 paths, real I/O, RX recovery, serial deskew and board/RF output remain OPEN. |

## Current-source package and exact remaining ledger

The fresh Rocky licensed package completed on the current dirty source with
digest `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`
(202 RTL/DV source files). Coverage, scoped formal and historical bug controls
all PASS. Its same-binary 131075-word closure measured generic87.49% and
XPM80.27%. Bit18/19/20/21/22 long streams passed on generic and real XPM.
Latest bit22 raw URG scores are generic87.16% and XPM80.12%; reviewed adjusted
views are bit21-only at99.66%/96.71%, not100%. `sample_count[22:0]` toggles
both ways in all16 counters/FIFO; bits31:23 remain reachable/open (288
directions/FIFO). The 4,194,309-word integer oracle first matched all eight
files of its MATLAB-validated fixture. Seeds610078/610079 then passed
4,194,309 four-plane output words with zero UVM errors/fatals and the public
reset/all-counter check. Same-binary URG confirms bit22 in 16/16 instances for
both FIFO builds. Logs and raw reports are under
`runs/thermo5_frozen_regression_fwftmon_20261008/` and
`runs/thermo5_bit22_urg_20261008/`. Hosted current-source CI remains OPEN.
An initial optional bit18 MATLAB vector attempt stopped after about32minutes
near the30-minute resource cap before writing vectors; its record remains at
`runs/thermo5_bit18_20261008/attempt.json`. A later MATLAB process also ran
for about four hours without output and was stopped after its exact command
and empty target were verified. The independent NumPy integer oracle matched
all eight outputs of a MATLAB fixture and generated 262150 words. Same-source
generic and XPM VCS tests passed; exact same-binary URG confirms bit21 in both
directions for all16 DPD counters/FIFO. The bit21 logs show 2,097,158 output
words checked and all16 lane counters cleared. Full details:
`docs/verification/thermo5-reachability-closure-20261008.md`.

## Remaining priority

1. Current generic/XPM raw counter remainder:288 reachable directions across
   bits31:23 in all16 DPD counters; later high bits remain OPEN until hit.
   Generic retains four interpolation
   clamp lines and four branch arms; valid-payload proof does not cover invalid
   startup payload evaluation.
2. Current XPM adjusted view still has vendor line/condition/branch/toggle
   bins and one FWFT transition OPEN. Nineteen exact vendor candidates did not
   map to native signatures and are not excluded. Current manifests/reports:
   `runs/thermo5_bit21_reviewed_exclusions_20261008/`.
3. Historical Oct7 XPM candidate counts (15 lines,32 conditions,461 toggle
   directions,50 branches,one FWFT transition) are superseded by the bit21
   exact raw/adjusted inventory. Do not reuse those old counts as current.
   Historical CSVs remain under
   `runs/thermo5_followup_long_20261007/remaining_final/`; current vendor
   signature mappings and unreviewed records remain OPEN.
4. Keep the XPM FWFT `stage1_valid->invalid` transition OPEN: the final
   same-binary full-run report for this source is8/9 (the earlier isolated
   experiment-only report was7/9). The legal common-reset attempt observed
   stage1_valid with `rd_rst_i=0` but did not hit the transition. Do not force
   internal pins or exclude it; continue reset-default and memory collision/
   clock-window goals with exact native signatures and denominators.
5. The parent drives both public reset requests in one epoch. A source-only or
   core-only **full-chain** reset is outside that parent contract. The legal
   common-assert/core-first-release test now hits line52 tuple `1/0`; remaining
   line57/59 rows stay OPEN as listed in the exact delta report.
6. Next natural threshold is bit23. A complete 8,388,615-word run is estimated
   at roughly 105 minutes per FIFO using measured bit22 wall throughput; first
   bit31 is roughly 19 days per FIFO. These are cost estimates, not proofs of
   unreachability. Never relabel unrun reachable bins as unreachable.
7. Restore VCS license connectivity and run the new VCS-UVM fault runner; then
   dispatch licensed CI from a clean checkout. XSim mutation controls pass, but
   that does not close the VCS-UVM fault-injection request.
8. Review physical lint/RDC, ASIC cap/leakage constraints and measured stalled
   throughput; actual mapped LEC is already PASS and needs no repeated run until
   implementation changes.
9. Board clocks/pins/parent I/O/RX/serial deskew/RF output remain independent OPEN
   work. No board is available; digital coverage does not imply board signoff.

Never rename partial adjusted scores or analytical disposition accounting100%.
The source of truth is actual URG plus exact remaining bins and proof contracts.

## Evidence navigation and maintenance

- [Coverage reasons](../../verification/thermo5-coverage-reasons-20261007.md)
- [DV/DE delivery](../../verification/thermo5-dv-de-delivery.md)
- [SpyGlass review](../../verification/thermo5-spyglass-review.md)
- [Two bug walkthroughs](../../verification/commit-bug-case-studies.md)
- [Oct 9 coverage/fault/CI resume](../../verification/thermo5-coverage-resume-20261009.md)
- [Reset/CDC evidence](../../verification/thermo5-reset-cdc-evidence.md)
- Tool commands: `dv/uvm/sim/README.md`, `dv/uvm/formal/README.md`,
  `docs/ai-native/commands.md`. Use unique run directories and source hashes.

Update this frontier and `docs/UPDATE_LOG.md` after a material result or next-action
change. Keep generated reports, vendor/PDK files and licenses out of commits.
Historical plans are under `../inactive/`; their scores/blockers are historical.

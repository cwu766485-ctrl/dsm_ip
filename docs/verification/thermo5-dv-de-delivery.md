# Thermo5 DV and DE delivery

Updated 2026-10-07. This portfolio uses the frozen 16-bit thermo5 SKU:
interpolation 2, DPD1 identity, generic/XPM independently compiled.

## DV evidence

Latest real GitHub Actions run [37462007850](https://github.com/cwu766485-ctrl/dsm_ip/actions/runs/37462007850)
passed both hosted syntax and licensed Rocky jobs on commit
`a9b0bc6f67f575e9bb98085b1e064f9eddc886f2`. Licensed execution includes
VCS/UVM independent scoreboard, same-build URG, scoped VC Formal,
both historical bug negative controls, and actual SpyGlass. Normalized
evidence is in `runs/thermo5_real_ci_37462007850/`. A disposable self-hosted
runner was registered and removed automatically at completion. Main is
unchanged; review branch is `dv-de-portfolio-20261006`.

| Coverage gap | Cause | Legal stimulus / proof | Checker | Same-build URG result |
| --- | --- | --- | --- | --- |
| TID bit15, 162 measured rows | Previous payload range missed signed endpoints | Full signed endpoint and long range-stress MATLAB streams | Four independent bit-true PA planes plus source monitor | All 162 hit in both directions, generic and XPM |
| DPD sample counter bits5:14, 16 lanes | Short stream | 9364 accepted beats /16387 checked words then public reset | Output scoreboard and all16 counter reset checks | Both directions hit; bit14 fall is public reset |
| Interp1 exact empty/blocked condition | Fixed-cycle stalls missed internal occupancy | Generate ready/stall from observed state | Full ordered PA scoreboard | Generic line71 exact operand bin hit; XPM already covered |
| Frame-gain positive/negative saturation | Unity/modest gain | Legal Q2.14 gain32767/-32768/24576 and endpoints | Independent saturated MATLAB vectors | Both saturation line/branch arms hit |
| Gain low11-bit rise | Previously only falling transitions | Legal gain0 then32767 then-32768 | MATLAB56-word oracle | Additional generic33 directional records closed; raw score87.48 |
| Runtime reset collision operand | Active-edge simulator collision | Falling-edge runtime reset harness | Three nonvacuous assertions and normal covers | Scoped formal uncoverable; raw URG retained |
| Illegal residual/default and unused high residual data | Architecture has seven even populations | Production generic FIFO, exact7:4 clock periods | Seven assertions proven, nine covers hit | Scoped proof; no URG exclusion; XPM transfer remains OPEN |
| Counter bits31:15 | Legal but billions of acceptances for highest bits | Unbounded32-bit carry/increment/hold proof | Independent ghost acceptance count | Reachable and raw-unhit, stays OPEN |

Latest same-build raw scores: generic87.01% ->87.48%, XPM79.96% ->80.26%.
The latest illegal-frame test passes its public-reset sticky-error clear
check for both implementations. Four formal jobs pass: reset3 assertions,
bounded counter3, unbounded counter35, generic CDC residual7; zero blackboxes.
Unified diagnostics contain12 expected negative-control records,3 compiler
warnings and no unexpected checker/assertion failures. Hierarchies
differ, so compare each FIFO to its own baseline. No exclusions are applied.
The fresh exact ledger under `runs/thermo5_real_ci_37462007850/ledger/`
records line bins, branch decision vectors, condition expressions, and
individual toggle directions, with source hashes and explicit OPEN entries.
URG Total Bits sums the two directional totals; individual missing-direction
records reconcile to that denominator. The original saved ledger note is
incorrect and is corrected in the current ledger generator/reason audit.

SpyGlass: zero errors/blackboxes, 39 warnings and four synthesis warnings;
see [individual review](thermo5-spyglass-review.md). Reset-use warnings still
require physical RDC/STA review. Two bugs have fresh VCS and XSim fixed/faulty
checks and an [interview walkthrough](commit-bug-case-studies.md).

## DE boundary

`syn/rtl/thermo5_frozen_asic.sv` adds a distinct explicit2/1 identity ASIC
top with generic FIFO; original4/4 configurable wrappers are preserved.
`syn/asic/thermo5_frozen.sdc` separates125/218.75MHz input/output domains,
min/max0.10/0.40ns assumed IP I/O budgets, setup/hold uncertainty0.10/0.05ns,
transition0.10ns, load5fF, asynchronous clock groups. It keeps reset
recovery/removal checks. Budgets are assumptions, not parent/board provenance.

Source filelist omissions for both vendor-neutral GT data boundary modules
were fixed; `link` failure is fatal. DC exports SVF, actual mapped netlist/DDC,
SDC and area/setup/hold/constraint/unit reports. Formality compares original
RTL against that actual netlist with the permitted cell DB and SVF.
`syn/asic/run_thermo5_frozen.py` records source/library hashes and exit gates.
No mapping, equivalence, area or frequency PASS is inferred before execution.

Actual DC mapping is PASS at `runs/thermo5_asic_retest_20261006_2016/`:
544463 mapped cells, area507779.648216 library units, zero unmapped cells
and zero macros/blackboxes. RTL/netlist equivalence remains OPEN. A fresh
isolated Formality V-2023.12-SP3 retry launched2026-10-07 11:22 SGT at
`runs/thermo5_fm_restored_20261007_retry1/` after the user restored the feature;
it has entered verify with170869 matched compare points and0 unmatched
compare points;26148 SVF commands accepted,0 rejected. Old license/option failures
are retained as historical evidence, not the current result. See the mapped
result below for timing/constraint limits; there is no equivalence PASS yet.

Latest follow-up CI37459008266 failed on an old source sequence resuming into
a new reset epoch. Stimulus now waits for all source beats before reset and
joins both threads; latest CI37462007850 now verifies this fix. CI37460826993
started after WSL recovery but tool licenses were unavailable; cancelled,
licensed CI was disabled pending valid service and has now been restored.
Earlier failed/cancelled runs remain historical evidence.

Required Windows checks: P0 XSim7/7 PASS; IP smoke PASS. Required FPGA OOC
completed14 configurations:12PASS, `p0_ooc_mb_ef2` WNS=-0.093ns and
`p0_ooc_mb_mash22` WNS=-0.688ns FAIL_TIMING. Command process exited normally
but report gates fail for those two configurations. This is independent of
thermo5 ASIC mapping. Reports:
`syn/reports/ooc_xc7z020clg400_1_20261007_112340/summary_all.csv`
(fresh2026-10-07 rerun reproduces the same12PASS/2FAIL).

Architectural ideal rate at218.75MHz (one word/cycle, no stalls):
14 x125MHz =8 x218.75MHz =1.75G complex input samples/s;
two x2 stages give7G complex interpolated samples/s;
each64-bit PA plane carries14G code bits/s, four planes56G bits/s aggregate.
These are port-level arithmetic limits; measured sustainable throughput
and mapped timing must be reported separately. There is no14GHz internal clock.

Physical board output, RX recovery, two GT CDC-11 paths and actual parent
I/O timing budgets remain separate OPEN integration items.

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
Earlier equivalence-only retest on2026-10-07 failed License Failure(-16):
Not authorized for feature Formality. No RTL/netlist equivalence result
exists; latest flow_manifest.json is FAIL for the equivalence-only attempt.
The restored-license DV CI37462007850 remains PASS at its recorded commit.
Latest restored-feature retry is RUNNING in the fresh directory above.
Next: inspect actual verify/failing/aborted/blackbox results and close the
cap/leakage constraint items.
Do not rerun the completed multi-hour synthesis just for the FM option fix.

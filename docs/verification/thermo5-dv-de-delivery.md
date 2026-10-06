# Thermo5 DV and DE delivery

Updated 2026-10-06. This portfolio uses the frozen 16-bit thermo5 SKU:
interpolation 2, DPD1 identity, generic/XPM independently compiled.

## DV evidence

Real GitHub Actions run [37458132897](https://github.com/cwu766485-ctrl/dsm_ip/actions/runs/37458132897)
passed both hosted syntax and licensed Rocky jobs on commit
`12004bed955bdb42690ade2afe6ffce2d8dd911a`. Licensed execution includes
VCS/UVM independent scoreboard, same-build URG, scoped VC Formal,
both historical bug negative controls, and actual SpyGlass. Normalized
evidence is in `runs/thermo5_real_ci_37458132897/`. A disposable self-hosted
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

Raw scores in the first complete CI: generic87.47%, XPM80.25%. Hierarchies
differ, so compare each FIFO to its own baseline. No exclusions are applied.
The exact ledger under `runs/thermo5_dv_de_delivery_20261006/ledger/`
records line bins, branch decision vectors, condition expressions, and
individual toggle directions, with source hashes and explicit OPEN entries.
Counts of directional records must not be called raw URG bit denominators.

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

Current DE execution is BLOCKED: classic hierarchical and flattened DC runs
were stopped without mapped netlists; after recovering unresponsive Rocky,
`runs/thermo5_asic_ultra_delivery_20261006/dc_shell.log` reports
`Fatal: Design Compiler is not enabled. (DCSH-1)`. A valid permitted license
service is required before the next compile_ultra run. Modified license-check
preloads found in local startup configuration are not used for recovery.
There is no actual ASIC cell-area number or RTL/netlist equivalence PASS yet.
Scripts are delivered, execution remains OPEN.

Latest follow-up CI37459008266 failed on an old source sequence resuming into
a new reset epoch. Stimulus now waits for all source beats before reset and
joins both threads; that fix still needs licensed retest. CI37460826993
started after WSL recovery but tool licenses were unavailable; cancelled,
licensed CI disabled pending valid service. The earlier real CI PASS applies
only to its recorded commit, not the later untested changes.

Required Windows checks: P0 XSim7/7 PASS; IP smoke PASS. Required FPGA OOC
completed14 configurations:12PASS, `p0_ooc_mb_ef2` WNS=-0.093ns and
`p0_ooc_mb_mash22` WNS=-0.688ns FAIL_TIMING. Command process exited normally
but report gates fail for those two configurations. This is independent of
thermo5 ASIC mapping. Reports:
`syn/reports/ooc_xc7z020clg400_1_20261006_193000/summary_all.csv`.

Architectural ideal rate at218.75MHz (one word/cycle, no stalls):
14 x125MHz =8 x218.75MHz =1.75G complex input samples/s;
two x2 stages give7G complex interpolated samples/s;
each64-bit PA plane carries14G code bits/s, four planes56G bits/s aggregate.
These are port-level arithmetic limits; measured sustainable throughput
and mapped timing must be reported separately. There is no14GHz internal clock.

Physical board output, RX recovery, two GT CDC-11 paths and actual parent
I/O timing budgets remain separate OPEN integration items.

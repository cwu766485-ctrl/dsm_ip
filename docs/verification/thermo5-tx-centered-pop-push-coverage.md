# Thermo5 TX Centered-Cubic Pop/Push Coverage Closure

Date: 2026-10-31  Product source SHA: `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`

## Result

A legal two-frame AXI-Lite product test now reaches both Centered-Cubic
single-entry pop/input Branch arms at
`rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:255`. The 11-cycle
inter-frame source-valid gap (`THERMO5_SOURCE_GAP_BEAT=32`, seed `610901`)
produced `stage1=1 stage2=1`; the independent four-plane bit-true checker
matched all 112 output words from 64 source beats and two TLAST markers. The
run reported zero UVM warnings, errors, fatals, and protocol errors.

The Raw URG union added exactly two Branch bins, two Condition bins, and 14
Line bins. Toggle coverage did not change. Raw denominators are unchanged;
there are still zero approved waivers and zero `.el` exclusions. The gate
remains `RAW_100_OPEN`.

| Metric | Before | After | Delta |
|---|---:|---:|---:|
| Branch | 520/637 (81.6327%) | 522/637 (81.9466%) | +2 |
| Condition | 601/849 (70.7892%) | 603/849 (71.0247%) | +2 |
| Line | 3,334/3,796 (87.8293%) | 3,348/3,796 (88.1981%) | +14 |
| Toggle | 83,575/104,480 (79.9914%) | 83,575/104,480 (79.9914%) | 0 |
| Legal Functional Coverage | 210/210 | 210/210 | 0 |

## Exact target bins and legal stimulus

The previous source-linked Raw ledger identified these exact unhit Branch
records:

| Closure task | Prior Raw Bin ID | Instance | Source decision |
|---|---|---|---|
| `TXB-9141942b3f6f51689217` | `4796580247344dc2c731` | `u_interp_1` | `182:0/0/-/-/-/-/-/1/0/-/1/-/-` |
| `TXB-33db6d34081fd3b6ec60` | `f2b36b12b909c892747f` | `u_interp_2` | `182:0/0/-/-/-/-/-/1/0/-/1/-/-` |

The new report no longer lists either exact decision path as an uncovered
Branch arm; each stage's public testbench event counter observed its
`pop_head && q_count != 2 && push_input` case. The new source-linked ledger
therefore contains only current Raw misses. It has 21,714 records: 372 remain
`PROVEN_UNREACHABLE` under the existing Formal/static review, and 21,342 are
`OPEN`. No newly uncovered record was waived or reclassified as unreachable.

The sweep tried source gaps of 1 through 11 cycles, stopping once both target
instances hit. All 11 runs passed the bit-true and protocol checks. Gaps 1–10
did not hit either target; gap 11 hit both. The raw VCS logs and VDB trees are
under the ignored directory
`runs/thermo5_tx_centered_pop_push_gap_closure_20261031_pr22/`; their command,
log, VDB tree, and SHA-256 inventory is recorded in
`gap_phase_sweep.json` there. The fresh URG merge command and report are in
the same run directory.

## Underflow observation and limits

For the 11-cycle inter-frame run, the monitor reported 50 total underflow
cycles and zero `underflow_before_last_source` cycles. The test's checked
contract is no underflow before all 64 source beats are accepted; the total
counter spans later drain/idle time too. Because those 50 cycles are not
partitioned by packet phase, this run does **not** settle whether all legal
source gaps are supported by the interface. The 16-cycle case remains
`OPEN`; its existing test fails on 54 underflows while still producing 112
words. Do not infer an unlimited-gap/service-rate guarantee from this result.

## Reproduction and evidence

The run reused the unchanged VCS V-2023.12-SP1 product binary built from the
75-source compile manifest; product RTL, testbench source, coverage hierarchy,
and algorithms were not modified. The exact per-run command is saved as
`source_gap<N>.command.txt` for each tested gap `N=1..11`. The URG merge used
the original 13-test product VDB set plus the 11 directed VDBs. Python
coverage inventory and the fail-closed gate were regenerated from that Raw
report.

Tracked current closure data is in
`data/thermo5-tx-current-source-gaps/`: the compressed per-bin ledger, task
table, summary, functional bin audit, and root-cause manifest. The Raw report
remains unadjusted. This increment does not constitute final TX signoff;
21,342 Raw code bins remain open, including the remaining Branch,
Condition/Line, and Toggle tasks. DPD Identity Formal, source-gap contract,
complete GT Parent payload verification, real XPM/GT Wizard, FPGA PPA, and
physical QAM256 BER also remain open or outside this Linux scope.

The machine-readable refresh summary is
[`thermo5-tx-centered-pop-push-evidence.json`](data/thermo5-tx-centered-pop-push-evidence.json).
The original 13-test witness used by Formal reviews is unchanged.

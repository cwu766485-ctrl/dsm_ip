# Thermo5 DV/DE remaining closure plan

Updated: 2026-10-08 12:43 SGT. Goal: graduate IC verification/design evidence with explicit
PASS, HIT, scoped proof and OPEN boundaries. Current results live only in
[execution-frontier.md](execution-frontier.md); this plan defines remaining work.

## P0: Preserve completed LEC and convergence evidence

Formality `runs/thermo5_fm_restored_20261007_retry1/` is PASS:170869 compare
points equivalent, zero failing/aborted/unmatched, matching DC netlist/SVF.
Repeat only after a relevant RTL/mapped implementation change. Do not keep this
completed task as an active license/LEC blocker.

Oct7 baseline20 cases and24 directed closure cases PASS. The latest-source
Oct8 frozen generic/XPM regression and independent131075-word same-build
closure also PASS. RTL/DV digest is
`0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`. Final
raw scores are87.49% generic and80.29% XPM after core-first release and a
same-binary FWFT-target test; adjusted scores were not recomputed. Exact
evidence is `runs/thermo5_gap_closure_fwftmon_20261008/closure.json` and
`runs/thermo5_gap_closure_fwftmon_20261008/exact_final_delta.json`; the earlier
[convergence record](../../verification/thermo5-convergence-20261007.md)
remains a separate historical checkpoint. Rocky WSL and the Synopsys license
responded on Oct8. Hosted current-source CI remains unrun.

## P1: Close the coverage ledger

Each selected reachable bin requires four linked pieces of evidence: unhit
reason, legal stimulus, independent scoreboard/checker, and before/after URG
from the same compiled source/configuration. Keep generic/XPM builds separate.

| Target | Next concrete action | Acceptance evidence |
| --- | --- | --- |
| DPD counters bits31:18,16 lanes | Completed milestone:131075 independent output words traverse bit17 and public reset in all16 lanes;448 directions/FIFO remain. Continue only affordable legal milestones. | All four PA planes match, accepted-count checks for all16 lanes, reset zero checks, exact directional URG deltas. No force/deposit, reduced counter width or VDB editing. |
| Higher counter bits | Use `reachable_counter_plan.csv` to estimate cost and choose stream budgets; retain full32-bit transition proof. | A proof validates behavior, not a simulation hit. Bit31 rise needs2^31 accepted words; current linear estimate is about18days per FIFO before oracle costs. Unexecuted directions stay OPEN. |
| Frozen alternate taps/constant controls/parameter errors | Review exact elaboration parameters, predicates and source hashes per record. | Configuration disposition applies only to this SKU; changing taps/coefficients/low-power mode reopens it. No blanket source-file exclusions. |
| DPD/interpolation saturation | Decompose arithmetic bounds from pipeline hold/update behavior; retain exhaustive scalar corroboration and analytical average bound. | Scoped assertions proven, meaningful covers/vacuity, no blackboxes. Oct7 DPD no-saturation/count-zero bounds proven; full identity payload remains inconclusive. Valid interpolation bounds proven; invalid-slot evaluation is outside that proof and remains in URG. |
| Reset condition1/0 | Review falling-edge reset contract and vacuity evidence. | Scoped unreachable result and normal covers remain separate from raw URG; no active-edge simulation race used as stimulus. |
| XPM residual/default/high-data paths,134 records | Completed actual-XPM scoped residual proof7 assertions/9 covers. Preserve hash-checked scope and exact exclusions; review broader reset requests independently. | Exact model/configuration/reset assumptions, zero unexpected blackboxes, nonvacuous assertions/covers. Interface-only simulation does not establish full transfer. |
| XPM FSM `stage1_valid->invalid`, line1277 | A read-only monitor observed stage1_valid and `rd_rst_i=0` before legal common public reset; same-binary test passed full replay. | Transition remains OPEN (8/9); exact delta at `runs/thermo5_gap_closure_fwftmon_20261008/exact_final_delta.json`. Vendor next-state advances on the next read edge before synchronized public reset arrives in this tested path. No force/deposit, exclusion, or general unreachability claim. |
| XPM wrapper reset-release rows at lines52/57/59 | Core-first release after common assertion hit line52 tuple `1/0`; 56-word four-plane replay and no-handshake reset checker passed. Exact same-binary before/after URG is in the linked delta. | Line57 tuple `1/1/0/1` is already covered in the full frozen baseline. Line57 tuple `1/1/1/0` and line59 tuples `1/0/1/1`, `1/1/1/0` remain OPEN. |
| XPM `WRST_OUT->WRST_IN`1759 / `WRST_EXIT->WRST_IN`1767 | Completed scoped proof: new reset request only after busy ends;2 assertions proven,4 normal covers,2 reentry goals uncoverable. Exact corresponding transitions/line/branch exclusions applied. | State-specific trigger trace, no stale output, fresh replay, matching URG; or reviewed scoped proof. No vendor-source modification. |
| Remaining XPM records | Some reviewed entries still lack native URG mappings. Latest adjusted remainder15 line/32 condition/461 toggle directions/50 branch plus FWFT transition; inspect `runs/thermo5_followup_long_20261007/remaining_final/` and [exact follow-up](../../verification/thermo5-xpm-exact-followup-20261007.md). | Every record has reviewed evidence or explicit OPEN. Vendor ownership alone is never an exclusion. |
| Independent source/core reset requests in full-chain UVM | Keep simultaneous public reset assertion, with an allowed core-first release order; do not use single-sided reset requests for this parent contract. | The two wrapper lines documented above are covered only where exact URG reports show them. Other rows and physical RDC remain separate OPEN work. |

Full100% is not an unconditional raw-DUT target for a frozen SKU containing
constant/disabled/error paths. Any adjusted result requires reviewed per-bin
exclusions and an actual URG report; preserve raw scores and unresolved bins.

## P2: Complete DE and lint engineering evidence

- Resolve ASIC `rd_bin_q[3]` max-capacitance with higher precision/load/fanout
  analysis and an implementation fix if required. Review the zero leakage target
  against a justified power budget; do not remove a valid constraint to get PASS.
- After any mapped change, rerun DC checks/setup/hold/constraints, export new
  netlist/SDC/SVF and repeat LEC against matching sources. Preserve old evidence.
- Report area in library units until the permitted unit basis is established.
  Architectural input1.75G complex samples/s and aggregate56G code bits/s are
  ideal limits. Measure accepted transactions/elapsed clocks under stalls.
- Review the two physical reset-use/RDC lint items by instance and reset contract;
  keep39 lint warnings +4 synthesis warnings visible and justified individually.

## P3: Keep regression and interview claims reproducible

Use existing launchers: `dv/uvm/sim/run_thermo5_dv_package.py`,
`dv/uvm/formal/run_thermo5_scoped_formal.py`, `syn/asic/run_thermo5_frozen.py`
and `.github/workflows/thermo5-dv.yml`. Record commit/source hash, tool version,
seed, binary/VDB, checker counts, diagnostics and exit status for every repeat.

For meaningful source/test changes, run matching-build baseline/directed URG,
formal and SpyGlass as applicable, then the trusted licensed CI job. Update the
coverage and bug evidence tables against the exact run, not a newer untested
working tree. Hosted syntax alone is not licensed DV execution.

Both real bug reconstructions already have fixed/faulty XSim/VCS controls and
an interview walkthrough. Extend those only when new implementation/checker
changes affect them; avoid repeating completed work as a new open deliverable.

## P4: Separate integration limitations

Board-free work can review two GT TX-active CDC-11 paths, validate RX diagnostic
wait/readiness against vendor CDR timing, and exercise behavioral loss/recovery.
RX closure requires all56 words on four lanes after recovery/reset replay.
Actual clocks/pins/parent I/O min/max, serial deskew, board output and RF measures
remain OPEN without physical information. Provisional positive OOC timing and
11ps hold margin are not system timing or board signoff.

## Change and handoff gates

Keep canonical RTL/numerical/reset behavior stable. For any RTL edit run P0 XSim
and IP smoke under `dv/verif/scripts/`; for MATLAB edits run the bit-true check;
for synthesis/timing edits run `syn/run_ooc_all_dsm.ps1 -Part xc7z020clg400-1`.
Record known OOC mb_ef2/mb_mash22 failures independently from thermo5 ASIC checks.

Update frontier, relevant evidence docs and `docs/UPDATE_LOG.md` after reviewed
results. History is in `../inactive/`; previous failures remain evidence, not
current blockers unless reproduced. Preserve raw logs, reports and databases.

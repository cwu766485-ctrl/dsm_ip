# DSM thermo5 DE freeze status — 2026-11-18

- Branch: `work/thermo5-vcu118-architecture-research`
- HEAD: `30ba6cb5ef53d0a9bed4889e1b0efdb881bdecef`
- Worktree: pre-existing dirty research workspace; no commit, tag, or merge made.

## Exact-source update — 2026-11-19 11:16 SGT

Candidate4 SpyGlass finished on the exact research wrapper/source manifest:
setup and CDC both have zero errors and zero waivers; the earlier three
`Clock_sync06` findings do not reproduce. Generic-FIFO RDC reports 17,895
`Ar_resetcross01` errors (`Qualifier not found`), 12 informational synchronized
crossings, and zero waivers. The 17,907 native rows reconcile into 86
normalized endpoint/reset signatures; none has a final safe disposition. See
`reset_cdc_rdc_root_cause.md` and
`runs/de_resetfix_spyglass_candidate4_04/rdc_triage_01/`. This scope is not
comparable to 45,778/239 Runtime or 10,539 frontend-only.

MASH A v9 has a placed DCP and remains in Route Phase 5. Its intermediate
WNS/TNS `−0.260/−0.260 ns` and WHS/THS `−0.018/−0.018 ns` are before the
XPM reset-stage-zero audit and are not final. No final routed DCP/STA exists.
A 16-frame independent continuous-state Golden and regression are prepared
under `runs/live_long_16frame_02/`, but the simulation has not run. The
four-frame digital loopback remains bounded PASS; RF remains NOT_MEASURED.
**DE Freeze remains NO.**

## Current snapshot — 2026-11-19

The matrix below is the 2026-11-18 snapshot; use this update for current
status. Runtime architecture mailbox Formal v7 is **PASS, scoped** (25/25
assertions, 28/28 non-vacuity goals, 11/11 covers). The three older Tcl v3
routes completed and are **FAIL** overall setup timing: EF1 WNS/TNS
−0.435/−31.817 ns (138 endpoints), MASH A −0.377/−30.773 ns (236), MASH B
−0.435/−28.402 ns (105); hold WNS is positive for all three. Full path
analysis is in `timing_root_cause_20261118.md`. The first candidate4/Tcl v8
attempt stopped before route because the script compared Vivado's Boolean
`ASYNC_REG=1` property against the text `TRUE`; no DCP was emitted. The v9
script corrects that check without widening exceptions. MASH A v9 is running
from a fresh directory under `runs/de_resetfix_ppa_08/candidate4/`; MASH B and
EF1 are queued. These OOC routes have no parent clock-source or board pin
budgets and cannot establish product signoff. **DE Freeze remains NO.**
The machine-readable current matrix is `de_signoff_matrix_20261119.csv`; it
separates bounded live digital evidence from randomized continuous-stream and
board RF status.

## Closure matrix

| Gate | Status | Evidence and root cause | Next action |
|---|---|---|---|
| Candidate3 DPD mailbox Formal | PASS, scoped | VC Formal v5: 17/17 assertions, 20/20 non-vacuity goals, 6/6 covers, `MAX_TAPS=4`; see `formal_disposition_20261118.md`. | Retain as one scoped proof only. |
| Runtime architecture mailbox Formal | NOT_RUN | v6 adds source hold, exact capture, pending stability, reset abort/default, and fresh-request-after-reset checks/covers. | Run `runs/de_candidate3_independent_reset_formal_07.sh`; inspect every assert and cover. |
| EF1 current Tcl v3 OOC route | NOT_RUN | In route; current intermediate `WNS=−0.354 ns`, `TNS=−27.297 ns`, `WHS=−0.008 ns`, `THS=−0.013 ns`. It uses original config RTL, old exceptions and OOC ports without `HD.PARTPIN_LOCS`; no final DCP/report yet. | Preserve and finish; inspect final Worst-20, then use corrected candidate only after Formal. |
| MASH A current Tcl v3 OOC route | NOT_RUN | In delay/skew optimization after rip-up/reroute; intermediate `WNS=−0.378 ns`, `TNS=−31.732 ns`, `WHS/THS=N/A` at that stage. It uses original config RTL and old exceptions; no final DCP/report yet. | Preserve and finish; do not sign off this result. |
| MASH B current Tcl v3 OOC route | NOT_RUN | Post-placement timing optimization completed; transitioning to route. It uses original config RTL and old exceptions; no final DCP/report yet. | Preserve and finish; do not sign off this result. |
| Corrected candidate3 EF1/MASH A/B routed timing | NOT_RUN | Fresh directories are prepared under `runs/de_resetfix_ppa_06/candidate3/`; no implementation DCP exists. | Run only after v6 passes; save full setup/hold/Worst-20/exception/bus-skew/power reports. |
| Runtime CDC output errors | BLOCKED | Previous source revision reported Clock_sync06 on PA valid and two destination-local epoch-reset outputs. A separate static reset-fix run reported zero Clock_sync06 with zero waivers, but its source hash does not match the present source snapshot. | Re-run CDC on exact current candidate hashes; review reset outputs against the common asynchronous-abort contract. |
| Runtime Generic FIFO RDC | BLOCKED | 45,778 messages / 239 groups, all `Ar_resetcross01`, zero waived. Grouping mixes held-mailbox/control crossings with unreset payload storage and same-cycle enables. Hierarchy buckets are not dispositions. | Disposition each structural group from actual valid/enable/reset cones and targeted assertions; do not waive the aggregate. |
| Live digital GTY replay | PASS, bounded | Four continuous frames, 21,056 words/lane, TX and loopback bit-true, zero underflow/overflow/gap. First-frame receiver metrics: EVM 2.551442%, SNDR 31.864285 dB, BER 15/37,376. | Add random backpressure, reset-during-traffic and restart stress with real propagated transaction epoch. |
| Candidate4 reset-boundary smoke | PASS, scoped | Icarus check confirms Core-only reset abort/release, AXI-Lite remains ready, and AXI-Lite reset abort/release. It skips existing SVA under `SYNTHESIS` and does not model live data traffic. | Run reset-during-active-frame and pending AXI response/configuration tests in the licensed full-chain environment. |
| Continuous 14.000 Gb/s product supply | BLOCKED | Demonstrated for a finite four-frame digital replay with 64-bit × 218.75 MHz; not demonstrated under long randomized conditions or product integration. | Run long continuous randomized AXIS/backpressure/reset regression and assert no active-frame underflow. |
| EF1+MASH combined product Top | NOT_RUN | Singleton candidate3 routes and complete reset/mailbox proofs have not passed. | Build and route only after singleton and reset gates pass. |
| Board RF EVM/ACLR | NOT_RUN | No board/RF measurement exists. | Measure on VCU118/RF setup; digital replay cannot close this gate. |
| DE Freeze | BLOCKED | At least Formal v6, candidate3 routed timing, exact-current CDC/RDC disposition, reset/backpressure regression, and combined top remain open. | Do not create RC/tag or merge. |

## Current active implementation attempts — 2026-11-19 00:25 SGT

The following preserved Vivado processes are still active. They use Tcl v3
and the original configuration RTL, so they are exploratory even if routing
later completes:

- `runs/de_resetfix_ppa_04/ef1/console.log`
- `runs/de_resetfix_ppa_05/mash_a/console.log`
- `runs/de_resetfix_ppa_05/mash_b/console_retry01.log`

The corrected candidate4 directories are prepared but not run. Source hashes
and commands are stored in each
`runs/de_resetfix_ppa_06/candidate4/<case>/` manifest. The latest exception
work is in `research/vcu118_arch/run_ppa_abort_candidate_resetfix_xpm_v6.tcl`
and remains conditional on the architecture-mailbox Formal proof.

## Reproduction anchors

```bash
# Candidate3 mailbox + architecture formal; run only when licensed RAM is free.
wsl.exe -d Rocky-8.10 -- bash -ilc 'cd /mnt/e/workspace/chip/dsm_ip/runs/thermo5_vcu118_arch_research && ./runs/de_candidate3_independent_reset_formal_07.sh'

# Existing four-frame live result (replays the captured run command).
cmd.exe /c runs/live_long_4frame_02/run_retry01.cmd

# Candidate3 singleton PPA, after Formal passes, with a fresh output directory.
# Use each case manifest's exact run.cmd; never reuse the existing v3 outputs.
```

Current limits: OOC PPA has no physical `HD.CLK_SRC` or parent I/O budget;
SpyGlass RDC structural grouping is not proof; digital GTY loopback is not RF
measurement. All three limits prevent product DE Freeze.

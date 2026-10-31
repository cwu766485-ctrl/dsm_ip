# Thermo5 TX Branch Consolidation Audit — 2026-10-31

## Repository and PR state

A fresh `git fetch origin --prune` and live GitHub branch/PR query found 26 remote branches and 21 open, unmerged PRs (#2–#22). The five non-PR branches are `main`, `thermo5`, `dsm`, `thermo3`, and `dv-de-portfolio-20261006`. No remote branch or PR was deleted or merged.

The stacked TX chain is:

```text
thermo5
  #2 -> #3 -> #4 -> #5 -> #6 -> #7 -> #8 -> #9 -> #10 -> #11
     -> #12 -> #13 -> #14 -> #15 -> #16

thermo5 <- #17 (integration review of the cumulative #16 state)
             -> #18 -> #19 -> #20 -> #21 -> #22
```

PR #17 is open but stale as an integration review because it stops at PR #16. PR #18–#22 add later frame-tail, pair-lookahead, CDC, and fixed-parameter audits. PR #22 is the current cumulative head:

- Base: `thermo5` at `eb1081bc7607ba2e9825d9e9fb32bcfa1c6a270e`.
- Head: `codex/thermo5-fixed-parameter-branch-audit` at `01d331295b6d8dfc1161cbd8526e7d237c82200d`.
- Ahead/behind `thermo5`: 55 / 0 commits.
- GitHub state: open, draft, unmerged.

The current follow-up is based on PR #22's exact tree and retains the entire reviewable history. A new draft Integration PR targets `thermo5`; it is not an instruction to merge PRs #2–#22 individually. No PR will be merged without explicit user approval.

## Cumulative diff review

PR #22's cumulative diff against `thermo5` contains 134 files (+66,278 / −1,326 lines). The only RTL path changed is `rtl/axis/dsm_axis14_to_core8_cdc.sv`. That change gates source `TREADY` with the synchronized source reset state and routes the FIFO's raw write-ready signal through an internal wire. The purpose is to avoid acknowledging an AXI-stream beat that the FIFO discards during source-domain reset release. The change affects the shared CDC used by both FIFO branches and is covered by the exact-source Product replay and reset-release test evidence.

The cumulative path audit found no RX or AI-DPD paths. No tracked `.vdb`, simulator log, waveform, or tool-cache artifact is present in the PR diff. Verification reports, source manifests, compact benchmark data, and harnesses are tracked as project evidence; generated VCS/URG/VC Formal work directories remain in ignored local `runs/`.

The frozen TX Product configuration remains Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120, 20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1 Identity DPD, AXI-Lite frontend, and Generic FIFO for Linux. Candidate 2/4-Tap DPD and PAIR_LOOKAHEAD studies remain separately identified and are not promoted into the Product configuration.

## Current Linux verification snapshot

The fixed Product SHA is `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`. Existing exact-source positive VCS evidence is 13/13 PASS; the 11-case legal frame-gap sweep passes its four-plane checker. A separate malformed-frame negative test passes the sticky-error/reset-recovery checker and reports two expected RTL assertion failures outside legal assertion totals. The code Raw report is the union of those 13 legal Product VDBs, 11 legal gap VDBs, and one expected-negative VDB.

- Legal applicable Functional Coverage: 210/210.
- Raw DUT coverage: Branch 524/637; Condition 610/849; Line 3,350/3,796; Toggle 83,587/104,480.
- The current miss ledger has 21,691 records: 371 `PROVEN_UNREACHABLE` under reviewed exact Formal/static configuration evidence and 21,320 `OPEN`.
- Waivers=0; active `.el` exclusions=0; Raw equals Adjusted; the gate is `RAW_100_OPEN`.
- The legal assertion report has zero failures, with two uncovered and two without attempts. The intentional negative report has two expected assertion failures.
- The new legal early-TLAST Formal run is inconclusive. DPD Identity and outstanding-word counter Formal remain inconclusive. The 16-cycle source-gap checker failure remains OPEN.
- Real XPM/GT Wizard/TXP payload simulation, FPGA PPA/timing, and physical QAM256 BER remain separate hardware signoff tasks.

The integration branch does not claim final coverage signoff or 100% Raw/Adjusted coverage. It updates the reports and evidence index while preserving every current OPEN bin and its original denominator.

## Cleanup checklist

| Action | State |
|---|---|
| Keep `main` and `thermo5` | Done |
| Keep `dsm`, `thermo3`, and `dv-de-portfolio-20261006` for independent review/archive | Pending review; branches preserved |
| Review the cumulative Integration PR and rerun/accept the exact-source Linux package on its frozen SHA | Pending |
| Obtain explicit approval before any merge into `thermo5` | Required; no merge performed |
| Preserve relevant SHAs, evidence manifests, and tags before deleting any superseded refs | Pending; no branch deletion performed |

Full per-artifact hashes, commands, coverage numerators/denominators, and remaining OPEN risks are recorded in [the final coverage evidence](data/thermo5-tx-final-coverage-evidence.json) and [the Linux signoff snapshot](thermo5-tx-coverage-final-signoff.md).

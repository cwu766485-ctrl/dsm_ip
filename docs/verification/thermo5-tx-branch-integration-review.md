# Thermo5 TX Branch Integration Review

**Status:** `INTEGRATION_REVIEW_READY; LINUX_SIGNOFF_OPEN`

**Date:** 2026-10-31 (Asia/Singapore)
**Scope:** Thermo5 TX branch and evidence audit; Linux Python/VCS/URG/VC Formal only.

This review starts from the exact PR #16 head and targets `thermo5`. It does not merge PRs or delete branches. RX, AI-DPD, Vivado implementation, and the frozen TX algorithm are outside this review.

## Source identity and branch audit

| Ref | SHA / relationship | Result |
|---|---|---|
| `thermo5` base | `eb1081bc7607ba2e9825d9e9fb32bcfa1c6a270e` | Preserved; PR #16 is a descendant. |
| PR #16 head | `eddddd650a2853a05deab0bdb7a2272fdb647d18`, tree `d4d5ee1c04299c8273f1b702d21160c5b1c01aae` | Exact integration review starting point. |
| Integration branch | `codex/thermo5-integration-review` | Created from the PR #16 head. |
| Ahead / behind | 44 commits ahead / 0 behind `thermo5` | Confirmed after `git fetch origin --prune`. |

The current remote has 20 branches: `main`, `thermo5`, 15 Codex TX branches, and the independent `dsm`, `thermo3`, and `dv-de-portfolio-20261006` branches. PRs #2–#16 are all open and unmerged. Their base/head references form one continuous chain:

| PR | Base | Head | State |
|---:|---|---|---|
| #2 | `thermo5` | `codex/thermo5-tx-gate0-baseline` | Open, draft |
| #3 | `codex/thermo5-tx-gate0-baseline` | `codex/thermo5-tx-gate1-algorithm-ab` | Open, draft |
| #4 | `codex/thermo5-tx-gate1-algorithm-ab` | `codex/thermo5-tx-gate2-worst-case` | Open |
| #5 | `codex/thermo5-tx-gate2-worst-case` | `codex/thermo5-tx-gate3-coverage` | Open |
| #6 | `codex/thermo5-tx-gate3-coverage` | `codex/thermo5-tx-product-coverage` | Open, draft |
| #7 | `codex/thermo5-tx-product-coverage` | `codex/thermo5-tx-closure-gates4-6` | Open, draft |
| #8 | `codex/thermo5-tx-closure-gates4-6` | `codex/thermo5-tx-final-closure` | Open, draft |
| #9 | `codex/thermo5-tx-final-closure` | `codex/thermo5-tx-coverage-audit` | Open, draft |
| #10 | `codex/thermo5-tx-coverage-audit` | `codex/thermo5-tx-final-signoff` | Open, draft |
| #11 | `codex/thermo5-tx-final-signoff` | `codex/thermo5-tx-negative-coverage-evidence` | Open, draft |
| #12 | `codex/thermo5-tx-negative-coverage-evidence` | `codex/thermo5-tx-outstanding-counter-formal` | Open, draft |
| #13 | `codex/thermo5-tx-outstanding-counter-formal` | `codex/thermo5-tx-causal-test-scope` | Open, draft |
| #14 | `codex/thermo5-tx-causal-test-scope` | `codex/thermo5-tx-cdc-end-branch-formal` | Open, draft |
| #15 | `codex/thermo5-tx-cdc-end-branch-formal` | `codex/thermo5-tx-cdc-default-branch-formal` | Open, draft |
| #16 | `codex/thermo5-tx-cdc-default-branch-formal` | `codex/thermo5-tx-linux-coverage-closure` | Open, draft |

Keep `main`, `thermo5`, and the independent research/portfolio branches. Keep all PR branches until an Integration PR is reviewed and merged to `thermo5`, the target regression passes, and the commit/evidence archive is retained. Do not delete refs as part of this review.

## Cumulative diff review

At PR #16, the cumulative comparison to `thermo5` contains 125 files (`54,890` additions and `145` deletions). Only one synthesizable RTL path differs: `rtl/axis/dsm_axis14_to_core8_cdc.sv`. That change gates the public AXI-Stream `TREADY` with the source-domain synchronized reset release and routes the FIFO's ready signal through an internal wire. It does not change interpolation, EF2, DPD coefficients/defaults, or sample order.

No RX or AI-DPD source is in the cumulative diff. No VDB, FSDB, VCD, simulator log, FPGA implementation database, license, or PDK collateral is tracked by the branch. Benchmark artifacts and compressed coverage ledgers are retained as review evidence. Candidate 2/4-tap DPD and `PAIR_LOOKAHEAD` results remain candidate-only and are not mixed into the one-tap product Raw coverage.

The integration review fixed two Markdown hard-break whitespace warnings without changing the reported data. `git diff --check origin/thermo5` and `git diff --check` pass on the integration worktree.

## Verification and evidence reconciliation

The PR #16 evidence index has 39 artifact entries; all 39 path, size, and SHA-256 checks match. Its VCS product source manifest has 77 compile-input hashes; all 77 match the current worktree. The frozen product is Centered-Cubic x2+x2, EF2 ORDER=2/STEP=5120/20-bit state, 32 chronological lanes, one-tap identity DPD, AXI-Lite frontend, and Generic FIFO for Linux.

| Check | Result |
|---|---|
| Python reference suite (`dv/uvm/refmodel/python`, Python 3.12) | 44/44 PASS |
| Coverage/F formal-disposition audit unit suite | 13/13 PASS |
| VCS V-2023.12-SP1 fresh compile on this integration worktree | PASS; compile log retained under ignored `runs/thermo5_integration_review_eddddd6/` |
| Reset-release source test, seed 610713 | PASS; one legal 32-beat packet, 56 four-plane words bit-true, zero UVM warning/error/fatal |
| Intentional illegal-frame test, seed 420102 | Expected assertions observed; sticky error/reset checker PASS; zero UVM warning/error/fatal. Kept separate from the legal product Raw VDB set. |
| PR #16 exact-source positive replay | 13/13 focused product tests PASS; exact compile inputs and per-test logs/VDBs are retained in the 39-entry evidence index. Reused rather than repeated wholesale. |
| Formal evidence | Nine exact source-bound bins proven unreachable and retained in Raw; DPD identity payload remains INCONCLUSIVE; pair-lookahead tautological goals remain OPEN. |
| Mutation evidence | Baseline PASS; `late_gain` and EF2 `plane_swap` detected by the independent bit-true checker. |

The first local reset-release invocation used a multi-frame vector set although that test requires one frame. Its frame-event checker failed before acceptance. The invocation was corrected to a one-frame, 56-word vector and passed; both logs remain under the ignored run directory. The fresh standalone compile/test VDBs are functional evidence only and were not merged into the DUT-only Raw report.

## Current coverage and signoff boundary

| Coverage | Raw covered / total | Status |
|---|---:|---|
| Legal applicable Functional Coverage | 210/210 | PASS for the audited legal product bins |
| URG scoreable functional records | 210/214 | Four raw zero-hit rows are two illegal-only semantic bins duplicated across type/monitor views; expected-negative hits are reported separately. |
| Branch | 520/637 (81.6327%) | 117 open |
| Condition | 601/849 (70.7892%) | 248 open |
| Line | 3,334/3,796 (87.8293%) | 462 open |
| Toggle | 83,575/104,480 (79.9914%) | 20,905 open |
| FSM states / transitions | 13/13; 22/22 | PASS for the measured product hierarchy |
| DUT assertions | 13 success / 15 attempted; 2 uncovered; 2 without attempts | OPEN |

The source-linked ledger has 21,732 Raw-miss records in 470 grouped tasks: 353 records are `PROVEN_UNREACHABLE` and remain in Raw (9 exact Formal records plus 344 exact static product-elaboration records); 21,379 records across 375 tasks remain `OPEN`. There are zero approved waivers and zero active `.el` exclusions, so Adjusted equals Raw and the fail-closed gate remains `RAW_100_OPEN`. No denominator, VDB, or DUT behavior was altered to raise a percentage.

## Frame-tail coverage follow-up

After opening the integration review, the product-parameter frame-tail harness
was corrected to match both stages (W=16, stage 1 LANES=8/append=1, stage 2
LANES=16/append=0). VC Formal V-2023.12-SP2 passed 6/6 assertions; 5/9 Covers
were reached and four exact tail-only Covers were reported uncoverable. The
non-vacuous source-stability assumption was active; setup violations and black
boxes were zero. Four Centered-Cubic Branch records were classified
`PROVEN_UNREACHABLE` in the audit ledger while remaining in Raw. The line-255
single-entry pop/push paths were formally reachable in the module harness but
the legal frame-replacement product test did not hit them and added no Raw
coverage. Raw percentages, waiver count, exclusions, and product RTL are
unchanged. Exact property/source/report hashes and the run command are recorded
in the [coverage closure index](data/thermo5-tx-coverage-closure-index.json)
and [source-bound Formal review](data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-formal-review.json).

The 16-cycle source-gap test still reports 54 underflows for 112 expected output words. The AXI-stream source-gap contract is unspecified, so this remains OPEN. The UVM top models the product frontend parameters but does not elaborate the complete GT Parent; its separate behavioral GT Parent run lacks a payload checker. Real XPM/GT Wizard, FPGA PPA/timing, and physical QAM256 BER remain hardware signoff gates.

## Current-source EF2 PAIR_LOOKAHEAD elaboration audit — 2026-10-31

The current-source review now marks 344 EF2 helper/selector code bins as
`PROVEN_UNREACHABLE` under the exact product parameter chain. This is a
source-bound static elaboration disposition; the separate PAIR_LOOKAHEAD
VC Formal goals were reported tautological and remain rejected. The Raw URG
still contains all 21,732 misses with unchanged denominators. Total reviewed
dispositions are 353, with 21,379 OPEN across 375 tasks; zero waivers and zero
active exclusions. The tracked 77-entry compile manifest was refreshed from
the exact 13-test VCS compile log and matches its captured source manifest.

## Integration decision

The branch ancestry and existing evidence are internally consistent enough to open a draft Integration Review PR against `thermo5`. This is not final TX signoff: code coverage, two assertion bins, Formal identity-DPD equivalence, source-gap contract, and hardware gates remain open. Do not merge the Integration PR or delete PR #2–#16 branches without explicit review/approval.

Machine-readable evidence and exact run hashes are in [`thermo5-tx-integration-review.json`](data/thermo5-tx-integration-review.json). The current execution boundary is tracked in [`execution-frontier.md`](../exec-plans/active/execution-frontier.md).

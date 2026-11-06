# Thermo5 Branch Consolidation Audit — 2026-11-06

## Audit scope and baseline

Repository: `cwu766485-ctrl/dsm_ip`; target branch: `thermo5`.

The audit started after `git fetch origin --prune`. At that point the target was
`2d7a58df43f7bffecd3d34edd2f21bb3262abe2b`, PR #40 was at
`330815a5db5a26af50de81aff0c304dea714ead3`, and PR #41 was at
`744683b987ae5ecdc542c7c5fbf24ad63301e25d`. Both PRs were Draft/Open and
unmerged. The local audit worktree was on PR #41 and clean before this audit
document and portable-path cleanup were prepared.

The audited product profile is Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 /
20-bit state, four 64-bit PA planes, DPD_MAX_TAPS=1 with Identity reset image,
AXI-Lite, and Generic FIFO. Round 11 binds the tested source to a 96-file
compile-input fingerprint `08e62a87420ee9a9acce7724d2cca3c909f8cb7265dac22563522ac97a74b300`
and 21-file product RTL aggregate
`c627e02758be102e379e5eb464590189f354894dc84fc967c8e408554be38fe8`.

## PR dependency and patch audit

| PR | Base / relationship | Audit result |
|---|---|---|
| #27 | `thermo5` | Phase A dynamic Oracle; predecessor to #28. |
| #28 | #27 head | Agent and Virtual Sequence work. |
| #29 | #28 head | System-random and DPD/Gain/Profile campaigns. |
| #30 | #29 head | STATUS/W1C coverage follow-up. |
| #31 | #30 head | Waiver review and formal follow-up. |
| #32 | Recorded base `c0e104878c71...`, not current #31 head `4942731e8228...` | Stale/diverged integration base; its final-source Formal changes are represented in the snapshot, but the PR itself was not mergeable. |
| #33–#35 | Sequential #32 → #33 → #34 → #35 | Condition, DPD payload-hold, and Identity-under-stall Formal follow-ups. |
| #36 and #37 | Parallel from #35 | Outstanding-counter Formal and frame-tail Formal; reviewed independently below. |
| #38 | #37 head | Generic-FIFO `core_data_empty` Formal follow-up. |
| #39 | #38 head | Passive monitors and transaction event bus. |
| #40 | Directly targets `thermo5` | Cumulative coverage-closure snapshot; 266 changed files. |
| #41 | Stacked on #40 | Round 11 verification refresh; 28 changed files, 3 commits. |

PRs #27–#39 are all still Open and unmerged. Their branch heads are not
ancestors of the target or PR #41 because #40 is a snapshot commit. A path and
patch comparison was therefore performed instead of relying on ancestry or
matching filenames. All 404 paths changed across #27–#39 exist in the PR #41
tree. Of those, 278 have the same blob as the corresponding PR head; a
per-file reverse-patch check succeeds for 303/404 paths. The other paths have
later edits or changed patch context; they are not classified as omitted just
because their blobs differ. Per-PR counts and exact branch SHAs are in the
machine-readable manifest.

The evolving source changes were cross-checked against the current Round 11
files and the fresh Round 11 regressions. The tested local source commit
`d823654cba715e9093bb8cc08e6d819e8ae1365f` has the same tree as published
source commit `cd9532a7d805f2f60250f2ef687a15711a9c485e`
(`244b49c4daf1561806d7f02d6dfb560227757571`). Later PR #41 commits change
reports and documentation, not the tested source tree.

### PR #36 and #37 Formal review

- PR #36's three changed Formal source files have exact blob matches in PR #41:
  `run_thermo5_axil_outstanding_fpv.py`,
  `run_thermo5_axil_outstanding_fpv.tcl`, and
  `thermo5_axil_outstanding_harness.sv`. The current evidence remains
  **INCONCLUSIVE** for the outstanding-counter saturation/underflow properties
  and target Covers. No Raw Branch is waived by this work.
- PR #37's `thermo5_frame_tail_harness.sv` is an exact blob match. The scoped
  Formal runner was subsequently extended for CDC proofs. Its reported proof
  covers a composed two-stage interpolator model, not the complete elastic
  FIFO / DPD product chain. The related Raw bins remain open pending exact
  reachability review.

## PR #40/#41 review

PR #40 changes documentation, UVM/DV, and Python coverage utilities. Its diff
does not change `rtl/`, `matlab/`, `syn/`, or `fpga/`; frozen product RTL and
algorithm are unchanged. The prior concern about a large `UPDATE_LOG.md`
truncation applied to an intermediate PR #36 comparison, not to PR #40 versus
`thermo5`: PR #40 adds 694 lines and removes 3, while PR #41 adds 46 lines.
The final PR #41 file retains the 5,427-line target history and grows to 6,164
lines.

GitHub check runs for both heads show `hygiene` and `syntax` **SUCCESS** and
`licensed-dv` **SKIPPED**. Neither PR has submitted reviews or review comments.
Manual VCS evidence in Round 11 is available, but the required final regression
must still be rerun after the merges on the resulting `thermo5` SHA. The
Round 11 source-tree runs passed Generic FIFO VCS (7 directed scenarios),
AXI-Lite product VCS, System Random 110/110, DPD × Gain × Profile 60/60,
randomized Reset 24/24 and COMMIT 24/24, and Python 64/64. The current coverage
gate remains `RAW_100_OPEN`; these results are not a complete signoff.

`git diff --check` found trailing whitespace in three Round 11 report headers;
those formatting-only lines have been cleaned. The added evidence also
contained machine-specific absolute workspace paths. They have been converted
to repository-relative paths or generic tool-root variables; VDB identities,
data, and recorded content hashes are unchanged.
A marker scan found no private-key, GitHub-token, cloud-key, Slack-token, or
license-value patterns.

## Worktree, stash, and branch disposition

The complete remote/local branch inventory, head SHAs, ancestry results,
worktree status, and stash reference are in
`data/thermo5-branch-consolidation-audit-20261106.json`.

- Retain `main`, `thermo5`, `thermo3`, `dsm`, and
  `dv-de-portfolio-20261006` as independent/long-lived branches.
- Keep PR #40 and #41 branches through merge and post-merge regression.
- Once both PRs are integrated and the final checks pass, close #27–#39 as
  **Superseded by PR #40/#41**. Their original head refs remain recoverable.
- Branches already ancestral to `thermo5` are integrated by commit ancestry.
  Do not delete refs merely to reduce the branch count.
- Preserve the dirty worktree `codex/thermo5-tx-frame-tail-full-chain-formal`
  at `af22d2a7f86ccc77ac7a3b9f04e671316a607d0f` and its uncommitted files as
  **Unique Changes Pending**. Preserve the Round 11 stash. No dirty worktree or
  stash was changed by this audit.
- The available GitHub connector has no remote-ref deletion operation, and no
  authenticated `gh` CLI is installed. Remote branch deletion is therefore
  not performed in this environment; all such refs remain recoverable. No
  force push was used.

## Phase decision

This was the decision at the end of the initial audit, before integration and
post-merge verification. The completed state is recorded in the following
section. Raw/Adjusted coverage, Formal gaps, vendor XPM/GT, FPGA PPA, and
physical RF/QAM256 remain separate open items.

## Post-merge disposition

PR #40 merged into `thermo5` as `f8b14df743eeb6facfd0378b402f1670a6cf9b0f`.
PR #41 was retargeted to the updated `thermo5` and merged as
`8fddad5ba59814d9a0b95a9d94b88e7036efc16f`. The merge tree is
`76b082af1c94a1082f3c68cc64fa42c1b63c6838`. The final source tree contains
the audited changes from PR #27–#39, including the distinct Formal work from
parallel PRs #36 and #37; their unresolved proof limits remain documented.

The complete requested Linux product regression was run from a detached
worktree at that exact merged SHA. All six suites passed. The 96-file compile
input and 21-file product RTL hashes are byte-identical to the reviewed Round
11 source manifest. Detailed commands, log hashes, Raw/Adjusted URG identity,
and remaining limits are in
[`thermo5-branch-consolidation-postmerge-20261106.md`](thermo5-branch-consolidation-postmerge-20261106.md)
and its JSON evidence manifest.

After those checks, PRs #27–#39 were each commented as superseded by #40/#41
and closed. Their Git refs were not deleted and remain recoverable. The
long-lived branches `main`, `thermo5`, `thermo3`, `dsm`, and
`dv-de-portfolio-20261006` remain preserved. The separate dirty Formal
worktree and existing stash are still untouched. The GitHub connector exposes
no branch-ref deletion operation in this environment; no force-push or remote
branch deletion was performed.

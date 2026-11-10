# Repository consolidation and coverage closure status

## Completed integration and retirement

The GitHub snapshot contained 55 branches: 34 Codex heads already ancestral
to thermo5, 13 diverged legacy heads, three active stacked PR heads and five
long-term branches. All 34 contained heads were retired after per-head
merge-base ancestry, fresh remote SHA and active-PR dependency checks.
No historical commits were merged again. The complete names, original SHAs,
merge bases, ahead/behind, deletion outcomes and archive refs are in
[data/thermo5-consolidation-20261110/branch_retirement_audit.csv](data/thermo5-consolidation-20261110/branch_retirement_audit.csv).
The actual GitHub remote is named github in this worktree; origin is local.

PR #49 merged as a642e6b658c33741db7f70e209672764565ff932.
PR #50 was retargeted to thermo5, then merged as
108b8ff3170c2bbcd26fcbe2d7040ddd14cd0288. PR #51 was retargeted next,
then merged as 635be681046b3ab7d6fdda7f4e9818d7226efd66.
Each merge matched its reviewed head SHA and preserved SIGNOFF_OPEN.
The final tree equals PR #51 HEAD 4fcc75b byte-for-byte. The three merged
working branches were then ancestry/SHA/dependency checked and deleted.
Total deleted: **37**; remote branches remaining: **18**. No force push.

The five retained long-term branches are main, thermo5, thermo3, dsm and
dv-de-portfolio-20261006. Thirteen legacy working branches remain deliberately:
all have pushed and verified lightweight archive tags named
archive/2026-11-10/<original-branch>. Their shared 21 unique commits have
stable Patch-IDs recorded; 164 source-file/commit records were checked,
104 reverse patches apply. Evolved hunks are not inferred equivalent merely
from filename presence. Previous cumulative snapshot integration represents
the major agent/oracle/random/formal functionality, but individual evolved
hunk review is incomplete. No legacy branch was deleted and no speculative
port PR was created. Exact lists and conservative decisions are in
legacy_branch_decisions.csv, legacy_file_review.json and
legacy_reverse_patch_review.json in the evidence directory.

CI hygiene/syntax were SUCCESS and licensed-dv SKIPPED. There were no
submitted independent reviews or unresolved review comments. Assistant
technical integration reviews were posted under the owner's explicit merge
instruction; these are not independent human approvals or waiver decisions.

## Frozen regression and coverage

A fresh compile on product SHA 635be681046b3ab7d6fdda7f4e9818d7226efd66
replayed all 586 existing scenarios with zero new seeds: 582 legal and four
expected-negative. All 586 pass their scenario checks; every Test VDB has the
same compile-parent fingerprint as the Design VDB. The replay retains the
I/Q saturation, address-return and strict two-stage replacement hits.
Hardware tools 48/48 and reference-model tests 66/66 PASS. The first model
invocation lacked PYTHONPATH and failed imports; its corrected rerun passed.
No RTL/MATLAB/product-parameter change was made. Full XPM/board/RF scope was
not run and remains outside these results.

Actual same-input full64 URG reports:

| Metric | Raw = zero-approved Adjusted | Analysis-only What-if |
| --- | --- | --- |
| Branch | 526/637 | 526/529 |
| Condition | 664/849 | 664/741 |
| Line | 3352/3796 | 3352/3363 |
| Toggle | 92640/104480 | 92640/93710 |

FSM remains complete. Raw missing=12,580; What-if missing=1,161.
The homogeneous replay adds zero bins relative to the verified incremental
baseline and confirms its existing hits. No mapping/checksum/warning/error
diagnostics appeared in the five URG logs.
Legal-only assertions: 13 SUCCESS, zero FAILURE; two q1_tail checks remain
without attempts (also listed UNCOVERED). The combined three assertion
failures are confined to expected-negative cases; they are not reported as
legal regression success. Full FIFO/DPD composition, DPD arbitrary-stall and
outstanding/COMMIT formal obligations remain OPEN.

## Exact dispositions and approval boundary

All 231 non-counter source hashes were checked. Each row now carries an
explicit disposition, rationale, native mapping status and reference scope in
final_exact_dispositions_231.csv. Current decisions: 109 EXCLUSION_CANDIDATE,
122 OPEN, zero additional HIT. The candidates comprise 80 frozen interpolator
tail toggles, 24 active-tap mirror toggles, four vector History lines and one
current-source line93 Formal tuple. None is approved. The other expressions
remain OPEN rather than being excluded from a simulation miss.
Native object lookup: 199 uniquely identified objects still requiring exact
vector/direction review, 24 ambiguous and eight missing. Unique object lookup
alone does not authorize an exclusion. In particular companion History-line
mapping and complex condition/branch vectors remain obligations.

The existing 11,419 analysis candidates retain unique semantic IDs, matching
source hashes and valid links to the 371 official Waiver IDs. The refresh also
finds 2,448 rows with an empty inherited analysis_group field; these need root-
cause group reconciliation before approval. This refresh is a source/identity
check, not independent proof of every native directive. No official .el was
generated or activated. Approved Waiver references: NONE.

The 930 counter directions remain legally reachable and OPEN (464 sample,
466 saturation). Existing independent block arithmetic evidence is retained;
deposits never enter product URG. Counter scope/acceptance approval references:
NONE. No reachability or product-scope waiver was fabricated.

**Code Coverage Signoff: OPEN. Full Linux DV Signoff: OPEN.**
Integration and the homogeneous-baseline blocker are closed; final coverage
is not. Continue evolved legacy-hunk review, exact reachability/native mapping,
and genuine independent candidate/exception review. Future changes should
use clean thermo5 and disposable task branches; no new Round-N branch was
created. This report is a documentation-only descendant of the frozen product
SHA; it does not change compiled source or claim a new product test SHA.

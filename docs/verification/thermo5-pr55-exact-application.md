# PR55 exact analysis application

2026-11-11 Asia/Singapore. Input decision commit36c2839 is engineering triage,
not approval. Frozen product635be681046b3ab7d6fdda7f4e9818d7226efd66 unchanged.
Existing33 decisions preserved; no reclassification or new seed campaign.

## Applied analysis scope

Native dump regenerated from the same589-test frozen parent set.33 exact
semantic IDs map to30 directives:23 parameter/assignment candidates and10
legal-packet CDC candidates. Two shared native blocks are deduplicated:
Stage1 Block47/checksum595236972 covers230,231;Stage2 Block43/checksum62050017
covers224,225,226. Block39/checksum2358869140 covers218. No wildcard used.
Scope checksums, directions, exact Condition/subexpression vectors and Native
Branch vector are recorded in native33.json. Direction bits of negated terms
are taken from native vectors, not guessed from signal names.

Strict URG results:

| Analysis run | Line removed | Condition removed | Toggle directions removed | Branch removed |
| --- | ---: | ---: | ---: | ---: |
| Parameter23,589 tests |6|11|6|0|
| All33,585 legal tests |7|11|14|1|
| All33,589 tests,diagnostic only |7|11|14|1|

All selected exact Condition and Line sets match; all Toggle directions match;
removed Branch is only CDC line122 decision0/-/1/1/0/-/-/-/-/-/-/-. Denominator
changes match33, covered counts unchanged, no URG mapping/checksum warnings.
Native XML remains unchanged. The two scalar-direction directives per constant
signal together exclude both directions, explicitly authorized by these rows.

CDC batch is legal32*k-beat/14:8 geometry only. The589-test combined diagnostic
view is not a new official legal-only scope policy; malformed-TLAST evidence
remains in negative_only and legal-only analysis is provided separately. No
CDC exclusion may enter official coverage without scope-policy approval.

The comparison verifier initially omitted URG metric-specific instance sections
and its exclusion icon; corrected HTML parsing now checks every exact row.
The scripts fail closed on source/native checksums, ID uniqueness, lost covered
counts, unexpected line/Condition/Branch sets, or wrong Toggle direction.
48 existing utility tests and Python compilation PASS. Script checks are
actual report checks, not independent reviewer approval.

## Remaining54 and Outstanding proof attempt

remaining54.csv retains exact IDs, source/native evidence and per-target next
obligations. Outstanding slots:2ingress+3gain+2interp1+1pending synthetic tail
+2elastic+11DPD+2elastic+2interp2+2elastic+1EF2+1bridge=29. Real-word counts
cannot simply equal total valid slots because synthetic tails are inserted and
dropped. Arbitrary stalls and reset epochs require weighted token conservation.

The actual existing frozen-product capacity assertion was rerun in VC Formal,
with its existing legal source hold constraint and RUN-only sequencer. Result:
**INCONCLUSIVE depth51**, property limit4minutes. No bound/Guard proof claimed;
other assertions/covers were NOT_RUN. This restricted harness does not cover
all STOP/reset epoch sequences. Setup reports zero clock/glitch/comb-loop/
multidriver violations; console retains reset warnings. Properties/setup/engine
records and source paths are retained. Outstanding candidates stay OPEN.

Other groups retain exact temporal obligations: stale q1_start versus occupancy;
reset-event versus sampled assertions; CDC FWFT/empty pointer timing; Gain
stale metadata with valid0; DPD pipe_ce evaluation; mailbox request deassertion
with pending/boundary. Prior ready-tail/reset legal test gives zero delta and
is not rerun under extra seeds. No new target test is claimed this execution.

## Unified approval package

approval_index_11593.csv.gz indexes11419 historical+141 prior+33 new candidates.
All sets individually unique and pairwise disjoint. Original exact records,
source hashes and Native mappings are referenced, not regenerated. Original371
Waiver IDs remain in their source ledger; index preserves historical references.
Every candidate remains PENDING. Root-cause batch approval must reference all
exact IDs and native object scope, including all shared block members. Five
broader shared records still require genuine approval. No approved.el exists.

930 legal counter directions remain separate. Existing32-bit block carry/wrap/
reset/stall evidence is not product URG. Requested owner decision: accept or
reject system-exhaustive toggle scope exception for exactly464 sample+466
saturation directions, with product fingerprint, exact ledger hash, independent
review role and signed approval reference. The owner/PR author identity alone
is not that record. Accepted exceptions0. Existing counter proposal and A/B
impact comparison remain unchanged; no RTL pruning.

## Measured coverage and decision

No DUT/DV executable change in this execution; reuse verified589-test same
parent, not unnecessary recompilation. Raw and zero-approved Official from
that set remain526/637 Branch,667/849 Condition,3352/3796 Line,92640/104480
Toggle; FSM13/13 states,22/22 transitions. New strict diagnostic What-if includes
existing analysis list plus33; prior141 candidates are still not applied.

| Metric | Raw = Official Approved Adjusted | Analysis-only combined What-if |
| --- | --- | --- |
| Branch |526/637|526/528|
| Condition |667/849|667/730|
| Line |3352/3796|3352/3356|
| Toggle |92640/104480|92640/93696|
| FSM states/transitions |13/13;22/22|13/13;22/22|

Officially remaining12577 =11593pending candidates+54technical unresolved+
930counter. Combined What-if remaining1125 =195noncounter+930counter. What-if
improvement33 is analysis denominator reduction, **not new HIT or approval**.
Cumulative focused231 ledger still3HIT; this execution newHIT0, approved
exclusion0,accepted exception0. Requested87 remain officially OPEN.

589/589 inherited regression PASS(585legal/4negative); legal assertions13success,
0failure,two q1_tail without attempts;combined3failures only negative. Latest
parent binding remains runs/rtl_invariants/final_binding.json; actual strict
reports and command manifests are under runs/pr55_exact/. Raw/Official reports
remain runs/rtl_invariants/urg/{raw,approved_adjusted}/report. Native dump
runs/pr55_exact/native/ records same inputs. Native VDB files never edited.

**Code Coverage Signoff: OPEN. Full Linux DV Signoff: OPEN.**
PR55 requires independent technical review and signed scope decisions. No merge
or branch deletion until actual review; no self-approval fabricated.

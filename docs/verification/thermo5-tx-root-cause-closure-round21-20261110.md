# Thermo5 Round 21: final coverage root-cause closure

Date: 2026-11-10 (Asia/Singapore). Base: PR #50 `818e1de799f9dfa0ccf098da11349d0c95fa34ad`.
Decision: measurable closure achieved; coverage and Linux DV signoff remain OPEN.

## Actual closure

Five previously uncovered native Condition bins are now HIT through two legal,
fixed-seed full-product I-only/Q-only saturation streams. No random seeds were
added. Each stream checks all four PA planes against Python fixed-point vectors,
all 16 lane saturation/sample counters, configuration mailbox causality and
queue drain. Internal VCD pre-edge state confirms the matching valid/saturation
tuple. Same-line expression/subexpression identities are kept separate.

Q-only: TXB-075cf0a496177c8cf2bd, TXB-12d7b8d0a06eb411ea9b,
TXB-7e3d8ab85dcbfde179c8. I-only: TXB-3dd5a40ea4392f6818d0,
TXB-4caf9df4a2f1c31b35a4. Full tuples, source hashes, native page hashes and
witness times are in `data/thermo5-r21/directed_exact_hits.json`.

## Coverage

| Metric | Raw | Approved Adjusted (zero approvals) | Analysis-only What-if |
|---|---:|---:|---:|
| Branch | 524/637 | 524/637 | 524/529 |
| Condition | 662/849 | 662/849 | 662/741 |
| Line | 3338/3796 | 3338/3796 | 3338/3363 |
| Toggle | 92632/104480 | 92632/104480 | 92632/93710 |
| FSM states/transitions | 13/13, 22/22 | same | same |

Raw uncovered: 12,606 (previously 12,611). What-if uncovered: 1,187
(previously 1,192): 5 Branch, 79 Condition, 25 Line, 148 non-counter Toggle,
930 Counter Toggle. Requested non-counter remainder: 262 -> 257.
Official approved exclusions=0; accepted coverage exceptions=0. The 11,419
What-if candidates remain pending; arithmetic subtraction is not an approval.
No official .el directive was added or broadened.

## Source and VDB consistency

Product RTL is unchanged. Frozen profile remains Centered-Cubic x2+x2, EF2
ORDER=2, STEP=5120, 20-bit state, 32 lanes, DPD_MAX_TAPS=1, AXI-Lite,
Generic FIFO. The optional VCD hook is disabled by default and guarded for
centered-cubic elaboration. Compile manifest binds 95 parsed files plus two
controlled inputs. All final tests share the exact current Design VDB parent;
none of the old mixed-parent merged aggregate is carried into final reports.

The 580 inherited scenarios were rerun from their saved native siminfo argv,
preserving scenario inputs and seeds. Four additional focused runs give 584
Test VDBs: 580 legal plus 4 expected-negative. One old saturation-vector input
lacked the newer per-lane count oracle. Its first failure is retained; an
independent count file was computed from unchanged original I/Q and coefficients
in a separate directory, and the retry passed. Only the passing retry is merged.

Legal-only assertion URG has 13 successes, zero failures, two uncovered/no-attempt
q1_tail assertions. All three failure identities in combined URG come from the
isolated expected-negative runs (CDC and the two interpolators). Do not report
the combined failure count as an unexpected legal failure or hide its provenance.

## Root causes, counters and Formal

The 262-row exact disposition CSV preserves expression, legal predecessor,
reachability and decision. Unresolved rows explicitly remain OPEN; no assertion
of unreachable is based on random misses. See the queue/review document for
single-entry replacement, tail metadata and empty/blocked analysis.

The isolated counter contract test passes independent arithmetic, 31 carry
boundaries, wrap, async reset and backpressure hold. Register deposits are block
verification only and never enter product coverage. All 930 reachable counter
bins stay OPEN pending product-owner/independent coverage-exception acceptance.

Fresh VC Formal passes both existing jobs: legal-metadata and runtime-reset
condition. Four assertions are proven, 12 covers reached and four target covers
uncoverable, with zero black boxes. These are scoped compositions; omitted
elastic FIFOs/DPD and the fixed packet schedule prevent claiming full-chain
q1_tail closure. Outstanding-counter and full-chain DPD proofs remain OPEN.

## Independent approval and integration

All 11,419 candidate IDs are unique and grouped by original root causes. The
original 371 official Waiver IDs and links are retained (two Raw-hit-resolved,
369 pending). Priority review: one AXI-Lite default-response Branch with prior
proof, and four static MAX_TAPS=1 vector-history Lines. Those four Lines are
outside the existing What-if candidates and still need exact native mapping
and approval. No reviewer identity or reference has been supplied.

Read-only GitHub review confirms PR #49 is Draft/Open against thermo5 and #50
is Draft/Open stacked on #49. Required order is review/merge #49, retarget and
review/merge #50, then review this round against the integrated source. No PR
was merged and no independent review was fabricated. Publication does not
constitute approval or final signoff.

## Reproduction and limits

Generate axis witnesses with `generate_thermo5_dpd_axis_witness.py --axis i|q
--output-dir <dir>`, compile the canonical `thermo5-vcs` product flow, and run
`thermo5_sku_axil_dpd_saturation_bittrue_test` with CORE_WORDS=112,
PACKET_BEATS=32, seed=210042. Add THERMO5_WITNESS_VCD to capture internal state.
Use `thermo5_r21_witness.py` to check exact expression/subexpression status and
pre-edge VCD state. Replay tooling requires the original inherited VDBs/vectors;
these large local artifacts are not shipped as source.

Checks: hardware tools 48/48; Python model 66/66; counter block PASS; inherited
580 scenarios plus four focused scenarios PASS after the documented oracle
repair; both scoped Formal jobs PASS; five actual URG reports completed.
Full Windows XSim, real XPM/GT, Vivado PPA/timing and physical board/RF checks
were not run. No algorithm or product RTL change requires claiming them here.
Raw VCDs/logs/VDBs stay ignored under runs; compact summaries and hashes are
tracked. Independent approvals, the remaining 1,187 What-if bins and full-chain
proof obligations are still required before signoff.

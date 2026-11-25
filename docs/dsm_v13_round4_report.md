# DSM V1.3 Round 4 — Module-Level and Formal-Assisted Coverage Closure

Date: 2026-11-25 23:00 SGT
Branch: `work/dsm-v13-mash-uvm-round4`
Baseline: Round 3 commit `9ae4e3fc574c34149930dca055d83528458be553`

## Result

Round 4 materially improved the directed and formal evidence, but functional
coverage convergence and final DV sign-off remain **OPEN**. No Product RTL was
changed, no coverage exclusion or waiver was applied, and raw coverage remains
equal to adjusted coverage. Eight MASH proof-backed records remain pending
independent waiver approval. Six restart × FIFO-state cross bins remain open
while the supported RUN-after-STOP timing contract is reviewed.

The frozen Round 3 matrix had 2,621 OPEN records, including 2,500 raw RTL
holes, 27 functional records, and 22 cross records. Round 4 disposition is:

| Disposition | Records |
|---|---:|
| Exact evidence HIT | 110 |
| NOT_APPLICABLE after Product-only AXI-Lite applicability audit | 3 |
| Formal evidence, approval pending | 8 |
| OPEN | 2,499 |
| OPEN_UNMAPPED | 1 |

These categories retain the original 2,621-record denominator. The current
selected-configuration raw RTL inventory has 2,463 OPEN bins; 75 exact Round 3
raw-bin keys no longer appear in the Round 4 raw inventory. Raw and adjusted
metrics are identical because there are zero approved exclusions and waivers.

## UVM and functional coverage

All seven independent VCS/URG configurations passed with zero UVM warnings,
errors, or fatals in their legal positive runs:

| Configuration | Positive test VDBs |
|---|---:|
| EF1 Product | 8 |
| EF2 Product | 9 |
| MASH Product | 6 |
| EF1 AXI-Lite | 6 |
| EF2 AXI-Lite | 7 |
| MASH AXI-Lite | 8 |
| MASH wrapper/core | 1 |

The URG runner also reports one isolated malformed-frame negative VDB per
Product/AXI-Lite SKU configuration; expected negative outcomes remain separate
from positive assertion status. The MASH wrapper/core elaboration keeps its own
coverage database. It is not merged with Product or AXI-Lite databases.

The Product-only `transaction_event_cg` applicability fix keeps three
AXI-Lite-only bins out of Product denominators while retaining the frozen Round
3 records as auditable applicability dispositions. EF1/EF2 Product groups
remain 100%. The other raw group totals are shown below after restoring the
full restart FIFO-state denominator.

MASH has four raw weighted-level bins (`-4`, `-2`, `0`, `+4`) open in each of
Product and AXI-Lite, plus one `minimum_rail × positive Stage1` cross open in
each configuration. Sequential formal evidence proves these as unreachable
within the stated W16/ACC18 reset-constrained MASH contract. The raw bins
remain visible; eight raw-bin waiver records and two cross-bin waiver records
are `APPROVAL_PENDING`. The focused MASH Product/AXI-Lite rail-history tests
hit the reachable maximum-rail × negative-Stage1 cross and check outputs with
the independent four-plane scoreboard.

### Functional coverage correction and current gaps

An earlier Round 4 draft ignored the partial/full FIFO states in the restart
covergroup. That denominator reduction was unsupported by a formal proof, so
the bins were restored and the affected AXI-Lite configurations were rebuilt
and rerun. The six corresponding baseline rows are no longer counted as hits.
The corrected raw functional results are:

| Configuration | Applicable group score | Functional group disposition |
|---|---:|---|
| EF1 Product | 100.00% | PASS |
| EF2 Product | 100.00% | PASS |
| MASH Product | 98.20% | `APPROVAL_PENDING` |
| EF1 AXI-Lite | 97.22% | OPEN |
| EF2 AXI-Lite | 97.39% | OPEN |
| MASH AXI-Lite | 96.63% | OPEN |

The remaining 22 functional group bins consist of 12 partial/full FIFO state
bins across the three AXI-Lite builds and 10 MASH raw weighted-level/input-rail
bins. The eight MASH bins are formally proven unreachable in the stated
W16/ACC18 MASH scope and remain raw-visible pending approval. The other six
are the partial/full cells in `restart × FIFO state`; they are OPEN, not
waived or marked unreachable. The separate `round4_early_restart_reproducer`
uses a real partial FIFO state and confirms STATUS is still RUN_ACTIVE and
DRAINING when RUN is reasserted. The independent PA scoreboard then reports a
four-plane mismatch at output word 45. This diagnostic VDB is excluded from
the passing URG merge. Whether early RUN during DRAINING is a supported
software operation remains a contract decision; see the diagnostic evidence
JSON for the command, log hash, source hash, and VDB hash.

The corrected cross report has eight missing cells: six AXI-Lite restart ×
FIFO-state cells (partial/full in EF1, EF2, and MASH) and two MASH minimum-rail
× positive-Stage1 cells with formal evidence pending approval. No cross bins
were removed from the denominator.

## Raw code coverage

The following selected-DUT raw metrics remain below the Round 4 final targets
(Line/Branch/Condition ≥95%, Toggle ≥90%) except for the listed MASH core
Condition and Toggle metrics. Raw equals adjusted for every row.

| Configuration | Line | Branch | Condition | Toggle |
|---|---:|---:|---:|---:|
| EF1 Product | 88.32% | 75.46% | 77.39% | 84.24% |
| EF2 Product | 83.09% | 64.10% | 67.65% | 81.98% |
| MASH Product | 87.88% | 75.53% | 76.90% | 80.63% |
| EF1 AXI-Lite | 88.97% | 78.74% | 79.76% | 80.46% |
| EF2 AXI-Lite | 84.04% | 69.07% | 71.61% | 78.63% |
| MASH AXI-Lite | 88.65% | 79.28% | 79.76% | 76.63% |
| MASH wrapper/core | 90.16% | 71.43% | 100.00% | 98.36% |

The focused module tests close useful DPD sub-block branches without combining
incompatible elaborations. `dpd_poly` orders 3, 5, and 7 each reached 100% Line,
Branch, and Condition in their standalone elaborations; Toggle reached 73.37%,
75.34%, and 77.06%, respectively. The identity sweep checked 196,608 accepted
and output samples over the signed 16-bit domain. The memory-polynomial
protocol test checked 173 samples, 73 output stalls, and 60 full-input stalls.
The four-tap 16-lane candidate test compared 93,184 samples (5,824 lane words)
against the independent Python integer oracle with zero output saturations.

Standalone DPD, memory-polynomial, and interpolator metrics and exact raw holes
are in `round4_block_level_code_coverage.csv` and
`round4_block_raw_open_rtl_bins.csv`. These reports retain per-elaboration raw
coverage; repeated source signatures across polynomial orders are not
deduplicated or merged. DPD memory-polynomial and interpolator modules still
have raw holes. The centered-cubic sustained block test is explicitly limited
to a zero-bubble case; its low standalone score is not treated as interpolator
closure. EF2-specific arithmetic also remains below the system code targets.

## FSM, assertions, and formal evidence

All 22 exact Round 3 raw FSM-transition records were hit in the fresh raw URG
inventory. One additional Round 3 matrix-only transition row has no exact raw
inventory mapping and remains `OPEN_UNMAPPED`; it is not counted as a raw-bin
hit. The row is preserved in `round4_fsm_transition_closure.csv` for audit.

Positive legal assertion runs have zero failures. MASH AXI-Lite has one
incomplete attempt of `p_accepted_vector_produces_output` in the isolated
reset-sweep VDB (4,687 real successes, 7,182 attempts in the positive merge).
The test performs legal reset epochs while data is active and this assertion
uses `disable iff (!rst_n)`. The attempt is retained as
`RESET_ABORT_EXPECTED`; it is not counted as a success or a failure. Each of
the other seven MASH AXI-Lite positive tests has zero incomplete attempts. The
assertion-isolation matrix records every isolated report hash.

Four MASH sequential formal assertions were proven and four required covers
were hit: atomic four-plane valid, held-word stability, no unreachable
weighted-level output, and minimum-rail never producing positive Stage1. The
formal harness uses the real reset sequence and source-stability assumption;
its scope is the W16/ACC18 MASH 1-1 contract. The MASH waiver proposal remains
pending independent approval.

The separate legal frame-tail metadata run passed two assertions. Its
packet-end, tail-transfer, subframe-start, and output-transfer witnesses were
hit; two active-bin covers were proven uncoverable for the exact legal
centered-cubic frame geometry. This formal result supports the `q1_tail`
no-attempt disposition only in that parameter and sampling scope; it does not
remove any raw URG bin.

## Evidence and remaining work

Machine-readable Round 3-to-Round 4 disposition, code/functional/cross
coverage, assertion audit, waiver proposal, open records, block-level tests,
formal results, source hashes, VDB hashes, and URG hashes are under
`docs/verification/data/dsm-v13-round4/`. The regression manifest preserves
the seven separate SKU/elaboration databases and eight separate block-level
coverage runs.

Checks completed:

- Seven independent Round 4 URG merges: PASS.
- Six selected Product/AXI-Lite elaborations rebuilt and all enumerated
  positive/negative test VDBs were replayed; seven URG merges PASS.
- Passing positive UVM runs: zero warnings/errors/fatals. The separate early
  restart diagnostic intentionally reproduces one scoreboard fatal and is not
  part of the passing merge.
- DPD identity exhaustive, DPD protocol, DPD order 3/5/7, four-tap
  memory-polynomial, centered-cubic sustained, and polyphase reachable block
  tests: PASS with independent checkers.
- MASH sequential Formal: 4/4 assertions proven, 4/4 covers hit.
- Legal frame-tail metadata Formal: PASS with two assertions proven and
  non-vacuity status recorded per cover.
- Python reference suite: 74/74 PASS.
- `git diff --check`: PASS.

The PowerShell/XSim command is not available in this Linux environment and was
not run. Product RTL did not change. CDC/RDC, STA/PPA, MATLAB latency
alignment, physical serializer DV-L2, and board/RF sign-off remain outside
this evidence. Functional convergence is not achieved: the six restart × FIFO
state bins need a resolved RUN/DRAINING contract and legal evidence, while the
eight MASH bins need independent waiver approval. Raw code targets also remain
open; do not claim final DV sign-off.

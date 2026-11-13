# Thermo5 DV Coverage Closure v4

Date: 2026-11-12 (SGT)  
Product SHA: `635be681046b3ab7d6fdda7f4e9818d7226efd66`  
Review chain: PR #55 -> #56 -> #57 (PR #57 remains open; no automatic merge)

## Measured result

The v3 frozen compile and VDB evidence were re-indexed for v4. The four P0 scenarios remain functional PASS with independent CDC/EF2/four-plane oracle evidence, but they produced **zero new Exact URG hits**. No new directed simulation or Formal run was started because the remaining targets have no new predecessor hypothesis and the prior full-product obligations are inconclusive.

| View | Branch | Condition | Line | Toggle | FSM |
|---|---:|---:|---:|---:|---:|
| Raw = Official Adjusted | 526/637 | 667/849 | 3352/3796 | 92640/104480 | 13/13 states, 22/22 transitions |
| Analysis-only What-if | 526/528 | 667/713 | 3352/3352 | 92640/93576 | same |

- Exact HIT added in v4: **0**
- Approved Exclusion added: **0**
- Accepted Scope Exception added: **0**
- Remaining technical Exact Bin: **48 OPEN** (22 Interpolator, 7 CDC, 2 Gain, 2 Frontend, 15 TX Top)
- Exclusion candidates: **11,599 PENDING**; no official `.el` generated
- Counter directions: **930 OPEN**, not classified unreachable
- Official remaining open: **12,577**

The v4 CSV keeps each Semantic ID, Native URG object/vector, RTL location, product/source fingerprint, predecessor state, and approval state. A simulation miss is not used as an exclusion decision.

## P0 and system cross evidence

The existing P0 matrix covers old/new configuration overlap, 64/96-beat STOP/PA-stall drain, and reset with pending COMMIT, non-zero EF2 state, and PA stall. All four cases passed protocol/scoreboard checks, independent trace oracle checks, and progress watchdogs. Their event witnesses are in `../thermo5-dv-v3/actual_event_witness.json`; the scenario matrix is in `../thermo5-dv-v3/scenario_matrix.csv`.

The v4 cross ledger records these as `PASS_FUNCTIONAL`, with Exact URG delta zero. Back-to-back COMMIT/BREADY stall, STOP/pending-COMMIT/restart, STATUS W1C/error-set/read, Gain/DPD/EF2 saturation, and FIFO refill/frame-start/backpressure remain OPEN because the inventory has no qualified packet/epoch-scoped evidence for them. Events from different packets or reset epochs were not combined.

## Formal status

No new Formal run was performed. Outstanding weighted token conservation remains INCONCLUSIVE (conditional 28-slot model; full RTL/reset/STOP refinement absent). `q1_tail` antecedents remain OPEN with no legal attempt. CDC FWFT/residual/drain, invalid Gain metadata, and TX STOP/drain conservation have no non-vacuous proof covering all v4 tuples. INCONCLUSIVE, unattempted, or assumption-dependent results are not PASS.

## Reproduction

```bash
# Reuse the frozen v3 compile/VDB and evidence
python3 tools/hw/thermo5_v3_inventory.py
python3 tools/hw/thermo5_v3_replay.py --execute
python3 tools/hw/thermo5_v3_urg.py --execute
python3 tools/hw/thermo5_v3_p0_witness.py
python3 -m unittest discover -s tools/hw/tests
PYTHONPATH="$PWD/dv/uvm/refmodel/python" python3 -m unittest discover -s dv/uvm/refmodel/python/tests
```

The measured v3 execution was 594/594 PASS (590 legal, 4 expected-negative), same compile parent and clean URG diagnostics. Licensed GitHub workflow status is `SKIPPED`; that is not a licensed verification PASS.

## Signoff

- Code Coverage Signoff: **OPEN** (48 technical bins, 11,599 pending candidates, 930 counter directions, and no independent approvals)
- Full Linux DV Signoff: **OPEN** (licensed workflow skipped and outstanding Formal/Assertion obligations)

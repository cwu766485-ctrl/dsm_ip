# Thermo5 TX Outstanding-Counter Capacity Formal Follow-up

Date: 2026-11-03 (Asia/Singapore)
Product RTL SHA: `1236d49c72360aa62e316aea147528d93a1b3705`
Formal base revision: `938176bb3e3c9850085889602306c1b861df8e76` (verification worktree had the harness/runner/TCL changes listed in the evidence JSON)

## Result

A product-configuration VC Formal rerun added arbitrary legal AXIS source bubbles and candidate source-bound capacity assertions, without bounding the source gap or PA stall. VC Formal completed the run with no setup errors and no black boxes, but the closure runner returned **INCONCLUSIVE** because no proof or exact guard Cover was resolved.

| Property | Result | Depth / witness |
|---|---|---:|
| `a_no_counter_saturation_guard` | INCONCLUSIVE, non-vacuous | 46 |
| `a_no_counter_underflow_guard` | INCONCLUSIVE, non-vacuous | 46 |
| `a_outstanding_not_greater_than_pipeline_slots` | INCONCLUSIVE | 34 |
| `a_outstanding_within_product_capacity` | INCONCLUSIVE | 34 |
| `a_pa_valid_has_outstanding_word` | INCONCLUSIVE, non-vacuous | 37 |
| `c_counter_saturation_guard` | INCONCLUSIVE | 34 |
| `c_counter_underflow_guard` | INCONCLUSIVE | 38 |
| source/core/output activity and arbitrary source bubble Covers | COVERED | 4 / 9 / 35 / 4 |

The legal source stability assumption is non-vacuous. The single Cover for an arbitrary source bubble reached depth 4. No maximum source-gap or PA-stall constraint was used. This demonstrates legal activity in the harness only; it does not prove the counter bound or either guard unreachable.

## Root-cause correction

An earlier candidate capacity expression referenced a generated EF2 array leaf hierarchically. VC Formal trace checking identified that reference as **UNDRIVEN** due to generated-array path resolution, so its resulting counterexample was a harness defect and was discarded. The current candidate uses a conservative constant slot for that EF2 stage. The revised run has no counterexample, but remains Inconclusive; the constant is not proof evidence and is not promoted to an invariant.

## Coverage and disposition

No URG run was performed, so this work has no code-coverage delta. The latest same-list Raw and Adjusted report remains Branch 525/637, Condition 658/849, Line 3351/3796, Toggle 84340/104480, FSM states 13/13, transitions 17/22, and legal applicable Functional Coverage 392/392. Approved waivers and active Exclusions remain zero. Both outstanding-counter Raw Branch bins remain **OPEN** and the gate remains `RAW_100_OPEN`.

The exact command, per-file source hashes, report hashes, property results, and coverage snapshot are recorded in [`thermo5-tx-outstanding-capacity-formal-followup-20261103.json`](data/thermo5-tx-outstanding-capacity-formal-followup-20261103.json). Full VC Formal databases and logs remain in the ignored local `runs/thermo5_tx_closure_current/gate4_1_capacity_corrected_full_20261103/` directory.

## Next action

Do not increase seeds or approve waivers from this result. A useful next Formal step must split the source-to-output conservation proof into independently proven control contracts at the CDC, interpolator/DPD elastic boundaries, and PA output, then compose those contracts into the outstanding-counter proof. Until those contracts yield a non-vacuous proof or exact Cover witness, retain both bins as OPEN. No product RTL or frozen algorithm was changed.

# DSM V1.4 independent DV waiver review

**Independent DV Reviewer:** Claude Code. **Final waiver approver:** product owner.
All 106 candidates are pending both decisions. No candidate in this packet has
been applied. Keep rejected rows and their rationale in the review record.

| Primary classification | Original candidates | Disposition |
|---|---:|---|
| Static parameter unreachable | 72 | Review the elaborated bounds and the exact rendered Line slot. |
| Structural unreachable | 12 | Review the 14:8 immediate-end inequality and the Generic FIFO valid/empty relation at the native observation point. |
| Formal proven unreachable within stated assumptions | 22 | Review the instantiated connections, reset semantics, proof scope and operational witnesses. |
| Incomplete proof | 0 | Examples outside the candidate packet stay OPEN. |
| Simulation cost only | 0 | Reachable counter directions outside the packet stay OPEN. |

- [106 candidate records](candidates.csv) identifies every SKU, instance, source
  line, expression or statement, operand or arm, current and baseline URG
  locators, source fingerprint, proof property, assumptions, applicability,
  and witness reference. Stable IDs are `V14-W001` through `V14-W106`.
- [Proof manifest](proof_manifest.json) gives the frozen Git revision and RTL
  tree, DUT parameter values, source and harness fingerprints, the SHA-256 of
  each native Formal report, and the tool's property outcomes with cover depths
  and vacuity status. Operational cover names support reachability of the
  relevant contexts. Only assertions whose tool result explicitly includes
  `non_vacuous` carry that designation.
- [Remaining control and counter examples](open_examples.csv) records
  incomplete control proofs and the exact ranged directional counter gaps.
  It is outside the 106-row candidate inventory. A row in a Toggle range
  represents each bit in that range for the listed direction. The measured
  cost of reaching high bits leaves those rows open.
- [Original Round 6 proposals](../../dsm-v13-round6/round6_waiver_candidates.csv)
  and [original V1.4 proposals](../additional_waiver_candidates.csv) remain
  the historical inventories. The 48 later static proposals in the
  [follow-up ledger](../static_followup_candidates.csv) form a separate batch.

## Review and approval

Review the four Formal run groups from the frozen commit in the manifest.
For each candidate record `review_id`, reviewer disposition and rationale.
Check the exact SKU/instance, elaborated parameter or guarded predicate,
URG line/operand/arm identity, post-reset/four-state sampling applicability,
and relevant Formal assumptions. In particular:

- Cubic stage 1 ties `in_tail` low. Its internally generated output tail
  remains reachable. Confirm the proposed tuples depend on the queued
  input-tail bit and check VCS sampling at reset.
- The DPD wrapper's empty-output/ready proof and its still-inconclusive
  payload-hold assertion concern different requirements.
- The CDC immediate-end arm has a parameter inequality independent of the
  older always-ready harness. The L151 end-remainder false arm has different
  product-scope proof requirements and stays open.
- The two FIFO metadata proofs use the elaborated widths and arbitrary
  traffic handshakes. Confirm each invalid metadata tuple against the
  actual Product Top wiring.

Any approval must name the reviewer decision and the final owner decision by
ID before adjustment. Verify the candidate is still a current raw miss before
applying an approved exact exclusion. Keep the two SKU reports independent.

## Reproduce the packet binding

Use the licensed run worktrees and the selected two-SKU cumulative audit.
The builder hashes the native Formal reports, checks each proof result,
verifies the current native HTML page, and rejects duplicate or hit bins.
It also checks the RTL bytes against the frozen Git revision. The checked-in
manifest contains normalized property evidence so the review can start from
GitHub. The ignored run directories retain the full native artifacts.

```bash
python3 dv/uvm/sim/package_dsm_v14_waiver_review.py \
  --round6-runs ../dsm-v13-mash-uvm-round6/runs \
  --v14-runs runs \
  --current-run runs/v14_latest_20261126 \
  --out runs/v14_waiver_review_replay
```

The current report locators refer to
`runs/v14_latest_20261126/cumulative/<configuration>/`. Use the
[directed closure follow-up](../../../../dsm_v14_directed_coverage_followup.md)
for the VCS/URG reproduction commands.

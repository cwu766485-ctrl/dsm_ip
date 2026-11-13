# Thermo5 DV convergence v2 execution evidence

2026-11-11 Asia/Singapore. Frozen product SHA:
`635be681046b3ab7d6fdda7f4e9818d7226efd66`; no product RTL changes.
Base `thermo5`: `02b5c95c8463827691e4eb95e245b6ca600a6543`.
This short task is stacked on PR55 HEAD `e781c329e20d5607daa9c5378f63dd8c4989012f`.
Neither PR is automatically merged. Technical proof is not independent approval.

## Measured results

- One new licensed directed scenario PASS, using the existing compiled product,
  existing non-identity vectors and fixed seed930000. No random search.
- Independent Python trace oracle PASS: 56 CDC words,56 EF2 words,56 four-plane
  PA words, frame0 applied configuration, zero underflow.
- One new validated single-packet COMMIT/non-identity/boundary/PA-stall window.
  It is **not** a simultaneous boundary/stall event.
- New Formal: five assertions PROVEN/non-vacuous, five exact target covers
  UNCOVERABLE, five positive covers COVERED, zero blackboxes/setup violations.
- Rebound the existing DPD ready proof to matching source hashes and parameters.
  Its separate payload-hold assertion remains INCONCLUSIVE.
- Original54 technical targets: six PROVEN_UNREACHABLE pending review;
  48 UNRESOLVED. No approved exclusions or accepted scope exceptions.
- Actual new Exact URG HIT: **0**. No further seed expansion.
- Utility checks:57/57 PASS. Existing589 regression results retained; only the
  new directed scenario was executed, not another full590-test regression.

## Exact ledger and proof scope

`data/thermo5-pr55-application/v2/coverage_exact_triage_v2.csv` preserves all87
input IDs: the33 already-reviewed CONFIG_UNREACHABLE candidates, six additional
PROVEN_UNREACHABLE candidates,48 UNRESOLVED. All87 remain officially OPEN.
The prior33 were not reclassified. Every record retains native vector and
checksum, source expression, instance and historical provenance; the v2
product-SHA field identifies the current frozen source.

`v2/supplemental_review6.csv` supplies six exact pending decisions:

| Root cause | Exact targets | Evidence |
|---|---|---|
| DPD output empty implies ready | TXB-33613a1855fcc02e8ef4; line93 tuple0/1 | Existing source-matched PROVEN assertion, target UNCOVERABLE, four positive covers |
| Mailbox pending implies synchronized request | TXB-a8041f215017e6e9b5f5; line333 tuple0/1/1 | New PROVEN assertion, target UNCOVERABLE; pending/apply/return-idle positive covers |
| Registered gain metadata implies corresponding valid | Lines112,113,123,124 tuple0/1; four exact IDs in supplemental CSV | Four PROVEN assertions, four UNCOVERABLE targets; live-metadata and invalid-input positive covers |

These targets are procedural expressions evaluated at active clock edges
outside reset. Formal initializes from saved reset and constrains reset high
thereafter. Repeated common-reset epochs require composition; no arbitrary
independent-domain reset signoff is inferred. Mailbox external inputs and frame
boundary are unconstrained. Gain parameters match the product: W16,LANES8,
GAIN_W16,GAIN_FRAC14,HOLD_STATE_ON_DISABLE0; input sidebands are unconstrained.

Gain lines136/137 remain unresolved at product level: the invalid-input metadata
combination is COVERED in the local overapproximation. A local proof cannot
exclude those bins without upstream FIFO composition.

The existing CDC FIFO proof's RTL/harness hashes match. Its runner differs only
in removal of the engine report's `-no_summary` option. The historical clocked
proof does not close continuous-expression event/delta sampling; all seven CDC
technical targets remain unresolved. Historical raw logs are referenced by the
committed audit hashes; this sprint did not rerun that proof or claim a fresh
DPD/CDC Formal run. See `formal_reuse_binding.json` and `new_formal_results.json`.
Formal warnings are retained in the latter; selected setup checks are clean.

Remaining48: Interpolator22,CDC7,Gain2,TX Top15,Frontend2. Interpolator
continuous expressions need predecessor/event/reset reasoning; clock-only
contradictions cannot justify their removal. Outstanding's conditional28-slot
model lacks complete RTL real/synthetic-token refinement. Its previous
INCONCLUSIVE capacity harness was not rerun. The two q1_tail assertion
antecedents remain full-product obligations; scoped omitted-datapath proofs
are not promoted to full-product PASS.

## Scenario inventory and new window

`v2/system_scenario_inventory_v2.csv` inventories590 actual results:
586 legal,4 expected-negative. It retains actual stimulus commands, log hashes,
VDBs, trace paths and observed checker pass messages. Three focused historical
commands are recovered from their Test VDBs, not inferred from scenario names.
All legal logs have zero UVM errors/fatals and no assertion error messages.

Packet audits are parsed only from actual event messages with integrity PASS;
report-count summary lines do not count. `packet_epoch_cross_evidence.json`
retains epoch/packet keys per scenario. Observed existing records include330
same-packet gap/FIFO-full/PA-stall windows,330 run/prefill/gap windows and four
ordered STOP/TLAST/drain windows. These are event records, not new URG hits.
Other requested crosses remain unverified unless explicit evidence is present;
a test name alone is not coverage.

New scenario589 reuses scenario110's attenuation C1=15614 Q2.14, the existing
32-beat packet/vector set and fixed seed. Only the existing directed
`THERMO5_REQUIRE_COMMIT_BOUNDARY_STALL` control is added. Existing source,
PA-sink, AXI-Lite and control ownership is unchanged. Expected output56 words;
existing20000-core-cycle watchdog, transaction scoreboard, EF2 reference,
configuration/status predictor and drained-expectation checks all pass.

The independent window checker requires one complete32-beat packet and one
reset epoch; accepted non-identity coefficient programming; successful COMMIT;
pending→boundary→ack→DONE; real PA stall after boundary; then drained idle.
It rejects reset joins, other-epoch stalls, multiple-packet ambiguity, rejected
writes and identity coefficients. The independent trace oracle checks the
actual CDC/EF2/PA data and applied configuration, independently of test names.

Measured events (ns, recorder epoch0/packet0): pending802.386,
boundary893.826,ack898.398,DONE965.000,PA stall971.550,
drained idle1346.454. This is a packet-lifetime cross, not overlapping boundary
and stall. The measured window and evidence hashes are in
`v2/directed_cross_witness.json`. No VCD/Exact Hit is claimed for this cross.
Other requested timing-window crosses still need equivalent instrumentation
and checker evidence; this sprint does not claim Gate2/3 complete.

## Same-parent licensed URG

Parent: `runs/rtl_invariants/compile2/simv.vdb`.
Compile argument SHA256:
`421a36094a493a2345eff8f165a44197bff12bbcf32a09963a61628353bf599e`.
All589 prior Test VDBs plus the one directed Test VDB are used for each view.
The new Test VDB's native siminfo binds to the same compiled executable.

| Metric | Raw = Official Adjusted | Analysis-only What-if |
|---|---:|---:|
| Branch |526/637|526/528|
| Condition |667/849|667/713|
| Line |3352/3796|3352/3352|
| Toggle |92640/104480|92640/93576|
| FSM states / transitions |13/13;22/22|13/13;22/22|

Three URG reports ran successfully under `runs/dv_convergence_v2/`.
No URG warning/error/checksum/mapping diagnostic; covered counts and denominators
are unchanged from the corresponding589-input views. Exact-hit delta0.
Raw/Official still have12577 unclosed bins; existing What-if has984.
The six new technical candidates are **not applied**, even to this What-if.
There is no new official `.el` or denominator change.

Existing11593 candidate IDs are preserved; supplemental six IDs are disjoint,
so11599 candidates now await independent review. Original371 Waiver references
remain in the unchanged historical index. Approved count0, accepted exceptions0.
The930 diagnostic-counter directions remain OPEN pending product-owner scope
acceptance; independent32-bit block arithmetic evidence is retained and is not
product URG coverage. No counter width or frozen RTL is changed.

## Reproduction and review

From this worktree, with the frozen compiled inputs and authorized licenses:

```bash
python3.12 tools/hw/thermo5_v2_commit_stall.py --out runs/dv_convergence_v2/nonidentity_commit_stall --execute
THERMO5_FORMAL_REPO="$PWD" THERMO5_FORMAL_OUT="$PWD/runs/dv_convergence_v2/mailbox_formal" /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV -f dv/uvm/formal/run_thermo5_mailbox_boundary_v2.tcl
THERMO5_FORMAL_REPO="$PWD" THERMO5_FORMAL_OUT="$PWD/runs/dv_convergence_v2/gain_formal" /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV -f dv/uvm/formal/run_thermo5_gain_metadata_v2.tcl
python3.12 tools/hw/thermo5_v2_urg.py --execute
python3.12 tools/hw/thermo5_v2_formal_results.py
python3.12 tools/hw/thermo5_coverage_exact_triage_v2.py --out docs/verification/data/thermo5-pr55-application/v2
python3.12 -m unittest discover -s tools/hw/tests
```

No tool install, source recompilation or algorithm regeneration is required by
these changes. Review must independently confirm proof/reset/configuration
scope, exact native vectors and the distinction between packet-window and
simultaneous crosses. Independent approval and product-scope decisions remain
outstanding; no Codex decision substitutes for them.

**Code Coverage Signoff: OPEN. Full Linux DV Signoff: OPEN.**

# Final coverage and CDC/RDC closure: partial execution

2026-11-12 SGT. Parent PR58 `30570df96f7322e52532097ffcc8a86125ce4470`.
Frozen product `635be681046b3ab7d6fdda7f4e9818d7226efd66`; RTL diff empty.
This is an incremental review package, not completed final signoff.

## Actual new verification

A new VCS component test checks asynchronous assertion and two-edge local release
of the actual reset synchronizer under three clock periods (8ns/4.572ns/10ns).
Six epochs,18 releases,25 checks PASS. Cyclic release orders and off-edge phases
are checked; not every permutation or product reset contract is covered.

Two purpose-specific product phase cases use source/AXIL offsets137/311ps and
3999/4999ps, reusing the frozen V3 executable and unchanged parameters. At493776ps
and498348ps respectively, the UVM observer records pending COMMIT, PA valid=f,
PA ready=0, EF2 zero-mask0 and branch state[-29277,13350,-21848,-28560]. Public
common reset discards old epoch and restores Identity; each post-reset56-word
CDC/EF2/four-plane oracle passes. Full oracle checks84 CDC/58 EF2/56 PA words
including the accounted pre-reset partial epoch. UVM error/fatal0; watchdog PASS.
These two intentional phase hypotheses are not a random seed campaign. No new
qualified functional cross coverpoint was added; do not infer cross closure from
simulation test counts. VCD/JSONL/log hashes bind actual evidence in adjacent JSON.

Same executable/design parent:594 inherited results +2 new legal results =596
input databases. This is an incremental merge, not a fresh596-test replay.
Five URG views ran:Raw,Official Adjusted,What-if,legal-only,negative-only.
All diagnostics checks clean;no lost covered metric count or denominator drift.
Exact coverage delta0 for Line/Condition/Branch/Toggle; no further phase expansion.

| Metric | Raw=Official Adjusted | Analysis-only What-if |
|---|---:|---:|
| Branch |526/637|526/528|
| Condition |667/849|667/713|
| Line |3352/3796|3352/3352|
| Toggle |92640/104480|92640/93576|
| FSM |13/13 states;22/22 transitions|same|

New Exact HIT0;approved exclusion0;accepted exception0.11599 original candidates
plus2 Gain proof candidates remain PENDING.46 technical unresolved plus8 proof
candidates pending;930 cumulative counter directions OPEN. Official remaining12577.
No official exclusion file generated. Candidate review index retains existing IDs,
source fingerprints and native references; full per-object scope classification,
shared-block review and actual independent decisions remain unfinished. The
filelist inventory explicitly does not pretend compiled modules are elaborated
instances or classify them NON_ELABORATED without hierarchy evidence.

## Static and XPM limitations

Three-domain crossing inventory records Gray pointers,req/ack,bundled data,status,
run,prefill and reset reconvergence. This is source inspection, not static CDC/RDC
signoff. SpyGlass executable was located after correcting its installation path.
The setup probe failed because no top was configured; no license refusal or clean
CDC/RDC result is inferred. Static violation count is UNKNOWN, not zero. Need a
proper AXIL product top, clock/reset constraints and licensed CDC/RDC goals.

The TB AXIL reset releases through one register on AXIL clock; dsm_reset_sync
uses two. Keep this explicit hardware reset contract obligation; no TB or product
reset implementation was silently modified. Component proof cannot close it.

Real AMD XPM models were not found in searched local installation locations.
XPM simulation/coverage are NOT_RUN/BLOCKED; no stand-in model and no Generic
formal exclusion reused. Generic and FPGA SKU remain separate ledger rows.
No reset-busy/full-empty/push-pop/recovery result is fabricated.

## Priority, fault and integration gaps

Source review finds cfg_done_q set in later busy-handshake completion logic after
STATUS W1C clear, so DONE set wins on that reachable conjunction. This is only a
source-derived hypothesis; spec priority confirmation and same-edge witness are
OPEN. Remaining seven requested concurrency combinations and additional negative
cases are not implemented by this increment. Four inherited expected-negative
cases retain their own URG evidence, not coverage of all newly requested faults.
Existing forced mailbox faults stay isolated from legal closure.

No new Formal run without a changed hypothesis. PR58 Gain composition retains its
initialized-reset procedural sampling scope; Outstanding full-token/reset/STOP
refinement and q1_tail antecedents remain OPEN/INCONCLUSIVE.11599 candidate
approvals and930 scope decisions require independent records. PR55->56->57->58
remain unmerged; no integrated clean-parent regression performed.

## Reproduction

```bash
python3.12 tools/hw/thermo5_final_reset_phase.py --execute
python3.12 tools/hw/thermo5_final_cdc_urg.py
python3.12 -m unittest discover -s tools/hw/tests
# component run from a fresh ignored runs directory
vcs -full64 -sverilog -top tb_thermo5_reset_release_contract \
  rtl/axis/dsm_reset_sync.sv dv/verif/reset/tb_thermo5_reset_release_contract.sv \
  -Mdir=runs/reset_replay/csrc -o runs/reset_replay/simv -l runs/reset_replay/compile.log
runs/reset_replay/simv -no_save -l runs/reset_replay/test.log
```

VCS V-2023.12-SP1_Full64.65 utility tests PASS;Python syntax/diff checks PASS.
Scripts require existing local V3 vectors/compile/VDB artifacts;fresh clone must
regenerate/recover baseline artifacts. No product RTL change, so no RTL smoke
claim needed. GitHub licensed job status is independent and not treated as local
verification. Code Coverage Signoff: **OPEN**. Full Linux DV Signoff: **OPEN**.
Next:configure static AXIL CDC/RDC,obtain real XPM models,implement remaining
qualified reset/full/drain and priority/negative tests,then independent approval
and authorized integration;do not claim this partial increment completes them.

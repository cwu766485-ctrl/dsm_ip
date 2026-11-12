# Thermo5 DV convergence v3: P0 execution

2026-11-11. Dependency: PR56 `84aac6bbfc95666ec7c2e312585e7a371488973e`
above PR55. Frozen product SHA `635be681046b3ab7d6fdda7f4e9818d7226efd66`.
Every tracked product RTL file was compared byte-for-byte to the frozen commit.
No RTL, algorithm, product parameter, agent ownership, scoreboard or Python
oracle architecture was modified. No automatic merge or branch deletion.

## P0 measured matrix

Four fixed directed cases complete the three requested P0 groups. All use
seed930000 solely for reproducibility, not a seed search. Source/frame geometry,
coefficient images, transaction counts and checks are explicit in the tests and
`data/thermo5-dv-v3/scenario_matrix.csv`.

| Case | Strict predecessor and actual event | Checked result |
|---|---|---|
| Old/new configuration overlap | Block old Identity PA output; program C1=12288; accepted RUN+COMMIT; wait pending; release progress until second frame approaches DPD; reblock PA before accepted boundary | Boundary and real PA stall both651.510ns; old PA accepted40/56,16 old words still outstanding; pre-edge config tuple111; ack656.082ns;112 CDC/EF2/four-plane PA words match independent model with new config applied only at frame1 |
|64-beat long packet | STOP while packet open (24 accepted beats); continue source through legal TLAST; partial PA-ready0xd during drain | STOP368.046ns < TLAST684.000ns < drain944.118ns;7 actual stalled core edges692.658..720.090ns;112 words checked |
|96-beat long packet | Same contract with longer single packet and full finite-pipeline drain | STOP368.046ns < TLAST940.000ns < drain1200.150ns;7 actual stalled edges948.690..976.122ns;168 words checked |
| Reset/pending/nonzero EF2/stall | Run24-beat partial prefix without illegal TLAST; real PA stall; nonzero EF2 state; accepted nonidentity COMMIT pending with no boundary/ack; public common reset | Pending482.346ns; reset asserted502.920ns and observed505.206ns; prior stalled edge500.634ns; EF2 zero-mask0,branch0 state[-29277,13350,-21848,-28560]; no config apply; postreset Identity56-word replay and drain PASS |

The overlap case now tests **simultaneous** accepted DPD boundary, pending
COMMIT and stalled old-config PA output. The blocked PA word belongs to the
first56-word frame because only40 words have been accepted, output order is
checked independently, and the Python trace model independently applies the
new coefficient at frame1. The native config VCD is sampled immediately
before the651510ps edge, not after NBA updates. No forcing/deposit is used.

The reset case checks the real four-branch EF2 state via existing read-only
probes; state is not inferred from nonzero input. Reset clears pending/busy,
restores Identity and all-zero EF2 state. The initial epoch is intentionally
reset-terminated: oracle checks28 CDC words,2 accepted EF2 words,0 accepted PA
words, and explicitly accounts for discarded model tail. Next epoch checks56
CDC/EF2/PA words. No discarded output is counted as completed or covered.

`actual_event_witness.json` contains monitor-event times, native VCD evidence
binding, actual state, independent oracle output and log/trace/VCD hashes.
Each P0 runs the existing transaction/protocol checks, lockstep/stall-hold
checks, bit-true PA scoreboard, status/config predictor and independent Python
CDC/EF2/PA trace oracle. All have zero unexpected underflow/protocol errors.
Overlap/reset have20000-core-cycle progress watchdogs; existing long-packet
watchdog is12000 cycles with bounded source/output/drain waits. Long cases
reuse the existing graceful-stop test, not a duplicate implementation.

## Inventory and compile consistency

The existing590 inventory rows were verified against log hashes and actual
trace events:472 distinct recorded stimulus/control/stall/response signatures,
118 duplicate records;47 rows lack traces and remain distinct/unverified for
semantic deduplication. Timing is retained in signatures. This establishes
identity of recorded events, not unobserved pin waveforms. No VDB was deleted
or dropped. The330 existing same-packet gap/FIFO/PA windows were not rerun to
search for additional coverage.

Two new UVM classes require a DV compile. The final compile is frozen under
`runs/dv_convergence_v3/compile`; original590 scenarios were replayed once on
that final parent to avoid mixing old/new Test VDB compile lineage. This is a
consistency regression, not seed expansion. All590 replay cases PASS plus4 P0
PASS:594 total,590 legal,4 expected-negative. Product parameters remain
Generic FIFO,AXI-Lite,centered cubic x2+x2,MAX_TAPS1,EF2 ORDER2/STEP5120.
Compile argument SHA256:
`930657751028c5fd28c8999cd6bcdab5c5b81abae42f315fbf2e50b82329b38c`.

Two overlap scheduling failures are retained under ignored
`runs/dv_convergence_v3/failed_attempt{1,2}`. First the readiness change was
requested after the native boundary was already presented. Moving observation
one registered FIFO upstream produced the real intersection, but the check
then skipped the first ready edge: existing `set_ready()` already returns on
that edge. Final code samples that edge directly. Neither failure is hidden as
a PASS or attributed to product RTL. An initial reset prefix attempt supplied
a32-beat packet override incompatible with24-beat partial prefix; that test
setup was removed without changing protocol rules. The final four scenarios
were all rerun against the final compile.

## Exact coverage and Formal

Five licensed URG views ran: Raw,Official Adjusted,Analysis-only What-if,
legal-only Raw and expected-negative-only. All use the same final parent and
appropriate Test VDB subset; the three combined views use identical594 inputs.
Zero URG warning/error/checksum/mapping diagnostics. No prior covered count or
metric denominator changed. **Actual new Exact Code Coverage HIT:0.**

| Metric | Raw = Official Adjusted | Analysis-only What-if |
|---|---:|---:|
| Branch |526/637|526/528|
| Condition |667/849|667/713|
| Line |3352/3796|3352/3352|
| Toggle |92640/104480|92640/93576|
| FSM states / transitions |13/13;22/22|13/13;22/22|

The48 exact technical targets were compared to the actual product URG. No
Condition target became Covered. All remain OPEN in `remaining48.csv`:
Interpolator22,CDC7,TX Top15,Frontend2,Gain2. P0 control/transaction scenarios
exercise different combinations; they are functional progress, not code-bin
closure. No additional seeds or unchanged INCONCLUSIVE harness were run.
Outstanding's conditional weighted28-slot bound remains unrefined to the full
RTL/reset/STOP chain. q1_tail antecedents remain full-product obligations.
New Formal runs:0; v2 scoped proof results are retained with their original
scope, not silently broadened. Remaining predecessor/event proofs are P1 work
after this P0 delivery, not completed by these four tests.

Pending candidates11599,approved exclusion0,accepted exception0. The930
cumulative-counter directions remain OPEN pending independent product scope
decision; no high bit is marked unreachable. Official remaining12577 =11599
pending candidates +48 unresolved +930 counters. Existing analysis-only
What-if remaining984 =54 unapplied technical targets (six proven pending
from v2 plus48 unresolved) +930 counters. No `.el` or denominator was changed.

Legal-only DUT assertions:13 SUCCESS,0 FAILURE,two q1_tail without attempts.
Combined3 assertion failures occur only in the four expected-negative cases;
negative test contracts still PASS. GitHub syntax/hygiene success is separate
from licensed verification; a skipped licensed job is never counted as PASS.

Utility regression:65/65 PASS. Python reference-model regression:66/66 PASS
with the required `PYTHONPATH`. Initial invocation without that import path
failed collection; it was corrected before reporting the measured result.

## Reproduction and review

P0 generation/compile/execution (licensed host):

```bash
bash dv/uvm/sim/run_thermo5_v3_p0.sh --execute
python3.12 tools/hw/thermo5_v3_inventory.py
python3.12 tools/hw/thermo5_v3_replay.py --execute
python3.12 tools/hw/thermo5_v3_urg.py --execute
python3.12 tools/hw/thermo5_v3_p0_witness.py
python3.12 -m unittest discover -s tools/hw/tests
PYTHONPATH="$PWD/dv/uvm/refmodel/python" python3.12 -m unittest discover -s dv/uvm/refmodel/python/tests
```

Inventory/replay depend on the existing local source590 commands/vector
artifacts; exact plans and per-test argv are retained in the manifests. A fresh
clone requires regenerating/recovering those inherited vectors before replay;
P0 vectors are generated directly by the committed script. Runtime artifacts
and large VCDs stay under ignored `runs/`; compact evidence hashes are tracked.

Review the actual event conjunction, old/new coefficient frame mapping, reset
partial-epoch accounting, single driver ownership and native URG deltas. No
reviewer approval is fabricated. Separate short task Review PR stacks on PR56;
no auto merge. Source,tool and VDB evidence hashes are in
`data/thermo5-dv-v3/execution_manifest.json` and `vdb_urg_manifest.json`.

**Code Coverage Signoff: OPEN. Full Linux DV Signoff: OPEN.**

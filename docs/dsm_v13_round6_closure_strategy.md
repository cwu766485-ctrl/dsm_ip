# Round 6 closure strategy for EF1 and MASH AXI-Lite

Baseline `1c91d73`. Scope is the two production AXI-Lite elaborations with
centered cubic interpolation and one DPD tap.

| Adjusted metric | EF1 remaining | MASH remaining |
|---|---:|---:|
| Line | 80 | 76 |
| Branch | 23 | 25 |
| Condition | 63 | 63 |
| Directional Toggle | 1,848 | 1,872 |

Condition starts at 643/706 per SKU. Gate A takes 28 more hits if the
denominator is unchanged. A 16-lane DPD hit alone yields 659/706 (93.34%).
If the independent wrapper tuple exclusion is also approved, this becomes
659/705 (93.48%) and 11 more hits would reach 95%. Gate B still requires
every remaining obligation to be closed. The baseline contains 4,050
remaining metric obligations across the two SKU reports.

## DPD witness and wrapper proof

The two-entry FIFO calculates its input ready from registered occupancy.
With occupancy one, accepting a valid DPD output without popping makes
occupancy two at the next edge. If the following DPD slot is a bubble,
the target tuple is present at that edge. The attached slice test drove
two valid words followed by a bubble with a blocked sink. VCS observed six
cycles at FIFO count two with ready and valid both low. Both accepted
words reached the checked sink unchanged. URG reported the exact L141
`0,1` operands covered in this slice run.

The first product experiment should look for an occupancy-one push with
no pop and a bubble in stage 9 before that edge. Use existing interface
controls to vary source bubble placement and hold PA until that event is
observable, then release and check drain and all four output planes.
Log per-lane last valid, FIFO count and push/pop, both interpolator queue
counts and accepted AXIS/PA events. Search across frame-boundary offsets
and clock phases using those observations rather than number of random
seeds. If the stage-9 bubble and occupancy-one push cannot be aligned in
product, use the real 16-lane DPD, FIFO, interpolator 2 and legal upstream
metadata and backend admission in the formal harness. Capture external
input differences for product replay. The local slice's direct control
of downstream ready proves local reachability only.

The wrapper condition uses different operands than L141. Lane 0 feeds
both wrapper signals and its empty-output state raises input ready.
VC Formal has reported the local ready implication `proven` and the
cover for the forbidden tuple `uncoverable`. Acceptance, transfer,
stall and stall release covers hit. The separate stalled-payload hold
property was still checking when the local reachability result appeared. Check the exact
`(in_ready, !out_valid)=(0,1)` report location in the reset sampling
scope before submitting one exclusion per SKU.

## Close remaining Condition, Line and Branch

- Treat interpolator 1 and interpolator 2 separately. Prove the stage-1
  tail metadata invariant from the reset and all assignments to the
  retained bits, with the elaborated `in_tail=0` connection. For stage 2
  constrain the tail using the real stage-1 metadata path through DPD
  and both elastic FIFOs. Partition predicates by queued vs stale
  metadata, tail vs non-tail, and reset vs runtime. Cover retained
  `q1_start` with a non-full queue before assuming that state is absent.
  Keep reset-at-stall sampling tied to the native VCS observation edge.
- For COMMIT L333, cover `1,0,1` at the first cycle the synchronized
  request is visible and at the interval after pending clears and before
  the request drops. For `0,1,1`, investigate whether pending can survive
  a synchronized request falling edge under the real shared reset and
  ack lifecycle. Run covers at exact core edges, then prove the
  unreachable case only if the induction closes. Observe request,
  pending, ack and the actual DPD boundary in the replay.
- Start CDC at L113 empty and L145 remainder/end pending with both clock
  phases accounted for. Drive packet boundaries, prefill, STOP in flight,
  drain and delayed PA ready. Preserve the drain-complete-before-RUN
  contract. For each waveform distinguish empty flag, valid beat and
  remainder. Carry the same witness into the corresponding Line and
  Branch checks wherever their exact predicates match.
- Reconcile Line and Branch missing statements and arms with native
  URG per-instance denominators. Use source/expression/arm identity,
  whitelist only proven stable scope and explicitly audit simulation-only
  statements such as MASH L254 for applicability. Keep raw counts in the
  release report.

## Start the counter campaign in parallel

The Round 5 rendered range inventory includes 640 EF1 and 624 MASH
missing sample-counter directions plus 784 saturation-counter directions
per SKU. These two counters alone account for 77.1% and 75.2% of the
respective remaining Toggle obligations. With a zero start, a bit-31
rise requires at least 2^31 qualifying increments in that lane. Both
directions by uninterrupted natural wrap require 2^32 increments.
A checked legal reset after the rise is another candidate for the
falling direction, provided native URG actually counts it. Saturation
increments are conditional per lane and typically slower than the
accepted sample count.

Measure VCS increments and checked PA words per wall-clock second on
one legal saturation stream and one sample-count stream. Use checkpointed
lengths to forecast both directions and stream the oracle instead of
materializing a multi-billion-word vector set. First close small ranges
with real data, coefficient round trips, frame and gang-stall events.
For constrained high data bits identify the exact bit and prove both
the value range and absence of the missing direction. A separate
formal counter transition proof gives verification evidence, but the
raw simulation toggle remains open until hit.

## Evidence gates

Freeze RTL, parameters, hierarchy, simulator and coverage schema.
Rebuild and replay the accepted 30 EF1 and 32 MASH VDB cases. Track
covered and missing identities for every metric, not just counts.
For the same schema require that each old hit is still present and
report every change in the instrumented universe. Keep per-SKU scores
and use separate identifiers for per-bit directions and expression arms.
Each new credit is either an exact URG hit on a passing product replay
or an independently reviewed, scoped exclusion with completed proof
and an applicability check. Proof timeouts and bounded no-hit results
stay OPEN. Preserve raw results, functional and mandatory cross checks,
FSM and non-vacuous critical assertions. Gate B requires all of them
along with clean UVM results and zero unexplained or unapproved items.

The slice test source is
`dv/uvm/tests/thermo5/block/thermo5_dpd_fifo_bubble_tb.sv`.
The existing wrapper proof flow is
`dv/uvm/formal/run_thermo5_dpd_vector_ready_fpv.tcl`.
Round 6 has no Product coverage credit yet.

## Reproduce the first checks

Compile the slice top `thermo5_dpd_fifo_bubble_tb` in VCS with
`-sverilog -cm cond` and these RTL sources from the frozen worktree:
`rtl/dpd/dpd_poly.v`, `rtl/dpd/dpd_memory_poly.v` and
`rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv`. Run `simv -cm cond`
and generate URG from `simv.vdb`. The measured output marker is
`R6_BUBBLE_SLICE_PASS hits=6 in=2 out=2`. Locate the L141 report table in
the `dpd_memory_poly` module page. Local execution artifacts are in
`runs/r6_bubble_replay/` and `runs/r6_vector_ready/`.

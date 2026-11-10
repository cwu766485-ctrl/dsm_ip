# Round 21 legal single-entry queue replacement closure

One directed full-product test closes 18 exact bins: two Branch, fourteen
Line, two Condition. Both centered-cubic stages now witness
q_count=1 && pop_head && push_input. No product RTL or parameters changed.

The public source driver pauses before beat 32 of two 32-beat packets.
VCD analysis showed a 12-source-cycle pause delivered the second frame too
late: the ending head popped before the next input arrived, and actual source
underflow occurred. That failed run is preserved and excluded from all merges.
A ten-cycle pause passed the four-plane oracle but delivered the input while
the queue was still full; it is also excluded. The eleven-cycle pause places
the next accepted input on the exact single-head retirement edge. It passes
both stage events, all 112 four-plane outputs, 64 source beats, two packet
ends, two frame starts, per-lane counters, zero underflow and legal drain.

The two exact Branch IDs are TXB-9141942b3f6f51689217 and
TXB-33db6d34081fd3b6ec60. Fourteen Lines at 256-261/263 in both stages
now execute. Conditions TXB-6bd0d4bf3b12051ce406 (interpolator frame end)
and TXB-7283983e103cdc1728bb (CDC start handshake) also hit.
All 18 IDs, source hashes, instances and native truth tuples are recorded in
[data/thermo5-r21/queue_boundary/exact_hits.json](data/thermo5-r21/queue_boundary/exact_hits.json).
The remaining ledger contains 231 exact non-counter bins; every unresolved
row stays OPEN.

The UVM test now supports THERMO5_REQUIRE_SINGLE_REPLACEMENT: a missed stage
event fails the run instead of reporting only functional PASS. Reproduce with
`dv/uvm/sim/run_thermo5_single_replacement.sh`, setting THERMO5_SIMV to the
current compiled product executable, THERMO5_VECTORS to the independent
112-word/two-frame identity vectors and THERMO5_OUT to a fresh run directory.
The runner checks both nonzero events and zero UVM errors/fatals. The strict
compile, simulation, runner replay and VCD checks passed. No internal force,
deposit, coverage exclusion or parameter override was used.

| Metric | Incremental Raw / zero-approved Adjusted | Analysis-only What-if |
| --- | --- | --- |
| Branch | 526/637 | 526/529 |
| Condition | 664/849 | 664/741 |
| Line | 3352/3796 | 3352/3363 |
| Toggle | 92640/104480 | 92640/93710 |

What-if remaining: 1,161 = 231 non-counter + 930 counter. Raw remaining:
12,580. This follow-up adds 18 bins over address-return closure; the two
follow-ups together add 26 bins over a98a32d. Approved exclusions/exceptions
remain zero. All three actual URG reports use identical inputs: the preserved
address-return aggregate, strict current Design VDB and strict passing Test
VDB. URG logs have no warning/error/checksum/mapping diagnostics. Product RTL
hashes match the frozen snapshot; the compile parent differs due to DV edits.
These are incremental results, pending homogeneous final replay/signoff.
Full regression and Formal were not rerun for this DV-only change.

## Remaining acceptance decisions

The three requested dispositions require different evidence. Reachable bins
need exact legal witnesses; current missed bins are not declared unreachable.
Configuration-dependent alternatives remain useful in shared modules: the
MAX_TAPS history paths and APPEND_TAIL_VECTOR alternatives are not established
global dead code and have not been deleted. No all-configuration dead RTL was
proven in this follow-up.

The 11,419 analysis candidates still lack real independent approval. The four
additional DPD History-line proposals still include two unresolved companion
native objects. The 930 counter directions are legally reachable; the existing
block arithmetic test supports a system scope acceptance request, not an
unreachability waiver. Neither a coverage percentage target nor a general
instruction to waive unnecessary bins supplies independent technical approval
for those exact records. Code Coverage and Full Linux DV signoff remain OPEN.

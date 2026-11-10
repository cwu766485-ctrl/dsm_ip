# Round 21 AXI-Lite blocked-response exact review

Candidate TXB-872eb98e51c3229e4c86 is the line-93 whole-expression tuple
0/1/1 for write_fire. A directed public AXI-Lite sequence holds BREADY low,
presents the next AW/W while backpressured, accepts both responses and checks
TAPS/CONTROL readback. VCS compile and test PASS; UVM errors/fatals=0.
Actual Raw/Approved Adjusted/What-if URG delta is zero in all metrics.
No extra seeds were added. Current remaining stays 1,161 (231+930).

The existing exact line-93 Formal harness was rerun on current product RTL:
one assertion PROVEN, non-vacuous; normal write_fire and response covers
reached at depth 4; the exact uncovered tuple is UNCOVERABLE. Two generated
constraints keep resets released after saved initialization. MAX_TAPS=1,
core_tx_active/core_draining are tied zero in this block harness. These ties
are recorded limitations; the write-channel transition logic is independent
of them. No product-wide waiver or full Linux DV signoff is claimed.

The transition argument is explicit: write_fire clears both pending flags
when it raises BVALID. While BVALID=1 both ready signals are zero, so neither
take term can set pending; the exact 0/1/1 conjunction cannot arise. This is
a configuration-block reachability result, not a removed defensive check.

The native template scope checksum and Condition 21 / vector 011 directive,
source/configuration hashes and proof reports are in
[data/thermo5-r21/bstall/exact_review.json](data/thermo5-r21/bstall/exact_review.json).
Approval remains PENDING_INDEPENDENT_REVIEW. No official .el changed, no
candidate was added to What-if and the 371 official IDs remain untouched.
The new test is retained as a legal protocol regression for blocked responses.
Full regression was not rerun; incremental merges still require homogeneous
replay before final coverage signoff.

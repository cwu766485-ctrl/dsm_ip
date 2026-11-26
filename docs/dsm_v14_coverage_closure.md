# DSM V1.4 coverage closure

## Branch ownership

| GitHub branch | Initial commit | Scope |
|---|---|---|
| `dsm_v1.2_cdc_rdc` | `0c871909` | Previously published CDC/RDC line and reset evidence |
| `dsm_v1.3_uvm_platform` | `2d2364f` | Multi-SKU UVM platform through adjusted functional coverage in Round 4 |
| `dsm_v1.4_coverage_closure` | `ecef4a3` | EF1 and MASH 1-1 Centered Cubic AXI-Lite code coverage |

V1.3 is an ancestor of V1.4. V1.2 has its own development history.
Treat any future CDC/RDC import as a specific reviewed change and rebuild
SKU-local coverage on the resulting RTL. Keep the original `work/*`
branches as run and review references. The local CDC worktree has one
additional commit, `336c1ce`. The V1.2 branch uses the previously
published tip.

## Current evidence

| Adjusted metric | EF1 AXI-Lite | MASH AXI-Lite |
|---|---:|---:|
| Line | 97.52% | 97.53% |
| Branch | 95.68% | 95.23% |
| Condition | 93.77% | 93.77% |
| Toggle | 98.13% | 97.63% |

VCS V-2023.12-SP1 replayed 12 passing two-packet frame replacement cases
with the existing, compatible Round 6 binaries. Each case accepted 64
source beats and checked 112 words on all four PA planes, including
drain completion and DPD lane counts. The six RUN/source delay pairs
per SKU produced zero target single-entry pop/push events in both
interpolators. The SKU-local URG merges had zero new hits in the four
code metrics. Exact Condition comparison retained all 662 hits per SKU.
See the [case manifest](verification/data/dsm-v14-coverage/frame_replacement_cases.json),
[raw and adjusted metrics](verification/data/dsm-v14-coverage/code_coverage.csv)
and [Condition comparison](verification/data/dsm-v14-coverage/condition_delta.json).

VC Formal V-2023.12-SP2 proved four RTL invariants. The production
Generic FIFO drives read-valid as the complement of read-empty. The
14:8 gearbox residual never escapes its legal seven values, with
core enable, ready and drain unrestricted. The elastic FIFOs feeding
Frame Gain and the DPD frame-start boundary zero their metadata whenever
their output is invalid. Both FIFO proofs are non-vacuous. Empty and
nonempty states were covered. An unconstrained gearbox source covered
a pending end with a short residual, so the L145 condition requires
product-legal replay or a stronger source-contract proof.

Three additional runs used the existing CDC proof harnesses. They
proved the outer default path and immediate frame-end arm unreachable
in their scopes. The immediate arm is also structurally unreachable
for the fixed 14:8 parameters because `rem_count_q + 14` is greater
than 8 for each case entering that branch. The end-remaining false arm
was proved under a valid 32-beat-quantized source with the core always
ready and enabled. L151 remains OPEN in the product ledger until its
applicability under stalls and product control is established. The
[formal results](verification/data/dsm-v14-coverage/formal_results.json)
include property outcomes, scope and report hashes.

## Waiver review and gates

The [additional waiver ledger](verification/data/dsm-v14-coverage/additional_waiver_candidates.csv)
maps 5 Condition, 5 Line and 2 Branch candidates **per SKU** to exact URG
instances and source predicates. It records the reason, proof result,
report hash and applicability. Each candidate is pending review.
Neither the numerator nor the denominator was changed. Raw results
and the Round 6 applied exclusions remain available. If the five prior
and five new Condition proposals per SKU are all approved, Condition
would be `662 / (706 - 10) = 95.11%`. Both the 95% official gate and
100% final gate are currently OPEN.

The next proof/replay loop must constrain stage-2 tail and frame markers
using the upstream product protocol before crediting any queue proof.
Keep COMMIT phase analysis aligned to actual product DPD handshakes.
For high-bit Toggle, track qualifying counter increments in a dedicated
long simulation and retain both edge directions. Known reachable
counter directions stay open until simulated. The final gate also
requires the reachable FSM, mandatory functional/cross and critical
assertion evidence on the final configuration.

## Reproduction

Run `dv/uvm/sim/run_dsm_v14_frame_replacement.py` with the Round 6 build
and merged baseline directories. Use VCS URG from the same release.
Run `dv/uvm/formal/run_thermo5_v14_frontend_control_fpv.tcl` with
`THERMO5_FORMAL_REPO` set to this checkout and `THERMO5_FORMAL_OUT`
set to a fresh, ignored run directory. The three CDC Tcl entry points
are `run_thermo5_cdc_default_branch_fpv.tcl`,
`run_thermo5_cdc_end_branch_fpv.tcl`, and
`run_thermo5_cdc_end_remaining_fpv.tcl`. Compare their native proof
reports before reviewing the candidate ledger.

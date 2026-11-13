# Thermo5 PR #55 — Exact-Bin Exclusion Technical Triage (NOT APPROVED)

- Product SHA: `635be681046b3ab7d6fdda7f4e9818d7226efd66`; base branch `thermo5`.
- Source ledger: `docs/verification/data/thermo5-rtl-invariants/open87_review.csv` (PR #55 branch).
- This is an additional engineering recommendation, **not independent reviewer approval**, not a formal proof of the full chain, and not an applied URG `.el`.
- Do not alter product RTL/parameters, raw VDB, DUT coverage hierarchy or the official adjusted coverage for this document.
- Exactly 33 new *non-overlapping technical candidates*: **23 parameter/assignment based** and **10 conditional on the legal packet contract**. Existing 11,560 candidate IDs remain separate. All 33 are **PENDING** until actual scope review; no approved/excluded/hit counts are changed.

## FRONTEND_CONSTANT_METADATA (6)

**Triage:** `STATIC_PARAMETER_AND_ASSIGNMENT`. Fixed Stage-2 APPEND_TAIL_VECTOR=0 forces i2_tail=0; final elastic FIFO's in_meta=1'b0 and output metadata is not product-consumed. For out_meta, review FIFO reset/occupancy/write-before-read path; RAM is not reset.

| Exact semantic ID | Metric | Instance | URG bin / direction | Native mapping |
|---|---|---|---|---|
| `TXB-163c73f4fcaa40135c32` | toggle | `dut.u_frontend.u_interp2_to_tid_fifo` | `Port Details:out_meta:0_to_1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-69539e312147372cd222` | toggle | `dut.u_frontend.u_interp2_to_tid_fifo` | `Port Details:in_meta:0_to_1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-834d3694d32e41562627` | toggle | `dut.u_frontend.u_interp2_to_tid_fifo` | `Port Details:out_meta:1_to_0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-a1f4b10f37fc0e0d7f0b` | toggle | `dut.u_frontend` | `Signal Details:i2_tail:0_to_1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-cc6988a51fba9f886f57` | toggle | `dut.u_frontend.u_interp2_to_tid_fifo` | `Port Details:in_meta:1_to_0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-f32b89aed692c2088278` | toggle | `dut.u_frontend` | `Signal Details:i2_tail:1_to_0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |

## INTERP1_ZERO_INPUT_TAIL (6)

**Triage:** `STATIC_PARAMETER_AND_ASSIGNMENT`. Stage 1 input in_tail=0; q0_tail/q1_tail are reset to zero and only copied from fixed-zero input or each other. Never treat stage-2 incoming tails the same way.

| Exact semantic ID | Metric | Instance | URG bin / direction | Native mapping |
|---|---|---|---|---|
| `TXB-471301ea0e99716856de` | cond | `dut.u_frontend.g_interp1_centered.u_interp_1` | `229:1/1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-49fe8b7a3097cfabcafe` | cond | `dut.u_frontend.g_interp1_centered.u_interp_1` | `229:0/1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-909c9c41ce328d3b5464` | cond | `dut.u_frontend.g_interp1_centered.u_interp_1` | `71:1/0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-9b12c02ba9030d039784` | line | `dut.u_frontend.g_interp1_centered.u_interp_1` | `231:0` | `EXACT_SHARED_BLOCK_MEMBERSHIP_MAPPED_REVIEW_SCOPE_REQUIRED` |
| `TXB-be8f42508812865048fe` | line | `dut.u_frontend.g_interp1_centered.u_interp_1` | `230:0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-d07f79d0903a608e2544` | cond | `dut.u_frontend.g_interp1_centered.u_interp_1` | `68:1/1/0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |

## INTERP2_APPEND_DISABLED (11)

**Triage:** `STATIC_PARAMETER_AND_ASSIGNMENT`. Stage 2 APPEND_TAIL_VECTOR=0 makes tail_output and tail_fire zero; synthetic-tail production lines cannot execute. Stage 2 CAN receive and consume upstream tail and that behavior must remain covered. Resolve any ambiguity in URG negated-expression operand truth mapping before application.

| Exact semantic ID | Metric | Instance | URG bin / direction | Native mapping |
|---|---|---|---|---|
| `TXB-1d320f7692d3831884d0` | cond | `dut.u_frontend.g_interp2_centered.u_interp_2` | `74:1/1/1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-3a9590e170ea70bbfa6e` | cond | `dut.u_frontend.g_interp2_centered.u_interp_2` | `85:1/0/1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-4445cf3565dc723fc045` | cond | `dut.u_frontend.g_interp2_centered.u_interp_2` | `74:1/1/0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-5289de10c1a887214158` | cond | `dut.u_frontend.g_interp2_centered.u_interp_2` | `71:1/0/1/1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-a0aba78f44b5d6586879` | line | `dut.u_frontend.g_interp2_centered.u_interp_2` | `226:0` | `EXACT_SHARED_BLOCK_MEMBERSHIP_MAPPED_REVIEW_SCOPE_REQUIRED` |
| `TXB-ac118cc658b7c8ebe27f` | cond | `dut.u_frontend.g_interp2_centered.u_interp_2` | `84:0/1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-b450fec02bca474b90bf` | cond | `dut.u_frontend.g_interp2_centered.u_interp_2` | `84:1/1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-ba8067539d65e06536a5` | line | `dut.u_frontend.g_interp2_centered.u_interp_2` | `224:0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-c659ce0f8167f1f726df` | line | `dut.u_frontend.g_interp2_centered.u_interp_2` | `225:0` | `EXACT_SHARED_BLOCK_MEMBERSHIP_MAPPED_REVIEW_SCOPE_REQUIRED` |
| `TXB-d50ead3bf05f3974fcad` | line | `dut.u_frontend.g_interp2_centered.u_interp_2` | `218:0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-da673e9462548c47c6c3` | cond | `dut.u_frontend.g_interp2_centered.u_interp_2` | `74:1/0/1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |

## LEGAL_FRAME_RESIDUAL_EIGHT (10)

**Triage:** `LEGAL_PROTOCOL_SCOPE_ONLY`. For externally legal positive packet lengths of 32*k AXIS beats and the fixed 14:8 gearbox, pre-end remainder=2 and pending end_remaining=8, otherwise zero; 89-state abstract control analysis supports this. Arbitrary TLAST produces counterexamples (e.g., remaining=12), so this is NOT module-wide dead code and does NOT apply without the verified legal packet constraint.

| Exact semantic ID | Metric | Instance | URG bin / direction | Native mapping |
|---|---|---|---|---|
| `TXB-06fed7d29a61e25fe30f` | toggle | `dut.u_cdc` | `Signal Details:end_remaining_q[1]:1_to_0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-1415045e35496892448e` | toggle | `dut.u_cdc` | `Signal Details:end_remaining_q[1]:0_to_1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-3e5062f914cef6907205` | toggle | `dut.u_cdc` | `Signal Details:end_remaining_q[4]:1_to_0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-4b9564ffe2d5249793c5` | toggle | `dut.u_cdc` | `Signal Details:end_remaining_q[2]:1_to_0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-85afd49f35a994cc290c` | branch | `dut.u_cdc` | `122:0/-/1/1/0/-/-/-/-/-/-/-` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-8c173b5f5995ee34fbfa` | toggle | `dut.u_cdc` | `Signal Details:end_remaining_q[4]:0_to_1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-bdf18ac87d802fe3b1d7` | toggle | `dut.u_cdc` | `Signal Details:end_remaining_q[2]:0_to_1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-c396f1ff30f1639e6be9` | toggle | `dut.u_cdc` | `Signal Details:end_remaining_q[0]:0_to_1` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-e4810d348ea657bf627a` | line | `dut.u_cdc` | `151:0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |
| `TXB-e48513f6185346ea2beb` | toggle | `dut.u_cdc` | `Signal Details:end_remaining_q[0]:1_to_0` | `EXACT_VECTOR_OR_DIRECTION_MAPPED` |

## Hard boundaries before an actual URG exclusion

1. The **3 shared native basic-block mappings** in this set require full member and native scope inspection, not blanket line exclusion. Existing 5 shared-block review obligations across the broader candidate population remain.
2. Resolve exact URG subexpression semantics (especially unary negations), source checksum, elaborated instance parameters and selected vector/direction on the *frozen* VDB. Do not guess from RTL line text.
3. CDC's 10 bins require an explicit **legal-only** coverage policy and evidence that malformed TLAST is tested as expected-negative elsewhere. An abstract transition analysis is not a full-chain equivalence proof.
4. Obtain genuine reviewer / owner decision for each semantic-ID group; no GitHub self-review is to be represented as independent approval.
5. Only once approved, use the repository's existing native-exclusion generator, create a separate approved `.el`, rerun Raw/Official Adjusted/Analysis-only URG on identical VDB inputs, verify no checksum/mapping/scope warnings, and record precise applied Bin counts.

## Remaining 54 technically OPEN: stop unproductive random scans

| Target | Decision/action |
|---|---|
| Interpolator residual conditions | Group by exact expression and sample/event clock context; target legal stage-1/stage-2 queue events and async-reset propagation separately. Avoid stable-state-only assumptions for event-driven Condition bins. |
| Outstanding high bits / guard | Derive actual real-word conservation across two elastic buffers, DPD, interpolation tail insertion/drop, reset and STOP. The old 29-slot conservative count is **not** a proof that bit5 or under/overflow guards are unreachable. |
| CDC FWFT/empty/ready and control | Derive predecessor states; exercise legal source bubbles, PA backpressure, frame boundary, soft reset and drain with independent reference. |
| Frame Gain valid/metadata | Exercise actual valid=0 with stale metadata as well as frame-start/end while all pipeline stages are stalled; don't exclude based solely on AND expression logic. |
| DPD/AXI-Lite commit | Exercise back-to-back legal COMMIT at true DPD input boundary and a delayed response; require exact URG delta and oracle pass. |
| Counter high bits (930) | Remain legally reachable; require product-scope acceptance decision or product redesign + full re-freeze, not unreachable exclusions. |

**Stopping rule:** Each new directed test must declare expected semantic IDs and demonstrate a new native Exact HIT. If no delta, keep existing evidence and reclassify the predecessor-state hypothesis; do not multiply seeds.

**Latest verified PR #55:** 589/589 (585 legal + 4 expected negative), zero new Exact HIT, zero approved exclusions/exceptions; Raw=Official Adjusted; both Code Coverage and full Linux DV Signoff OPEN.

# DSM V1.3 Round 6 coverage execution

**Gate A OPEN. Gate B OPEN.** This run targets the EF1 and MASH 1-1
AXI-Lite products with Centered Cubic interpolation and one DPD tap.
EF2 retains its separate Research status. The frozen baseline is
`1c91d73`. The product RTL is identical to that baseline.

## VCS and URG results

| Product | Metric | Round 5 raw / adjusted | Round 6 raw / adjusted | Round 6 adjusted hits / total | OPEN |
|---|---|---:|---:|---:|---:|
| EF1 AXI-Lite | Line | 93.36% / 97.52% | 93.36% / 97.52% | 3148 / 3228 | 80 |
| EF1 AXI-Lite | Branch | 94.27% / 95.68% | 94.27% / 95.68% | 510 / 533 | 23 |
| EF1 AXI-Lite | Condition | 86.77% / 91.08% | 89.34% / 93.77% | 662 / 706 | 44 |
| EF1 AXI-Lite | Toggle | 90.42% / 98.09% | 90.46% / 98.13% | 94836 / 96648 | 1812 |
| MASH AXI-Lite | Line | 93.18% / 97.53% | 93.18% / 97.53% | 3005 / 3081 | 76 |
| MASH AXI-Lite | Branch | 94.87% / 95.23% | 94.87% / 95.23% | 499 / 524 | 25 |
| MASH AXI-Lite | Condition | 86.77% / 91.08% | 89.34% / 93.77% | 662 / 706 | 44 |
| MASH AXI-Lite | Toggle | 88.25% / 97.58% | 88.29% / 97.63% | 75604 / 77440 | 1836 |

Each SKU needs nine additional Condition hits at the current denominator
to reach Gate A. Gate B requires further hits or approved exclusions
for all outstanding items, plus independent evidence for reachable FSM,
mandatory functional and cross bins and critical assertion activation.
Those sign-off gates have no new closure verdict in this report.

VCS rebuilt both product configurations and replayed all 62 original tests
(30 EF1 and 32 MASH). It ran 158 additional candidates that passed
(79 per SKU) and 10 diagnostic cases that failed on unexpected input
underflow. URG merged only the 220 accepted VDBs (109 EF1 and 111 MASH),
independently for each SKU. All accepted runs had zero UVM errors and
fatals and their expected test completion markers. The
[case manifest](verification/data/dsm-v13-round6/round6_product_cases.json)
includes the failed diagnostics and their hashes. The
[instance audit](verification/data/dsm-v13-round6/round6_instance_counters.csv)
checks raw counts and denominators for all four metrics. The
[exact audit](verification/data/dsm-v13-round6/condition_non_regression.json)
verified that both SKUs retained all 643 original Condition hits, with an
unchanged 741-bin raw universe. The
[missing-set audit](verification/data/dsm-v13-round6/round6_missing_set_non_regression.json)
found no lost native Branch arms or Toggle bit directions. Its Line
comparison checks all rendered per-line missing counts. Individual
statement IDs inside a multi-slot source line are not exposed in the
HTML export.

## Checked product witness

`dpd_memory_poly.v:141` lacked operand tuple `0,1` at all 16 lane instances.
During the initial PA backpressure sweep, the DPD final stage remained
valid when its downstream FIFO filled. A longer source gap could align
the bubble but caused 17 unexpected underflows when the input was still
running. Its diagnostic VDBs provided zero coverage credit.

The accepted `drain_start_32` replay waits for core TX to be active with
at least 18 accepted source beats in an open packet, issues AXI-Lite STOP,
and lets the packet finish through its normal TLAST handshake. It inserts
the source gap after beat 20 and sweeps the onset of PA backpressure
relative to STOP. Both products recorded one FIFO fill edge with a DPD
stage-9 bubble and two cycles of the target tuple. Both checked 56 PA
words against the four-plane Python oracle with zero underflows,
errors and fatals. Exact URG Condition hits grew by 19 per SKU.

- DPD L141 `0,1` at all 16 lanes on each Product Top.
- First interpolator L67 `0,1`, where a non-full queue retains `q1_start`.
- Frame Gain L48 `1,0`, where an empty first stage can advance despite
  the second stage being blocked.
- CDC L261 `0,1,1`, where the read frame-start flag remains while the
  read output is ready and the read valid is low.

## Waiver rationale and proof scope

The adjustment retains the existing Round 5
[applied waiver ledger](verification/data/dsm-v13-round5-axil-focus/round5_code_waivers.csv).
It includes the fixed one-tap DPD accumulator and history paths, statically
selected tap wiring, fixed elaboration guards, proven constant DPD
accumulator directions, and the individually mapped Condition relations.
The regenerated counters reconcile these same deductions against the new
raw URG reports. No Round 6 proposal has been applied.

The [Round 6 candidate ledger](verification/data/dsm-v13-round6/round6_waiver_candidates.csv)
identifies each exact instance, source line, predicate, operand tuple,
native URG report anchor and SHA-256, its proof and its rationale.
Ten Condition and 72 Line candidates are awaiting independent
applicability and approval review. If all five Condition proposals per
SKU are approved, the score would be 662/701 (94.44%) and Gate A would
still require four additional hits per SKU.

- **DPD Vector Wrapper L93 `0,1`**, one per SKU. Lane 0 supplies both
  wrapper signals and computes input ready as downstream ready OR output
  empty. The post-reset ready implication is proven non-vacuous, the
  forbidden tuple cover is uncoverable, and accept, transfer, stall and
  stall-release covers hit. The separate payload hold property was
  inconclusive and supplies no exclusion evidence.
- **First Centered Cubic instance L68, L220 and L229**, four tuples per SKU.
  Each requires `q0_tail=1`. The production stage ties `in_tail` low.
  Reset clears both queued tail bits and all queue updates copy either
  zero input or a previously cleared flag. VC Formal proved the invariant
  on the 8-lane append instance. Local nonempty and emitted-tail covers
  hit. Internally generated output tail is distinct from these input
  queue flags. This proof has post-reset two-state scope and needs
  matching against native URG sampling before any deduction.

- **Single-tap DPD history operations**, 36 Line bins per SKU. Lane
  L332–L333 shift history only inside the loop starting at tap 1 with
  the bound `tap < MAX_TAPS-1`. With `MAX_TAPS=1` it has no iterations.
  Wrapper L61–L62 would require `tap > lane` even though the only tap
  index is zero. Wrapper L80–L81 would require `h >= LANES` even though
  the only history index is zero. The ledger hashes the audited RTL and
  identifies the matching URG report and exact statement for each bin.

The second interpolator consumes tail metadata and has
`APPEND_TAIL_VECTOR=0`. Its independent 16-lane harness proved it
cannot generate a tail and found local drop-tail and tail-lookahead
witnesses. Both local harnesses reached disabled head candidates and
retained start metadata. The real product stage 2 L67 remains open
because these local covers leave the input metadata unconstrained.
The formal configuration block reached COMMIT L333 tuple `1,0,1` at
depth 4 and normal apply at depth 5. Tuple `0,1,1` and the request/pending
implication remain inconclusive. Product COMMIT credit requires replay
against the real DPD boundary. An independent post-merge sweep ran 24
additional positive cases per SKU using eight AXI-Lite clock phase
offsets crossed with three source clock offsets. All 48 passed with
zero additional Line, Branch, Condition or Toggle hits. This sweep
kept the COMMIT-before-RUN placement of the template. A second sweep
issued runtime COMMIT after the first observed boundary. It crossed four
legal three-frame placements with four AXI-Lite phase offsets using
identity coefficients so the oracle stayed valid before and after the
mailbox update. All 32 cases passed with zero additional hits in the
four reported metrics. The products still need a replay that places
the request edge on the exact target DPD boundary.
See the [phase manifest](verification/data/dsm-v13-round6/round6_commit_phase_cases.json)
and its [exact Condition delta](verification/data/dsm-v13-round6/round6_commit_phase_condition_delta.json).
The [runtime manifest](verification/data/dsm-v13-round6/round6_runtime_commit_cases.json)
and its [exact Condition delta](verification/data/dsm-v13-round6/round6_runtime_commit_condition_delta.json)
record the second sweep.
The [formal evidence](verification/data/dsm-v13-round6/round6_formal.json)
records the verification scope and exact property outcomes.

## Remaining obligations

- **Condition**. Each SKU has 22 Cubic tuples, seven CDC, two COMMIT, two
  gain, two frontend and one DPD wrapper tuple. EF1 also has eight AXI-Lite
  product-control tuples. MASH has seven product-control tuples and one
  simulation-helper tuple. Cubic L304 and L309 include a reset/posedge
  sampling question. The local proofs disable under reset and provide
  no evidence for those reset tuples. Use actual product wiring for the
  stage-2 tail/boundary constraints and check each native URG operand.
  See the [Condition inventory](verification/data/dsm-v13-round6/round6_condition_gaps.csv).
- **Line and Branch**. Each SKU has 32 DPD lane statements and 26 Cubic
  statements outstanding. Cubic accounts for 12 Branch arms per SKU.
  Remaining entries include elaboration guard error bodies and real
  control paths in CDC, drain and the configuration mailbox. The
  [Line and Branch inventory](verification/data/dsm-v13-round6/round6_statement_branch_gaps.csv)
  reconciles all missing counts and records source-line counts and
  rendered Branch operand vectors. URG can aggregate multiple statement
  slots on a single rendered source line.
- **Toggle**. Every unhit direction is represented in the
  [signal and bit-range export](verification/data/dsm-v13-round6/round6_toggle_ranges.csv).
  High sample/saturation counter bits remain the dominant cluster.
  A 32-bit counter starting at zero requires at least 2^31 qualifying
  increments for its top bit's first rise. Observed short-stream runs
  with 2360 DPD sample increments per lane and roughly 3.5–7.2 CPU
  seconds for EF1 or 2.0–4.2 for MASH give order-of-magnitude estimates
  of 37–76 and 21–44 CPU-days respectively for the first rise if the
  observed rate persists. Startup overhead and sustained data-rate
  differences limit this estimate. Saturation increments require a
  separate throughput measurement. Counter reachability remains valid
  and the missing simulation directions remain OPEN.
- **Next evidence**. Replay the COMMIT witness on both full products,
  validate Cubic tail and reset semantics under the integrated protocol,
  and extract bit- and instance-scoped proofs for remaining constant
  candidates. Complete mandatory functional, FSM and assertion gates
  against the final cumulative databases before any sign-off.

## Reproduction

Use VCS V-2023.12-SP1 and the normal `thermo5-vcs` target with top
`dsm_v13_multi_sku_uvm_tb`, `THERMO5_USE_AXIL=1`,
`THERMO5_CENTERED_CUBIC=1`, `THERMO5_DPD_MAX_TAPS=1`,
`THERMO5_COV_HIER=dv/uvm/sim/dsm_v13_product_dut_coverage.hier` (absolute
path), and `THERMO5_CHECK_VECTORS=0` for the reusable test binary.
Set `DSM_ARCH` via `THERMO5_TOP_ARGS`, then `THERMO5_TIDSM_ORDER` and
`THERMO5_STEP` to 1/1/7168 for EF1 or 3/2/5120 for MASH. Place the binaries
in the two configuration subdirectories of the build directory.

Run `dv/uvm/sim/run_dsm_v13_round6_product.py` with `--round5` pointing
to the Round 5 worktree containing its VCS command logs, VDBs and vector
inputs. Pass `--build`, a fresh `--out`, and the VCS `--urg` binary.
Use its cumulative URG directory as input to the Round 5 instance
auditor and the Round 6 Condition and statement/branch auditors. Use
the latter on the original Round 5 report too, then compare its
statement/branch CSV and expanded Toggle directions with the Round 6
missing-set auditor. The
VC Formal V-2023.12-SP2 Tcl entry points are under `dv/uvm/formal/`.
Review properties from their named local run directories in the formal
evidence JSON.

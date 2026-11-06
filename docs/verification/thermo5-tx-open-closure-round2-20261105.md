# Thermo5 TX Linux Open Closure — Round 2 — 2026-11-05

## Result

This round closes the planned live EF2 checks for the exercised packet, DPD,
and COMMIT paths; closes the seven requested system scenario crosses across
this and the preceding Round 1 campaigns; repairs the long STOP/PA-stall test;
and classifies both legal `q1_tail` assertion no-attempts as unreachable under
the exact legal product frame-marker contract using a fresh non-vacuous Formal
proof.

This is **not final DUT code-coverage signoff**. Raw/Adjusted Code Coverage
remains below 100%, 371 waiver candidates remain unapproved, and the outstanding
counter and full-chain DPD Identity proofs remain open. No RTL product behavior,
DSM algorithm, RX, AI-DPD, XPM, GT Wizard, Vivado implementation, or physical RF
result was changed or signed off.

## Source and product identity

- Branch: `codex/thermo5-final-integration`.
- Base HEAD before the current uncommitted work: `6bef1cbd66a55bbec5601a5d36fa4c86f85bfd26`.
- Worktree remains dirty; exact source hashes are recorded in the adjacent
  [evidence JSON](data/thermo5-tx-open-closure-round2-20261105.json).
- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state;
  four 64-bit PA planes; DPD_MAX_TAPS=1 with Identity reset image; AXI-Lite;
  Generic FIFO.
- The change set is verification/model/testbench/documentation only. Product
  RTL and the frozen algorithm are unchanged.

## P1 — online independent EF2 checking

The Unified Scoreboard compares every accepted 32-lane EF2 I/Q word against an
independent Python sidecar. The online checker passed 178 legal runs: 110
system-random packets, 60 legal DPD/gain/input-profile cases, and 8
COMMIT-boundary cases, with zero EF2 lane mismatches. A deliberate EF2 expected
value mutation was detected at word 0/lane 0 and failed the negative test as
expected. Reset-truncated epochs remain checked by the independent trace Oracle
using only causally available post-reset output.

Python unit tests passed 62/62. The 110-packet UVM campaign passed with zero
unexpected underflow, no scoreboard mismatch, and a successful independent
Python trace replay for every case.

## P2 — requested system scenario matrix

The seven requested scenario families have exact sampled URG evidence across
the referenced Round 1 campaigns and the fresh Round 2 110-packet campaign.
This closes those named scenarios; it does not claim every Cartesian
combination of all control and traffic dimensions was exercised.

| Scenario | Result |
|---|---:|
| DPD x Gain x Input Profile | 60/60 legal tuples, 0 uncovered |
| COMMIT x Frame Boundary x PA Stall | 2/2 bins covered |
| Reset x Pending COMMIT | 4/4 bins covered |
| STATUS x COMMIT x STOP | 1/1 bin covered |
| Source Gap x PA Stall x FIFO Full | 1/1 packet-scenario bin covered |
| RUN x Prefill x Source Gap | 1/1 temporal bin covered |
| STOP x TLAST x Drain | 1/1 temporal bin covered |

The three newly added covergroups sample passive accepted transaction/interface
observations. The first cross is explicitly a packet-scenario cross: each event
must occur within the same accepted packet, and the independent integrity
checkers must pass. The RUN/source-gap cross requires a legal RUN and prefill
before a post-RUN gap. STOP/TLAST/Drain requires STOP before accepted TLAST and
a successful idle STATUS response after drain.

The directed long STOP test passed with one legal 64-beat packet, accepted
TLAST, 112 drained PA words, and partial PA backpressure during drain. The
independent Python trace replay matched CDC/EF2/PA 112/112, with zero
underflows. Its exact command and logs are in the evidence JSON.

## P3 — assertion, Formal, and coverage status

### `q1_tail` assertions

The two DUT properties without attempts in the legal 110-seed simulation are
at:

- `thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1.unnamed$$_1`
- `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1`

They map to `assert(q1_tail)` at
`rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310`. A fresh VC Formal
run of `thermo5_frame_tail_legal_metadata_harness` at the exact product stage
geometries proved, non-vacuously, that the assertion antecedent
`q_count==2 && q0_end && !q1_start` cannot occur for either stage under the
legal product frame-marker schedule. The harness also reached legal frame-end,
tail-transfer, output-transfer, and subframe witnesses. Both corresponding
cover goals were reported `uncoverable`.

Disposition: **PROVEN_UNREACHABLE within the stated legal metadata contract**.
The assertions still have no simulation attempts, and the Formal result alone
does not authorize changing the Raw denominator or applying an Exclusion. The
existing 371 waiver candidates remain pending review; approved waivers and
active exclusions remain zero.

### Outstanding counter guards

The fresh product-bound Formal run used the existing public-interface harness,
with one legal source hold-VALID assumption, arbitrary source gaps, and
unconstrained per-plane PA_READY. It produced witnesses for source acceptance,
core acceptance, output acceptance, and an arbitrary source bubble. The guard
assertions were non-vacuous, but the five invariants and both guard reachability
covers ended `INCONCLUSIVE` at depths 34–50. The runner exited successfully,
but its fail-closed manifest status is `INCONCLUSIVE`; this is **not a proof**
and does not disposition the two guard bins. A separate property-level retry
for `a_no_counter_underflow_guard` also ended `INCONCLUSIVE(depth=56)` after
about 304 seconds. It did not produce a Cover witness and does not close the
underflow bin.

### Raw/Adjusted code coverage

No new Round 2 VDBs were merged into a full-product inventory, so this round
makes no global code-coverage delta claim. The last integrated signoff report
uses this Raw=Adjusted reference snapshot:

| Metric | Raw | Adjusted |
|---|---:|---:|
| Branch | 524/637 | 524/637 |
| Condition | 657/849 | 657/849 |
| Line | 3338/3796 | 3338/3796 |
| Toggle | 91112/104480 | 91112/104480 |

FSM was previously reported 13/13 states and 22/22 transitions. The gate stays
`RAW_100_OPEN`. A separate retained Round 9 package reports Branch 525/637, Condition 658/849,
Line 3351/3796 and Toggle 84340/104480. That package has source revision
`c0e104878c71a1f4d873b0553e8ee0940560df71`, a design VDB from product source
`1236d49c72360aa62e316aea147528d93a1b3705`, and 248 retained test VDBs. It is
a distinct mixed-provenance inventory and is not silently combined with the
integrated snapshot above or this Round 2 campaign. The Round 2 system-random
URG is scenario evidence only, not a replacement DUT-only product inventory.
Do not treat its per-run coverage or functional cross closure as global DUT
code-coverage signoff.

Previously audited legal functional coverage remains 412/412 legal rows
(206 distinct bins across 13 groups); the three new system crosses are reported
separately above. Legal regression assertion failures: zero. The intentional
EF2 mutation is reported only as an expected-negative run.

The full-chain DPD Identity proof remains `INCONCLUSIVE/OPEN`; no new identity
proof was run because its RTL/harness inputs did not change. DPD Identity must
not be presented as fully formally signed off.

## Commands and evidence

Fresh Round 2 system-random command:

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
PYTHONPATH=dv/uvm/refmodel/python \
python3.12 dv/uvm/sim/run_thermo5_system_random.py \
  --random-seeds 100 --long-seeds 10 --seed-base 721000 \
  --out runs/thermo5_open_closure_round2_20261105/system_random_full
```

Fresh q1-tail Formal command:

```bash
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs frame_tail_legal_metadata \
  --out-dir runs/thermo5_q1_tail_formal_20261105
```

Fresh outstanding-counter Formal command:

```bash
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
python3.12 dv/uvm/formal/run_thermo5_axil_outstanding_fpv.py \
  --out-dir runs/thermo5_axil_outstanding_round2_20261105
```

Python validation command:

```bash
PYTHONPATH=dv/uvm/refmodel/python \
python3.12 -m unittest discover -s dv/uvm/refmodel/python/tests -v
```

Python was 3.12.13; VCS/URG were V-2023.12-SP1; VC Formal was V-2023.12-SP2.
Exact summary/manifests, URG results, Formal properties/logs and source SHA-256
values are indexed in the adjacent JSON. Large run databases remain under
ignored `runs/` and are not tracked.

## Remaining OPEN items

1. 371 waiver candidates have not been reviewed or approved; Raw and Adjusted
   must remain equal with zero exclusions until approved evidence exists.
2. The product-bound outstanding-counter Formal run remains inconclusive;
   both saturation/underflow guard root causes remain OPEN.
3. Full-chain DPD Identity equivalence Formal remains inconclusive/open.
4. Canonical DUT code coverage still has substantial unhit Branch, Condition,
   Line and Toggle bins. Continue exact-bin root-cause work and directed legal
   stimulation; do not change the denominator or force internal states.
5. Real XPM/GT Wizard simulation, Vivado PPA/routed timing, and physical
   RF/QAM256 validation remain NOT_RUN and outside this Linux signoff.
6. This change set is local and uncommitted; no PR or merge was created.

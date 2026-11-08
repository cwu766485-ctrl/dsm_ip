# Thermo5 TX DPD Identity Formal Closure — 2026-11-09

**Status: OPEN.** This is an intermediate proof update for PR #47, not Linux DV signoff. Product RTL, product parameters, and the frozen algorithm were not changed.

## Frozen source and tool context

| Item | Value |
|---|---|
| Local source commit / tree | `c29e76ae153e67c96a5d73642e833b7308bb3c87` / `2e4e2f583eba13338171a024b01eca090eaf5e13` |
| PR #47 remote HEAD / tree at review | `f6b71c59b812cdc9748bf0ecbb7157fd6a16933b` / `2e4e2f583eba13338171a024b01eca090eaf5e13` |
| PR state | Open, Draft; base `thermo5` at `7708d0eb9a2128942ff802202c0d1716c8c11f8b` |
| Product RTL aggregate SHA-256 | `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003` |
| Product configuration | Centered-Cubic x2+x2; EF2 ORDER=2 / STEP=5120 / 20-bit; DPD_MAX_TAPS=1, Identity reset; AXI-Lite; Generic FIFO |
| Compile fingerprint | `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7` (95/95 compile inputs matched in the bound Round 17 package) |
| Tool | VC Formal V-2023.12-SP2, linux64; Rocky 8.10 WSL2 |
| Product RTL / parameters changed | No / No |

The current local tree exactly matches the PR's remote tree before this report update. The formal helper harness is `dv/uvm/formal/thermo5_dpd_identity_lemmas_harness.sv` (SHA-256 `18a42a6b22c4a2c55f867aeb2468e75ae7cd26a133cd37d13c8ae3f61630e24a`); the base leaf harness is `dv/uvm/formal/thermo5_dpd_identity_harness.sv` (SHA-256 `dada30a04dd29000e5466761a4b507b399d701157fd24c77c972ea24a1d052ec`).

## Controlling run: repository Identity runner

Command:

```bash
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_convergence.py \
  --job identity \
  --out-dir runs/codex_round17_identity_official_auto_lemmas_20261109 \
  --auto-lemmas
```

The VC Formal process exited 0, but the runner correctly returned exit 1 and `INCONCLUSIVE_OR_FAIL`: the final composition has 24 assertions, only one proven and 23 inconclusive. The five required original assertions were not all proven. VC Formal reported zero black boxes, no SAT counterexample, and three `SPECIFIED_MAXTIME_EXCEEDED` warnings. The configured automatic flow allows 30 seconds per property and 1 minute overall for this job; this run is proof-incomplete, not a design counterexample.

### The five original assertions

| Property | Controlling auto-lemma run | Earlier engine record | Current interpretation |
|---|---|---|---|
| `a_identity_payload` | INCONCLUSIVE, depth 245, non-vacuous | `b8`, depth 221, INCONCLUSIVE | OPEN; stall-dependent payload composition is not closed |
| `a_no_saturation_i` | INCONCLUSIVE, depth 244 | `b8`, depth 221, INCONCLUSIVE | OPEN; no SAT counterexample |
| `a_no_saturation_q` | INCONCLUSIVE, depth 244 | `b6`, depth 2569, INCONCLUSIVE | OPEN; no SAT counterexample |
| `a_saturation_count_zero` | INCONCLUSIVE, depth 244 | `b6`, depth 2569, INCONCLUSIVE | OPEN; no SAT counterexample |
| `a_valid_latency` | PROVEN | `e1`, depth 1611, PROVEN | Proven in the controlling run |

The current runner's property report does not expose per-property engine IDs. The engine labels in the “Earlier engine record” column are historical, from the preserved earlier engine report; they are not attributed to the current run.

The automatic run promoted the 19 S0–S6/configuration alignment lemmas and `a_gain_identity`. It did **not** converge `a_gain_identity_s6` or the S7–S10 arithmetic/output obligations in the final composition: these remain INCONCLUSIVE at depth 244. The base intermediate assumptions are reset plus the harness's payload-stability-under-backpressure contract; no assumption fixes `out_ready=1`.

### Separate staged experiments and reproducibility limit

Independent saved property reports show successful local proofs for the S7 I/Q transfer, S7 product identity, S8 term identity, S9 pair identity, and S10 sum/output identity groups. A separate S7 transfer replay ended INCONCLUSIVE at depth 405, however, and the repository's automatic staged runner did not reproduce those local proofs. A hand-composed final report produced 3/5 original assertions as PROVEN and 2/5 as INCONCLUSIVE, but its imported stage assumptions were not validated by a fail-closed evidence manifest within that run. Therefore these exploratory results are recorded as supporting analysis only; they do not override the controlling runner or close full-chain Identity.

A separate non-vacuity witness run reached the five S7–S10 activity Covers at depths 8, 9, 10, 11 and 12. The repository runner also reached all four original endpoint/stall/recovery Covers. These witnesses establish reachable activity in the leaf harness; they do not prove the arithmetic assertions or compose the configured TX chain.

The five activity witnesses can be replayed using the archived overlay and TCL:

```bash
mkdir -p runs/thermo5_identity_activity_replay
cp docs/verification/data/thermo5-r17/final_closure_audit/thermo5_tx_r17_identity_activity_cover_harness_20261109.sv \
  runs/thermo5_identity_activity_replay/harness_activity.sv
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
THERMO5_FORMAL_REPO="$PWD" \
THERMO5_FORMAL_OUT="$PWD/runs/thermo5_identity_activity_replay" \
THERMO5_FORMAL_TOP=thermo5_identity_lemmas_harness \
vcf -batch -fmode FPV -f \
  docs/verification/data/thermo5-r17/final_closure_audit/thermo5_tx_r17_identity_activity_cover_20261109.tcl
```

No SAT counterexample has been observed. The remaining root cause is proof convergence and inconsistent reproduction across staged partitions, not an identified RTL defect. Do not increase timeout alone or weaken the properties. The next useful step is to make each staged assumption consumption mechanically bind to its exact source/configuration/property proof, then prove the remaining arithmetic properties with a token-indexed induction that preserves arbitrary stalls.

## Other required closure gates

| Gate | Current state |
|---|---|
| Outstanding Counter capacity / saturation / underflow | OPEN; five assertions and two guard Covers remain inconclusive in the existing scoped run |
| COMMIT lifecycle | OPEN; no end-to-end Shadow → Request → CDC Pending → Frame Apply → Active Epoch → ACK → STATUS/DONE proof |
| Active-Tap configuration | OPEN; existing product harness proves 4/6 assertions; two tap-count properties and activity Covers are inconclusive |
| Product `q1_tail` | OPEN; the two legal successful-attempt bins remain uncovered; current metadata proof is not full FIFO/DPD path composition |
| Waiver inventory | 371 official IDs: 2 resolved by Raw HIT, 369 pending independent review; 0 approvals and 0 official exclusions |
| Current Raw / Adjusted code coverage | No new official URG run; last same-manifest result remains Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92072/104480; FSM 13/13 states and 22/22 transitions; Raw equals zero-exclusion Adjusted |
| Full product regression | Not rerun in this follow-up |
| XPM / GT Wizard / Vivado / FPGA / physical QAM256 | Not run; separate signoff scope |

The 551-Test-VDB Round 17 package is not present in this isolated checkout. Do not derive new official Coverage from the one-Test smoke database or from these Formal runs. No Waiver was approved, no `.el` was created/applied, and no coverage denominator changed.

## Evidence index

Machine summary and artifact SHA-256 values: [`thermo5_tx_r17_identity_stage7_to10_formal_followup_20261109.json`](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_identity_stage7_to10_formal_followup_20261109.json). Full VCF internal work directories remain ignored under `runs/`; their key property/console/report hashes are in the machine summary. The activity-cover overlay and TCL are archived in `data/thermo5-r17/final_closure_audit/` so the five activity Covers can be independently reconstructed.

**Decision:** DPD Identity and overall Linux DV signoff remain **OPEN**. PR #47 is an intermediate proof-evidence PR and must not be merged as final signoff.

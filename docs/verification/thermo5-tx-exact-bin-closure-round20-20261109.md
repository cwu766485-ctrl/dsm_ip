# Thermo5 TX Exact-Bin Closure — Round 20

**Date:** 2026-11-09
**Review branch:** `codex/thermo5-round20-exact-bin-closure`
**Base / PR:** PR #49, base commit `49b9121a860c6b85057047c7696876df7f6cd740`
**Decision:** Coverage closure remains **OPEN**; this is not Linux DV signoff.

## Executive result

The focused VCS tests passed, but none of the 263 requested non-counter exact
bins gained a Raw hit. The strict Analysis-only URG run applies one additional
exact AXI-Lite Branch candidate; it is not independently approved. Thus:

- Raw and Official Adjusted each retain 263 requested non-counter bins and
  12,611 total uncovered code bins.
- Analysis-only What-if has 262 requested non-counter bins plus 930 Counter
  Toggle bins, 1,192 total.
- Approved exclusions remain zero. The official Waiver CSV still has 371
  records; two are semantically resolved by Raw hits, 369 await review, and no
  reviewer or approval reference was added.
- Counter high bits remain in DUT coverage scope. The proposed block-level
  arithmetic evidence plus a reviewed system coverage exception is pending;
  no denominator reduction is applied.

## Baseline and evidence integrity

Product configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit
state; 32 chronological lanes; `DPD_MAX_TAPS=1`, Identity reset image;
AXI-Lite and Generic FIFO. Product RTL was not modified.

The Product RTL aggregate SHA-256 remains
`fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003` (source
revision `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`). The compile used VCS
V-2023.12-SP1_Full64. Its command, source input manifest SHA-256
`e825c86e1e703d58d86a1719010ec889fe8ea41278a5d0e1af0d2ba2f816fd4c`, filelist
and compile log hashes are in the
[evidence manifest](data/thermo5-r20/thermo5_tx_r20_evidence_manifest.json).
The three changed UVM sources and SHA-256 values are recorded there as well.

The final Raw, zero-approved Official Adjusted, and strict Analysis-only URG
reports were rerun with the same ordered set: one Design VDB and 27 test VDB
paths. These paths contain the frozen Round 18 554-test aggregate plus 21 R19
tests replayed against the current R20 compile and five focused R20 tests.
The 21 replay VDBs and five new VDBs share the current Design VDB compile
parent. The frozen aggregate still carries the Round 16 parent signature, so
the merged result is useful for round-to-round diagnosis but is **not a
homogeneous compile-parent signoff baseline**. All VDB tree fingerprints were
rechecked after the final URG run; stale prior manifest claims were retained
for audit and replaced by observed fingerprints. See the
[VDB manifest](data/thermo5-r20/thermo5_tx_r20_vdb_manifest.json).

All three URG commands completed with exit status 0, each reported 27 test
inputs, and each log had zero Warning/Error/Checksum/Mapping/Scope diagnostic
lines. The exact log and dashboard hashes are in the evidence manifest. This
clean tool run does not remove the mixed-parent limitation above.

## Raw, official, and what-if coverage

| Metric | Raw | Official Adjusted | Analysis-only What-if | What-if excluded | What-if remaining |
|---|---:|---:|---:|---:|---:|
| Branch | 524 / 637 (82.26%) | 524 / 637 (82.26%) | 524 / 529 (99.05%) | 108 | 5 |
| Condition | 657 / 849 (77.39%) | 657 / 849 (77.39%) | 657 / 741 (88.66%) | 108 | 84 |
| Line | 3,338 / 3,796 (87.93%) | 3,338 / 3,796 (87.93%) | 3,338 / 3,363 (99.26%) | 433 | 25 |
| Toggle | 92,632 / 104,480 (88.66%) | 92,632 / 104,480 (88.66%) | 92,632 / 93,710 (98.85%) | 10,770 | 1,078 |
| FSM states | 13 / 13 (100%) | 13 / 13 (100%) | 13 / 13 (100%) | 0 | 0 |
| FSM transitions | 22 / 22 (100%) | 22 / 22 (100%) | 22 / 22 (100%) | 0 | 0 |
| URG assertions | 15 / 19 successful (78.95%) | same as Raw | same as Raw | 0 | 3 failures; 4 uncovered; 2 without attempts |

Raw and Official Adjusted are identical because the official approval count and
active exclusions are both zero. What-if excludes 11,419 exact bins across the
four code metrics. It leaves 1,192 exact bins uncovered. Its unchanged covered
numerators, FSM results, and assertion results were checked against URG; this
analysis-only result is not an approved signoff report.

The Raw total is 12,611 uncovered code bins. The Raw-to-Round-20 exact-hit
delta is **0 Branch, 0 Condition, 0 Line, 0 Toggle**. Exact ledgers:

- [263 requested non-counter bins](data/thermo5-r20/thermo5_tx_r20_non_counter_status_263.csv.gz)
- [1,192 Analysis-only What-if remaining bins](data/thermo5-r20/thermo5_tx_r20_analysis_whatif_remaining_1192.csv.gz)
- [930 Counter high-bit Toggle bins](data/thermo5-r20/thermo5_tx_r20_counter_remaining_930.csv.gz)

## Non-counter exact-bin disposition

All 263 requested bins remain open in Raw and Official Adjusted. The ledger
contains every native URG tuple, semantic ID, hierarchy, source position,
parameter set, source hash, classification, and Round 20 outcome.

| Metric / root | Count | Round 20 outcome |
|---|---:|---|
| Branch — interpolator Stage 1/2 `pop_head`, `q_count != 2`, `push_input` | 2 | No exact hits; reachability remains UNKNOWN. |
| Branch — AXI-Lite default write-response false arm | 1 | Exact current-source Formal proof exists; strict What-if excluded 1 bin. Independent approval is pending; official bin remains open. |
| Branch — CDC `end_remaining_q <= CORE_LANES` false arm | 1 | Legal frame-end test hit the normal arm only. Defensive/negative-only candidate remains pending review; not proven unreachable. |
| Branch — Outstanding counter saturation / underflow guards | 2 | No exact hits; capacity and conservation proof remain OPEN. |
| Condition — interpolator | 36 | No exact hits; 32 Reset/State-Hold and 4 Empty/Blocked bins remain open. |
| Condition — DPD saturation | 21 | No exact hits; no-saturation, I-only, Q-only, simultaneous, invalid-output and stall tuples remain subject to exact ledger review. |
| Condition — CDC / TX Top / frame gain / AXI-Lite config / frontend / DPD vector wrapper | 27 | No exact hits; all exact tuples remain open. |
| Line — interpolator / DPD vector wrapper / CDC | 25 | No exact hits; 20 / 4 / 1 respectively. |
| Other Toggle — interpolator / AXI-Lite config / EF2 / TX Top / CDC / frontend | 148 | No exact hits; exact signal, bit and direction are in the ledger. |

The 263-row ledger classifies 261 rows as `UNKNOWN` and two as
`DEFENSIVE_NEGATIVE_ONLY`; no simulation miss was promoted to an
unreachability proof. In the Analysis-only result the AXI-Lite false arm is
removed, so five Branch, 84 Condition, 25 Line, and 148 non-counter Toggle
bins remain open. The two interpolator branch IDs are
`TXB-33db6d34081fd3b6ec60` and `TXB-9141942b3f6f51689217`; the CDC and
Outstanding guard exact IDs are in the same ledger.

The campaign did not capture an internal VCD state-transition witness for the
still-missing interpolator, CDC-false-arm, or Outstanding-guard branches. The
accepted-transaction JSONL and UVM event counters are not a substitute for
that internal state evidence. These branch tasks therefore remain OPEN. The
DPD condition matrix (no saturation, I-only, Q-only, simultaneous I/Q,
invalid-output, and stall combinations) was not newly run as a dedicated
R20 matrix; prior saturation replay does not close those exact Condition bins.

### AXI-Lite What-if candidate

Candidate `TXB-3df5f13a8d51ee9bdea5` maps to
`thermo5_dpd_axi_lite_cfg.sv:246`, instance `thermo5_sku_uvm_tb.dut.u_cfg`,
and the false arm of `if (write_resp != 2'b00)` under the `default` address
case. The formal manifest records `a_write_case_default_unreachable` as
PROVEN with zero assumptions and zero black boxes. Its RTL source SHA matches
the current source. Strict URG applied one exact Analysis-only exclusion with
zero diagnostics. The exact `.el`, Formal manifest and source fingerprint are
bound in the evidence manifest. No reviewer approval exists; it remains
excluded only in What-if.

## Directed campaign and checker results

The VCS product compile passed. The 21 R19 scenarios were replayed with the
current compiled image; five focused VCS scenarios were added. All 26 VCS
tests passed. The checked-in
[test matrix](data/thermo5-r20/thermo5_tx_r20_test_results.csv) contains exact
commands, seeds, configurations, log hashes, checker summaries, and VDB tree
hashes.

| Focus | Stimulus | Checker result | Exact target delta |
|---|---|---|---:|
| Interpolator | Seeds 202032/202064/202096; legal 32/64/96-beat packets; source-bubble and PA-stall probabilities 25% | All three UVM tests PASS; scoreboard, online EF2 checks and drain checks report no data, metadata, epoch, index, or protocol mismatch. | 0 |
| AXI-Lite | Seed 202047; register/protocol directed test | PASS; 56 writes, 51 reads; response and register predictor checks passed with zero mismatch. No stream traffic. | 0 |
| CDC | Seed 202048; legal 56-sample frame, end and drain | PASS; 56 CDC/output words, four-plane checker pass, queues drained, zero underflow. `cdc_end_false_arm=0`; no Python trace oracle was run for this scenario. | 0 |
| DPD | Replayed existing DPD saturation/configuration scenarios, including seed 190031 | VCS replay passed; the Python per-lane oracle passed where a trace was available. This round did not run a new DPD-focused randomized matrix across all requested profiles. | 0 |

The 26-test matrix records 23 Python oracle PASS, two NOT_RUN (the AXI-Lite
register-only and CDC directed tests), and one NOT_APPLICABLE (the replay
scenario has no applicable oracle trace). The AXI-Lite and CDC tests still
have their listed UVM protocol/register/scoreboard checks. No test was counted
as an exact coverage hit merely because it passed.

The CDC false arm was not observed. The legal 56-sample test establishes a
normal end/drain witness, not a proof that the opposite arm is unreachable.
The 16-phase trial from earlier rounds is not treated as proof. The
interpolator simultaneous-pop/push paths and outstanding guards likewise
remain OPEN pending a reachable state witness or scoped proof. A separate
diagnostic run with a `REQUIRE_CDC_END_FALSE_ARM` guard failed only because
that target bin was not observed; it was excluded from the 26 qualifying
VCS-pass entries and from the URG VDB set. This is not a DUT failure or an
unreachability proof.

## Counter decision

The remaining 930 counter transitions are 464 `sample_count` and 466
`saturation_count` bins in `rtl/dpd/dpd_memory_poly.v`. They are 32-bit
diagnostic outputs of the lane block; the 16-lane wrapper leaves those output
ports unconnected. The registers reset to zero and increment in the lane
block; no system-level lifetime bound or overflow exclusion was established.
Keep the bins in the DUT-only URG denominator.

The existing rate model projects approximately 23.81 CPU days to reach the
top `sample_count` transition and 32.31 CPU days for the slowest measured
`saturation_count` transition. These are projections, not test results or
proofs. Proposed acceptance is a dedicated block-level arithmetic proof plus
an independently reviewed system-coverage exception; both remain OPEN and do
not change the product URG denominator.

## Waivers, Assertions, Formal, and regression state

- Official waiver inventory: 371 IDs retained; 2 semantically resolved by
  Raw hits, 369 pending independent review, 0 approved, 0 official Exclusions.
- Analysis-only: 11,419 strict exact candidates applied; zero URG diagnostic
  lines; no assertion/FSM/covered-numerator change. This is not official.
- URG assertions inherited from the merged VDBs: 19 total, 15 success, 3
  failure, 4 uncovered, 2 without attempts. These categories overlap. The
  three failures are the CDC property and the two centered interpolator
  `q1_tail` properties. The two `q1_tail` properties are also uncovered; the
  UVM register `do_read` and `do_write` properties are uncovered and without
  attempts.
- No new Formal run or full Product Regression was performed. Outstanding
  Counter, full-chain DPD Identity, COMMIT lifecycle, and product-level
  `q1_tail` obligations remain OPEN. A historical zero-assumption AXI-Lite
  configuration proof supports only the single Analysis-only candidate above.
- No Raw exact code-coverage delta occurred. Functional feature coverage was
  not re-signed as a whole in this focused round.

## Decision and next steps

**Coverage Gate: OPEN. Full Linux DV Signoff: OPEN.** No official Adjusted
coverage increase is claimed. XPM, GT Wizard, FPGA timing/PPA, and physical
QAM256 remain outside this Linux round.

1. Rebuild/replay the frozen 554-test aggregate with the current Product
   compile parent before using a homogeneous VDB set for final signoff.
2. Review the single AXI-Lite candidate and the existing candidate packages;
   do not activate the `.el` without real independent approval.
3. Use exact state/event witnesses to target the remaining interpolator,
   CDC, AXI-Lite and DPD bins. If three targeted batches produce no exact hit,
   stop seed growth and reassess reachability.
4. Keep all 930 counter bins open until the block-level proof and coverage
   acceptance proposal are reviewed. Then rerun complete regression, Formal,
   Raw URG, and officially approved Adjusted URG on one source/compile/VDB
   manifest.

### Reproduction and artifact index

- Compile: the exact command is in the evidence manifest; compile log SHA-256
  `df61e94cf41f42dad16a7555de81c18613082f05994a1889a990fb95bb2dd332`.
- Final Raw URG log SHA-256:
  `66fa9b6ad28c563d9c613dc39c75d05d961fc314429ed4fef3320e75e11c5fcc`.
- Final Official zero-approved URG log SHA-256:
  `0920f58fcc86c9fe232ce3ed1bb01b3e289db1aa033d79911a67f4a12377d4e8`.
- Final strict Analysis-only URG log SHA-256:
  `b168d3e18a5fc1de6c47ae383ce6078fb69a21c8e8fe6088d0a62f004c82faf7`.
- Runs remain under ignored `runs/thermo5_r20_exact_bin_20261109/`; no VDB,
  simulator log, waveform, or tool cache is added to Git.

# Thermo5 TX Round 15 — Coverage-Directed Signoff Closure

**Decision: Linux DV signoff remains OPEN.** Round 15 regenerated a homogeneous Raw/Adjusted URG baseline and added eight legal directed data patterns. They produced 784 exact Toggle-bin hits, leaving 13,171 uncovered DUT code bins. There are still zero independently approved Waivers and zero active exclusions, so official Adjusted Coverage equals Raw. AXI outstanding-counter Formal remains inconclusive, full-chain DPD Identity remains inconclusive, and the two legal product `q1_tail` assertions still have no legal attempts. No FPGA or physical signoff is claimed.

## 1. Baseline and PR integration

PR #44 was merged into `thermo5` as commit `6b0d7c4ac4949fe0fa86af3da345a4e8dbeac7b5`; GitHub reports PR #44 closed and merged. Round 15 uses that merge commit as the frozen product source. Product configuration is Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, DPD_MAX_TAPS=1 with Identity reset image, AXI-Lite, and Generic FIFO.

The Product RTL aggregate SHA-256 remains `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`. The 95-source compile fingerprint is `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`. No Round 15 change modifies product RTL, frozen algorithm, parameters, or the coverage denominator.

The official coverage snapshot contains one Design VDB and 240 Test VDBs: 232 same-product Round 14 VDBs plus eight Round 15 directed data VDBs. Every compile-input source hash matches the product manifest. Raw and Adjusted were run from the same stable VDB list; the VDB manifest SHA-256 is `548b143f1d1c45355a8810c65027da22ccdf9aa5eefe3f17aa756d77366d0bb4`. The path-free, per-VDB hash inventory is in [`thermo5_tx_r15_vdb_manifest_240.json`](data/thermo5-r15/thermo5_tx_r15_vdb_manifest_240.json). The top-level VDB manifest records the product fingerprint, campaign counts, URG source manifest and log hashes: [`thermo5_tx_r15_vdb_manifest.json`](data/thermo5-r15/thermo5_tx_r15_vdb_manifest.json).

Tools recorded by the runs: VCS V-2023.12-SP1_Full64, URG V-2023.12-SP1, VC Formal V-2023.12-SP2, Python 3.12.13; Linux kernel `6.6.87.2-microsoft-standard-WSL2`.

The 232 existing regression VDBs are same-source carry-forward evidence, not 232 newly rerun tests. Round 14's Generic FIFO and AXI-Lite regressions, System Random 110/110, DPD/Gain/Profile 60/60, randomized Reset/COMMIT 24+24, Python reference 64/64, hardware utility 47/47, direct scoreboard mutations 6/6, and legal-applicable functional coverage 218/218 remain the current carried-forward results. A complete fresh product regression was not run in Round 15.

## 2. Raw and official Adjusted coverage

No Waiver was independently approved and the Adjusted run applied no exclusion. Therefore Raw and official Adjusted are identical:

| Metric | Raw covered / total | Raw | Approved Adjusted covered / total | Adjusted | Remaining exact bins |
|---|---:|---:|---:|---:|---:|
| Branch | 524 / 637 | 82.2606% | 524 / 637 | 82.2606% | 113 |
| Condition | 657 / 849 | 77.3852% | 657 / 849 | 77.3852% | 192 |
| Line | 3,338 / 3,796 | 87.9347% | 3,338 / 3,796 | 87.9347% | 458 |
| Toggle | 92,072 / 104,480 | 88.1240% | 92,072 / 104,480 | 88.1240% | 12,408 |
| FSM state | 13 / 13 | 100% | 13 / 13 | 100% | 0 |
| FSM transition | 22 / 22 | 100% | 22 / 22 | 100% | 0 |

There are **13,171** remaining code bins across Branch, Condition, Line and Toggle. The complete exact-bin inventory is [`thermo5_tx_r15_exact_remaining_bins.csv.gz`](data/thermo5-r15/thermo5_tx_r15_exact_remaining_bins.csv.gz); the full source-linked before/after ledger is [`thermo5_tx_r15_exact_uncovered_bins.csv.gz`](data/thermo5-r15/thermo5_tx_r15_exact_uncovered_bins.csv.gz). The raw URG log SHA-256 is `5c559913092e90974f2da2689986c2cb9e5c98f6a84993a4c1452d2ee386dd34`; the Adjusted URG log SHA-256 is `4d7cae06279ccc4dbfd0b006757486675c52d572547b86b8ae036c0550319ceb`. The logs and VDBs are generated run outputs under ignored `runs/`; their hashes and exact input manifest are retained in the evidence package.

Current OPEN bins are grouped by root cause as follows. The groups within each metric sum exactly to that metric's open count.

| Metric | Root cause | OPEN bins |
|---|---|---:|
| Branch | Legal stimulus / checker review | 89 |
| Branch | Fixed product configuration | 21 |
| Branch | Product cadence alignment | 2 |
| Branch | Guarded address decode | 1 |
| Condition | Reset release / state hold | 188 |
| Condition | Interpolator empty / blocked | 4 |
| Line | Fixed product configuration | 244 |
| Line | DPD tap-history configuration | 176 |
| Line | Legal stimulus / checker review | 32 |
| Line | CDC / residual state | 6 |
| Toggle | DPD tap-history configuration (Pair-1) | 8,192 |
| Toggle | Data value / transition stimulus | 2,478 |
| Toggle | Identity DPD arithmetic | 944 |
| Toggle | Counter high bits | 640 |
| Toggle | CDC / residual state | 130 |
| Toggle | Other fixed product configuration | 24 |

The 120 Active-Tap toggle candidates are a separate review view and overlap the existing Toggle root-cause totals; they must not be added to the 12,408 denominator or remaining count a second time.

## 3. Round 15 directed tests and actual coverage delta

Eight legal Identity-DPD product patterns were run with the four-plane UVM bit-true scoreboard and Python vector oracle: Zero (seed 610720), positive full scale (610721), negative full scale (610722), alternating I/Q (610723), impulse (610724), ramp (610725), PRBS (610726), and quantizer tie (610727). All eight ended with PASS markers, zero UVM errors/fatals, and four-plane data checks passing. Their run-log and VDB-tree hashes are in [`thermo5_tx_r15_data_campaign.json`](data/thermo5-r15/thermo5_tx_r15_data_campaign.json).

The exact Raw delta was 784 directional Toggle bins; Line, Condition, and Branch changed by zero. The 784 exact URG bin identities and associated source positions are in [`thermo5_tx_r15_toggle_hit_delta.csv`](data/thermo5-r15/thermo5_tx_r15_toggle_hit_delta.csv). Forty root-cause task groups are now `RESOLVED_BY_RAW_HIT`; 375 task groups remain OPEN. The full task table is [`thermo5_tx_r15_root_cause_tasks.csv`](data/thermo5-r15/thermo5_tx_r15_root_cause_tasks.csv).

AXI-Lite register access also passed independently: 48 read checks, 52 write-response checks, zero predictor mismatches, and no pending reads/writes at drain. The legal outstanding-counter directed test passed for two 32-beat packets, 64 accepted source beats, 112 output words, maximum outstanding count 28, no underflow, and a drained bit-true scoreboard. It did **not** hit either outstanding-counter guard and produced no DUT code-coverage delta. Both standalone test VDBs are excluded from the 240-VDB official aggregate; they are retained as focused test evidence only in [`thermo5_tx_r15_focused_test_matrix.json`](data/thermo5-r15/thermo5_tx_r15_focused_test_matrix.json), with exact commands, logs and VDB-tree hashes.

One exploratory outstanding-counter run used `PACKET_BEATS=64`; it failed the test's two-packet TLAST contract and emitted a UVM fatal. That run is not in the official VDB set. The corrected seed-151002 run uses `PACKET_BEATS=32`, passes with zero fatal/error, and is the result reported above.

## 4. Waiver review and fixed-configuration toggles

The local Round 12 review ledger has 369 candidates: 361 configuration candidates, four previously stale Formal candidates, and four unresolved interpolator candidates. GitHub's older ledger has 371 rows; the two remote-only entries are already Raw hits and require no exclusion. All 369 local entries remain `PENDING_INDEPENDENT_REVIEW`; Approved=0, rejected=0, official exclusions=0. Source and configuration binding is refreshed to product SHA `6b0d7c4...` and VDB manifest SHA `548b143f...` in [`thermo5_tx_r15_waiver_review.csv`](data/thermo5-r15/thermo5_tx_r15_waiver_review.csv).

The four former Formal candidates now have current-source proof runs recorded. The AXI-Lite configuration candidate and the CDC end-residual candidate have scoped proofs, but still need independent exact-bin review. The CDC immediate-frame-end proof and the Raw candidate source location do not match, so that candidate remains OPEN and receives no exclusion. The CDC default proof has a nonempty legal-frame cover and an uncoverable default-path cover, but its exact candidate-to-URG location mapping remains pending. The four interpolator candidates are not closed by the frame-tail proof below; their exact Raw paths remain OPEN.

For the 8,192 Pair-1 Toggle bins, VC Formal proves 64 lane invariants: four Pair-1 accumulator nodes per each of 16 production DPD lanes remain zero with `MAX_TAPS=1`, arbitrary input/coefficient/tap-enable values and backpressure. Both input-accept and output-transfer Covers are reached; the only formal reset constraint is `rst_n==1`, with zero black boxes. This is scoped DPD-leaf evidence, not a complete proof of every top-level reset, RUN/STOP and COMMIT sequence. The exact per-bin package [`thermo5_tx_r15_pair1_waiver_candidates.csv.gz`](data/thermo5-r15/thermo5_tx_r15_pair1_waiver_candidates.csv.gz) is evidence for independent review only; none of its bins is approved or excluded.

The 120 Active-Tap bins remain OPEN: the current product-active-tap property and commit-applied Cover are INCONCLUSIVE. The per-bin list is [`thermo5_tx_r15_active_tap_waiver_candidates.csv`](data/thermo5-r15/thermo5_tx_r15_active_tap_waiver_candidates.csv). No candidate has been auto-approved and no `.el` exclusion has been applied.

## 5. Branch, condition and counter closure status

The focused AXI-Lite register test exercised the product register interface but added no code bin to the official Raw aggregate. The counter long-stream test reached maximum outstanding=28 but neither saturation nor underflow guard. No R15 legal directed test closed a Branch or Condition bin. Consequently all 113 Branch and 192 Condition bins remain OPEN. Exact identities, instance paths, source positions, and root-cause task IDs are available in the remaining-bin and task ledgers above; the first directed targets remain AXI-Lite address decode, CDC residual/frame tail, interpolator empty/blocked/tail, outstanding guards, and reset/state hold.

The sample-counter block-level proof passes the count/hold/increment relationship and all 32 per-bit carry/transition lemmas. It establishes the counter arithmetic contract, not a maximum legal product runtime. The 640 system-level high-bit toggle bins therefore remain OPEN; no product lifetime bound was assumed. AXI outstanding saturation/underflow Formal remains INCONCLUSIVE.

## 6. Formal and assertion matrix

The machine-readable matrix with evidence paths and hashes is [`thermo5_tx_r15_formal_matrix.json`](data/thermo5-r15/thermo5_tx_r15_formal_matrix.json). Key dispositions:

| Property / evidence | Result | Signoff disposition |
|---|---|---|
| MAX_TAPS=1 DPD Pair-1 structural invariant | PROVEN_SCOPED; 64 properties; input/output Covers reached | Evidence package only; independent reviewer and exact waiver approval pending |
| Product Active-Tap configuration / commit-applied Cover | INCONCLUSIVE | OPEN; no waiver |
| AXI outstanding saturation / underflow / capacity | INCONCLUSIVE; five assertions and guard Covers unresolved | OPEN; no waiver |
| Sample-counter increment / carry lemma | PROVEN_SCOPED; 32 bit transitions | System high-bit coverage remains OPEN; does not provide product runtime bound |
| EF2 product parameter / PAIR_LOOKAHEAD=0 | PROVEN_SCOPED | Configuration evidence only |
| Two-stage centered interpolator legal frame geometry | PROVEN_SCOPED with legal Covers | Does not include intermediate FIFO/DPD; legal production `q1_tail` properties remain without attempts |
| CDC residual end-path candidate | PROVEN_SCOPED, no assumptions, legal Covers reached | Exact URG mapping and reviewer approval remain pending |
| CDC immediate end branch candidate | Proof scoped to a different source location | Mapping mismatch; candidate OPEN |
| CDC default-path candidate | PROVEN_SCOPED; legal activity Cover reached, default path uncoverable | Exact Raw mapping review pending |
| AXI-Lite config default candidate | PROVEN_SCOPED; four assertions proven, legal read activity reached | Exact-bin review and approval pending |
| Full-chain DPD Identity | INCONCLUSIVE in Round 14; unchanged product RTL hashes; not rerun in Round 15 | OPEN; not PROVEN |
| `q1_tail` at both production interpolators | OPEN; zero legal attempts in the separated legal assertion run | OPEN; expected-negative assertion tests remain separate |
| COMMIT → Pending → Apply → ACK → DONE full-chain invariant | OPEN; no Round 15 end-to-end proof | OPEN |

The combined 240-test URG assertion summary includes three failures from the isolated expected-negative VDBs, 13 successes, and two uncovered DUT assertions. These failures are not reported as legal-test failures. Round 14's separated legal assertion regression had zero unexpected failures; the two production `q1_tail` properties had no legal attempts. Formal INCONCLUSIVE and missing attempts are not converted to PASS.

## 7. Reproduction, manifests and final decision

The Raw and zero-exclusion Adjusted URG invocations are the exact expanded command arrays recorded in the run `report_manifest.json`; both consumed the same 1-design/240-test VDB manifest. Run outputs are under ignored `runs/thermo5_round15_6b0d7c4/urg_incremental/final_raw_adjusted_240/`. The path-free URG manifest and hashes are committed under `docs/verification/data/thermo5-r15/`.

Evidence generation command:

```bash
python3.12 tools/hw/thermo5_tx_round15_finalize_evidence.py \
  --baseline-ledger docs/verification/data/thermo5-r15/thermo5_tx_r15_exact_uncovered_bins.csv.gz \
  --before-report /tmp/dsm_ip_thermo5_round14/runs/thermo5_round14_253268f/coverage_final_232/raw_urg \
  --after-report runs/thermo5_round15_6b0d7c4/urg_incremental/final_raw_adjusted_240/raw_urg \
  --raw-inventory runs/thermo5_round15_6b0d7c4/urg_incremental/final_raw_adjusted_240/raw_inventory \
  --report-manifest runs/thermo5_round15_6b0d7c4/urg_incremental/final_raw_adjusted_240/report_manifest.json \
  --out-dir docs/verification/data/thermo5-r15 \
  --product-sha 6b0d7c4ac4949fe0fa86af3da345a4e8dbeac7b5
```

The report generator checks stable VDB manifests, product source SHA, exact before/after directional Toggle bins, expected campaign count, candidate-ledger cardinality, and Formal evidence presence. `python3.12 -m py_compile` passed for the changed evidence and Formal utilities; `git diff --check` passed.

- **Functional coverage:** 218/218 legally applicable bins remain PASS on the Round 14 same-source carry-forward; fresh full functional regression not rerun in Round 15.
- **DUT code coverage:** OPEN (`RAW_100_OPEN`); 13,171 exact bins remain; Raw=official Adjusted.
- **Waivers:** 369 pending local candidates, zero approved, zero exclusions; Pair-1 proof package is pending review.
- **Formal / assertions:** OPEN because outstanding counter, full-chain DPD Identity, legal `q1_tail`, and full COMMIT lifecycle obligations are unresolved or inconclusive.
- **Linux DV signoff:** NOT SIGNED OFF.
- **XPM, GT Wizard, integrated CDC/RDC, Vivado timing/PPA, FPGA, RF and physical QAM256:** NOT RUN / outside this Linux round.

No RTL was removed, no parameter or denominator was changed, no exclusion was applied, and no Formal inconclusive result was treated as proof.

# Thermo5 TX Round 17 — Approved Exclusion and Exact-Bin Closure

**Date:** 2026-11-08

**Review PR:** [#46](https://github.com/cwu766485-ctrl/dsm_ip/pull/46), open and draft

**Product-source baseline:** `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`

**Decision:** Linux DV signoff remains **OPEN** (`RAW_100_OPEN`). This round did not produce a new Raw or Adjusted URG run, approve a waiver, apply an exclusion, or close a new exact coverage bin.

## 1. Scope and source review

The frozen product profile remains Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1 with Identity reset image, AXI-Lite, and Generic FIFO. Product RTL aggregate SHA-256 is `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`.

PR #46 was reviewed through its GitHub metadata, changed-file inventory, and patch. It is still open/draft, has 15 changed paths, and contains Round 16 documentation and evidence only. It does not change RTL, product parameters, testbench source, or the frozen algorithm. This Round 17 evidence is added to that review branch; it is not merged into `thermo5` here.

The preserved Round 16 evidence identifies one Design VDB and 362 Test VDBs, manifest SHA-256 `75b83f5b49a6fd180f3485f56066a7325a27825edc78284be2d83d24c6fd6fef`, report-manifest SHA-256 `8745380d90c08e217a1e7bc8f21cd11fec93dc79eeb88f3e091daff7e76f30b3`, and product compile fingerprint `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`. These are the last measured Round 16 inputs/results, not newly regenerated Round 17 evidence.

A static source rebind was made from the archived Round 16 VCS compile log and current checked-out source files. It hashes 95 parsed compile sources plus two controlled filelist/hierarchy inputs. Its structured fingerprint is `f0ef176a049ec16e14c7302dd3493d05c3ba8395dc5a7c44eb34ba2c99b0a0fa`, which does **not** match the Round 16 URG report fingerprint `e723c226...`. It is therefore retained as a diagnostic source manifest only and is not accepted as proof that the archived VDB/report is bound to that structured manifest. No report metadata was rewritten to conceal this mismatch.

## 2. Round 17 tool availability and executed checks

| Tool / check | Result | Evidence |
|---|---|---|
| VCS V-2023.12-SP1_Full64 `vcs -ID` | **BLOCKED** | Exit 1: installed build rejects WSL2 kernel `6.6.87.2-microsoft-standard-WSL2` as unsupported. Log SHA-256 `014f33392fd1e9b278321b665ec6e02302e0820ad4545dd0a3ca2718a9225d9d`. |
| URG V-2023.12-SP1 `urg -version` | **BLOCKED** | Exit 1: VCS support script cannot be found after the VCS environment failure. Log SHA-256 `bd2186c6e7d11b83f1bb80bfac5a4f9c3e90b9578eeed1592f44528216718ae8`. |
| VC Formal V-2023.12-SP2, `counter` and `ef2_product_params` jobs | **BLOCKED_LICENSE** | VC Static could not check out `VC-STATIC-COMPILE`; `setup.txt` and `properties.txt` were not produced. No Round 17 property is Proven or Inconclusive from this attempt. Summary SHA-256 `59b01a3c9a72951a505448ad767babe6940af04f02891b8af0a0df0c0fa38dd7`. |
| Round 17 VCS product regression / URG merge | **NOT RUN** | VCS/URG could not start. No Round 17 VDB or coverage delta exists. |
| Python reconciliation and static checks | **PASS** | 371-ID reconciliation, 305-record priority ledger, Python compile, and `git diff --check`. |

Exact tool commands and log hashes are recorded in `data/thermo5-r17/thermo5_tx_r17_execution_evidence.json`; local raw tool logs remain under ignored `runs/thermo5_round17/`.

Commands executed in this environment:

```bash
VCS_ARCH_OVERRIDE=linux64 /opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -ID
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -version
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs counter ef2_product_params --out-dir runs/thermo5_round17/formal_scope
python3.12 -m unittest discover -s tools/hw/tests \
  -p 'test_thermo5_tx_waiver*.py' -v
python3.12 -m py_compile tools/hw/thermo5_tx_round17_reconcile.py
python3.12 tools/hw/thermo5_tx_round17_reconcile.py \
  --out-dir docs/verification/data/thermo5-r17
```

## 3. Last measured Round 16 coverage (carry-forward only)

Raw and official zero-exclusion Adjusted were generated from the same Round 16 VDB manifest. Since approved waivers and active exclusions were both zero, the last measured Raw and Adjusted values were identical:

| Metric | Raw covered / total | Raw | Approved Adjusted covered / total | Approved Adjusted | Excluded | Exact open |
|---|---:|---:|---:|---:|---:|---:|
| Branch | 524 / 637 | 82.2606% | 524 / 637 | 82.2606% | 0 | 113 |
| Condition | 657 / 849 | 77.3852% | 657 / 849 | 77.3852% | 0 | 192 |
| Line | 3,338 / 3,796 | 87.9347% | 3,338 / 3,796 | 87.9347% | 0 | 458 |
| Toggle | 92,072 / 104,480 | 88.1240% | 92,072 / 104,480 | 88.1240% | 0 | 12,408 |
| FSM state | 13 / 13 | 100% | 13 / 13 | 100% | 0 | 0 |
| FSM transition | 22 / 22 | 100% | 22 / 22 | 100% | 0 | 0 |

There were 13,171 exact open DUT code records (113 Branch + 192 Condition + 458 Line + 12,408 Toggle). These are Round 16 measured results, not a Round 17 rerun. Round 17's VDB input set and coverage delta are **NOT RUN / NOT AVAILABLE**.

The last functional evidence reports 16/16 URG groups at 100% and 436/436 legally applicable bins carried forward from the Round 15 legal-bin audit. Round 16 product regressions, System Random 110/110, DPD/Gain/Profile 60/60, COMMIT boundary / PA stall 2/2, Reset / Pending COMMIT 8/8, direct SV scoreboard mutations 6/6, and Python reference tests 64/64 were PASS on the unchanged product-source baseline. They were not rerun in Round 17. Round 16 aggregate assertions included 15 successes, 3 isolated expected-negative failures, 4 uncovered properties, and 2 properties without attempts; they do not constitute full Assertion Signoff.

## 4. Gate A — waiver inventory and audit binding

### Exact 371-to-369 reconciliation

The official waiver CSV contains 371 unique IDs. The clean Round 16 candidate review contains 369 unique IDs; all 369 map one-to-one to an exact Round 16 open Raw bin and match the source-file SHA recorded in the Round 16 gap ledger. Their classifications remain 361 `ELIGIBLE`, 4 `NEEDS_REPROOF`, and 4 `UNRESOLVED`. None has independent approval.

The two IDs absent from the clean candidate inventory have separate archived Raw-hit evidence and are recorded as `RESOLVED_BY_RAW_HIT` in the Round 17 reconciliation ledger:

| Waiver ID | Exact bin | Metric / source | Archived Raw witness | Round 17 handling |
|---|---|---|---|---|
| `W-75530ed17d5b396a4e9b` | `75530ed17d5b396a4e9b` | Line, `thermo5_dpd_axi_lite_cfg.sv:142` | 1/1, missing 0 | Resolved from Raw evidence; no exclusion. |
| `W-d7cb262894a5aae016b6` | `d7cb262894a5aae016b6` | Branch, `thermo5_dpd_axi_lite_cfg.sv:135` | 7/7, missing 0 | Resolved from Raw evidence; no exclusion. |

The historical Round 15 refresh CSV is malformed: 370 physical rows, 368 unique IDs, duplicate IDs `W-92ac451faeb760079ca8` and `W-cd4717ad916b9979a47a`, and missing official IDs `W-75530ed17d5b396a4e9b`, `W-d7cb262894a5aae016b6`, and `W-f4e9c70e66ecbf5e4ca2`. The last ID is restored in the clean 369-candidate inventory. The Round 15 file and official waiver CSV are preserved unchanged; the normalized Round 17 CSV is the non-destructive reconciliation record.

### Fail-closed pipeline result

The pipeline was not weakened and no failure condition was removed. Its available probes correctly remain fail-closed:

1. Official 371-row input against the current Round 16 open-bin ledger stops because `W-75530ed17d5b396a4e9b` maps to zero **open** Raw bins; it is already a Raw hit.
2. A temporary 369-row active-candidate copy with the newly rebound compile manifest stops because its existing candidate-audit records still name a different, older raw-gap-ledger path.
3. The Round 16 report fingerprint (`e723c226...`) differs from the newly reconstructed structured compile fingerprint (`f0ef176a...`). The candidate-audit tool rejects this mismatch as `URG report configuration differs from product compile`.
4. Reusing the legacy Round 16 source manifest directly is also rejected because it lacks the structured `VCS_PRODUCT_COMPILE_INPUTS` schema required by the current candidate-audit tool (`compile manifest is not a product VCS compile manifest`).

Therefore the Round 17 normalized inventory reconciliation **passes**, but regenerating a fail-closed candidate-audit manifest bound to the 371-row official CSV **does not pass**. No pipeline-generated current audit manifest was created, and no `.el` exclusion was generated or applied. A supported licensed Linux run must regenerate a compile/report/VDB-consistent manifest and then regenerate the candidate audit from that same evidence before this Gate can close.

## 5. Gate B — fixed-configuration candidates

| Candidate group | Exact inventory | Existing evidence | Round 17 disposition |
|---|---:|---|---|
| DPD Pair-1 Toggle | 8,192 bins / 64 scoped properties | Round 16 leaf proofs are `PROVEN_SCOPED`, with activity covers; proof scope omits AXI-Lite COMMIT/mailbox/CDC and RUN/STOP integration. | Candidate only. No independent approval, official `.el`, or Adjusted exclusion. |
| EF2 Pair-Look-Ahead branches | 80 bins | Product parameters are ORDER=2 / STEP=5120 / 20-bit; Round 16 static-parameter evidence says the current product default leaves the branch disabled. | Exact configuration candidate only; no new proof or reviewer approval in Round 17. |
| Other fixed-parameter branches | 8 bins | Round 16 parameter evidence exists for the relevant product elaboration. | Candidate only; no independent approval or exclusion. |
| Other legacy candidates | 369 rows total: 361 / 4 / 4 classifications above | Exact source/bin mapping is reconciled; the four historical Formal candidates are not promoted to Round 17 proof results. | All pending. |

No claim is made that local leaf proofs alone justify product-level exclusions through reset, COMMIT, stall, or RUN/STOP transitions. All candidates remain outside official Adjusted coverage until current-source, exact-bin evidence and independent reviewer approval are recorded.

## 6. Gate C — exact Branch and Condition ledger

`data/thermo5-r17/thermo5_tx_r17_branch_condition_ledger.csv` contains all 305 exact open Branch/Condition records from the Round 16 Raw ledger, joined to source position, instance, exact bin, prior root cause, candidate relationship, and next action. Every record is explicitly `OPEN` with Round 17 test/proof result `NOT_RUN_IN_ROUND17`.

| Group | Count | Current disposition | Closure requirement |
|---|---:|---|---|
| Pair-Look-Ahead helper Branch | 80 | Configuration-inactive candidate; not approved | Preserve exact elaboration evidence, verify per-bin URG mapping and upper product constraints, then independent review. |
| Other fixed-parameter Branch | 8 | Candidate; not approved | Exact elaborated parameter and source mapping, then independent review. |
| Remaining Branch | 25 | Open; reachability/test result not updated this round | AXI-Lite address decode, CDC residual/frame end, interpolator empty/blocked/tail, reset hold, cadence and outstanding-counter cases need per-bin legal witness or non-vacuous proof. |
| Reset release / state hold Condition | 188 | Open; no Round 17 legal witness | Directed reset/enable/stall sequence with independent checker and exact URG hit. |
| Interpolator empty / blocked Condition | 4 | Open; product reachability unresolved | Legal two-stage frame/tail sequence or source-bound non-vacuous formal proof. |

No new test or formal witness ran because VCS and VC Formal could not execute. A test PASS alone would not close these records; the checker and exact URG hit must agree.

## 7. Gate D — Line and Toggle inventory

| Metric / root-cause group | Exact open bins | Round 17 result |
|---|---:|---|
| Line — fixed product configuration | 244 | Open; no approved exclusions. |
| Line — DPD tap history | 176 | Open; no new directed tests. |
| Line — legal stimulus / checker review | 32 | Open; no new legal witness. |
| Line — CDC / residual state | 6 | Open; no new legal witness. |
| Toggle — DPD Pair-1 tap history | 8,192 | Candidate only; no approved exclusions. |
| Toggle — data value / stimulus | 2,478 | Open; no new target-bin campaign. |
| Toggle — Identity DPD arithmetic | 944 | Open; no full-chain formal closure. |
| Toggle — counter high bits | 640 | Open; product runtime/overflow contract not established. |
| Toggle — CDC / residual state | 130 | Open; no new target-bin campaign. |
| Toggle — other fixed product configuration | 24 | Candidate only; no approved exclusions. |

Counter high-bit coverage is not waived: no product runtime maximum or overflow contract was newly established, and a shortened Block-Level counter would not count as product-instance coverage. No Round 17 Line or Toggle Bin was hit or excluded.

## 8. Gate E — Formal and Assertion matrix

| Property area | Last valid evidence | Round 17 status |
|---|---|---|
| Pair-1 leaf invariants | 64/64 scoped properties proven in Round 16; non-empty input/output activity covers | `PROVEN_SCOPED` carry-forward only; no new run and no approved waiver. |
| EF2 product parameter / Pair-Look-Ahead | Round 16 static configuration proof passed in its stated elaboration scope | `PROVEN_SCOPED` carry-forward; no current Round 17 run; no automatic exclusion. |
| Outstanding Counter capacity / saturation / underflow | Round 16 was `INCONCLUSIVE` | `OPEN / INCONCLUSIVE`; Round 17 attempt blocked by license, which is not a proof result. |
| DPD Identity full chain | Leaf proof omits the complete AXI-Lite shadow/COMMIT/mailbox/CDC chain | `OPEN`; no full-chain proof. |
| COMMIT → Pending → Apply → ACK → STATUS/DONE | Directed/random regressions passed in Round 16; complete composed invariant remains absent | `OPEN`; no new test or proof this round. |
| Two product `q1_tail` assertions | Round 16 recorded zero legal attempts | `OPEN / WITHOUT_ATTEMPTS`; no Round 17 legal attempt. |
| Active-Tap configuration | Prior evidence remains unresolved/inconclusive | `OPEN`; no Round 17 run. |

VC Formal was attempted for `counter` and `ef2_product_params` but could not check out its compile license. No `INCONCLUSIVE` result is converted to `PROVEN`; no new Formal signoff is claimed.

## 9. Gate F — Linux signoff decision and required next evidence

- Functional/regression results listed above are Round 16 carry-forward evidence, not Round 17 reruns.
- Raw and Adjusted remain the Round 16 same-input results; no Approved Exclusion exists.
- The fail-closed pipeline audit could not be rebound to the official CSV and matching URG report, so Gate A remains partly open.
- 305 Branch/Condition records, 458 Line records, and 12,408 Toggle records remain open in the last measured ledger. No Round 17 exact coverage gain occurred.
- Outstanding Counter, full-chain DPD Identity, COMMIT lifecycle, `q1_tail`, and Active-Tap obligations remain open.
- Real XPM, GT Wizard, integrated CDC/RDC, Vivado timing/PPA, FPGA, board, and physical QAM256 evidence are outside this Linux result and were not run.

**Final decision: NOT SIGNED OFF.** The current measured code coverage is still Round 16 Raw=Adjusted, below 100% for Branch, Condition, Line, and Toggle. No official adjusted 100% claim is supported. Continue on a licensed supported Linux EDA host: regenerate product compile and URG report manifests from one frozen SHA and VDB set, rebind the 371-row inventory (keeping the two Raw-hit IDs as resolved audit records), regenerate the pipeline audit, then proceed with approved exact exclusions and target-bin tests/formal. Keep every unproven or legally reachable bin OPEN.

## 10. Round 17 artifact index

| Artifact | Purpose |
|---|---|
| `data/thermo5-r17/thermo5_tx_r17_waiver_reconciliation.csv` | All 371 official IDs with two `RESOLVED_BY_RAW_HIT` and 369 pending candidates. |
| `data/thermo5-r17/thermo5_tx_r17_waiver_reconciliation.json` | Machine-readable counts and malformed Round 15 audit reconciliation. |
| `data/thermo5-r17/thermo5_tx_r17_branch_condition_ledger.csv` | 305 exact open Branch/Condition tasks. |
| `data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json` | Source-hash parent inventory for the archived compile inputs. |
| `data/thermo5-r17/thermo5_tx_r17_historical_compile_manifest.json` | Static rebind manifest; fingerprint differs from the Round 16 URG report and is not a current URG-compatible manifest. |
| `data/thermo5-r17/thermo5_tx_r17_execution_evidence.json` | Tool attempts, exact statuses, hashes, coverage carry-forward, and gate disposition. |
| `tools/hw/thermo5_tx_round17_reconcile.py` | Read-only inventory reconciliation; it does not alter official waiver state or emit exclusions. |

Raw tool logs and VDBs remain in ignored local `runs/` directories. The Round 16 source, coverage, VDB, Formal, regression, and run-log manifests remain under `data/thermo5-r16/`.

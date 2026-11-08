# Thermo5 TX Round 17 — Approved Exclusion and Exact-Bin Closure

## Superseding update — WSL VCS/URG recovery (2026-11-08)

The environment and coverage statements in the original snapshot below describe the earlier attempt at PR #46 head `3205448de89458281fd7ff9e17ff8c4c0fd35ab2`; they are historical and superseded. VCS `V-2023.12-SP1_Full64` and URG `V-2023.12-SP1` have now run successfully in this Rocky 8.10 WSL2 environment when invoked in 64-bit mode. The previous “WSL2 kernel rejected” conclusion was incorrect: the failed URG probe selected the default 32-bit support path. No kernel spoofing or `VCS_ARCH_OVERRIDE` was used.

At source HEAD `4d92ecb8467b095b50478065e29e9646f2cff27e`, selected Generic FIFO, AXI-Lite, System Random, DPD matrix, COMMIT/PA-stall, Reset/Pending-COMMIT, STOP/Drain/Restart, scoreboard mutation, Python reference and reset-only Formal checks passed. A new same-input Raw/zero-exclusion Adjusted URG was generated from one current Design VDB and 551 Test VDBs (362 carry-forward plus 189 fresh). It reports Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92072/104480, FSM states 13/13 and transitions 22/22. The 189 fresh VDBs added no exact DUT code-coverage hits. Waivers approved: 0; exclusions applied: 0; 13,171 code bins remain open.

The detailed current report and command list are `thermo5-tx-r17-wsl-vcs-reverification-20261108.md`; its machine-readable evidence/hash manifest is `data/thermo5-r17/thermo5_tx_r17_wsl_vcs_reverification.json`. The formal, waiver, assertion and physical-validation risks listed there remain open. Linux DV signoff is not complete, and PR #46 remains Draft/Open and unmerged.

**Date:** 2026-11-08

**Review PR:** [#46](https://github.com/cwu766485-ctrl/dsm_ip/pull/46), open and draft

**Product-source baseline:** `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`

**Decision:** Linux DV signoff remains **OPEN** (`RAW_100_OPEN`). This round did not produce a new Raw or Adjusted URG run, approve a waiver, apply an exclusion, or close a new exact coverage bin.

## 1. Scope and source review

The frozen product profile remains Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1 with Identity reset image, AXI-Lite, and Generic FIFO. Product RTL aggregate SHA-256 is `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`.

PR #46 was re-audited at head `3205448de89458281fd7ff9e17ff8c4c0fd35ab2`, based on `thermo5` at `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`. At that audit head it was open and Draft, three commits ahead, and changed 26 paths: Round 16/17 reports and audit data, the Formal harness/runner, and the Round 17 reconciliation utility. The diff contains no product RTL, product-parameter, algorithm, or UVM scenario/agent changes. It is not documentation-only because Formal executable collateral and the reconciliation utility changed. GitHub reports no submitted reviews. At commit `3205448`, Repository Hygiene run `42468815736` passed and Thermo5 DV run `42468815748` passed the Python syntax/reference job; `licensed-dv` was skipped. The workflow condition only enables that self-hosted licensed job for `workflow_dispatch` or a push to `thermo5`, with the licensed-runner variable enabled. The conditional intermediate merge for audit-evidence-only PRs therefore does not apply: this PR still needs independent review, and its Formal harness changes have not run in the licensed CI job. No merge to `thermo5` is made.

The preserved Round 16 evidence identifies one Design VDB and 362 Test VDBs, manifest SHA-256 `75b83f5b49a6fd180f3485f56066a7325a27825edc78284be2d83d24c6fd6fef`, report-manifest SHA-256 `8745380d90c08e217a1e7bc8f21cd11fec93dc79eeb88f3e091daff7e76f30b3`, and product compile fingerprint `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`. These are the last measured Round 16 inputs/results, not newly regenerated Round 17 evidence.

A static source rebind was made from the archived Round 16 VCS compile log and current checked-out source files. It hashes 95 parsed compile sources plus two controlled filelist/hierarchy inputs. Its structured fingerprint is `f0ef176a049ec16e14c7302dd3493d05c3ba8395dc5a7c44eb34ba2c99b0a0fa`, which does **not** match the Round 16 URG report fingerprint `e723c226...`. It is therefore retained as a diagnostic source manifest only and is not accepted as proof that the archived VDB/report is bound to that structured manifest. No report metadata was rewritten to conceal this mismatch.

## 2. Round 17 tool availability and executed checks

| Tool / check | Result | Evidence |
|---|---|---|
| VCS V-2023.12-SP1_Full64 `vcs -ID` | **BLOCKED** | Exit 1: installed build rejects WSL2 kernel `6.6.87.2-microsoft-standard-WSL2` as unsupported. Log SHA-256 `014f33392fd1e9b278321b665ec6e02302e0820ad4545dd0a3ca2718a9225d9d`. |
| URG V-2023.12-SP1 `urg -version` | **BLOCKED** | Exit 1: VCS support script cannot be found after the VCS environment failure. Log SHA-256 `bd2186c6e7d11b83f1bb80bfac5a4f9c3e90b9578eeed1592f44528216718ae8`. |
| VC Formal V-2023.12-SP2 | **LICENSE RESTORED** | A later checkout succeeded. Current-source targeted proof results, including PASS and INCONCLUSIVE outcomes, are in §11 and the recovery manifest. The initial license failure is retained as historical evidence only. |
| Round 17 VCS product regression / URG merge | **NOT RUN** | VCS/URG could not start. No Round 17 VDB or coverage delta exists. |
| GitHub Actions at PR head `3205448d` | **PARTIAL** | Repository Hygiene run `42468815736` passed; Thermo5 DV run `42468815748` passed its `syntax` job, while `licensed-dv` was skipped. No licensed VCS/URG evidence was produced by CI. There are no independent PR reviews. |
| Python reconciliation and static checks | **PASS** | 371-ID reconciliation, 305-record priority ledger, Python compile, and `git diff --check`. |

Exact tool commands and the initial attempt hashes are recorded in `data/thermo5-r17/thermo5_tx_r17_execution_evidence.json`. License-recovery commands, result manifests and hashes are in `data/thermo5-r17/thermo5_tx_r17_license_recovery.json`; local raw tool logs remain under ignored `runs/thermo5_round17/`.

VCS/URG retry commands and one representative targeted VC Formal invocation are shown below. The per-run Formal commands, source hashes, result manifests, and artifact hashes are recorded in the license-recovery JSON.

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 VCS_ARCH_OVERRIDE=linux64 \
  /opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -ID
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  /opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -version
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_axil_cfg_coverage.py \
  --out-dir runs/thermo5_round17/retry_license_20261108/axil_cfg_current_source_retry
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
| DPD Pair-1 Toggle | 8,192 bins / 64 scoped properties | Re-run on current product RTL: 64/64 lane invariants proven for `MAX_TAPS=1`; input-accept and output-transfer activity Covers reached. Proof scope still omits AXI-Lite COMMIT/mailbox/CDC and RUN/STOP integration. | Stronger current-source candidate evidence only. No independent approval, official `.el`, or Adjusted exclusion. |
| EF2 Pair-Look-Ahead branches | 80 bins | Current-source product-parameter proof passes for ORDER=2 / STEP=5120 / 20-bit, with Pair-Look-Ahead disabled and invalid-parameter guard inactive; target Covers are uncoverable in that elaboration. | Exact configuration candidate only; no independent reviewer approval. |
| Other fixed-parameter branches | 8 bins | Round 16 parameter evidence exists for the relevant product elaboration. | Candidate only; no independent approval or exclusion. |
| Other legacy candidates | 369 rows total: 361 / 4 / 4 classifications above | Exact source/bin mapping is reconciled; the four historical Formal candidates are not promoted to Round 17 proof results. | All pending. |

No claim is made that local leaf proofs alone justify product-level exclusions through reset, COMMIT, stall, or RUN/STOP transitions. All candidates remain outside official Adjusted coverage until current-source, exact-bin evidence and independent reviewer approval are recorded.

## 6. Gate C — exact Branch and Condition ledger

`data/thermo5-r17/thermo5_tx_r17_branch_condition_ledger.csv` contains all 305 exact open Branch/Condition records from the Round 16 Raw ledger, joined to source position, instance, exact bin, prior root cause, candidate relationship, and next action. Every record is explicitly `OPEN` with Round 17 test/proof result `NOT_RUN_IN_ROUND17`.

| Group | Count | Current disposition | Closure requirement |
|---|---:|---|---|
| Pair-Look-Ahead helper Branch | 80 | Configuration-inactive candidate; not approved | Preserve exact elaboration evidence, verify per-bin URG mapping and upper product constraints, then independent review. |
| Other fixed-parameter Branch | 8 | Candidate; not approved | Exact elaborated parameter and source mapping, then independent review. |
| Remaining Branch | 25 | Four have scoped current-source Formal proofs; 21 have no new witness. All remain open pending exact-bin mapping/review or legal stimulus. | AXI-Lite default and three CDC cases have source-bound proofs and positive context Covers; exact native URG mapping and Reviewer approval remain open. Remaining address, interpolator, cadence, and outstanding-counter cases need target evidence. |
| Reset release / state hold Condition | 188 | Three exact records have scoped Formal target-Cover evidence; all 188 remain open pending mapping/review or legal URG hit. | Includes the Generic-FIFO `core_data_empty` relation and stage-1/stage-2 line-309 reset operands. The reset proofs do not satisfy legal `q1_tail` assertion attempts. |
| Interpolator empty / blocked Condition | 4 | Open; product-path reachability unresolved | The two-stage legal-metadata proof reaches frame/tail transfers but omits the intervening FIFOs and DPD; no product VDB/URG hit was generated. |

Current-source Formal provides exact, non-vacuous evidence for four former `NEEDS_REPROOF` Branch candidates: AXI-Lite write case default (`W-9010fccd0889b46ea284`), CDC `advance` case default (`W-98a39b6429bbed7c29ad`), CDC `end_remaining` false arm (`W-32b5745433f0ff75d5c2`), and immediate CDC frame-end arm (`W-a9fc97093bdddfb7f5aa`). Their source hashes match the current RTL; legal transaction/frame Covers were reached and each target Cover was reported uncoverable in its scoped proof. All four remain `OPEN_FORMAL_MAPPING_REVIEW`: the new Formal runs do not regenerate URG, prove native-bin identity, or provide independent Reviewer approval. A test PASS alone would not close these records; exact URG mapping and approval are still required.

Additional scoped Formal runs prove the EF2 pair equivalence, product EF2 parameter guards, CDC data-empty relationship, legal frame-tail metadata/reset properties, and the 2072-accepted-input DPD gap-counter bound. Their scope limits are recorded in §11. These proofs do not create URG hits and do not close full-chain `q1_tail`, unrestricted runtime-counter, or product-level DPD Identity obligations.

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
| Pair-1 leaf invariants | Current-source 64/64 properties proven for 16 lanes; input/output activity Covers hit; no assumptions beyond reset initialization; 0 black boxes | `PROVEN_SCOPED`; exact 8,192-bin URG map and independent waiver review remain open. |
| EF2 pair equivalence | Current-source 7/7 assertions and 4/4 activity/stall Covers passed | `PROVEN_SCOPED`; the product configuration still disables this candidate architecture. |
| EF2 product parameter / Pair-Look-Ahead | Current-source parameter proof passed; invalid-parameter and Pair-Look-Ahead Covers uncoverable | `PROVEN_SCOPED`; candidate exclusions remain unapproved. |
| Outstanding Counter capacity / saturation / underflow | Current-source full wrapper attempt ran 310.73 s; all five assertions and both guard Covers are INCONCLUSIVE | `OPEN / INCONCLUSIVE`; no assumption-based waiver. |
| DPD Identity | Current-source compositional one-tap output-under-stall proof passed local lemmas/output checks; the separate simple end-to-end identity harness remains INCONCLUSIVE on payload/saturation | Local datapath `PROVEN_SCOPED`; full-chain config/COMMIT/mailbox/CDC Identity remains OPEN. |
| COMMIT → Pending → Apply → ACK → STATUS/DONE | No complete current-source composition run | `OPEN`; previous directed/random results are carry-forward only. |
| Two product `q1_tail` assertions | Legal-attempt regressions remain without direct assertion attempts. Scoped legal-metadata proof reaches frame/tail transfers but makes the two target antecedent Covers uncoverable under its stated schedule; reset-condition proof covers reset events and makes reset bins uncoverable | `OPEN / WITHOUT_ATTEMPTS`; these scoped results do not satisfy complete product-path assertion signoff. |
| Active-Tap configuration | Lean controller run: pending-bank tap invariant proven; invalid tap write, rejected invalid COMMIT, and legal commit/apply Covers reached; active output tap invariant INCONCLUSIVE; 0 assumptions and 0 black boxes | `OPEN / INCONCLUSIVE`; no Active-Tap exclusion or approval. |

VC Formal is operational after license recovery. Results remain separated by scope: no `INCONCLUSIVE` is converted to `PROVEN`, and no proof automatically approves a Waiver or creates an URG hit.

## 9. Gate F — Linux signoff decision and required next evidence

- Functional/regression results listed above are Round 16 carry-forward evidence, not Round 17 reruns.
- Raw and Adjusted remain the Round 16 same-input results; no Approved Exclusion exists.
- The fail-closed pipeline audit could not be rebound to the official CSV and matching URG report, so Gate A remains partly open.
- 305 Branch/Condition records, 458 Line records, and 12,408 Toggle records remain open in the last measured ledger. No Round 17 exact coverage gain occurred.
- Outstanding Counter, full-chain DPD Identity, COMMIT lifecycle, `q1_tail`, and Active-Tap obligations remain open.
- Real XPM, GT Wizard, integrated CDC/RDC, Vivado timing/PPA, FPGA, board, and physical QAM256 evidence are outside this Linux result and were not run.

**Final decision: NOT SIGNED OFF; Gate 0 remains blocked.** The current measured code coverage is still Round 16 Raw=Adjusted, below 100% for Branch, Condition, Line, and Toggle. No official adjusted 100% claim is supported. VC Formal license is restored, but VCS V-2023.12-SP1 still rejects the WSL2 kernel with the correct `linux64` architecture override, and URG cannot initialize without the VCS support script. PR #46 remains Draft with no independent reviews; its hosted `licensed-dv` job was skipped. Since the PR contains Formal harness/runner changes as well as audited records, it does not meet the plan's audit-evidence-only condition for an OPEN intermediate merge. Do not merge it to `thermo5` yet. A supported licensed Linux EDA host and independent review are required before re-running product regression/URG, approving exact exclusions, or proceeding to final integration. Keep every unproven or legally reachable bin OPEN.

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
| `data/thermo5-r17/thermo5_tx_r17_license_recovery.json` | Current-source VC Formal reruns, WSL2 VCS/URG retry, tool/log hashes, scoped results, and explicit coverage/waiver non-impact. |

License-recovery evidence JSON SHA-256: `0b41803385b28e95a93c5673abf9452d3f8ff3fa57cf3acd5248ad135c0864e1`.

Raw tool logs and VDBs remain in ignored local `runs/` directories. The Round 16 source, coverage, VDB, Formal, regression, and run-log manifests remain under `data/thermo5-r16/`.

## 11. License recovery and current-source Formal reruns

VC Formal V-2023.12-SP2 checked out its runtime license successfully. The successful and inconclusive jobs are bound to product RTL revision `cc77a9e8e512bfa718ee3f67d4ed9ff6aaba0410` and per-file SHA-256 manifests. The controlled product source remains `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`, with RTL aggregate SHA-256 `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`.

| Run | Result | Scope and disposition |
|---|---|---|
| AXI-Lite config default/reachability | PASS, 4/4 assertions; 1 positive read Cover and three target Covers uncoverable; 0 assumptions, 0 black boxes | Current `MAX_TAPS=1` controller module. `W-9010...` target is proven unreachable in its stated write-response/address case scope. |
| CDC default branch | PASS, 2/2 assertions; legal advance/frame Covers reached; exact default path uncoverable; 0 assumptions, 0 black boxes | Exact Generic-FIFO 14:8 product configuration. `W-98a...` is still pending native URG map and review. |
| CDC end-remaining branch | PASS, 5/5 assertions; legal 64-beat packet/frame Covers reached; target false arm uncoverable; 0 assumptions, 0 black boxes | Exact legal packet-multiple contract and 14:8 ratio in the harness. `W-32b...` still pending map and review. |
| CDC immediate end branch | PASS, 1/1 assertion; product end context/completed-frame Covers reached; target arm uncoverable; 0 assumptions, 0 black boxes | Scoped Generic-FIFO CDC. `W-a9f...` still pending map and review. |
| Outstanding counter | INCONCLUSIVE, 5/5 assertions and two guard Covers inconclusive; source/core/output activity Covers reached | Full wrapper attempt. This is not evidence of unreachability. |
| Pair-1 | PASS, 64/64 properties across 16 lanes; input-accept/output-transfer Covers reached; reset-only formal constraint; 0 black boxes | Proves Pair-1 accumulators zero under the exact `MAX_TAPS=1` leaf elaboration. Excludes AXI-Lite/COMMIT/CDC/RUN/STOP composition. |
| EF2 pair equivalence | PASS, 7/7 assertions and 4/4 Covers | Scalar/candidate equivalence for signed-16 inputs and stalls; this is not evidence that the candidate is enabled in the product. |
| EF2 product parameters | PASS, 2/2 assertions; invalid parameter and Pair-Look-Ahead Covers uncoverable | Proves the current parameter branch in its stated product elaboration. |
| DPD gap counter | PASS, 3/3 assertions and 4/4 Covers | Bound to at most 2,072 accepted samples/reset epoch; does not prove unrestricted product runtime or AXI outstanding-counter safety. |
| DPD Identity under stall | PASS, compositional local datapath proof, 41 internal lemmas; endpoint, stall and recovery Covers reached | Proves local one-tap arithmetic/latency/stall behavior. Full chain through shadow/COMMIT/mailbox/CDC/active epoch remains excluded. |
| Simple DPD Identity chain | INCONCLUSIVE on payload equality and saturation/count properties; endpoint/stall/recovery Covers reached | Local simulation/formal chain only; no full configured TX chain signoff. |
| Frame-tail legal metadata | PASS, 2/2 assertions; legal frame/tail/output Covers reached; target active-bin Covers uncoverable | Stated two-stage 8-lane/16-lane frame geometry; intervening FIFOs and DPD metadata path omitted. |
| Frame-tail reset conditions | PASS, 2/2 assertions; runtime reset/queue nonempty/reset-empty Covers reached; reset operand target Covers uncoverable | Does not create legal attempts for the two product `q1_tail` assertions. |
| CDC data-empty condition | PASS, 3/3 relationship assertions; source/FIFO/public-empty Covers reached; exact raw target Cover uncoverable | Exact Generic-FIFO relationship; keep the raw condition open pending native mapping and independent review. |
| Active-Tap controller attempt | FAIL-CLOSED / INCONCLUSIVE; pending-bank tap invariant proven, active output invariant unresolved; illegal tap write, rejected COMMIT, and legal commit/apply Covers reached | Current AXI-Lite config with `MAX_TAPS=1`, no environment assumptions, 0 black boxes. Formal runner returns nonzero because the active output property remains open. |

The initial Active-Tap proof also instantiated the 16-lane DPD datapath and enlarged the model without resolving the control properties. The retained lean attempt removes that irrelevant arithmetic cone while hashing the actual wrapper/frontend source files that connect `u_cfg.dpd_active_taps` to the product DPD `active_taps` port. Its remaining INCONCLUSIVE status is reported as OPEN. The exact commands, run paths, property states and SHA-256 digests are in the recovery JSON manifest.

These Formal runs do not create VCS tests, VDBs, URG hits or approved exclusions. Raw/Adjusted numbers remain the Round 16 carry-forward table in §3. All 369 active candidate dispositions remain pending; 0 approved Waivers and 0 active Exclusions remain in force.

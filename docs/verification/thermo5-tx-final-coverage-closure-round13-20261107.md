# Thermo5 TX Final Coverage Closure — Round 13

> **Final Round 13 status update (2026-11-07):** This file preserves the
> initial audit snapshot below. Its initial statement that VCS/URG/VC Formal
> could not run is superseded. The tools have since run successfully; the
> same-manifest Raw/Adjusted URG report was regenerated and current-source
> Formal reproofs were completed for four candidates. See the current report
> [`thermo5-tx-linux-final-signoff-round13-20261107.md`](thermo5-tx-linux-final-signoff-round13-20261107.md)
> and manifest [`thermo5_tx_r13_final_coverage_manifest.json`](data/thermo5-r13/thermo5_tx_r13_final_coverage_manifest.json).
> The final decision remains OPEN: no Waiver is approved, Raw equals official
> Adjusted, and required assertion/Formal/code-coverage items remain open.

**Disposition: OPEN — NOT SIGNED OFF.** This report records the Round 13 audit and the Linux work that could be completed on the current WSL Rocky environment. It does not convert What-if exclusions into approved waivers, and it does not treat an unavailable Formal run as proof.

## 1. Baseline and PR #42 Review

| Item | Audited value |
|---|---|
| Repository | `cwu766485-ctrl/dsm_ip` |
| Integrated `thermo5` base | `73577475230a9c4e51273ac7071437f0a7373d48` |
| PR #42 | [Draft, open, not merged](https://github.com/cwu766485-ctrl/dsm_ip/pull/42) |
| PR head / audited source commit | `644458deaf7481673c80177f1621efbff9252419` |
| Product RTL source SHA | `a03c2ddf2b997a3aff7ea54acdd2f6e2f6cdcce0` |
| Product compile fingerprint | `9f5e2d49d42795bb4b38f62b909cc690dcb726f1217efcdc4cd50029a0d4184a` |
| Product profile | Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; DPD_MAX_TAPS=1, Identity reset; AXI-Lite; Generic FIFO |
| Manifest integrity | 97/97 source and compile inputs match; 233/233 Round 12 VDBs match (1 design + 232 tests; 3,040 files, 3,286,141 bytes) |

PR #42 changes no product RTL or frozen TX algorithm. The reviewed diff is verification, evidence, and documentation work. GitHub reports no CI checks and no submitted reviews. Round 12 VDBs remain internally bound to the same product source and compile fingerprint, but they are historical Round 12 evidence, not a fresh Round 13 regression. Therefore PR #42 is not cleared for merge by this Round 13 work: current VCS regression and URG regeneration could not run on this host.

The working branch is `codex/thermo5-round13-closure`. Its starting commit is PR #42 head above. Seven pre-existing Round 12 CSVs appear modified in the checkout because of CRLF/LF conversion; `git diff --ignore-space-at-eol` is empty for them, and they were not edited or staged. The Round 13 manifest records this dirty state. Do not use a blanket restore or stage operation on those files.

Machine-readable baseline: [`thermo5_tx_r13_baseline_manifest.json`](data/thermo5-r13/thermo5_tx_r13_baseline_manifest.json). It binds the source, compile and VDB manifests, exact candidate inputs, Formal attempt, and hashes of generated audit artifacts.

## 2. Coverage Baseline and Waiver Status

Round 13 did not create a new VCS VDB or URG report. The table below is the validated Round 12 same-manifest coverage baseline, carried forward without claiming a Round 13 rerun. Official Adjusted remains identical to Raw because no waiver is approved and no official Exclusion is active.

| Metric | Official Raw / current official Adjusted | Raw uncovered | Round 12 What-if after 361 candidate bins | What-if uncovered |
|---|---:|---:|---:|---:|
| Branch | 524 / 637 (82.2606%) | 113 | 524 / 536 (97.7612%) | 12 |
| Condition | 657 / 849 (77.3852%) | 192 | 657 / 741 (88.6640%) | 84 |
| Line | 3,338 / 3,796 (87.9347%) | 458 | 3,338 / 3,644 (91.6026%) | 306 |
| Toggle | 91,288 / 104,480 (87.3737%) | 13,192 | 91,288 / 104,480 (87.3737%) | 13,192 |
| FSM states | 13 / 13 (100%) | 0 | 13 / 13 (100%) | 0 |
| FSM transitions | 22 / 22 (100%) | 0 | 22 / 22 (100%) | 0 |

The Round 12 What-if excluded 101 Branch, 108 Condition, and 152 Line bins. Those exclusions were analysis-only; none is an official approval. Against the official Raw denominator, 13,955 bins remain uncovered. Against the What-if denominator, 13,594 remain. The distinction is material.

### 2.1 Reconciliation of 371 official rows and 369 local candidates

The official GitHub waiver CSV has 371 IDs; the local candidate audit has 369. There are no local-only IDs. The two GitHub-only IDs are already Raw hits and are retained in the resolved-by-Raw-hit archive, so neither needs an exclusion:

| Waiver ID | Raw result | Disposition |
|---|---:|---|
| `W-75530ed17d5b396a4e9b` | 1/1 HIT | Archived as already covered |
| `W-d7cb262894a5aae016b6` | 7/7 HIT | Archived as already covered |

Of the 369 current candidate rows: 361 are eligible only for the prior What-if analysis, four need current-source reproof, and four remain unresolved. There are zero approved, zero rejected, and zero active official exclusions. No Reviewer or Approval Reference was invented.

The row-by-row review is in [`thermo5_tx_r13_waiver_candidate_review.csv`](data/thermo5-r13/thermo5_tx_r13_waiver_candidate_review.csv). It carries exact source file/hash, hierarchy, raw Bin ID, product configuration, Formal context, mapping, and Round 13 action for each row. All 361 candidate exclusions remain nonofficial pending evidence review and an independent approval.

### 2.2 Four candidates requiring reproof

| ID | Instance | RTL location | Exact native bin | Round 13 status |
|---|---|---|---|---|
| `W-9010fccd0889b46ea284` | `u_cfg` | `thermo5_dpd_axi_lite_cfg.sv:246` | `190:0/-/-/-/-/1/0/-/default/-/-/-/-/-/-/-/-/-` | OPEN; current proof not obtained |
| `W-32b5745433f0ff75d5c2` | `u_cdc` | `dsm_axis14_to_core8_cdc.sv:146` | `122:0/-/1/1/0/-/-/-/-/-/-/-` | OPEN; current proof not obtained |
| `W-a9fc97093bdddfb7f5aa` | `u_cdc` | `dsm_axis14_to_core8_cdc.sv:215` | `122:0/-/1/-/-/0 2 4 6/1/-/1/1/-/-` | OPEN; current proof not obtained |
| `W-98a39b6429bbed7c29ad` | `u_cdc` | `dsm_axis14_to_core8_cdc.sv:141` | `122:0/-/1/-/-/default/-/-/-/-/-/-` | OPEN; current proof not obtained |

### 2.3 Four interpolation candidates still unresolved

| ID | Instance | RTL location | Exact native bin | Round 13 status |
|---|---|---|---|---|
| `W-fca77c64e5465f089f37` | `u_interp_2` | centered interpolator `:129` | `129:1/-` | UNRESOLVED |
| `W-e8e68602c739b86a80b5` | `u_interp_2` | centered interpolator `:217` | `182:0/0/-/1/-/-/-/-/-/-/-/-/-` | UNRESOLVED |
| `W-f83f4a14b37b232df778` | `u_interp_2` | centered interpolator `:223` | `182:0/0/-/-/1/1/-/-/-/-/-/-/-` | UNRESOLVED |
| `W-ccf37502b42fd61c4cd7` | `u_interp_1` | centered interpolator `:229` | `182:0/0/-/-/-/-/1/-/-/-/-/-/-` | UNRESOLVED |

These four are not included in the What-if `.el`, and none was reclassified unreachable.

## 3. Fixed-Configuration Toggle Review

The Round 13 audit generated exact, per-bin inventories for the two requested groups. It did **not** generate an official `.el` or change the official waiver ledger.

| Group | Exact bins | Static product argument | Evidence state |
|---|---:|---|---|
| DPD pair-1 sums | 8,192 | With `MAX_TAPS=1`, the elaborated tap loop computes tap 0 only and feeds pair-0. Pair-1 combinational sums initialize to zero; their registers reset to zero and capture zero when enabled, and hold under stall. | Static source/config candidate only; no current Formal proof or independent approval |
| Active-tap buses | 120 | Product `MAX_TAPS=1`; reset image is tap count 1; legal tap-count range is 1..MAX_TAPS, and invalid values do not commit. The legal active setting is therefore one. | Static source/config candidate only; no current Formal proof or independent approval |

Exact rows are preserved separately in [`thermo5_tx_r13_pair1_exact_bins.csv.gz`](data/thermo5-r13/thermo5_tx_r13_pair1_exact_bins.csv.gz) and [`thermo5_tx_r13_active_taps_exact_bins.csv.gz`](data/thermo5-r13/thermo5_tx_r13_active_taps_exact_bins.csv.gz). They are marked `WAIVER_CANDIDATE`, not `APPROVED`; Exclusion count remains zero. The argument must still be independently reviewed against elaborated instances, reset behavior, COMMIT legality, and each bit/direction mapping.

## 4. Remaining Exact Bins by Root Cause

The complete 13,594-row, exact-Bin inventory is [`thermo5_tx_r13_exact_bin_disposition.csv.gz`](data/thermo5-r13/thermo5_tx_r13_exact_bin_disposition.csv.gz). Its reachability/status fields distinguish:

| Reachability/status | Bins | Interpretation |
|---|---:|---|
| `REACHABLE_BY_ACCEPTED_SAMPLE_COUNTER` | 640 | DPD sample-count high bits have a legal increment path; current tests did not run long enough to toggle them. They remain OPEN for coverage. |
| `STATIC_PARAMETER_INVARIANT_REVIEW_CANDIDATE` | 8,312 | Pair-1 and active-tap exact toggles appear constant under the product configuration; this is a candidate argument, not a PROVEN_UNREACHABLE result. |
| `UNRESOLVED` | 4,642 | Remaining branches, conditions, lines, and toggles lack a current witness or reviewed proof. |

No bin is marked `PROVEN_UNREACHABLE`; no official exclusion is active. All 12 Branch bins, 84 Conditions, 306 Lines, and 4,880 remaining Toggles stay `OPEN` pending hit or reviewed proof. A candidate status is not a HIT or Exclusion.

### 4.1 Branch — 12 OPEN bins

| Bin ID | Instance | Source location | Root cause / next action |
|---|---|---|---|
| `9010fccd0889b46ea284` | `dut.u_cfg` | `thermo5_dpd_axi_lite_cfg.sv:246` | Guarded address decode; test exact legal address through public AXI-Lite and independently check response, or prove with non-vacuous current-source Formal |
| `98a39b6429bbed7c29ad` | `dut.u_cdc` | `dsm_axis14_to_core8_cdc.sv:141` | Legal stimulus/checker; exact public stimulus and observed DUT event required |
| `32b5745433f0ff75d5c2` | `dut.u_cdc` | `dsm_axis14_to_core8_cdc.sv:146` | Legal stimulus/checker; exact public stimulus and observed DUT event required |
| `a9fc97093bdddfb7f5aa` | `dut.u_cdc` | `dsm_axis14_to_core8_cdc.sv:215` | Legal stimulus/checker; exact public stimulus and observed DUT event required |
| `ccf37502b42fd61c4cd7` | `u_interp_1` | centered interpolator `:229` | Interpolator legal witness/checker required |
| `fca77c64e5465f089f37` | `u_interp_2` | centered interpolator `:129` | Interpolator legal witness/checker required |
| `e8e68602c739b86a80b5` | `u_interp_2` | centered interpolator `:217` | Interpolator legal witness/checker required |
| `f83f4a14b37b232df778` | `u_interp_2` | centered interpolator `:223` | Interpolator legal witness/checker required |
| `0cfac9d3b4f8ffc01d7e` | `dut` | `tid32_thermo5_axi_lite_axis_frontend_tx.sv:203` | Outstanding counter saturation guard; define legal overflow contract and prove/test exact reachability |
| `280780368b4aad849606` | `dut` | `tid32_thermo5_axi_lite_axis_frontend_tx.sv:204` | Outstanding counter underflow guard; define legal underflow contract and prove/test exact reachability |
| `4796580247344dc2c731` | `u_interp_1` | centered interpolator `:255` | Product cadence; derive 14:8 ingress and both interpolation-stage schedule, then obtain a legal witness |
| `f2b36b12b909c892747f` | `u_interp_2` | centered interpolator `:255` | Product cadence; derive 14:8 ingress and both interpolation-stage schedule, then obtain a legal witness |

### 4.2 Condition — 84 OPEN bins

| Root cause | Bins | Root-cause tasks | Closure work |
|---|---:|---:|---|
| Reset release / state hold | 80 | 62 | Directed legal reset-release, enable, and stall sequences; independent assertion/checker and exact URG hit required |
| Interpolator empty / blocked | 4 | 4 | Legal source bubble with downstream backpressure; compare all four PA planes and prove the exact state/branch event |

### 4.3 Line — 306 OPEN bins

| Root cause | Bins | Tasks | Closure work |
|---|---:|---:|---|
| CDC / residual state | 6 | 6 | Reconstruct residual packing and legal frame-tail path; target each line with a DUT event |
| DPD tap history / configuration | 176 | 11 | Separate product-active tap history from unused tap paths; use exact one-tap configuration and independent output checks |
| Fixed product configuration | 92 | 23 | Bind parameter/define guards to elaborated product values; only exact, reviewed unreachable lines may become waiver candidates |
| Legal stimulus / checker review | 32 | 32 | Add legal interface witness and independent checker where reachable |

### 4.4 Toggle — 4,880 OPEN after the two unapproved candidate groups

| Root cause | Bins | Tasks | Closure work |
|---|---:|---:|---|
| CDC / residual state | 130 | 6 | Analyze residual bits against legal 14:8 packing, stalls, and frame tails |
| DPD `sample_count` high bits | 640 | 2 | Reachability is duration-bounded by accepted samples; define product operating/overflow contract before any waiver decision |
| Data value / toggle stimulus | 3,262 | 140 | Group by exact signal/instance/bit/direction and create targeted legal stimulus plus checker |
| DPD saturation counter high bits | 848 | 2 | Repeated saturation path is potentially reachable; stress and/or prove exact per-bit reachability |

The 8,312 static-configuration candidates (8,192 pair-1 + 120 active-tap) plus these 5,282 other bins reconcile to all 13,594 What-if-open bins. The official Raw open count remains 13,955 until approved exclusions and/or new DUT hits are produced.

## 5. Formal, Assertions, Regression, and Tool Limits

### 5.1 Formal

The focused AXI-Lite config-coverage Formal command was attempted once against the current source. VC Formal started, but its `read_file -vcs` frontend invoked VCS, which rejected the current WSL2 kernel (`6.6.87.2-microsoft-standard-WSL2`) as unsupported. No `properties.txt` or `setup.txt` was generated. This is **NOT PROVEN / unable to start**, not a proof failure and not a pass. The direct `vcs -full64 -ID` probe returned the same unsupported-kernel message; setting `VCS_ARCH_OVERRIDE=linux64` did not change the result.

| Obligation | Round 13 status |
|---|---|
| Outstanding counter saturation / underflow | OPEN; historical proof was inconclusive; current reproof unavailable |
| COMMIT → Pending → Apply → ACK → DONE | OPEN; no new proof |
| `q1_tail` assertions on full product path | OPEN; historical legal regression had no attempts; no new witness |
| DPD Identity local arithmetic / output-under-stall | Historical scoped leaf evidence only; full-chain composition OPEN |
| Four stale Formal waiver candidates | OPEN; not re-proven |
| Four interpolation candidates | UNRESOLVED; current-source reachability not established |

Formal attempt command:

```bash
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
VCS_ARCH_OVERRIDE=linux64 VCS_TARGET_ARCH=linux64 \
python3.12 dv/uvm/formal/run_thermo5_axil_cfg_coverage.py \
  --out-dir runs/thermo5_r13_axil_cfg_reproof
```

Evidence hashes: Formal manifest `8183b69dc10393c4821ee7a49f53dde3a186de2fcb5c54dd96d15f06e25f9b25`; console log `10720745143b522fe6183c1defec45364f8e4bcc52798e76ffe74c6504712b3b`. Full local evidence is under ignored `runs/thermo5_r13_axil_cfg_reproof/`.

### 5.2 Regression and mutation

Round 12 records 230 legal tests plus two expected-negative tests, 110 system-random cases, 60 DPD/Gain/Profile cases, 24 Reset cases, 24 COMMIT cases, Python reference 64/64, 436/436 legal functional bins, and six direct SV scoreboard mutation cases. These are inherited Round 12 results, not reruns at Round 13. Round 13 did not produce a new VCS result, mutation result, VDB, or URG report.

| Suite / evidence | Round 13 disposition |
|---|---|
| Generic FIFO / AXI-Lite VCS product regression | NOT RUN; VCS rejects host kernel |
| System Random 110, DPD/Gain/Profile 60, Reset 24, COMMIT 24 | Historical Round 12 PASS only; not rerun |
| Direct SV scoreboard mutation (six injected cases, seven expected checker reports) | Historical Round 12 PASS only; not rerun |
| Python reference model | PASS, 64/64 in this Round 13 workspace |
| Coverage / waiver utility tests | PASS, 41/41 in this Round 13 workspace |
| Round 13 source/VDB/bin audit utility | PASS_AUDIT_GENERATED_NOT_SIGNOFF |
| Round 13 Raw / Adjusted URG | NOT RUN; no new coverage VDBs |
| Round 13 AXI-Lite Formal reproof | NOT PROVEN; VCS reader failure before elaboration |

Round 13 locally reran the Python reference tests and coverage-tool tests:

```bash
PYTHONPATH=dv/uvm/refmodel/python python3.12 -m unittest discover \
  -s dv/uvm/refmodel/python/tests -p 'test_*.py'
python3.12 -m unittest discover -s tools/hw/tests \
  -p 'test_thermo5_tx_*.py'
python3.12 -m py_compile tools/hw/thermo5_tx_round13_audit.py
python3.12 tools/hw/thermo5_tx_round13_audit.py
```

The first two commands passed 64/64 and 41/41 respectively; audit generation reconciled source hashes, all 233 VDBs, 371/369 waiver rows, and all 13,594 exact bins. These checks do not exercise the DUT and do not close code coverage.

The completed command/output logs are retained locally under ignored
`runs/thermo5_r13_local_checks/`:

| Log | SHA-256 |
|---|---|
| `python_reference.log` | `64df1a0a43393351f21c1544733abf4cc97bbcbf8b2042a8bb44b8a582ab4a19` |
| `coverage_tools.log` | `265ea51dd3b1485bada8e7e348a37a8e28c8dc9a8f6caaeb7371be67ad3c8dcf` |
| `audit_compile.log` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` (empty output; exit 0) |
| `audit_generate.log` | `125f9f6a240be045ffb915e01f33f434e89713d4f3b87160909809ea40c781c9` |

The generator reported `PASS_AUDIT_GENERATED_NOT_SIGNOFF`, 97 source inputs,
233 VDBs, 3,040 VDB files, 0 missing/mismatched files, and 0 active
Exclusions.

### 5.3 Stage execution status

| Stage | Status | Evidence / blocker |
|---|---|---|
| 0 — Baseline | PARTIAL PASS | PR/source/config/VDB integrity audited; no Round 13 simulation or URG refresh; PR #42 has no CI/review and remains Draft |
| 1 — Existing 369 candidates | AUDIT PACKAGE BUILT, APPROVAL OPEN | All rows are source/hash/mapping-bound; four current-source proofs could not run; four interpolation candidates unresolved; no approval claimed |
| 2 — Fixed configuration toggles | STATIC CANDIDATES DOCUMENTED, NOT APPROVED | 8,312 exact bins enumerated; no current Formal, independent reviewer, or strict URG Exclusion run |
| 3 — Reachable bins | OPEN | Exact inventory and closure actions delivered; no new RTL-hit evidence because VCS cannot run on this host |
| 4 — Formal/assertion | OPEN | VCS reader rejects WSL2 kernel; previous outstanding-counter inconclusive and `q1_tail` no-attempt status remain |
| 5 — Signoff | NOT SIGNED OFF | No same-round Raw/Adjusted URG, no approved waivers, 13,955 official Raw bins remain open |

## 6. Signoff Decision and Next Actions

**Linux Functional Signoff:** not newly re-established in Round 13; Round 12 functional results remain historical and source/config-bound.

**Linux Code Coverage Signoff:** OPEN. Official Raw/Adjusted remain 524/637 Branch, 657/849 Condition, 3338/3796 Line, 91288/104480 Toggle; official waiver approvals and active exclusions are both zero. What-if numbers must not be labeled signoff numbers.

**Linux Formal Signoff:** OPEN. No Round 13 proof was completed. `INCONCLUSIVE` or tool-start failure is not `PROVEN`.

**FPGA / GT / Physical RF Signoff:** NOT RUN here. Real XPM/GT Wizard, FPGA timing/PPA, board, and physical QAM256 testing are outside this Linux closure record.

Recommended order when a supported VCS host is available:

1. Re-run VCS/URG from a clean checkout at a fixed SHA; produce one manifest for source, defines, test stimuli, and every VDB. Re-run Raw URG before any adjustment.
2. Re-prove the four stale waiver cases and resolve the four interpolation cases with exact non-vacuous reachability evidence.
3. Obtain independent review for any exact waiver, including the 8,312 fixed-configuration toggle candidates. Generate strict `.el` only from approved rows and compare Raw/Adjusted from the same VDB manifest.
4. Close reachable branches first, then targeted conditions/lines/toggles, recording exact URG before/after hits and independent checker results per batch.
5. Complete current-source counter, COMMIT lifecycle, `q1_tail`, and full-chain DPD Identity proof/checker matrix. Keep all unsupported or inconclusive obligations OPEN.
6. Reassess PR #42 for merge only after required regression, URG, and review checks pass.

## 7. Round 13 Evidence Index

| Artifact | Purpose |
|---|---|
| [`thermo5_tx_r13_baseline_manifest.json`](data/thermo5-r13/thermo5_tx_r13_baseline_manifest.json) | Source/config/VDB hashes, PR state, tool status, and Round 12 carry-forward boundary |
| [`thermo5_tx_r13_waiver_candidate_review.csv`](data/thermo5-r13/thermo5_tx_r13_waiver_candidate_review.csv) | Row-level audit of all 369 local candidates |
| [`thermo5_tx_r13_exact_bin_disposition.csv.gz`](data/thermo5-r13/thermo5_tx_r13_exact_bin_disposition.csv.gz) | Exact 13,594-bin What-if-open ledger with status and next action |
| [`thermo5_tx_r13_pair1_exact_bins.csv.gz`](data/thermo5-r13/thermo5_tx_r13_pair1_exact_bins.csv.gz) | Exact 8,192 pair-1 toggle review candidates |
| [`thermo5_tx_r13_active_taps_exact_bins.csv.gz`](data/thermo5-r13/thermo5_tx_r13_active_taps_exact_bins.csv.gz) | Exact 120 active-tap toggle review candidates |
| [`thermo5_tx_round13_audit.py`](../../tools/hw/thermo5_tx_round13_audit.py) | Deterministic source/VDB/waiver and exact-bin audit generator; never emits official Exclusions |
| [Round 12 What-if report](thermo5-tx-round12-waiver-what-if-20261106.md) | Historical same-manifest Raw vs analysis-only What-if URG results |

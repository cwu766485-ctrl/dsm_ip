# Thermo5 TX Round 17 Precise Exclusion What-if Report

**Date:** 2026-11-09 11:41 +08:00
**Review branch:** `codex/thermo5-round17-formal-closure`
**Purpose:** Execute exact, analysis-only URG exclusions against the frozen Round 17 Product VDB set and measure the actual What-if Adjusted report.

## Decision

The same-input URG run applied **8,721 candidates as direct, unique native URG bins**. A further **236 candidate lines had no standalone native object** in URG's template, but were marked excluded as exact associated line effects of mapped native exclusions; the runner compared all 429 excluded `(instance, source line)` pairs against the candidate source-line set and found **zero unexpected and zero missing line bins**. **13 candidates remain OPEN** because their native branch/line mapping is complex or ambiguous.

In total, URG removed **8,957 exact candidate rows** from the report denominators with **zero URG diagnostics** under `-excl_strict`. The resulting report is an **Analysis-only What-if**, not official Adjusted Coverage. The official waiver list still has zero approved waivers and zero official exclusions. Linux DV signoff remains **OPEN**.

## Raw vs What-if Adjusted URG

Both reports were generated from the same 1 Design VDB + 551 Test VDB manifest. `Covered` did not change; the denominator decreased only by the listed exclusion count.

| Metric | Raw covered / total | Raw | Excluded | What-if covered / total | What-if | Remaining uncovered |
|---|---:|---:|---:|---:|---:|---:|
| Branch | 524 / 637 | 82.2606% | 98 | 524 / 539 | 97.2171% | 15 |
| Condition | 657 / 849 | 77.3852% | 108 | 657 / 741 | 88.6640% | 84 |
| Line | 3,338 / 3,796 | 87.9347% | 429 | 3,338 / 3,367 | 99.1387% | 29 |
| Toggle | 92,072 / 104,480 | 88.1240% | 8,322 | 92,072 / 96,158 | 95.7507% | 4,086 |
| FSM states | 13 / 13 | 100% | 0 | 13 / 13 | 100% | 0 |
| FSM transitions | 22 / 22 | 100% | 0 | 22 / 22 | 100% | 0 |

There are **4,214 remaining code bins** across Branch, Condition, Line and Toggle (15 + 84 + 29 + 4,086). This is an actual URG report result, not a projected denominator calculation. The exact remaining-bin ledger is [round17_exact_whatif_remaining_bins.csv.gz](data/thermo5-r17/analysis_only/round17_exact_whatif_remaining_bins.csv.gz).

## Candidate mapping and execution

| Batch | Candidates | Direct native mapping | Exact associated line effects | Removed from report | Still OPEN | URG diagnostics |
|---|---:|---:|---:|---:|---:|---:|
| A — DPD Pair-1 Toggle | 8,192 | 8,192 | 0 | 8,192 | 0 | 0 |
| B — EF2 fixed parameters | 436 | 284 | 152 | 436 | 0 | 0 |
| C — DPD one-tap history | 176 | 96 | 80 | 176 | 0 | 0 |
| D — CDC residual | 137 | 132 | 3 | 135 | 2 | 0 |
| E — Other product parameters | 29 | 17 | 1 | 18 | 11 | 0 |
| **Total** | **8,970** | **8,721** | **236** | **8,957** | **13** | **0** |

The 236 associated effects are line bins that URG did not expose as a standalone native template object. They were **not** written as broad or wildcard `.el` entries. The batch directives targeted direct native bins; after each run, the fail-closed runner checked the actual URG excluded line set against the candidate `(instance, source line)` set. All 429 excluded line bins matched exactly; no out-of-candidate line was excluded. The 13 unresolved bins were left out of the `.el` files.

### Batch metric deltas

| Batch | Branch excluded | Condition excluded | Line excluded | Toggle excluded |
|---|---:|---:|---:|---:|
| A — DPD Pair-1 Toggle | 0 | 0 | 0 | 8,192 |
| B — EF2 fixed parameters | 88 | 108 | 240 | 0 |
| C — DPD one-tap history | 0 | 0 | 176 | 0 |
| D — CDC residual | 0 | 0 | 5 | 130 |
| E — Other product parameters | 10 | 0 | 8 | 0 |
| **Combined** | **98** | **108** | **429** | **8,322** |

All five batch URG runs and the combined run used `-excl_strict`; each reported zero warning/error/reject/checksum/mapping diagnostics. The URG process completed successfully. The run is fail-closed: it validates the manifest, source/compile binding, VDB trees, native `.el` hashes, metric denominator deltas, excluded line identities, and unchanged FSM/assertion metrics.

## Exact candidate bins still OPEN

These 13 semantic IDs are retained in the execution ledger with `OPEN_NATIVE_MAPPING`. None was forced into an exclusion file.

| Record / semantic ID | Metric | Instance | Source location / native bin | Mapping issue | Existing waiver ID |
|---|---|---|---|---|---|
| `TXR-09cfe3a3ae45a29d7aff` / `TXB-0260d31bb5bee4f1a4c6` | Branch | `thermo5_sku_uvm_tb.dut.u_cdc` | `dsm_axis14_to_core8_cdc.sv:141`; `122:0/-/1/-/-/default/-/-/-/-/-/-` | Complex branch bin | `W-98a39b6429bbed7c29ad` |
| `TXR-158f98630956bf8f38d1` / `TXB-e8358208ee175c15bb7d` | Branch | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1` | `dsm_interp_x2_centered_cubic_vector.sv:210`; `182:0/1/0/-/-/-/-/-/-/-/-/-/-` | Complex branch bin | `W-1e23fb57b68ef73f6869` |
| `TXR-2e110a6a42b9507f4f4e` / `TXB-ef2fb170941b345476dc` | Branch | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:129`; `129:1/-` | Complex branch bin | `W-fca77c64e5465f089f37` |
| `TXR-4ca9572515cfc8e4f17c` / `TXB-7ea7a7506f13f31ca4a9` | Branch | `thermo5_sku_uvm_tb.dut.u_cdc` | `dsm_axis14_to_core8_cdc.sv:215`; `122:0/-/1/-/-/0 2 4 6/1/-/1/1/-/-` | Complex branch bin | `W-a9fc97093bdddfb7f5aa` |
| `TXR-5d66742ac5ee92698d70` / `TXB-91d5b4a40917c980da7a` | Branch | `thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain` | `dsm_frame_gain_vector.sv:97`; `71:0/1/0/-/-/-/-/-/-/-/-` | Complex branch bin | `W-48945012f702b0a23803` |
| `TXR-69a63074fc234cce76ba` / `TXB-39a0a549d32bc9ef1e01` | Branch | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1` | `dsm_interp_x2_centered_cubic_vector.sv:229`; `182:0/0/-/-/-/-/1/-/-/-/-/-/-` | Complex branch bin | `W-ccf37502b42fd61c4cd7` |
| `TXR-7e241a7b79141319ca0d` / `TXB-484e84e9cd94e6ec3279` | Line | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1` | `dsm_interp_x2_centered_cubic_vector.sv:294`; `294:0` | Ambiguous native line mapping | None |
| `TXR-951f511a4341e180d9fe` / `TXB-f79886c4544d0700fcd7` | Line | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:295`; `295:0` | Ambiguous native line mapping | None |
| `TXR-9ae5aed11efe319e4f3e` / `TXB-32b923f55e34401249a8` | Branch | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:210`; `182:0/1/0/-/-/-/-/-/-/-/-/-/-` | Complex branch bin | `W-1129900cf23695da581a` |
| `TXR-adeaefe4f47bc818c54c` / `TXB-603e97cceda8c0d4d0ed` | Branch | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:217`; `182:0/0/-/1/-/-/-/-/-/-/-/-/-` | Complex branch bin | `W-e8e68602c739b86a80b5` |
| `TXR-b6aed066c642859ac818` / `TXB-c79cdf2b9f5b4620688e` | Branch | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:223`; `182:0/0/-/-/1/1/-/-/-/-/-/-/-` | Complex branch bin | `W-f83f4a14b37b232df778` |
| `TXR-ce96d871e70173a45806` / `TXB-c4ef368c3540489d22a1` | Line | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1` | `dsm_interp_x2_centered_cubic_vector.sv:295`; `295:0` | Ambiguous native line mapping | None |
| `TXR-e3900d3466ef41bc33c3` / `TXB-7c41e79c69d1cad81d2f` | Line | `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:294`; `294:0` | Ambiguous native line mapping | None |

The 9 complex branch records and 4 ambiguous lines account for all 13 remaining candidate mappings. The exact native mapping and execution statuses for every one of the 8,970 rows are in [round17_candidate_exclusion_execution.csv.gz](data/thermo5-r17/analysis_only/round17_candidate_exclusion_execution.csv.gz).

## Official waiver reconciliation

The official CSV still contains 371 unique IDs:

- 2 are `RESOLVED_BY_RAW_HIT` and need no exclusion.
- 367 pending official IDs have a unique association to this 8,970-candidate set.
- 2 pending official IDs are outside this candidate set and remain open: `W-9010fccd0889b46ea284` and `W-32b5745433f0ff75d5c2`.
- Independent reviewer approvals: **0**.
- Official active exclusions: **0**.

The per-ID reconciliation is [round17_official_waiver_reconciliation.csv](data/thermo5-r17/analysis_only/round17_official_waiver_reconciliation.csv). No official waiver status was changed and no official `.el` was generated. The five `.el` files below are Analysis-only inputs and must not be used as signoff exclusions:

- [a_dpd_pair1_analysis_only.el](data/thermo5-r17/analysis_only/a_dpd_pair1_analysis_only.el)
- [b_ef2_fixed_parameters_analysis_only.el](data/thermo5-r17/analysis_only/b_ef2_fixed_parameters_analysis_only.el)
- [c_dpd_tap_history_analysis_only.el](data/thermo5-r17/analysis_only/c_dpd_tap_history_analysis_only.el)
- [d_cdc_residual_analysis_only.el](data/thermo5-r17/analysis_only/d_cdc_residual_analysis_only.el)
- [e_other_parameters_analysis_only.el](data/thermo5-r17/analysis_only/e_other_parameters_analysis_only.el)

## Source, tool and reproducibility binding

- Product configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, STATE_BITS=20; 32 chronological lanes; DPD_MAX_TAPS=1, Identity reset image; AXI-Lite; Generic FIFO.
- VDB source checkout HEAD: `17b88280e98096469a57ba51df5b17d53194911a`.
- Product source SHA recorded by the compile manifest: `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`.
- Product RTL aggregate SHA-256: `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`.
- Compile fingerprint SHA-256: `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`.
- Compile-parent source hashes checked: 97/97.
- VDBs: 1 Design + 551 Test. All 552 VDB tree fingerprints matched before and after execution (0 mismatch).
- Canonical VDB manifest SHA-256: `e0f306b30b206df08b6c37991c940d855e4e03d0659640d38c066b4b6897b509`.
- Compressed VDB manifest: [thermo5_tx_r17_input_vdb_manifest.json.gz](data/thermo5-r17/analysis_only/thermo5_tx_r17_input_vdb_manifest.json.gz), SHA-256 `60c15a64cba00a0b243af7c5142d0a6153d61299155429cf9c65678dc67fdbae`.
- URG: V-2023.12-SP1, 64-bit (`-full64`).
- Native mapping tool SHA-256: `b3978fe31d5aaab2f72b4f9c93382f2367b2dcfda4e6fe32149a73be8effb465`; URG execution runner SHA-256: `c58ff4bdb858c47526cb5c614e0f555d68d9cdf411f4dac7c0554fb508cafd7b`.
- Full local execution manifest: `runs/thermo5_r17_native_analysis_20261109_final_release/analysis_execution_manifest.json`, SHA-256 `e30c0a51e9d04631129ef6cde1c15ef28492f22b255c40b0f76d976eca97a20b`.
- Raw URG log SHA-256: `9871f4b268481b1bd5cfd8f0705d4b178cb7ab64d62127e98c4dcd6d4e2282d4`.
- Combined What-if URG log SHA-256: `d04741cb10192f963646ebf29cda1a7fe4125ea84fa9ca1978d1a44a84d77890`.
- Five batch log SHA-256 values: A `284fdc28cb7c91a397416cc89585ece6f58f625e5b4a0e237190d1d037c9c806`; B `db7da5e35fda5c5c480badb76a3f8eef28a96633a3a7ce190412a7a67a1d704c`; C `25cb495956e8cbf3d023f1944c0e2280bf5fb1bcae4a622f9113d4c0fe2fe2f8`; D `1fa6748427a31c8a5650f6c65ea272af47e94481b26d51639b5e919766097e4e`; E `0d116c5aaae0f4a3a11be29e56eb6a75fe4cb185f3b48f47f1b0da6623bda8ff`.

The VDB manifest and portable evidence JSON are committed. The full simulator databases and raw tool logs remain under the ignored `runs/` tree per repository policy; their paths, hashes, and exact VDB inventory are recorded in the evidence JSON. Re-run the frozen execution with:

```bash
python3.12 tools/hw/thermo5_tx_run_native_analysis_exclusions.py \
  --out-dir runs/thermo5_r17_native_analysis_20261109_final_release
```

The default inputs are bound by the checked VDB, run, compile, native-mapping, candidate, review, and official-waiver manifests. The runner refuses an existing evidence output directory and fails closed on a manifest mismatch, URG diagnostic, denominator mismatch, changed covered-bin count, unexpected excluded line or altered FSM/assertion coverage. The emitted URG command form is `urg1 -full64 -dir <Design VDB> <551 Test VDBs> -elfilelist <analysis_only filelist> -excl_strict -format both`.

## Artifacts and checks

- [Portable execution evidence JSON](data/thermo5-r17/analysis_only/thermo5_tx_r17_analysis_execution_evidence.json), SHA-256 `72a2588cc51d56596433872c7d3850d824643617094d7a4e0fe47a626b51ba5e`: binds all report counts, source/compile/VDB hashes, log hashes, and `OPEN_NOT_OFFICIAL_SIGNOFF` status.
- [Native mapping manifest](data/thermo5-r17/analysis_only/round17_candidate_native_mapping_manifest.json), SHA-256 `9d7d483a5d99c640c5487414457d694c7e92d52cce96e2274966acbb2f456475`: candidate count, exact/direct and unresolved mapping counts, source and native-template hashes.
- Candidate execution ledger SHA-256: `f3eff6da3fe1bffa538ade380065904ccd0c484264194061b1f2b55a1ff9a051`.
- What-if remaining-bin ledger SHA-256: `439afbeaea3c45ea367afac7833a8b7103ecb2b653e66d686376a4c9858f4`.
- Candidate mapping ledger SHA-256: `393eacac224826d73958eeffb05ae7476d392d90f181962f947c118143a0d5a6`.

The mapping command was `python3.12 tools/hw/thermo5_tx_native_exclusion.py --template-dir runs/thermo5_r17_precise_exclusion_20261109_native_template_retry1`. The five `.el` files were regenerated without trailing blank lines, then the complete Raw + five batch + combined strict URG sequence was rerun on the same manifest. Checks for this report commit: Python 3.12 syntax compilation of both tools; artifact hash/count and candidate disposition checks against the execution manifest; `git diff --check`. No RTL or product configuration changed. No new simulation/Formal claim is made by this URG analysis.

## Closure decision and next action

**Analysis-only What-if URG: PASS** for same-input execution, exact denominator deltas, strict mode, and zero diagnostics. **Official waiver/signoff: OPEN.** The 8,957 removed candidate rows (including 236 associated line effects) still require independent review before any can become official exclusions; 13 candidate bins remain unmapped; 4,214 exact bins remain for reachability/test closure. Do not call this 100% coverage or Final Linux DV Signoff.

Next, submit the 8,957 technically mapped candidates and associated exact URG effects for independent review, investigate the 13 native mapping gaps without broadening exclusions, and then target the actual 4,214 remaining bins. Preserve the Raw report and current VDB manifest as the comparison baseline.

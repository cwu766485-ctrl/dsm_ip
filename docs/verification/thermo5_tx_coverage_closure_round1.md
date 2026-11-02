# Thermo5 TX Coverage Closure — Round 1

**Status: PARTIAL, `RAW_100_OPEN`.** This round adds an audited legal outstanding-counter stress test, a separate mailbox negative test result, an exact condition-bin audit, and a fail-closed waiver pipeline. It does not close the two counter guard bins or the 131 OPEN condition bins. No waiver or exclusion is approved.

## Product and evidence identity

- Baseline commit: `88c9682501fd60bb14e6ea9b1f569f8eeb97e708`.
- Product source SHA: `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`.
- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; DPD_MAX_TAPS=1 Identity DPD; Generic FIFO; AXI-Lite TX parent.
- VCS: Synopsys V-2023.12-SP1. URG reports are produced from one design VDB and the same 27 test VDBs for Raw and Adjusted.
- Product compile manifest: `data/thermo5-tx-product-compile-manifest-round1.json`, SHA-256 `74e961a4808c808b63ad4f0b51f36cc3be81731b4f257b9a5ab908e9b28c71fa`.
- VDB input manifest SHA-256: `8df67cf55bec13d314452e6e5567f59d22538b0d5a851ec59f5b6df214a293fc`.
- Dual URG report manifest SHA-256: `b76092eff6e1fad45b83b015cdf8da1067f97488a0f422b433b996a324fa886a`.

The VDBs and raw tool logs remain in the ignored local `runs/thermo5_coverage_closure_round1/` directory. The exact VDB inventory and report manifests, Raw/Adjusted summaries, assertion summary, waiver audit and gate result are committed as evidence snapshots under `data/thermo5-tx-round1-*.json`; their SHA-256 values are indexed in `data/thermo5-tx-round1-evidence.json`. Raw and Adjusted used identical inputs. Their VDB tree hashes matched before and after URG.

## Branch dispositions

Exact record IDs, paths, legal/negative classification, checker evidence and remaining disposition are in `data/thermo5-tx-round1-branch-dispositions.csv`.

| Target | Result | Product / legality | Disposition |
|---|---|---|---|
| `thermo5_dpd_axi_lite_cfg.sv:364`, `TXB-dbf3b013d97e6a45fd92` | Exact error observed in the dedicated mailbox-fault negative run; Raw branch is hit | The check is enclosed by `ifndef SYNTHESIS`; the taken arm is a simulation-only fault defense, not synthesized product logic | Accounted as `HIT_EXPECTED_NEGATIVE_ONLY`; do not count as legal assertion pass or apply a waiver |
| `tid32_thermo5_axi_lite_axis_frontend_tx.sv:203`, `TXB-e99262dd92665c3b9ea8` | Legal stress peaked at 28; saturation guard was not taken; corresponding Raw branch remains uncovered | Synthesizable product logic; maximum-count arm is a defensive state | `OPEN`; existing VC Formal assertion and target cover are inconclusive |
| `tid32_thermo5_axi_lite_axis_frontend_tx.sv:204`, `TXB-c16debdf7d9cbab220ac` | Legal test observed no underflow; corresponding Raw branch remains uncovered | Synthesizable product logic; zero-count decrement arm is a defensive state | `OPEN`; existing VC Formal assertion and target cover are inconclusive |

The legal test used the public source, AXI-Lite and PA interfaces; it checked all 112 output words against the bit-true scoreboard, counted 112 core accepts and 112 output accepts, and observed source/PA stalls. It did not force the counter. The already captured VC Formal run has zero environment assumptions and positive source/core/output activity covers, but reports the saturation property/cover `INCONCLUSIVE` at depths 142/141 and the underflow property/cover `INCONCLUSIVE` at depths 102/103. The saved Formal manifest's full product SHA is `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b`, older than this round's `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`; the target counter RTL file hash is unchanged, but this Formal run is context only. It is not a reachability proof, so both bins stay OPEN.

## Condition closure audit

`data/thermo5-tx-round1-condition-closure.csv` is an exact join of the 71 OPEN condition tasks and 131 raw/semantic Bin IDs against the current Raw URG HTML. The audit checks each current URG instance, source line, condition class and operand tuple. All 131 still report `Not Covered`:

| Root-cause group | OPEN task groups | Exact OPEN bins | Current treatment |
|---|---:|---:|---|
| Reset release / state hold | 67 | 127 | Legal reset, enable, stall and drain traffic is exercised; exact operand bins remain OPEN |
| Interpolator empty / blocked | 4 | 4 | Empty/backpressure behavior is exercised; exact `can_emit_head` operand bins remain OPEN |
| **Total** | **71** | **131** | No bin closed; no waiver or exclusion |

Raw Condition remains `610/849`; delta from the stated baseline is zero. The directed test passing is not treated as evidence that a different exact URG operand bin was hit. Additional seed sweeps are not justified until the four interpolator predicates and the reset/state-hold roots have a more specific stimulus hypothesis.

## Coverage and waiver results

| Metric | Raw | Adjusted | Delta from stated baseline |
|---|---:|---:|---:|
| Branch | 525/637 (82.4176%) | 525/637 (82.4176%) | +1 hit |
| Condition | 610/849 (71.8492%) | 610/849 (71.8492%) | 0 |
| Line | 3351/3796 (88.2771%) | 3351/3796 (88.2771%) | +1 hit |
| Toggle | 84343/104480 (80.7265%) | 84343/104480 (80.7265%) | +756 hits |
| FSM states / transitions | 13/13; 22/22 | 13/13; 22/22 | 0 |
| Legal applicable Functional Coverage | 210/210 (100%) | 210/210 (100%) | 0 |

The one additional branch hit is present in the separate expected-negative mailbox fault run. It is not a legal-path closure. The one line and 756 toggle-bin changes are in the Raw VDB union; no RTL behavior or coverage denominator changed.

The waiver pipeline now validates exact raw/semantic Bin IDs, source file/line SHA, product source/configuration fingerprint, review approval, and hashed proof evidence. It rejects inconclusive or vacuous Formal evidence, stale source/configuration, wildcard URG entries and unreviewed candidates. It writes active `.el` entries only for approved rows and runs Raw/Adjusted from one identical VDB list. Current audit: **371 pending candidates, 0 approved, 0 rejected, 0 active Exclusions**. The generated `thermo5_tx_main.el` contains no active directives, so Raw equals Adjusted.

The fail-closed waiver audit was regenerated with:

```bash
python3.12 tools/hw/thermo5_tx_waiver_pipeline.py \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --gap-ledger docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-gap-ledger.csv.gz \
  --compile-manifest docs/verification/data/thermo5-tx-product-compile-manifest-round1.json \
  --repo-root . \
  --el-output dv/uvm/sim/thermo5_tx_main.el \
  --audit-output runs/thermo5_coverage_closure_round1/waiver_audit.json
```

## Assertion audit

The legal-only assertion report has 13 DUT assertion successes, zero failures, two uncovered records and two records without attempts. The two uncovered / no-attempt records name the same defensive interpolator property at each stage:

- `thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1.unnamed$$_1`
- `thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1`

Both originate at `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310` and reject same-frame data after a frame-end vector. This is an illegal frame/protocol defense. The malformed-frame Negative Regression reaches the first-stage assertion and its independent checker observes the expected RTL error and public-reset recovery; the second-stage property remains without attempts. The legal and negative results are reported separately.

The Raw union assertion inventory contains two expected failures from the negative tests (CDC frame alignment and first-stage malformed frame); do not report the union as a legal assertion PASS. The bound outstanding SVA is testbench verification logic, outside the DUT code-coverage hierarchy. In the legal stress it recorded zero failures for both guard-not-taken properties (348 attempts each, 327 successes each).

## Reproduction commands and evidence

VCS compile command is captured in the product compile manifest. The new legal stress and the two negative tests were run on that compile:

```bash
runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/simv +UVM_TESTNAME=thermo5_sku_axil_outstanding_bounds_test +VEC_DIR=runs/thermo5_coverage_closure_round1/vectors112 +ntb_random_seed=610902 -cm line+cond+fsm+tgl+branch+assert -cm_dir runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/cov_thermo5_sku_axil_outstanding_bounds_test_seed610902.vdb +CORE_WORDS=112 +PACKET_BEATS=32 -l runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/thermo5_sku_axil_outstanding_bounds_test_seed610902.log
runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/simv +UVM_TESTNAME=thermo5_sku_axil_illegal_frame_test +VEC_DIR=runs/thermo5_ef2_qualification/vectors56 +ntb_random_seed=420102 -cm line+cond+fsm+tgl+branch+assert -cm_dir runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/cov_axil_illegal_frame_seed420102.vdb -l runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/axil_illegal_frame_seed420102.log
runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/simv +UVM_TESTNAME=thermo5_sku_axil_mailbox_fault_test +VEC_DIR=runs/thermo5_ef2_qualification/vectors56 +ntb_random_seed=420103 -cm line+cond+fsm+tgl+branch+assert -cm_dir runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/cov_axil_mailbox_fault_seed420103.vdb -l runs/thermo5_coverage_closure_round1/vcs_outstanding_v3/axil_mailbox_fault_seed420103.log
```

The expected negative logs contain their named RTL assertion/error, independent `[NEGATIVE]` checker marker, `[SKU_PASS]` marker, and zero UVM warnings/errors/fatals. Evidence SHA-256:

| Artifact | SHA-256 |
|---|---|
| VCS compile log `vcs_outstanding_v3/compile.log` | `cc2dc234b819b93a49fc92e0a8c62b032d46bc178c794881cddd402d21f40cf8` |
| Legal outstanding test log | `8c0bf383f41176b604cf046c8521aa2f0cdb3e2aaf45aaa3b37df58fdbd5026e` |
| Negative malformed-frame log | `de9a29b2ad1fcd7edd6176eb93ebe6ef2de97b0e7ebba3ba3596c2b46376b421` |
| Negative mailbox log | `6df2bc06b9558c2f37a3d4bac20b79edaa09b1e51cce1e03fe3d64cf0c92d90d` |
| Raw URG log | `ef03edf6843f89a61957ffdceab62a598155e4941cb364b0a7cb893683867247` |
| Adjusted URG log | `10290e98d840b2c2f0f9e317deacd12722da9946118752acc334798c867254bd` |
| Assertion report manifest | `3b61c0e9599f24a87151d38260ec9dc9fab41a3a2da8662c0d55b99c4db3c72f` |

The VDB report command is recorded verbatim in `runs/thermo5_coverage_closure_round1/urg_dual_round1_v6/report_manifest.json`; its inputs are hashed in the sibling `vdb_manifest.json`. The fail-closed coverage gate output is `runs/thermo5_coverage_closure_round1/coverage_gate_round1_final.json` and returns `RAW_100_OPEN`. The gate invocation was:

Tracked byte-for-byte report snapshots are `data/thermo5-tx-round1-vdb-manifest.json`, `data/thermo5-tx-round1-urg-report-manifest.json`, `data/thermo5-tx-round1-raw-coverage-summary.json`, `data/thermo5-tx-round1-adjusted-coverage-summary.json`, `data/thermo5-tx-round1-legal-assertion-summary.json`, `data/thermo5-tx-round1-waiver-audit.json`, and `data/thermo5-tx-round1-coverage-gate.json`. The full VCS compile and test logs remain local; their exact commands and SHA-256 values are listed above. The `vdb_manifest.json` records VDB file hashes, but the VDB payload itself is intentionally not committed.

```bash
python3.12 tools/hw/thermo5_tx_coverage_gate.py \
  --raw-summary runs/thermo5_coverage_closure_round1/urg_dual_round1_v6/raw_inventory/summary.json \
  --assertion-summary runs/thermo5_coverage_closure_round1/assertions_legal_v3/inventory/summary.json \
  --groups-html runs/thermo5_coverage_closure_round1/urg_dual_round1_v6/raw_urg/groups.html \
  --functional-bin-detail docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-functional-bin-detail.csv \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --el-file dv/uvm/sim/thermo5_tx_main.el \
  --waiver-audit runs/thermo5_coverage_closure_round1/waiver_audit.json \
  --adjusted-summary runs/thermo5_coverage_closure_round1/urg_dual_round1_v6/adjusted_inventory/summary.json \
  --adjusted-report-manifest runs/thermo5_coverage_closure_round1/urg_dual_round1_v6/report_manifest.json \
  --source-manifest docs/verification/data/thermo5-tx-product-compile-manifest-round1.json \
  --repo-root . \
  --output runs/thermo5_coverage_closure_round1/coverage_gate_round1_final.json
```

Python checks:

```bash
python3.12 -m unittest discover -s tools/hw/tests -v
python3.12 -m compileall -q tools/hw
python3.12 tools/hw/thermo5_tx_round1_condition_audit.py \
  --gap-ledger docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-gap-ledger.csv.gz \
  --task-csv docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-closure-tasks.csv \
  --raw-urg runs/thermo5_coverage_closure_round1/urg_dual_round1_v6/raw_urg \
  --output docs/verification/data/thermo5-tx-round1-condition-closure.csv
```

Result: 31/31 Python hardware utility tests passed; `compileall` passed; condition join passed with 71 tasks / 131 exact current URG misses. VCS compile was also attempted again on 2026-11-01, but the VCS license checkout queued and could not be acquired; that attempt is not used as PASS evidence. No new counter-guard negative test was compiled or added.

## Remaining OPEN and next action

- Two synthesizable outstanding counter guard Branch bins remain OPEN; old Formal results are inconclusive.
- All 71 Condition task groups / 131 exact bins remain OPEN.
- 112 Raw Branch, 239 Raw Condition, 445 Raw Line and 20,137 Raw Toggle bins remain uncovered; no exclusion is active.
- Functional coverage is 210/210 legal applicable bins. Legal DUT assertions have zero unexpected failures; the two defensive interpolator assertions remain uncovered / without attempts.
- Real XPM, GT Wizard, FPGA PPA and physical RF/QAM validation are outside this Linux round.

Next Linux work should resume the two counter-guard root causes when a VCS/VC Formal license is available, using separate fault-injection Negative Tests only if they can be compiled and checked; then target exact condition-bin stimulus. Do not run broad seed sweeps without a new root-cause hypothesis. Line/Toggle specialization remains for a later round.

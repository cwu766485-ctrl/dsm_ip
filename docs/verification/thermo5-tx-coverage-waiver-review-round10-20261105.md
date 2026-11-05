# Thermo5 TX Coverage and Waiver Review — Round 10

**Date:** 2026-11-05 17:30 SGT
**Working branch / HEAD:** `codex/thermo5-final-integration` / `6bef1cbd66a55bbec5601a5d36fa4c86f85bfd26` (dirty, uncommitted worktree)
**Product RTL source SHA:** `1236d49c72360aa62e316aea147528d93a1b3705`
**Product:** Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, DPD_MAX_TAPS=1 with Identity reset image, AXI-Lite, Generic FIFO.

## Result

URG Raw coverage was regenerated from the current retained product VDB inventory. An analysis-only Adjusted report was then generated from the exact same VDB inputs with 98 narrowly mapped Condition/Branch candidates. It completed without URG exclusion warnings. This is a coverage sensitivity report, **not an approved waiver signoff**.

| Project RTL metric | Raw | Analysis-only Adjusted | Change |
|---|---:|---:|---:|
| Line | 3317/3796 = 87.38% | 3317/3796 = 87.38% | unchanged |
| Condition | 631/849 = 74.32% | 631/765 = 82.48% | 84 exclusions |
| Branch | 503/637 = 78.96% | 503/623 = 80.74% | 14 exclusions |
| Toggle | 82308/104480 = 78.78% | 82308/104480 = 78.78% | unchanged |
| FSM states | 13/13 = 100% | 13/13 = 100% | unchanged |
| FSM transitions | 15/22 = 68.18% | 15/22 = 68.18% | unchanged |

The URG whole-design dashboard score is 77.76% Raw and 79.42% Adjusted. This is URG's aggregate across its enabled coverage metrics, not a replacement for the per-metric project-RTL results above. The DUT assertion inventory is unchanged: 13 successes, 2 uncovered properties, 2 without attempts, and 0 failures.

The report consumed 195 unique test-VDB paths plus one design VDB; the URG dashboard records 193 tests. This accounting discrepancy is retained as an open evidence-quality item. The VDBs are from multiple existing campaigns; VCS simulations were not rerun for this coverage refresh, so this is not a newly compiled single-source regression package.

## Waiver list judgment

The official `docs/verification/thermo5_tx_waivers.csv` remains unchanged: **371 PENDING, 0 approved, 0 active official exclusions**. I did not enter a reviewer identity or approval reference. The per-row review ledger is `docs/verification/data/thermo5-tx-waiver-review-round10-20261105.csv`.

| Review disposition | Count | Assessment |
|---|---:|---|
| Recommend for independent review and provisional Adjusted analysis | 98 | 84 exact Condition bins supported by fixed product configuration; 13 exact configuration Branch bins; 1 exact Branch bin with current non-vacuous Formal evidence. URG applied these 98 entries without warnings. |
| Keep OPEN — EF2 Branch checksum mismatch | 88 | URG emitted 24 `UCAPI-EL-MCM` warnings when these EF2 Branch exclusions were attempted. None were included in the final analysis-only `.el`. |
| Keep OPEN — URG Line basic-block granularity | 37 | A separate Line-only probe with these 37 directives reduced the Line denominator by 153. The effect is broader than the 37 candidate ledger rows, so none were included. |
| Keep OPEN — no unique native URG mapping | 141 | 116 Line, 24 Condition, and 1 Branch candidate did not map one-to-one to a native URG exclusion entry. |
| Keep OPEN — stale Formal source context | 4 | The interpolation proof scripts/harness have changed since the recorded evidence. |
| Keep OPEN — CDC parent mapping review | 3 | Formal evidence exists, but the exact parent-level Bin mapping remains unresolved. |

The 98 entries in the analysis-only `.el` are **not approvals**. Official status remains 371 PENDING and the authoritative Raw gate remains `RAW_100_OPEN`. No Raw denominator, VDB, or official waiver row was edited. The 37 Line and 88 EF2 Branch findings are intentionally not used to improve the final Adjusted percentages.

## Reproduction and evidence

- Raw URG report: `runs/thermo5_tx_closure_current/current_source_20261104/waiver_round10_review/round10_product_raw_with_exclusion_dump/`
- Raw project-RTL inventory: `.../round10_product_raw_inventory/`
- Analysis-only exclusion file: `.../provisional_candidate/provisional_candidates.el`
- Adjusted URG report: `.../provisional_candidate/adjusted_urg/`
- Adjusted inventory: `.../provisional_candidate/adjusted_inventory/`
- Line-scope probe: `.../line_scope_probe/`
- Input manifest and commands/logs: `.../round10_vdb_input_manifest.json`, `.../provisional_candidate/adjusted_urg_command.json`, `.../provisional_candidate/adjusted_urg.log`
- Machine-readable summary and hashes: `docs/verification/data/thermo5-tx-coverage-waiver-review-round10-20261105.json`

Commands executed:

```bash
bash -ilc 'cd /home/ray/workspace/dsm_ip && python3.12 runs/thermo5_tx_closure_current/current_source_20261104/waiver_round10_review/run_exact_metric_dump.py'
python3.12 runs/thermo5_tx_closure_current/current_source_20261104/waiver_round10_review/provisional_candidate/build_provisional_candidate.py
bash -ilc 'cd /home/ray/workspace/dsm_ip && python3.12 runs/thermo5_tx_closure_current/current_source_20261104/waiver_round10_review/provisional_candidate/run_adjusted_urg.py'
python3.12 tools/hw/thermo5_coverage_denominator.py runs/thermo5_tx_closure_current/current_source_20261104/waiver_round10_review/provisional_candidate/adjusted_urg runs/thermo5_tx_closure_current/current_source_20261104/waiver_round10_review/provisional_candidate/adjusted_inventory
```

URG version: V-2023.12-SP1. The analysis-only `.el` SHA-256 is `7d326287793538749045fe8e5570802e57f50b644475e0d14dbcd43819873aa2`; the adjusted dashboard SHA-256 is `c597d6f72b25593444535a09bd3e0e6d472f50fa8071a427c5de14b80682e9c6`. The machine-readable evidence JSON records the remaining input, report, and source hashes.

## Remaining closure

- Keep `RAW_100_OPEN`; 273 waiver-candidate rows remain OPEN, and all 371 official waiver rows still require independent review/approval.
- Reconcile the 195 VDB input paths with URG's 193-test count and establish a single-source clean VDB package before final signoff.
- Continue exact reachable-bin closure and the outstanding-counter / DPD Identity Formal work; no coverage result here resolves those proof obligations.
- XPM, GT Wizard, FPGA timing/PPA, and physical RF/QAM256 validation remain outside this Linux URG run and are NOT_SIGNED_OFF.

No RTL, frozen algorithm, RX, or AI-DPD changes were made in this coverage review.

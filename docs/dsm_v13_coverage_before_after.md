# DSM V1.3 Coverage Before / After — Round 1 to Round 2

Date: 2026-11-25

Round 1 percentages come from `docs/verification/data/dsm-v13-round1/hardware_code_coverage.csv` and `functional_coverage.csv`. Round 2 is a fresh VCS/URG run at the candidate source snapshot. Raw equals adjusted for both rounds; no approved waiver/exclusion was applied. Percentages are reported by configuration and scope; MASH Product is a new DUT boundary and is not directly comparable to the old scalar wrapper experiment.

## DUT code coverage

| Same-scope configuration | Metric | Round 1 raw | Round 2 raw / adjusted | Change |
|---|---|---:|---:|---:|
| EF1 Product | Line | 88.26% | 88.26% | +0.00 pp |
| EF1 Product | Branch | 75.00% | 75.00% | +0.00 pp |
| EF1 Product | Condition | 77.06% | 77.06% | +0.00 pp |
| EF1 Product | Toggle | 83.90% | 83.90% | +0.00 pp |
| EF1 Product | FSM | 100.00% | 100.00% | +0.00 pp |
| EF1 AXI-Lite | Line | 88.20% | 88.35% | +0.15 pp |
| EF1 AXI-Lite | Branch | 73.94% | 74.86% | +0.92 pp |
| EF1 AXI-Lite | Condition | 76.11% | 80.03% | +3.92 pp |
| EF1 AXI-Lite | Toggle | 79.20% | 79.89% | +0.69 pp |
| EF1 AXI-Lite | FSM | 68.18% | 68.18% | +0.00 pp |
| EF2 Product | Line | 82.59% | 82.59% | +0.00 pp |
| EF2 Product | Branch | 62.22% | 62.22% | +0.00 pp |
| EF2 Product | Condition | 67.51% | 67.51% | +0.00 pp |
| EF2 Product | Toggle | 81.44% | 81.44% | +0.00 pp |
| EF2 Product | FSM | 100.00% | 100.00% | +0.00 pp |
| EF2 AXI-Lite | Line | 82.88% | 83.43% | +0.55 pp |
| EF2 AXI-Lite | Branch | 63.42% | 65.46% | +2.04 pp |
| EF2 AXI-Lite | Condition | 66.43% | 69.85% | +3.42 pp |
| EF2 AXI-Lite | Toggle | 76.87% | 77.58% | +0.71 pp |
| EF2 AXI-Lite | FSM | 68.18% | 68.18% | +0.00 pp |
| MASH wrapper/core | Line | 90.16% | 90.16% | +0.00 pp |
| MASH wrapper/core | Branch | 71.43% | 71.43% | +0.00 pp |
| MASH wrapper/core | Condition | 100.00% | 100.00% | +0.00 pp |
| MASH wrapper/core | Toggle | 98.36% | 98.36% | +0.00 pp |

MASH Product and MASH AXI-Lite are new top-level Product configurations and have no Round 1 same-scope baseline. Their Round 2 metrics are in `code_coverage.csv`. DUT-only selected hierarchy scores are retained for traceability but are not the sign-off metric.

## Functional coverage

| Same-scope configuration | Round 1 URG group score | Round 2 URG group score | Change |
|---|---:|---:|---:|
| EF1 Product | 45.10% | 79.54% | +34.44 pp |
| EF1 AXI-Lite | 52.23% | 87.95% | +35.72 pp |
| EF2 Product | 46.26% | 74.06% | +27.80 pp |
| EF2 AXI-Lite | 53.10% | 88.66% | +35.56 pp |

The functional scores are indicative rather than strictly denominator-identical. Round 2 corrected applicability: EF2-only coverage is excluded from EF1, MASH-only coverage is included only for MASH, and STOP/restart/run-prefill/drain groups are instantiated only in AXI-Lite builds. The correction removes non-applicable groups instead of deleting legal bins from an applicable group. Round 1 did not include a MASH Product covergroup baseline; its legacy MASH histogram was 5/7. Round 2 MASH Product has a fresh covergroup score of 76.57% with four raw weighted-level bins still uncovered; MASH AXI-Lite scores 88.31%. The legacy wrapper/core has no integrated Product functional score.

## Interpretation

Round 2 materially improves EF1/EF2 AXI-Lite Condition/Branch coverage and extends UVM integration to MASH Product. EF1/EF2 Product code percentages are unchanged from Round 1. The MASH wrapper/core code metrics are a same-scope rerun and unchanged. No target threshold is met for all required dimensions across the three SKUs, and a higher functional score does not constitute closure. Raw and adjusted remain equal and all remaining holes stay OPEN until a directed witness or independently reviewed reachability disposition is recorded.

# Evidence Index

Only compact CSV, JSON, and text summaries needed by public documentation are
kept here. Raw logs, waveforms, VDBs, simulator work directories, board captures,
and PDK output are intentionally excluded from Git.

| Area | Location | Interpretation |
|---|---|---|
| FPGA OOC | `ooc/` | Post-synthesis feature and historical comparisons |
| Integration | `integration/` | Historical routed records; inspect configuration before use |
| Frontend | `frontend/` | Model-level transmitter and DSM summaries |
| DPD | `dpd/` | Offline calibration and model experiments |
| Coverage | `SYSTEM_CODE_COVERAGE_AUDIT.md`, waiver CSV | Frozen-SKU UVM coverage audit |

The historical full-TX evidence does not represent the current BP EFDSM2 frozen
SKU. The current SKU still requires its own complete routed and board closure.

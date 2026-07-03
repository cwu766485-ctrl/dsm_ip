# Core MATLAB Flow

This folder contains the retained Cartesian DSM MATLAB pipeline:

- QAM-OFDM I/Q generation and COE export
- fixed-point Q1.15 input preparation
- LPDSM evaluation and metric calculation
- reconstruction, alignment, EVM, SNDR, ACPR/ACLR helpers
- comparison and sweep scripts kept for reproducibility

Important entry points:

| File | Purpose |
|---|---|
| `stage1_ofdm_qam_to_coe_lp_dsm_input_v3.m` | Generate 16-QAM OFDM I/Q and export ROM COE files |
| `stage1_ofdm_qam_to_coe_lp_dsm_input_256qam.m` | Generate 256-QAM input vectors |
| `stage2_dsm_and_metrics_v3.m` | Run LPDSM and calculate signal metrics |
| `plot_nominal_ofdm16qam_osr32_compare_v1.m` | Generate the nominal P0 comparison plot |
| `eval_legacy_rtl_metrics_table*.m` | Evaluate retained RTL metric tables |

Generated local outputs may appear under `coe/`, `meta/`, `signals/`, or
`results/`.

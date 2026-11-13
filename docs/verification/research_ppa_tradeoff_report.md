# Thermo5 Architecture Research and PPA Tradeoff

Date: 2026-11-13. Status: `MODEL_COMPARISON_REPRODUCIBLE; PPA_OPEN`.

The repository's controlled held-out model benchmark is documented in
`thermo5-tx-design-ablation.md`, with seed-level data, fixed model settings,
plots and hashes. Four matched cells are exported in
`architecture_ab_comparison.csv`. Each primary cell uses four held-out seeds
and 224,256 uncoded bits with a common Q1.15 256-QAM OFDM stimulus, fixed
receiver timing, and common nominal/stress behavioral output assumptions.
This is a model-level comparison, not hardware PPA or a physical radio result.

Under the existing model, centered cubic + EF2 (cell D) changes mean EVM from
3.443% to 2.464%, BER from 0.004223 to `9.3643e-5`, and SNDR from 29.261 dB to
32.168 dB relative to centered cubic + first-order DSM (cell B). The
adjacent-band values are simulation proxies, not standards ACLR. No hardware
BER inference is made from these Python/model results.

The requested new eight-group held-out experiment bundle was not found as a
complete provenance set containing raw CSV, full parameters, seeds, commit
SHA and plotting code. Those eight groups are `NOT_VALIDATED` and are not
claimed as reproduced evidence.

No same-constraint P&R results are available for LUT/FF/DSP/BRAM, Fmax, WNS,
logic depth, routed latency/throughput or dynamic power. These are `NOT_RUN`,
not zero-cost improvements. Standard ACLR is also `NOT_RUN`; the current
adjacent-band proxy does not meet that measurement contract.

## Research directions

- A: 32-lane EF2 parallel arithmetic. Existing repository evidence describes
  pair-lookahead structure and a bit-true miter, but no same-device
  synthesis/timing/power comparison exists. Current evidence supports an
  implementation scheduling optimization, not a new communications
  mechanism.
- B: Interpolator + DSM joint spectral optimization. Existing held-out data
  shows a model-level tradeoff, but no new eight-group result or standards
  ACLR data was verified here.

The available evidence does not establish a mechanism independent of cubic
interpolation, EF2 or DPD integration. That claim needs constituent ablations
under common constraints, independent held-out seeds, and reproduced raw
metrics. No research candidate is promoted to product RTL by this report.

Reproduction details and data hashes are indexed in
`thermo5-tx-design-ablation-evidence.json`. Hardware PPA requires the licensed
Vivado OOC flow with identical target, constraints and tool version for all
candidates, followed by matched-activity power analysis; these runs were not
executed here.

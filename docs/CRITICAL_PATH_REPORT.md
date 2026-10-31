# Critical Path Report — Thermo5 TX

## Status (2026-10-31)

**Current frozen EF2 TX product: FPGA routed timing NOT_SIGNED_OFF.**

This file is the required, stable entry point for critical-path evidence. It must not be read as a claim that the current 32-lane order-2 EF2 product has met the 218.75 MHz timing requirement on a target FPGA.

### Product configuration under review

- TX: 125 MHz AXI-Stream ingress, 14:8 gearbox, 218.75 MHz core.
- Centered-Cubic interpolation x2 + x2; four-plane offset second-order EF2, STEP=5120 and 20-bit state.
- DPD_MAX_TAPS=1, reset identity image; Linux VCS uses Generic async FIFO in place of FPGA XPM.
- Pair look-ahead is currently disabled in the product. Its VCS and scoped Formal equivalence evidence does not establish any PPA improvement.

### Available historical PPA — different configuration

See [Thermo3 and Thermo5 routed PPA comparison](THERMO3_THERMO5_ROUTED_PPA.md).

That report uses the `xczu15eg-ffvb1156-2-i` and records a prior **four-tap memory-DPD / first-order-era** configuration with Thermo3 and Thermo5 output plane counts. The report's routed positive WNS for those historical implementations is **not evidence for the present order-2 EF2 product** and must not be carried into the current signoff score.

### Required current-product signoff

1. Recreate the exact source SHA, device, clocks, XDC, and elaborated product parameter manifest, including vendor XPM and GT integration level.
2. Run synthesis, place, route, and post-route `report_timing_summary`. Record setup and hold WNS/TNS, critical-path startpoint/endpoint, data/route delay, unconstrained paths, clock interactions, and implementation tool versions.
3. Compare scalar EF2 and exact pair look-ahead under the **same** part, placement strategy, constraints and clock target. Record LUT/FF/DSP/BRAM, fmax, dynamic power, and II.
4. Keep GT Wizard payload/link timing and physical four-lane 14 Gb/s testing as separate gates.
5. Set this file's product status to PASS only after storing source-bound routed reports and a reproducible evidence manifest.

### Current references

- [TX Linux coverage signoff](verification/thermo5-tx-coverage-final-signoff.md)
- [Algorithm A/B experiments](verification/thermo5-tx-design-ablation.md)
- [Active execution frontier](exec-plans/active/execution-frontier.md)

**Current disposition: NOT_RUN for current-product routed FPGA timing; no physical RF or serial-link compliance claim.**

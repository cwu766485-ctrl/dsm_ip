# Centered-cubic arithmetic optimization research

Status: **candidate; core OOC timing marginally met, overall timing and whole RTL formal proof open**. This separate branch and worktree were forked from architecture research commit `0e4732bf7a08cf6d9c4b5d00f493e89e590a2a2d`, so the baseline four-case PPA sources cannot change while their jobs run.

The synthesized baseline EF1 critical core path crosses the first centered-cubic midpoint arithmetic into the following elastic buffer. The candidate preserves the exact fixed Q14 coefficients and rewrites the numerator as `9*(x0+xp1)-(xm1+xp2)`, then divides by 16 with signed ties away from zero and saturates to W bits. There is no added latency, handshake, reset or interface change. An independent Z3 integer proof establishes the 16-bit input range and rounding identity; exhaustive 4-bit tuples, all reduced 21-bit rounding values and 100,000 16-bit vectors pass. The full 16-bit RTL SAT miter and its numerator sub-miter timed out; the separate rounding bit-vector miter passes. A separate VC Formal check of the standalone 16-bit arithmetic miter returned inconclusive at its 4-minute property limit (`runs/cubic_vcf_01/properties.txt`), despite the process exit code being zero. This evidence does not replace sequential equivalence or timing signoff.

## Verification

- Directed XSim `run_xsim_thermo5_i2_d1_axis.ps1`: PASS (`runs/verify_xsim_launcher/console.log`).
- VCS `thermo5-vcs-regression` using preserved baseline vectors: PASS, including expected negative protocol test (`runs/verify_vcs_launcher/console.log`).
- XPM runtime full-chain QAM seed 281001, RMS 0.09, 5,264 output words per stream: all eight streams, six mode transitions and blocked-PA reset pass (`runs/qam281001/simulation.log`). The 36 PA capture files across all phases for EF1, EF2 and MASH match pre-existing baseline files exactly by SHA256 (`runs/qam281001_all_comparison.json`), so the prior offline EVM/BER for these captured streams is unchanged.

```bash
python3 dv/uvm/sim/run_thermo5_runtime_xsim.py --out runs/repro_qam_NEW \
  --vectors /mnt/e/workspace/chip/dsm_ip/runs/thermo5_runtime_product/runs/runtime_qam281001/vectors \
  --words 5264 --beats 3008 --seed 281001 --xpm
python3 research/vcu118_arch/compare_qam_captures.py \
  --reference /mnt/e/workspace/chip/dsm_ip/runs/thermo5_runtime_product/runs/runtime_qam281001/capture_xpm_fixed \
  --candidate runs/repro_qam_NEW --out runs/repro_qam_comparison_NEW.json
```

Run the required XSim and VCS commands from `AGENTS.md`, with new output directories and preserved vectors. A separate matched VCU118 EF1 implementation completed under `runs/optimized_ppa_ef1_01/`; its Tcl SHA256 matches the baseline. Synthesized core WNS improves from -1.823 to +1.140 ns, while DSP drops from 670 to 496 (LUT 48,098 to 48,069; FF 49,833 to 49,836). Overall candidate synthesis WNS is -0.694 ns on an unexpanded cross-clock path; the CDC contract needs review. Routed comparison: core WNS -2.797 to +0.075 ns and core WHS +0.027 to +0.023 ns; approximate core Fmax 135.722 to 222.420 MHz; LUT 47,321 to 47,053; FF 50,206 to 49,853; DSP 670 to 496; BRAM 6.5 for both; vectorless total power 5.331 to 4.815 W. The candidate core WNS is only 0.075 ns and its worst core path is from `run_sync2` to an interpolator-to-TID FIFO clock-enable, with 3.974 ns routed net delay. The overall candidate WNS is -0.363 ns and WHS +0.002 ns; its worst setup is an AXI-Lite-to-core `cfg_mailbox_q` to `cfg_pending_core` transfer. The mailbox request passes through synchronizers and the data is held until acknowledgement, but CDC correctness and a physical timing constraint must be reviewed and proven; no false path is added. The OOC clock source/port positions and I/O budgets are not physical board signoff. Repeat for EF2, MASH and runtime after reviewing constraints. The candidate must not be merged into product until margin, corner/parameter equivalence, full regressions, and CDC/constraints review are complete. All outputs must use fresh run directories.

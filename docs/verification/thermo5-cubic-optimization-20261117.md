# Centered-cubic arithmetic optimization research

Status: **candidate; routed timing and whole RTL formal proof open**. This separate branch and worktree were forked from architecture research commit `0e4732bf7a08cf6d9c4b5d00f493e89e590a2a2d`, so the baseline four-case PPA sources cannot change while their jobs run.

The synthesized baseline EF1 critical core path crosses the first centered-cubic midpoint arithmetic into the following elastic buffer. The candidate preserves the exact fixed Q14 coefficients and rewrites the numerator as `9*(x0+xp1)-(xm1+xp2)`, then divides by 16 with signed ties away from zero and saturates to W bits. There is no added latency, handshake, reset or interface change. An independent Z3 integer proof establishes the 16-bit input range and rounding identity; exhaustive 4-bit tuples, all reduced 21-bit rounding values and 100,000 16-bit vectors pass. The full 16-bit RTL SAT miter and its numerator sub-miter timed out; the separate rounding bit-vector miter passes. This evidence does not replace sequential equivalence or timing signoff.

## Verification

- Directed XSim `run_xsim_thermo5_i2_d1_axis.ps1`: PASS (`runs/verify_xsim_launcher/console.log`).
- VCS `thermo5-vcs-regression` using preserved baseline vectors: PASS, including expected negative protocol test (`runs/verify_vcs_launcher/console.log`).
- XPM runtime full-chain QAM seed 281001, RMS 0.09, 5,264 output words per stream: all eight streams, six mode transitions and blocked-PA reset pass (`runs/qam281001/simulation.log`). The 10 active PA captures for EF1, EF2 and MASH match pre-existing baseline files exactly by SHA256 (`runs/qam281001_comparison.json`), so the prior offline EVM/BER for these captured streams is unchanged.

```bash
python3 dv/uvm/sim/run_thermo5_runtime_xsim.py --out runs/repro_qam_NEW \
  --vectors /mnt/e/workspace/chip/dsm_ip/runs/thermo5_runtime_product/runs/runtime_qam281001/vectors \
  --words 5264 --beats 3008 --seed 281001 --xpm
python3 research/vcu118_arch/compare_qam_captures.py \
  --reference /mnt/e/workspace/chip/dsm_ip/runs/thermo5_runtime_product/runs/runtime_qam281001/capture_xpm_fixed \
  --candidate runs/repro_qam_NEW --out runs/repro_qam_comparison_NEW.json
```

Run the required XSim and VCS commands from `AGENTS.md`, with new output directories and preserved vectors. Generate a separate matched VCU118 implementation using `research/vcu118_arch/run_ppa.py --cases ef1`, compare its routed setup/hold, Fmax, utilization and power against the original matched EF1 run, and repeat for EF2, MASH and runtime if justified. The candidate must not be treated as a timing fix or merged into product until route, corner/parameter equivalence, full regressions, and CDC/constraints review are complete. All outputs must use fresh run directories.

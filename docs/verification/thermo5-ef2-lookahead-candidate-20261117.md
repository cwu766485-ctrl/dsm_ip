# Isolated EF2 pair-lookahead research

Status: **candidate only; no fresh PPA or product signoff**. This branch derives from `3f88efef965e2d5705adc57d06f530c265af2e82` and includes the isolated centered-cubic arithmetic candidate. It sets the existing EF2 `PAIR_LOOKAHEAD` implementation to 1 in the four-plane wrapper. The scalar default remains unchanged on the baseline architecture branch.

Required directed XSim and VCS regression pass with preserved vectors. XPM runtime QAM256 seed 281001, 5,264 words per stream, passes all eight stream phases, six mode transitions, and blocked-PA reset; all 36 generated phase/plane PA files are SHA256-identical to the preserved baseline. Logs and comparison are in `runs/verify_xsim_launcher/`, `runs/verify_vcs_launcher/`, `runs/qam281001/` and `runs/qam281001_all_comparison.json`.

```bash
python3 dv/uvm/sim/run_thermo5_runtime_xsim.py --out runs/repro_qam_NEW \
  --vectors /mnt/e/workspace/chip/dsm_ip/runs/thermo5_runtime_product/runs/runtime_qam281001/vectors \
  --words 5264 --beats 3008 --seed 281001 --xpm
python3 research/vcu118_arch/compare_qam_captures.py \
  --reference /mnt/e/workspace/chip/dsm_ip/runs/thermo5_runtime_product/runs/runtime_qam281001/capture_xpm_fixed \
  --candidate runs/repro_qam_NEW --out runs/repro_comparison_NEW.json
```

This finite test does not prove all fixed-point states or clamp transitions and does not establish timing benefit. Existing pair-level equivalence evidence and the full unmodified EF2 recurrence remain separate. Before adopting, prove full-vector state equivalence including saturation/ties and stalls, run the same-boundary EF2 routed PPA and CDC/constraints review, then repeat other architecture and system regressions. Do not change Golden data, merge into product, or claim convergence on the basis of these captures.

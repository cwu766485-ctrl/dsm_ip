# Band-Pass DSM Block

## DUT

- `rtl/tx_bandpass_if/dsm_core_bp_ef2.sv`: BP EFDSM2 core under test.
- `rtl/dsm/singlebit/dsm_core_ef2.sv`: shared EF2 arithmetic dependency.

## Testbenches

`tb_dsm_core_bp_ef2_bittrue.sv` compares bit, signed code, and quantizer state
against a Python-generated vector. `tb_dsm_core_bp_ef2_random.sv` replays the
same seeded random/extrema vector with deterministic enable bubbles.
`tb_dsm_core_bp_single.sv` is a directed smoke test. The 2026-08-12 block
regression passed both bit-true and randomized protocol tests at 4096 samples.
Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_bp_dsm_block.ps1
```

## Reference and Vectors

- Python source: `uvm_verif/refmodel/python/dsm_refmodel/bp_ef2.py` (`BpEf2`).
- Generator: `uvm_verif/refmodel/python/generate_bp_ef2_vectors.py`.
- Per-run vector: `verif/out_xsim_bp_dsm_block/bp_ef2_equivalence.csv`.

The CSV is regenerated for the requested sample count, so it is not tracked in
this directory.

# DPD Block

## DUT

- `rtl/dpd/dpd_poly.v`: memoryless Poly3/5/7 arithmetic.
- `rtl/dpd/dpd_memory_poly.v`: memory-polynomial C1/C3/C5 path.
- `rtl/dpd/dpd_lut.v`: LUT DPD path.
- `rtl/dpd/dpd_frontend.v`: runtime mode selection, coefficient banks,
  commit, safety fallback, valid/ready behavior.

## Testbenches

`tb/` contains arithmetic bit-true, Poly7 directed, memory-polynomial,
protocol assertion, safety, feature-gate, and compile-matrix tests. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1
```

## Reference and Vectors

- MATLAB source: `matlab/dpd/prepare_dpd*_bittrue_vectors.m`.
- Python integer reference: `uvm_verif/refmodel/python/dsm_refmodel/dpd.py`.
- Generated vectors: `matlab/out/dpd/bittrue/`.
- Per-run copies and RTL dumps: `verif/out_xsim_dpd/`.

`vectors/` intentionally contains only the vector contract. It must not become
a second copy of generated golden CSV files.

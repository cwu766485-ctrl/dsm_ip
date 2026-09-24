# DPD Vector Contract

Source of truth: MATLAB generators under `matlab/dpd/`.

| Test family | Generator | Generated location |
|---|---|---|
| Poly3/5 | `prepare_dpd_bittrue_vectors.m` | `matlab/out/dpd/bittrue/` |
| Poly7 | `prepare_dpd7_bittrue_vectors.m` | `matlab/out/dpd/bittrue/` |
| Memory polynomial | `prepare_dpd_memory_poly_bittrue_vectors.m` | `matlab/out/dpd/bittrue/` |

`run_xsim_dpd_bittrue.ps1` copies the needed inputs, expected outputs, and
coefficients into its disposable XSim work directory. Do not commit duplicates
here.

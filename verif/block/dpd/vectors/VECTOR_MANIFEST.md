# DPD Vector Manifest

| Suite | Generator | Input space | Boundary coverage |
|---|---|---|---|
| Poly3/5/7 | `matlab/dpd/prepare_dpd*_bittrue_vectors.m` | Q1.15 I/Q, Q2.14 coefficients | zero, signed extrema, saturation and C1/C3/C5/C7 terms |
| Memory Poly5 | `matlab/dpd/prepare_dpd_memory_poly_bittrue_vectors.m` | four taps, C1/C3/C5 | tap history, signed data and coefficient quantization |
| Protocol | `tb_dpd_frontend_random_protocol.sv` | 113 deterministic pseudo-random I/Q samples | `0x8000`, `0x7fff`, input/output bubbles, unsafe commit, clear, safe re-commit |

Generated CSVs are not stored here. See `matlab/out/dpd/bittrue/` during a run.

# Interpolation Vector Manifest

| Suite | Generator | Coverage |
|---|---|---|
| Modes 0 to 4 | `matlab/models/prepare_interp_frontend_bittrue_vectors.m` | Q1.15 I/Q and all x1/x4/x8/x16/x32 paths |
| x32 variants | same generator | I0/I1/I2/I3 implementations |
| Protocol | `tb_interp_frontend_random_protocol.sv` | 97 pseudo-random transactions, zero/extrema, input bubbles and output backpressure |

Generated CSVs remain under `matlab/out/interp_frontend/bittrue/`.

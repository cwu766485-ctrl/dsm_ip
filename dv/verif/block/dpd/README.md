# DPD Block

## DUT and retained tests

- `rtl/dpd/dpd_memory_poly.v`: pipelined C1/C3/C5 Memory-Poly datapath.
- `tb/tb_dpd_identity_exhaustive.sv`: exhaustive 16-bit identity-domain check.
- `tb/tb_dpd_memory_poly_bittrue.sv`: MATLAB-vector arithmetic comparison.
- `tb/tb_dpd_memory_poly_random_protocol.sv`: ordering, output stability,
  input/output backpressure, and one-tap unity-C1 behavior.

The random protocol test is run with licensed VCS:

```bash
bash dv/verif/block/dpd/run_memory_poly_random_vcs.sh
```

The identity sweep runner is `dv/verif/block/dpd/run_identity_exhaustive_vcs.sh`.
Both runners write to `runs/`; no generated simulator products are stored in
this source directory.

## Reference model boundary

MATLAB generators under `matlab/dpd/` own fixed-point vector generation. The
Python integer DPD model under `dv/uvm/refmodel/python/dsm_refmodel/dpd.py` is
the independent VCS/UVM regression reference. The thermo5 frozen SKU uses
identity coefficients; these tests do not by themselves establish nonlinear
DPD/PA linearization quality.

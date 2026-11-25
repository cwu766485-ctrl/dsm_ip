# DPD Block

## DUT and retained tests

- `rtl/dpd/dpd_memory_poly.v`: pipelined C1/C3/C5 Memory-Poly datapath.
- `tb/tb_dpd_identity_exhaustive.sv`: exhaustive 16-bit identity-domain check.
- `tb/tb_dpd_memory_poly_bittrue.sv`: MATLAB-vector arithmetic comparison.
- `tb/tb_dpd_memory_poly_random_protocol.sv`: ordering, output stability,
  input/output backpressure, and one-tap unity-C1 behavior.
- `tb/tb_dpd_poly_closure.sv`: independent Python-oracle miter for the
  memoryless C3/C5/C7 datapath, run separately at polynomial orders 3, 5, and 7.
- `tb/tb_thermo5_fitted_dpd.sv`: Python-oracle bit-true check for the
  16-lane, four-tap memory-polynomial path.

The random protocol test is run with licensed VCS:

```bash
bash dv/verif/block/dpd/run_memory_poly_random_vcs.sh
```

The identity sweep runner is `dv/verif/block/dpd/run_identity_exhaustive_vcs.sh`.
Both runners write to `runs/`; no generated simulator products are stored in
this source directory.

The Round 4 order sweep uses directed signed-boundary IQ/coefficient vectors,
checks saturation and output stability during backpressure, and writes a
separate VCS coverage database per elaborated order. The order-specific
databases are not compatible with the SKU Product VDBs and must not be merged
into them.

## Round 4 closure evidence

The order 3, 5, and 7 Python-oracle closures each passed 72 directed vectors,
including three expected output saturations, 15 input-stall cycles, and 20
output-stall cycles. Standalone `dpd_poly` Line, Branch, and Condition coverage
reached 100% for each order; Toggle coverage remains below 90% and is retained
as OPEN. `dpd_sat_signed` also has standalone raw holes in the order runs.

The exhaustive identity test checked all 65,536 signed 16-bit input values in
three repeated acceptance phases (196,608 accepted/output samples). The
memory-polynomial protocol test passed 173 samples, with 73 output stalls and
60 full-input stalls. A four-tap, 16-lane candidate was checked against the
independent Python model over 93,184 samples (5,824 lane words), with zero
output saturations. Candidate coefficients and test vectors are not the frozen
Product one-tap identity configuration.

Coverage is reported independently for each block elaboration in
`docs/verification/data/dsm-v13-round4/round4_block_level_code_coverage.csv`;
exact standalone raw holes are in `round4_block_raw_open_rtl_bins.csv`. Do not
sum duplicate source signatures across polynomial orders as unique holes or
merge these VDBs with SKU Product coverage. Memory-polynomial and
interpolator-related blocks retain uncovered raw bins; block PASS means the
checker passed, not that code coverage closed.

## Reference model boundary

MATLAB generators under `matlab/dpd/` own fixed-point vector generation. The
Python integer DPD model under `dv/uvm/refmodel/python/dsm_refmodel/dpd.py` is
the independent VCS/UVM regression reference. The thermo5 frozen SKU uses
identity coefficients; these tests do not by themselves establish nonlinear
DPD/PA linearization quality.

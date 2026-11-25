# Failed Seed / Early Attempt Record

No random seed remains failing in the final Round 1 matrix. This file records
non-seed test-harness failures discovered during bring-up; they are not RTL
counterexamples and are excluded from pass counts.

| Early result | Cause | Correction | Final evidence |
|---|---|---|---|
| EF1 reset test failed while selecting reset-state hierarchy | Test was hard-coded to an EF2 internal path | Replaced with a SKU-neutral reset-state observation; EF1 payload pipeline is intentionally excluded | `round1_final/ef1/thermo5_sku_reset_test_seed3.log` and reset sweep log |
| EF1/EF2 FIFO-empty scoreboard mismatch | Full-frame expected vector was reused for a seven-word short-frame test | Added `generate_thermo5_fifo_empty_vectors.py` to derive the short-frame oracle | `round1_final/ef1` and `ef2/thermo5_sku_fifo_empty_test_seed5.log` |
| First Python unittest command failed at import | Started discovery from repository root, while this test suite imports from the Python refmodel working directory | Reran from `dv/uvm/refmodel/python` | `round1_final/python_unittest.log`: 72 tests, all OK |

There is no failing random seed or RTL mismatch to reproduce. For the successful
MASH seed 130011, rebuild and run:

```sh
make -C dv/uvm/sim dsm-v13-mash11-vcs DSM_V13_OUT=runs/repro/mash11
runs/repro/mash11/mash11/simv \
  +UVM_TESTNAME=mash11_vector_test \
  +MASH_VECTORS=runs/dsm_v13_round1/round1_final/mash11/vectors_seed130011 \
  +ntb_random_seed=130011 -l runs/repro/mash11/seed130011.log
```

# DPD Block

## DUT

- `rtl/dpd/dpd_poly.v`: memoryless Poly3/5/7 arithmetic.
- `rtl/dpd/dpd_memory_poly.v`: memory-polynomial C1/C3/C5 path.
- `rtl/dpd/dpd_lut.v`: LUT DPD path.
- `rtl/dpd/dpd_frontend.v`: runtime mode selection, coefficient banks,
  commit, safety fallback, valid/ready behavior.

## Testbenches

`tb/` contains arithmetic bit-true, Poly7 directed, memory-polynomial,
protocol assertion, safety, feature-gate, and compile-matrix tests. The
`tb_dpd_memory_poly_random_protocol` test directly randomizes downstream
ready on the reusable Memory-Poly5 core and checks a one-tap unit-C1 oracle,
ordering, output stability during stalls, and a full-pipeline backpressure
event. Run:

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
## Memory-Poly Ready/Valid Closure

`tb_dpd_memory_poly_random_protocol.sv` drives `dpd_memory_poly` directly.
It uses one active tap and unity `C1`, so every accepted output must equal the
accepted input exactly. The test fills the ten-stage pipeline, applies
randomized input bubbles and output backpressure, checks output stability while
stalled, and requires both an output stall and an `in_ready` stall.

The Linux/VCS reproduction command is:

```bash
cd <repository-root>
bash verif/block/dpd/run_memory_poly_random_vcs.sh
```

The runner compiles `rtl/dpd/dpd_poly.v` together with
`rtl/dpd/dpd_memory_poly.v`, because `dpd_poly.v` contains the shared
`dpd_sat_signed` helper definition. Do not add a nonexistent
`dpd_sat_signed.v` path to a VCS file list.

Only `DPD_MEMORY_RANDOM_PROTOCOL_VCS_PASS`, together with zero VCS errors and
fatals in `verif/out_vcs_dpd_memory_poly_random/sim.log`, closes FSKU-010.

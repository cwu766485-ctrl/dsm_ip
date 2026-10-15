# Single-Lane DSM Algorithm Study

This branch isolates scalar-sample delta-sigma modulator (DSM) cores for
algorithm comparison. Each core consumes one signed sample per enabled clock
and updates its own quantization-error state. The scope is low-pass Cartesian
DSM: single-bit and multi-bit LP, EF, and MASH variants.

The `rtl/top/p0_top_*` wrappers are retained only as verification carriers.
They instantiate independent scalar I/Q cores and a simple Fs/4 merge; they
are not the subject of this branch. No wide-lane transmitter, DPD,
interpolator, AXI/FIFO, GT, or board integration is included.

## Contents

- `rtl/dsm/singlebit/`: seven single-bit low-pass algorithm cores.
- `rtl/dsm/multibit/`: parameterized multi-bit core and seven named variants.
- `matlab/`: fixed-point and exploratory algorithm models.
- `dv/verif/`: deterministic XSim stimulus/capture and lightweight checks.
- `syn/`: 14-top FPGA OOC comparison flow for the scalar algorithms.
- `docs/`: scope, architecture, verification contract, and historical PPA data.

## Regressions

On Windows with Vivado 2024.1 installed at the default path:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_multibit.ps1
```

Each run writes to a timestamped directory under `runs/dsm/`. To use another
Vivado installation, pass `-VivadoSettings <path-to-settings64.bat>`.
MATLAB reference checks are available through `scripts/run_matlab_p0_bittrue_check.cmd`
and `scripts/run_matlab_p0_eval.cmd`.

The historical 100 MHz XC7Z020 OOC comparison is recorded in
`docs/evidence/ooc/p0_ooc_xc7z020_20260705_multibit_summary.csv`. It is a proxy
comparison, not a current board or product-level timing signoff. Re-run it with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1
```

See [the specification](docs/SPEC.md), [verification plan](docs/VPLAN.md), and the
[architecture guide](docs/architecture/single-lane-dsm-architectures.md).

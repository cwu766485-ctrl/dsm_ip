# Verification

Verification is split into block, subsystem, and IP-system levels:

- `block/`: lightweight arithmetic and protocol tests for individual RTL blocks.
- `subsystem/`: boundary tests for TX frontend, IF/DSM, feedback, and control.
- `tb/`: retained IP-top and route-level directed XSim testbenches.
- `scripts/`: XSim runners and regression helpers.
- `vectors/`: checked-in input vectors and vector-format rules.
- `../uvm_verif/`: complete IP-system UVM environment for Linux VCS/Verdi.

The retained `verif/` tree deliberately contains only reusable directed and
layered verification collateral. Empty legacy UVM directories and generated
XSim/SpyGlass outputs are not kept here.

MATLAB is the fixed-point signoff reference. The dependency-light Python
integer model under `uvm_verif/refmodel/python/` is the Linux/VCS regression
reference and must remain sample-by-sample equal to MATLAB.

## P0 DSM Regression

Included testbenches:

- `tb_p0_lp1`
- `tb_p0_lp2`
- `tb_p0_ef1`
- `tb_p0_ef2`
- `tb_p0_mash11_mb`
- `tb_p0_mash111_mb`
- `tb_p0_mash22_mb`

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1
```

Input vectors:

```text
verif/vectors/p0/rom_i.mem
verif/vectors/p0/rom_q.mem
```

Generated outputs are written under `verif/out_xsim_p0/` and ignored by Git.

LPDSM/LPDSM2/EFDSM/EFDSM2 emit 1-bit sign-domain traces. The MASH testbenches
emit native multibit `yout` traces.

## Initial IF/DSM Bit-True Regression

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_if_dsm_bittrue.ps1
```

This flow generates Python bit-exact vectors and compares the full-precision
Fs/4 mixer plus BP EFDSM2 RTL transaction by transaction.

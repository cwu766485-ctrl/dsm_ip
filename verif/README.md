# Verification

This folder contains the XSim regression flow for the retained P0 RTL paths.

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

# Cartesian DSM Single-Bit Models

This folder contains convenience wrappers for the verified single-bit DSM
MATLAB reference behavior.

The bit-true reference remains:

```text
matlab/bittrue/p0_dsm_bittrue.m
```

Supported algorithms:

- LPDSM
- LPDSM2
- EFDSM
- EFDSM2
- MASH11
- MASH111
- MASH22

Run:

```matlab
y = dsm_singlebit_model(x, "ef2");
```

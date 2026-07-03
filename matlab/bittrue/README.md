# Bit-True Models

This folder contains MATLAB fixed-point models that are intended to match the
P0 RTL simulation dumps sample-for-sample.

Main entry point:

```matlab
T = p0_compare_rtl_xsim();
```

Compared structures:

- LPDSM
- LPDSM2
- EFDSM
- EFDSM2
- MASH11
- MASH111
- MASH22

The sign-domain structures are compared against `sim_bits_01_*.txt`. The MASH
structures are compared against native multibit `sim_yout_signed_*_mb.txt`.

# Digital-IF BPDSM MATLAB Route

`bp_single_fs4_model.m` and `bp_ef2_fs4_model.m` are fixed-point references
for the one-bit real-IF candidates. `bp_mash11_exploratory_model.m` keeps its
native multilevel MASH output and therefore is not a current one-bit DPA model.

The route must be assessed at the real RF aperture:

```text
I/Q -> full-precision IF -> BPDSM -> IF BPF -> DDC -> CP/FFT EVM and ACLR
```

It is not interchangeable with the native low-pass I/Q metric.

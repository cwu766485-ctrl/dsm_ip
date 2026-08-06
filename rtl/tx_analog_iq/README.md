# Analog-IQ Transmitter Route

This route is the primary DPD communication-chain path:

```text
AXI I/Q -> DPD -> interpolation -> low-pass I/Q DSM -> 1-bit I and Q pins
      -> external reconstruction LPFs -> analog IQ mixer and RF LO -> PA
```

`dsm_iq_analog_top.sv` fixes `DUC_MODE=2`, which intentionally disables the
digital real-RF outputs. It does not create a fake `rf_bit` monitor value.

The reusable packaged `dsm_ip_axi_top` can use `DUC_MODE=2` directly. Its
`i_bit` and `q_bit` outputs are the digital boundary for the external analog
reconstruction and IQ-upconversion chain. A physical feedback receiver must
return downconverted complex I/Q through `s_axis_obs`.

This route preserves the existing LPDSM, LPDSM2, EFDSM, EFDSM2, and MASH
comparisons as low-pass complex-baseband DSM evidence.

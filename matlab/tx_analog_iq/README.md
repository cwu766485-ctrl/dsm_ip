# Analog-IQ MATLAB Route

Use the existing low-pass I/Q DSM models and DPD model with this physical
boundary:

```text
complex DPD output -> interpolation -> I/Q low-pass DSM -> reconstruction LPFs
-> analog IQ mixer -> RF LO -> PA -> observation receiver
```

The analog mixer is outside the current digital RTL model. Its LO frequency is
not limited by the 100 MHz PL clock. Native I/Q EVM remains the digital DSM
metric; RF EVM requires a declared reconstruction-filter, mixer, PA, and
observation-receiver model.

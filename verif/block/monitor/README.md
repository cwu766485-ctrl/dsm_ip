# Monitor Block

## DUT

`rtl/dpd/dpd_observer.v` contains error, power, peak, clipping, saturation,
slew, and spectral-proxy accumulators.

## Testbench

`tb/tb_dpd_observer_behavioral.sv` compares every final counter to a known
behavioral observation window. `tb/tb_dpd_observer_random_protocol.sv` adds
invalid beats, signed extrema, completion, and clear behavior. On 2026-08-12,
the behavioral test passed with 63 pairs and one drop; the random test passed
129 samples with 12 invalid beats. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_observer_behavioral.ps1
```

## Reference and Vectors

- MATLAB generator: `matlab/dpd/prepare_dpd_observer_behavioral_vectors.m`.
- Generated vectors and expected metadata: `matlab/out/dpd/observer/`.
- Per-run copies: `verif/out_xsim_dpd_observer/`.

The current model is a digital behavioral observation reference, not a measured
RF PA/ADC signoff model.

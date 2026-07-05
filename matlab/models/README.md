# MATLAB Models

This folder contains executable algorithm references before RTL is written.

## Interpolation Frontend

```matlab
cd matlab
path_setup
interp_frontend_float
interp_frontend_fixed
prepare_interp_frontend_bittrue_vectors
```

Supported modes:

| Mode | Function |
|---:|---|
| 0 | bypass |
| 1 | x4 halfband FIR cascade |
| 2 | x8 halfband FIR cascade |
| 3 | x16 halfband FIR cascade |
| 4 | x32 halfband x4 + CIC x8 + compensation FIR |

RTL bit-true coverage:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_interp_frontend.ps1
```

```matlab
cd matlab
path_setup
T = compare_interp_frontend_rtl_xsim;
disp(T)
```

Current RTL bit-true scope covers modes 0 through 4. Mode 4 uses the MATLAB
fixed-point CIC-equivalent FIR impulse and compensation FIR coefficients.

Generated outputs are written to `matlab/out/interp_frontend/`:

- frequency-response CSV files
- floating-point vectors
- fixed-point bit-true vectors
- quantized coefficient CSV files
- summary metrics

The fixed-point summary measures numerical error between the fixed-point model
and the floating-point reference. It is not an end-to-end communication-link
SNR/EVM result: no AWGN, DSM quantization noise, DAC model, reconstruction
filter, or analog impairment is included in this frontend-only check.

## System Metrics

```matlab
entry_interp_frontend_system_eval
```

This runs a behavioral 16-QAM OFDM chain through interpolation, Fs/4 DUC,
EFDSM2, ideal reconstruction, alignment, and metric measurement. Native
EVM/SNDR is the primary comparison against the historical DSM flow; the
RF-recovered EVM/SNDR columns are diagnostic only and depend on the assumed RF
reconstruction/downconversion model.
Optional AWGN, phase-noise, clipping, and PA nonlinearity knobs are available in
`interp_frontend_system_eval.m` but are disabled in the clean baseline.

Run a reduced calibration sweep:

```matlab
entry_interp_frontend_calibrate_system
```

This writes:

- `interp_frontend_system_calibration.csv`
- `interp_frontend_system_calibration_by_native.csv`

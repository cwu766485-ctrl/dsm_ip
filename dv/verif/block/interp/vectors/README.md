# Interpolation Vector Contract

`matlab/models/prepare_interp_frontend_bittrue_vectors.m` generates fixed-point
input and expected vectors under `matlab/out/interp_frontend/bittrue/`.
`run_xsim_interp_frontend.ps1` copies only the required inputs into its XSim
work directory and MATLAB compares the RTL dumps afterward. Generated CSV files
are not duplicated here.

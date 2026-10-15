# DSM Helper Scripts

The retained Windows command files launch MATLAB P0 checks:

- `run_matlab_p0_bittrue_check.cmd`: compare single-bit RTL dumps with the
  fixed-point model.
- `run_matlab_p0_eval.cmd` and `run_matlab_p0_eval_seven.cmd`: evaluate P0
  algorithm metrics.
- `run_matlab_p0_export.cmd`: export the P0 deterministic input vectors.

Set `MATLAB_EXE` in a command file if MATLAB is installed at a different path.

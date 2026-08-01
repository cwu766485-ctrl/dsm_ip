function T = compare_lpdsmdpa_bpf_dpd_rtl_xsim()
% Enforce the release-gated LPDSM2 DPA+BPF Memory-Poly RTL comparison.

  here = fileparts(mfilename('fullpath'));
  repo = fileparts(fileparts(here));
  exp_dir = fullfile(repo, 'matlab', 'out', 'dpd', 'lpdsmdpa_bpf_bittrue');
  rtl_dir = fullfile(repo, 'verif', 'out_xsim_lpdsmdpa_bpf_dpd');
  T = compare_dpd_memory_poly_rtl_xsim('exp_dir', exp_dir, 'rtl_dir', rtl_dir);
  assert(T.expected_samples == 256, 'Unexpected MATLAB vector count.');
  assert(T.rtl_samples == T.expected_samples, ...
    'RTL output count does not match the MATLAB vector count.');
  assert(T.mismatch == 0 && T.max_abs_error_lsb == 0, ...
    'LPDSM2 DPA+BPF release package is not MATLAB/RTL bit-true.');
end

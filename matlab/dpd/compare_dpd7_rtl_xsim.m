function T = compare_dpd7_rtl_xsim(varargin)
% Compare seventh-order dpd_poly XSim output against MATLAB fixed-point data.
  cfg.exp_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
    'out', 'dpd', 'bittrue');
  cfg.rtl_dir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
    'verif', 'out_xsim_dpd');
  for n = 1:2:numel(varargin), cfg.(varargin{n}) = varargin{n+1}; end
  expected = readtable(fullfile(cfg.exp_dir, 'dpd7_expected_iq.csv'));
  rtl = readtable(fullfile(cfg.rtl_dir, 'dpd7_rtl_iq.csv'));
  n = min(height(expected), height(rtl));
  di = int64(rtl.i_q1_15(1:n)) - int64(expected.i_q1_15(1:n));
  dq = int64(rtl.q_q1_15(1:n)) - int64(expected.q_q1_15(1:n));
  mismatch = nnz(di ~= 0 | dq ~= 0);
  max_abs_error_lsb = max([abs(di(:)); abs(dq(:)); 0]);
  T = table(n, height(expected), height(rtl), mismatch, max_abs_error_lsb, ...
    'VariableNames', {'compared_samples','expected_samples','rtl_samples', ...
    'mismatch','max_abs_error_lsb'});
end

function T = compare_dpd_rtl_xsim(varargin)
% compare_dpd_rtl_xsim
% Compare dpd_poly RTL dump against MATLAB fixed-point expected vectors.

  cfg.exp_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                         'out', 'dpd', 'bittrue');
  cfg.rtl_dir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                         'verif', 'out_xsim_dpd');
  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end

  E = readtable(fullfile(cfg.exp_dir, 'dpd_expected_iq.csv'));
  R = readtable(fullfile(cfg.rtl_dir, 'dpd_rtl_iq.csv'));
  n = min(height(E), height(R));

  di = int64(R.i_q1_15(1:n)) - int64(E.i_q1_15(1:n));
  dq = int64(R.q_q1_15(1:n)) - int64(E.q_q1_15(1:n));
  mismatch = nnz(di ~= 0 | dq ~= 0);
  max_abs_err = max([abs(di(:)); abs(dq(:)); 0]);

  T = table(n, height(E), height(R), mismatch, max_abs_err, ...
    'VariableNames', {'compared_samples','expected_samples','rtl_samples', ...
                      'mismatch','max_abs_error_lsb'});
end

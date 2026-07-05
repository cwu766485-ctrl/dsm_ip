function T = compare_interp_frontend_rtl_xsim(varargin)
% Compare dsm_interp_frontend RTL dumps against MATLAB fixed-point vectors.

  cfg.exp_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                         'out', 'interp_frontend', 'bittrue');
  cfg.rtl_dir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                         'verif', 'out_xsim_interp_frontend');
  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end

  rows = cell(5, 1);
  for mode = 0:4
    exp_path = fullfile(cfg.exp_dir, sprintf('interp_mode%d_expected.csv', mode));
    rtl_path = fullfile(cfg.rtl_dir, sprintf('interp_mode%d_rtl.csv', mode));
    E = readtable(exp_path);
    R = readtable(rtl_path);
    n = min(height(E), height(R));
    di = int64(R.i_q1_15(1:n)) - int64(E.i_q1_15(1:n));
    dq = int64(R.q_q1_15(1:n)) - int64(E.q_q1_15(1:n));
    mismatch = nnz(di ~= 0 | dq ~= 0);
    max_abs_err = max([abs(di(:)); abs(dq(:)); 0]);
    rows{mode + 1} = {mode, n, height(E), height(R), mismatch, max_abs_err};
  end

  T = cell2table(vertcat(rows{:}), 'VariableNames', ...
      {'mode','compared_samples','expected_samples','rtl_samples', ...
       'mismatch','max_abs_error_lsb'});
end

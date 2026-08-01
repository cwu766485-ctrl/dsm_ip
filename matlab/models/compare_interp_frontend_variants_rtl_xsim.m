function T = compare_interp_frontend_variants_rtl_xsim(varargin)
% Compare each x32 RTL realization to its fixed-point architecture contract.

  cfg.exp_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                         'out', 'interp_frontend', 'bittrue');
  cfg.rtl_dir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                         'verif', 'out_xsim_interp_frontend');
  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end

  ids = {'I0', 'I1', 'I2', 'I3'};
  rows = cell(numel(ids), 1);
  for k = 1:numel(ids)
    if strcmp(ids{k}, 'I2')
      expected_name = 'interp_I2_expected.csv';
    else
      expected_name = 'interp_mode4_expected.csv';
    end
    E = readtable(fullfile(cfg.exp_dir, expected_name));
    R = readtable(fullfile(cfg.rtl_dir, sprintf('interp_%s_rtl.csv', ids{k})));
    n = min(height(E), height(R));
    di = int64(R.i_q1_15(1:n)) - int64(E.i_q1_15(1:n));
    dq = int64(R.q_q1_15(1:n)) - int64(E.q_q1_15(1:n));
    rows{k} = {string(ids{k}), n, height(E), height(R), ...
      nnz(di ~= 0 | dq ~= 0), max([abs(di(:)); abs(dq(:)); 0])};
  end
  T = cell2table(vertcat(rows{:}), 'VariableNames', ...
    {'interp_id', 'compared_samples', 'expected_samples', 'rtl_samples', ...
     'mismatch', 'max_abs_error_lsb'});
  if any(T.mismatch ~= 0) || any(T.expected_samples ~= T.rtl_samples)
    error('One or more x32 interpolation RTL outputs do not match their fixed-point contract');
  end
end

function T = prepare_interp_i2_bittrue_vectors(varargin)
% Create bit-true I2 vectors for the monolithic x32, 1195-tap FIR RTL.
% I2 is intentionally compared to its own one-stage fixed-point contract,
% not to I0's intermediate-rounding contract.

  cfg.n_input = 128;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
                         'out', 'interp_frontend', 'bittrue');
  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end

  if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end
  input_path = fullfile(cfg.out_dir, 'interp_input_iq.csv');
  if ~exist(input_path, 'file')
    prepare_interp_frontend_bittrue_vectors('n_input', cfg.n_input);
  end
  X = readtable(input_path);
  if height(X) ~= cfg.n_input
    error('I2 input vector length mismatch: expected %d, got %d', ...
          cfg.n_input, height(X));
  end

  C = generate_i2_pure_fir_coeffs();
  hq = double(C.coeff_q2_16(:));
  yi = monolithic_interp(int64(X.i_q1_15), hq);
  yq = monolithic_interp(int64(X.q_q1_15), hq);
  T = table((0:numel(yi)-1).', yi, yq, ...
            'VariableNames', {'n', 'i_q1_15', 'q_q1_15'});
  writetable(T, fullfile(cfg.out_dir, 'interp_I2_expected.csv'));
end

function y = monolithic_interp(x, hq)
  rate = 32;
  xu = zeros(numel(x) * rate, 1);
  xu(1:rate:end) = double(x(:));
  acc = filter(hq, 1, xu);
  rounded = round_shift_vec(acc, 16);
  rounded = min(max(rounded, -32768), 32767);
  y = int64(rounded);
end

function y = round_shift_vec(x, sh)
  y = zeros(size(x));
  pos = x >= 0;
  y(pos) = floor((x(pos) + 2^(sh - 1)) / 2^sh);
  y(~pos) = -floor((-x(~pos) + 2^(sh - 1)) / 2^sh);
end

function T = run_dsm_single_multi_metric_compare(varargin)
%RUN_DSM_SINGLE_MULTI_METRIC_COMPARE Compare single-bit and multibit DSM metrics.
%
% The same high-rate narrowband I/Q source is used for all rows. Metrics are
% reported in two domains:
%   native:       complex I/Q low-pass reconstruction
%   RF_recovered: Fs/4 real merge, ideal RF band-pass, and I/Q recovery
%
% This script is for MATLAB exploration. Multibit rows are not RTL bit-true.

  cfg = default_cfg();
  for k = 1:2:numel(varargin)
    cfg.(varargin{k}) = varargin{k + 1};
  end

  rng(cfg.seed);
  x = make_bandlimited_iq(cfg);
  xi = int64(round(real(x) * 32767));
  xq = int64(round(imag(x) * 32767));

  algs = ["lp1", "lp2", "ef1", "ef2", "mash11", "mash111", "mash22"];
  rows = {};
  ir = 0;

  for ia = 1:numel(algs)
    alg = algs(ia);

    yi = dsm_singlebit_model(xi, alg);
    yq = dsm_singlebit_model(xq, alg);
    [native, rfrec] = eval_pair(single_to_float(yi, alg), ...
                                single_to_float(yq, alg), x, cfg);
    ir = ir + 1;
    rows(ir, :) = {char(alg), 'singlebit', 1, min([yi(:); yq(:)]), ...
                   max([yi(:); yq(:)]), native.EVM_rms_percent, ...
                   native.SNDR_dB, rfrec.EVM_rms_percent, rfrec.SNDR_dB};

    for ib = 1:numel(cfg.multibit_list)
      nbits = cfg.multibit_list(ib);
      yi = dsm_multibit_model(xi, alg, nbits);
      yq = dsm_multibit_model(xq, alg, nbits);
      [native, rfrec] = eval_pair(double(yi), double(yq), x, cfg);
      ir = ir + 1;
      rows(ir, :) = {char(alg), 'multibit', nbits, min([yi(:); yq(:)]), ...
                     max([yi(:); yq(:)]), native.EVM_rms_percent, ...
                     native.SNDR_dB, rfrec.EVM_rms_percent, rfrec.SNDR_dB};
    end
  end

  T = cell2table(rows, 'VariableNames', ...
      {'algorithm','model_type','nbits','min_code','max_code', ...
       'native_EVM_percent','native_SNDR_dB', ...
       'RF_recovered_EVM_percent','RF_recovered_SNDR_dB'});

  if cfg.write_csv
    out_dir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                       'out', 'dsm_multibit');
    if ~exist(out_dir, 'dir')
      mkdir(out_dir);
    end
    writetable(T, fullfile(out_dir, 'dsm_single_multi_metric_compare.csv'));
  end
end

function cfg = default_cfg()
  cfg.n = 32768;
  cfg.seed = 29;
  cfg.drive_peak = 0.38;
  cfg.recon_taps = 255;
  cfg.passband_norm = 0.035;
  cfg.rf_bandpass_bw = 0.10;
  cfg.rf_bandpass_trans = 0.03;
  cfg.align_max_lag = 16;
  cfg.multibit_list = [4];
  cfg.write_csv = true;
end

function [native, rfrec] = eval_pair(yi, yq, x, cfg)
  h = lowpass_coeff(cfg.recon_taps, cfg.passband_norm);
  gd = floor(numel(h) / 2);

  y_native = filter(h, 1, yi(:)) + 1j * filter(h, 1, yq(:));
  x_native = filter(h, 1, x(:));
  y_native = y_native(gd+1:end);
  x_native = x_native(gd+1:end);
  [ya, xa] = align_and_gain(y_native, x_native, cfg.align_max_lag);
  native = calc_sndr_evm(ya, xa);

  rf = fs4_duc(yi(:), yq(:));
  rf = ideal_rf_bandpass(rf, cfg);
  y_rf = recover_fs4_iq(rf, h);
  y_rf = y_rf(gd+1:end);
  x_rf = x(:);
  x_rf = x_rf(1:min(numel(x_rf), numel(y_rf)));
  y_rf = y_rf(1:numel(x_rf));
  [yr, xr] = align_and_gain(y_rf, x_rf, cfg.align_max_lag);
  rfrec = calc_sndr_evm(yr, xr);
end

function y = single_to_float(raw, alg)
  alg = lower(string(alg));
  y = double(raw(:));
  if startsWith(alg, "mash")
    return;
  end
  y(y == 0) = -1;
end

function rf = fs4_duc(i_data, q_data)
  n = (0:numel(i_data)-1).';
  ph = mod(n, 4);
  rf = zeros(numel(i_data), 1);
  rf(ph == 0) = +i_data(ph == 0);
  rf(ph == 1) = +q_data(ph == 1);
  rf(ph == 2) = -i_data(ph == 2);
  rf(ph == 3) = -q_data(ph == 3);
end

function y = recover_fs4_iq(rf, h)
  n = (0:numel(rf)-1).';
  lo_i = cos(pi/2 * n);
  lo_q = sin(pi/2 * n);
  i_mix = 2 * rf(:) .* lo_i;
  q_mix = 2 * rf(:) .* lo_q;
  y = filter(h, 1, i_mix) + 1j * filter(h, 1, q_mix);
end

function y = ideal_rf_bandpass(x, cfg)
  n = numel(x);
  X = fftshift(fft(x(:)));
  f = ((0:n-1).' - floor(n/2)) / n;
  fc = 0.25;
  g = raised_cosine_band(abs(f), fc - cfg.rf_bandpass_bw/2, ...
                         fc + cfg.rf_bandpass_bw/2, cfg.rf_bandpass_trans);
  y = real(ifft(ifftshift(X .* g)));
end

function g = raised_cosine_band(fabs, f1, f2, trans)
  g = zeros(size(fabs));
  g(fabs >= f1 & fabs <= f2) = 1;
  lo = fabs >= (f1 - trans) & fabs < f1;
  hi = fabs > f2 & fabs <= (f2 + trans);
  if any(lo)
    t = (fabs(lo) - (f1 - trans)) / max(trans, eps);
    g(lo) = 0.5 - 0.5*cos(pi*t);
  end
  if any(hi)
    t = (fabs(hi) - f2) / max(trans, eps);
    g(hi) = 0.5 + 0.5*cos(pi*t);
  end
end

function x = make_bandlimited_iq(cfg)
  n = (0:cfg.n-1).';
  tones = [0.0041 0.0083 0.0137 0.0211];
  ph = 2*pi*rand(1, numel(tones));
  x = zeros(cfg.n, 1);
  for k = 1:numel(tones)
    x = x + exp(1j * (2*pi*tones(k)*n + ph(k)));
  end
  x = x / max(abs(x)) * cfg.drive_peak;
end

function [y_al, x_al, best_lag] = align_and_gain(y, x, max_lag)
  y = y(:);
  x = x(:);
  trim = min(512, floor(min(numel(y), numel(x)) / 16));
  if trim > 0
    y = y(1+trim:end-trim);
    x = x(1+trim:end-trim);
  end
  best_metric = -inf;
  best_lag = 0;
  best_y = [];
  best_x = [];
  for lag = -max_lag:max_lag
    if lag >= 0
      yy = y(1+lag:min(numel(y), lag+numel(x)));
      xx = x(1:numel(yy));
    else
      xx = x(1-lag:min(numel(x), numel(y)-lag));
      yy = y(1:numel(xx));
    end
    if numel(xx) < 1024
      continue;
    end
    c = (yy' * xx) / (yy' * yy + eps);
    yy = yy * c;
    metric = abs(xx' * yy) / sqrt((xx' * xx + eps) * (yy' * yy + eps));
    if metric > best_metric
      best_metric = metric;
      best_lag = lag;
      best_y = yy;
      best_x = xx;
    end
  end
  y_al = best_y;
  x_al = best_x;
end

function m = calc_sndr_evm(y_hat, x_ref)
  e = y_hat - x_ref;
  ps = mean(abs(x_ref).^2);
  pe = mean(abs(e).^2);
  m.SNDR_dB = 10 * log10((ps + eps) / (pe + eps));
  m.EVM_rms_percent = sqrt((pe + eps) / (ps + eps)) * 100;
end

function h = lowpass_coeff(ntaps, fc)
  mid = (ntaps - 1) / 2;
  n = (0:ntaps-1) - mid;
  h = 2 * fc * sinc_local(2 * fc * n) .* hamming_local(ntaps);
  h = h / sum(h);
end

function y = sinc_local(x)
  y = ones(size(x));
  nz = abs(x) > 1e-12;
  y(nz) = sin(pi*x(nz)) ./ (pi*x(nz));
end

function w = hamming_local(n)
  k = 0:n-1;
  w = (0.54 - 0.46*cos(2*pi*k/(n-1))).';
end

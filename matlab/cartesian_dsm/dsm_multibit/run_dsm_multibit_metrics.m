function T = run_dsm_multibit_metrics(varargin)
%RUN_DSM_MULTIBIT_METRICS Native-domain metrics for exploratory multibit DSMs.
%
% This is a MATLAB-only exploration check. It verifies output code ranges and
% estimates native complex-baseband EVM/SNDR after ideal low-pass
% reconstruction. These models are not RTL bit-true yet.

  cfg = default_cfg();
  for k = 1:2:numel(varargin)
    cfg.(varargin{k}) = varargin{k + 1};
  end

  rng(cfg.seed);
  x = make_bandlimited_iq(cfg);
  xi = int64(round(real(x) * 32767));
  xq = int64(round(imag(x) * 32767));

  algs = ["lp1", "lp2", "ef1", "ef2", "mash11", "mash111", "mash22"];
  rows = cell(numel(algs), 1);

  h = lowpass_coeff(cfg.recon_taps, cfg.passband_norm);
  gd = floor(numel(h) / 2);

  for ia = 1:numel(algs)
    alg = algs(ia);
    yi = dsm_multibit_model(xi, alg, cfg.nbits);
    yq = dsm_multibit_model(xq, alg, cfg.nbits);
    y = double(yi) + 1j * double(yq);

    y_rec = filter(h, 1, y);
    x_rec = filter(h, 1, x);
    y_rec = y_rec(gd+1:end);
    x_rec = x_rec(gd+1:end);

    [y_al, x_al, lag] = align_and_gain(y_rec, x_rec, cfg.align_max_lag);
    q = calc_sndr_evm(y_al, x_al);

    all_codes = [yi(:); yq(:)];
    rows{ia} = {char(alg), cfg.nbits, min(all_codes), max(all_codes), ...
                numel(unique(all_codes)), max(abs(all_codes)), ...
                lag, q.EVM_rms_percent, q.SNDR_dB};
  end

  T = cell2table(vertcat(rows{:}), 'VariableNames', ...
      {'algorithm','nbits','min_code','max_code','num_levels_seen', ...
       'max_abs_code','align_lag','native_EVM_percent','native_SNDR_dB'});

  if cfg.write_csv
    out_dir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                       'out', 'dsm_multibit');
    if ~exist(out_dir, 'dir')
      mkdir(out_dir);
    end
    writetable(T, fullfile(out_dir, 'dsm_multibit_metrics.csv'));
  end
end

function cfg = default_cfg()
  cfg.nbits = 4;
  cfg.n = 32768;
  cfg.seed = 23;
  cfg.drive_peak = 0.38;
  cfg.recon_taps = 255;
  cfg.passband_norm = 0.035;
  cfg.align_max_lag = 16;
  cfg.write_csv = true;
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

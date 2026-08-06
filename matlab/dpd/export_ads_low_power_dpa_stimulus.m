function S = export_ads_low_power_dpa_stimulus(varargin)
% Export a project-compatible one-bit PWL stimulus for the ADS DPA baseline.
%
% This exporter models the digital chain through an optional fixed-point DPD,
% LPDSM2, x32 ideal
% band-limited interpolation, and Fs/4 I/Q merge. It intentionally does not
% model the PA or the ADS reconstruction filter. The output files form the
% fixed interface between the DSM/DPD MATLAB flow and the circuit simulator.

  cfg.n_symbols = 8;
  cfg.n_samples = 256;
  cfg.seed = 211;
  cfg.vdd_v = 1.2;
  cfg.bb_fs_hz = 3.125e6;
  cfg.osr = 32;
  cfg.nfft = 128;
  cfg.ncp = 16;
  cfg.nused = 12;
  cfg.qam_order = 16;
  cfg.input_backoff = 0.45;
  cfg.edge_s = 10e-12;
  cfg.dpd_coeff_q = [];
  cfg.dpd_taps = 4;
  cfg.dpd_orders = [1 3 5];
  cfg.dpd_drive_limit = 0.75;
  cfg.file_stem = 'rf_bit_samples';
  cfg.out_dir = '';
  cfg = parse_kv(cfg, varargin{:});
  cfg.fs_hz = cfg.bb_fs_hz * cfg.osr;
  cfg.if_hz = cfg.fs_hz / 4;
  assert(cfg.edge_s > 0 && cfg.edge_s < 1/cfg.fs_hz, ...
    'edge_s must be positive and shorter than one DSM sample.');

  repo = fileparts(fileparts(fileparts(mfilename('fullpath'))));
  if isempty(cfg.out_dir)
    cfg.out_dir = fullfile(repo, 'ads', 'low_power_dpa', 'data');
  end
  if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end

  x = make_ofdm(cfg);
  dpd_saturation_count = 0;
  dpd_limit_count = 0;
  if ~isempty(cfg.dpd_coeff_q)
    [x, dpd_saturation_count] = apply_q214_memory_poly(x, cfg);
    [x, dpd_limit_count] = limit_drive(x, cfg.dpd_drive_limit);
  end
  high_rate = bandlimited_interpolate(x, cfg.osr);
  i_bit = lp_dsm2_bit(real(high_rate));
  q_bit = lp_dsm2_bit(imag(high_rate));
  phase = mod((0:numel(high_rate)-1).', 4);
  rf_signed = i_bit;
  rf_signed(phase == 1) = q_bit(phase == 1);
  rf_signed(phase == 2) = -i_bit(phase == 2);
  rf_signed(phase == 3) = -q_bit(phase == 3);
  rf_bit = rf_signed > 0;
  assert(cfg.n_samples >= 16 && cfg.n_samples <= numel(rf_bit), ...
    'n_samples must be between 16 and %d for this waveform.', numel(rf_bit));
  rf_bit = rf_bit(1:cfg.n_samples);
  rf_signed = rf_signed(1:cfg.n_samples);

  t = (0:numel(rf_bit)-1).' / cfg.fs_hz;
  drive_hi = cfg.vdd_v * double(rf_bit);
  drive_lo = cfg.vdd_v - drive_hi;
  samples = table((0:numel(rf_bit)-1).', t, double(rf_bit), rf_signed, ...
    drive_hi, drive_lo, 'VariableNames', {'sample_index', 'time_s', 'rf_bit', ...
    'rf_signed', 'drive_hi_v', 'drive_lo_v'});
  writetable(samples, fullfile(cfg.out_dir, [cfg.file_stem '.csv']));

  write_pwl(fullfile(cfg.out_dir, [cfg.file_stem '_drive_hi_pwl.txt']), drive_hi, cfg);
  write_pwl(fullfile(cfg.out_dir, [cfg.file_stem '_drive_lo_pwl.txt']), drive_lo, cfg);
  manifest = table(cfg.fs_hz, cfg.if_hz, cfg.bb_fs_hz, cfg.osr, cfg.vdd_v, ...
    cfg.n_symbols, cfg.seed, numel(rf_bit), cfg.edge_s, ...
    mean(double(rf_bit)), 'VariableNames', {'fs_hz', 'if_hz', 'bb_fs_hz', ...
    'osr', 'vdd_v', 'n_symbols', 'seed', 'samples', 'pwl_edge_s', ...
    'rf_bit_one_fraction'});
  writetable(manifest, fullfile(cfg.out_dir, [cfg.file_stem '_manifest.csv']));

  S = struct('samples', numel(rf_bit), 'fs_hz', cfg.fs_hz, ...
    'if_hz', cfg.if_hz, 'out_dir', cfg.out_dir, ...
    'rf_bit_one_fraction', mean(double(rf_bit)), ...
    'dpd_enabled', ~isempty(cfg.dpd_coeff_q), ...
    'dpd_saturation_count', dpd_saturation_count, ...
    'dpd_limit_count', dpd_limit_count, ...
    'path', fullfile(cfg.out_dir, [cfg.file_stem '.csv']));
  fprintf('ADS DPA stimulus exported: %d samples at %.3f MHz to %s\n', ...
    S.samples, S.fs_hz/1e6, S.path);
end

function x = make_ofdm(cfg)
  rng(cfg.seed, 'twister');
  X = zeros(cfg.nfft, cfg.n_symbols);
  used = [(cfg.nfft/2-cfg.nused/2+1):(cfg.nfft/2), ...
    (cfg.nfft/2+2):(cfg.nfft/2+1+cfg.nused/2)];
  side = sqrt(cfg.qam_order);
  symbols = randi([0 cfg.qam_order-1], numel(used), cfg.n_symbols);
  i = mod(symbols, side);
  q = floor(symbols / side);
  X(used, :) = complex(2*i-(side-1), 2*q-(side-1));
  X = X / sqrt(mean(abs(X(used, :)).^2, 'all'));
  x = ifft(ifftshift(X, 1), cfg.nfft, 1);
  x = [x(end-cfg.ncp+1:end, :); x];
  x = x(:);
  x = cfg.input_backoff * x / max(abs(x) + eps);
  x = quantize_q15(x);
end

function y = bandlimited_interpolate(x, factor)
  n = numel(x);
  X = fftshift(fft(x(:)));
  Y = zeros(n * factor, 1);
  first = floor((numel(Y)-n)/2) + 1;
  Y(first:first+n-1) = X;
  y = ifft(ifftshift(Y)) * factor;
end

function bits = lp_dsm2_bit(x)
  q15 = int64(saturate_signed(round(x(:) * 2^15), 16));
  bits = 2 * double(dsm_singlebit_model(q15, 'lp2')) - 1;
end

function x = quantize_q15(x)
  re = saturate_signed(round(real(x) * 2^15), 16) / 2^15;
  im = saturate_signed(round(imag(x) * 2^15), 16) / 2^15;
  x = complex(re, im);
end

function y = saturate_signed(x, width)
  lo = -2^(width-1);
  hi = 2^(width-1)-1;
  y = min(max(x, lo), hi);
end

function [y, saturation_count] = apply_q214_memory_poly(x, cfg)
% Match the project Q1.15/Q2.14 memory-polynomial execution convention.
  expected = cfg.dpd_taps * numel(cfg.dpd_orders);
  assert(numel(cfg.dpd_coeff_q) == expected, ...
    'dpd_coeff_q must contain %d Q2.14 complex coefficients.', expected);
  q_i = int64(saturate_signed(round(real(x(:))*2^15), 16));
  q_q = int64(saturate_signed(round(imag(x(:))*2^15), 16));
  acc_i = zeros(numel(x), 1, 'int64');
  acc_q = zeros(numel(x), 1, 'int64');
  for tap = 0:cfg.dpd_taps-1
    ii = [zeros(tap, 1, 'int64'); q_i(1:end-tap)];
    qq = [zeros(tap, 1, 'int64'); q_q(1:end-tap)];
    r2 = bitsra(ii.*ii + qq.*qq, 15);
    % Q1.15 unity: the C1 path must start at 2^15 before the Q2.14 product.
    radial = int64(2^15);
    gr = int64(0); gi = int64(0);
    base = tap * numel(cfg.dpd_orders);
    for order_idx = 1:numel(cfg.dpd_orders)
      assert(cfg.dpd_orders(order_idx) == 2*order_idx-1, ...
        'Only consecutive odd DPD orders [1 3 ...] are supported.');
      if order_idx > 1, radial = bitsra(radial .* r2, 15); end
      coeff = cfg.dpd_coeff_q(base + order_idx);
      gr = gr + bitsra(int64(round(real(coeff))) .* radial, 15);
      gi = gi + bitsra(int64(round(imag(coeff))) .* radial, 15);
    end
    acc_i = acc_i + bitsra(ii.*gr - qq.*gi, 14);
    acc_q = acc_q + bitsra(ii.*gi + qq.*gr, 14);
  end
  yi = saturate_signed(acc_i, 16);
  yq = saturate_signed(acc_q, 16);
  saturation_count = sum(yi ~= acc_i | yq ~= acc_q);
  y = double(yi)/2^15 + 1j*double(yq)/2^15;
end

function [y, count] = limit_drive(x, limit)
  y = x(:);
  over = abs(y) > limit;
  y(over) = y(over) .* limit ./ abs(y(over));
  count = sum(over);
end

function write_pwl(path, values, cfg)
  ts = 1 / cfg.fs_hz;
  n = numel(values);
  fid = fopen(path, 'w');
  assert(fid >= 0, 'Cannot open PWL output: %s', path);
  cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '%.15g %.15g\n', 0, values(1));
  for k = 2:n
    t0 = (k-1) * ts;
    fprintf(fid, '%.15g %.15g\n', t0-cfg.edge_s, values(k-1));
    fprintf(fid, '%.15g %.15g\n', t0, values(k));
  end
  fprintf(fid, '%.15g %.15g\n', n*ts, values(end));
end

function cfg = parse_kv(cfg, varargin)
  assert(mod(numel(varargin), 2) == 0, 'Use name/value pairs.');
  for k = 1:2:numel(varargin)
    name = char(varargin{k});
    assert(isfield(cfg, name), 'Unsupported option: %s', name);
    cfg.(name) = varargin{k+1};
  end
end

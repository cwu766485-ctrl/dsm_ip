function T = run_dpd_fixed_baseline(varargin)
% run_dpd_fixed_baseline
% Fixed-point sanity model for the planned RTL polynomial DPD block.
%
% Datapath convention:
%   input I/Q: signed Q1.15
%   coefficients: signed Q2.14
%   terms: x * (c1 + c3*|x|^2 + c5*|x|^4)

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});

  rng(cfg.seed);
  x = make_ofdm_source(cfg);
  x = cfg.input_backoff * x(:) / max(abs(x(:)) + eps);

  y_pa = memoryless_pa(x, cfg.pa);
  coeff_float = fit_memoryless_poly(y_pa, x, cfg.poly_order, cfg.ridge);
  coeff_q = quantize_signed(coeff_float, cfg.coeff_frac, cfg.coeff_w);

  x_dpd_float = apply_memoryless_poly(x, coeff_float, cfg.poly_order);
  x_dpd_fixed = dpd_poly_fixed_model(x, coeff_q, cfg);

  y_float = memoryless_pa(limit_drive(x_dpd_float, cfg.dpd_drive_limit), cfg.pa);
  y_fixed = memoryless_pa(limit_drive(x_dpd_fixed, cfg.dpd_drive_limit), cfg.pa);

  rows = repmat(empty_row(), 3, 1);
  rows(1) = eval_case("PA_only", x, y_pa, cfg);
  rows(2) = eval_case("Float_DPD_plus_PA", x, y_float, cfg);
  rows(3) = eval_case("Fixed_DPD_plus_PA", x, y_fixed, cfg);
  T = struct2table(rows);

  out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  if ~exist(out_dir, 'dir')
    mkdir(out_dir);
  end

  writetable(T, fullfile(out_dir, 'dpd_fixed_baseline.csv'));
  write_summary_md(T, cfg, coeff_float, coeff_q, fullfile(out_dir, 'dpd_fixed_baseline.md'));
  save(fullfile(out_dir, 'dpd_fixed_baseline.mat'), 'cfg', 'T', 'coeff_float', 'coeff_q');

  disp(T);
end

function y = dpd_poly_fixed_model(x, coeff_q, cfg)
  xi = quantize_signed(real(x), cfg.input_frac, cfg.input_w);
  xq = quantize_signed(imag(x), cfg.input_frac, cfg.input_w);

  c1r = real(coeff_q(1)); c1i = imag(coeff_q(1));
  c3r = real(coeff_q(2)); c3i = imag(coeff_q(2));
  c5r = real(coeff_q(3)); c5i = imag(coeff_q(3));

  yi = zeros(size(xi));
  yq = zeros(size(xq));
  for n = 1:numel(xi)
    i = int64(xi(n));
    q = int64(xq(n));
    r2 = bitsra(i*i + q*q, cfg.input_frac);
    r4 = bitsra(r2*r2, cfg.input_frac);

    gr = int64(c1r) + bitsra(int64(c3r)*r2, cfg.input_frac) + bitsra(int64(c5r)*r4, cfg.input_frac);
    gi = int64(c1i) + bitsra(int64(c3i)*r2, cfg.input_frac) + bitsra(int64(c5i)*r4, cfg.input_frac);

    io = bitsra(i*gr - q*gi, cfg.coeff_frac);
    qo = bitsra(i*gi + q*gr, cfg.coeff_frac);
    yi(n) = saturate_int(io, cfg.input_w);
    yq(n) = saturate_int(qo, cfg.input_w);
  end

  y = double(yi) / 2^cfg.input_frac + 1j * double(yq) / 2^cfg.input_frac;
end

function cfg = default_cfg()
  cfg.seed = 7;
  cfg.nfft = 256;
  cfg.ncp = 32;
  cfg.nsym = 96;
  cfg.nused = 48;
  cfg.qam_order = 16;
  cfg.fs_hz = 100e6;
  cfg.channel_bw_hz = 20e6;
  cfg.adjacent_offset_hz = 20e6;
  cfg.input_backoff = 0.58;
  cfg.dpd_drive_limit = 0.92;
  cfg.poly_order = 5;
  cfg.ridge = 1e-7;
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_w = 16;
  cfg.coeff_frac = 14;
  cfg.pa.c1 = 1.0 + 0.00j;
  cfg.pa.c3 = -0.52 + 0.24j;
  cfg.pa.c5 = 0.18 - 0.16j;
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0
    error('Arguments must be key/value pairs.');
  end
  for k = 1:2:numel(varargin)
    key = varargin{k};
    val = varargin{k+1};
    if ~isfield(cfg, key)
      error('Unknown configuration field: %s', key);
    end
    cfg.(key) = val;
  end
end

function x = make_ofdm_source(cfg)
  used = used_subcarriers(cfg.nfft, cfg.nused);
  X = zeros(cfg.nfft, cfg.nsym);
  data = qammod_square(randi([0 cfg.qam_order-1], numel(used), cfg.nsym), cfg.qam_order);
  X(used, :) = data;
  td = ifft(ifftshift(X, 1), cfg.nfft, 1);
  td_cp = [td(end-cfg.ncp+1:end, :); td];
  x = td_cp(:);
  x = x / rms(abs(x));
end

function used = used_subcarriers(nfft, nused)
  neg = (nfft/2 - nused/2 + 1):(nfft/2);
  pos = (nfft/2 + 2):(nfft/2 + 1 + nused/2);
  used = [neg pos];
end

function s = qammod_square(idx, M)
  m = sqrt(M);
  ii = mod(idx, m);
  qq = floor(idx ./ m);
  re = 2*ii - (m - 1);
  im = 2*qq - (m - 1);
  s = complex(re, im);
  s = s / sqrt(mean(abs(s(:)).^2));
end

function y = memoryless_pa(x, pa)
  r2 = abs(x).^2;
  y = pa.c1 .* x + pa.c3 .* x .* r2 + pa.c5 .* x .* (r2.^2);
end

function coeff = fit_memoryless_poly(in_sig, target, order, ridge)
  A = poly_basis(in_sig, order);
  coeff = (A' * A + ridge * eye(size(A, 2))) \ (A' * target(:));
end

function y = apply_memoryless_poly(x, coeff, order)
  y = poly_basis(x, order) * coeff;
end

function A = poly_basis(x, order)
  x = x(:);
  powers = 1:2:order;
  A = zeros(numel(x), numel(powers));
  for k = 1:numel(powers)
    A(:, k) = x .* (abs(x).^(powers(k) - 1));
  end
end

function y = limit_drive(x, limit)
  scale = limit / max(abs(x) + eps);
  if scale < 1
    y = x * scale;
  else
    y = x;
  end
end

function q = quantize_signed(x, frac, width)
  maxv = 2^(width-1) - 1;
  minv = -2^(width-1);
  qr = min(max(round(real(x) * 2^frac), minv), maxv);
  qi = min(max(round(imag(x) * 2^frac), minv), maxv);
  q = complex(qr, qi);
end

function y = saturate_int(x, width)
  maxv = int64(2^(width-1) - 1);
  minv = int64(-2^(width-1));
  y = min(max(int64(x), minv), maxv);
end

function row = eval_case(name, ref, y, cfg)
  [ya, xa] = align_gain(y, ref);
  ev = calc_evm_sndr(ya, xa);
  ac = calc_aclr(y, cfg.fs_hz, cfg.channel_bw_hz, cfg.adjacent_offset_hz);
  row = empty_row();
  row.Case = string(name);
  row.EVM_percent = ev.EVM_percent;
  row.SNDR_dB = ev.SNDR_dB;
  row.ACLR_L_dBc = ac.ACLR_L_dBc;
  row.ACLR_R_dBc = ac.ACLR_R_dBc;
  row.ACLR_avg_dBc = mean([ac.ACLR_L_dBc ac.ACLR_R_dBc]);
  row.PAPR_dB = 10*log10(max(abs(y).^2) / mean(abs(y).^2));
end

function row = empty_row()
  row = struct('Case', string(""), 'EVM_percent', NaN, 'SNDR_dB', NaN, ...
    'ACLR_L_dBc', NaN, 'ACLR_R_dBc', NaN, 'ACLR_avg_dBc', NaN, 'PAPR_dB', NaN);
end

function [ya, xa] = align_gain(y, x)
  n = min(numel(y), numel(x));
  y = y(1:n);
  x = x(1:n);
  ya = y * ((y' * x) / (y' * y + eps));
  xa = x;
end

function m = calc_evm_sndr(y, x)
  e = y(:) - x(:);
  ps = mean(abs(x(:)).^2);
  pe = mean(abs(e).^2);
  m.EVM_percent = sqrt((pe + eps) / (ps + eps)) * 100;
  m.SNDR_dB = 10*log10((ps + eps) / (pe + eps));
end

function m = calc_aclr(y, Fs, BWch, adjOffset)
  y = y(:);
  nfft = 8192;
  win = hann_local(min(4096, numel(y)));
  [Pxx, f] = welch_psd(y, win, floor(numel(win)/2), nfft, Fs);
  main = abs(f) <= BWch/2;
  left = (f >= -adjOffset - BWch/2) & (f <= -adjOffset + BWch/2);
  right = (f >= adjOffset - BWch/2) & (f <= adjOffset + BWch/2);
  pch = sum(Pxx(main)) + eps;
  m.ACLR_L_dBc = 10*log10((sum(Pxx(left)) + eps) / pch);
  m.ACLR_R_dBc = 10*log10((sum(Pxx(right)) + eps) / pch);
end

function [Pavg, f] = welch_psd(x, win, noverlap, nfft, Fs)
  step = numel(win) - noverlap;
  nseg = max(1, floor((numel(x) - noverlap) / step));
  Pavg = zeros(nfft, 1);
  for s = 1:nseg
    idx0 = (s - 1) * step + 1;
    idx = idx0:(idx0 + numel(win) - 1);
    if idx(end) > numel(x), break; end
    X = fftshift(fft(x(idx) .* win, nfft));
    Pavg = Pavg + abs(X).^2 / max(sum(abs(win).^2), eps);
  end
  Pavg = Pavg / max(nseg, 1);
  f = ((0:nfft-1).' - nfft/2) / nfft * Fs;
end

function w = hann_local(n)
  k = (0:n-1).';
  w = 0.5 - 0.5*cos(2*pi*k/max(n-1, 1));
end

function write_summary_md(T, cfg, coeff_float, coeff_q, path)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot write %s', path); end
  cleanup = onCleanup(@() fclose(fid));
  fprintf(fid, '# Fixed-Point Polynomial DPD Baseline\n\n');
  fprintf(fid, '- Input: Q1.%d, signed %d-bit\n', cfg.input_frac, cfg.input_w);
  fprintf(fid, '- Coefficients: Q2.%d, signed %d-bit\n\n', cfg.coeff_frac, cfg.coeff_w);
  fprintf(fid, '## Coefficients\n\n');
  fprintf(fid, '| Term | Float real | Float imag | Quant real | Quant imag |\n');
  fprintf(fid, '|---:|---:|---:|---:|---:|\n');
  powers = 1:2:cfg.poly_order;
  for k = 1:numel(coeff_float)
    fprintf(fid, '| x*abs(x)^%d | %.12g | %.12g | %d | %d |\n', powers(k)-1, ...
      real(coeff_float(k)), imag(coeff_float(k)), int32(real(coeff_q(k))), int32(imag(coeff_q(k))));
  end
  fprintf(fid, '\n## Metrics\n\n');
  fprintf(fid, '| Case | EVM %% | SNDR dB | ACLR_avg dBc | PAPR dB |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|\n');
  for k = 1:height(T)
    fprintf(fid, '| %s | %.6f | %.6f | %.6f | %.6f |\n', ...
      T.Case(k), T.EVM_percent(k), T.SNDR_dB(k), T.ACLR_avg_dBc(k), T.PAPR_dB(k));
  end
end

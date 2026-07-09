function T = run_dpd_memoryless_baseline(varargin)
% run_dpd_memoryless_baseline
% First AI-communication-IP baseline: conventional memoryless polynomial DPD.
%
% This model is intentionally independent of RTL. It establishes the
% calibration problem before adding a hardware DPD frontend:
%
%   OFDM/QAM source -> DPD candidate -> behavioral PA -> metrics
%
% The DPD coefficients are learned with an indirect-learning architecture:
% fit a post-distorter that maps PA output back to PA input, then reuse the
% fitted coefficients as a predistorter.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});

  rng(cfg.seed);
  x = make_ofdm_source(cfg);
  x = x(:);
  x = cfg.input_backoff * x / max(abs(x) + eps);

  y_pa = memoryless_pa(x, cfg.pa);
  post_coeff = fit_memoryless_poly(y_pa, x, cfg.poly_order, cfg.ridge);
  x_dpd = apply_memoryless_poly(x, post_coeff, cfg.poly_order);

  scale = cfg.dpd_drive_limit / max(abs(x_dpd) + eps);
  if scale < 1
    x_dpd = x_dpd * scale;
  end

  y_dpd_pa = memoryless_pa(x_dpd, cfg.pa);

  rows = repmat(empty_row(), 2, 1);
  rows(1) = eval_case("PA_only", x, y_pa, cfg);
  rows(2) = eval_case("DPD_plus_PA", x, y_dpd_pa, cfg);
  T = struct2table(rows);

  out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  if ~exist(out_dir, 'dir')
    mkdir(out_dir);
  end

  writetable(T, fullfile(out_dir, 'dpd_memoryless_baseline.csv'));
  write_summary_md(T, cfg, post_coeff, fullfile(out_dir, 'dpd_memoryless_baseline.md'));
  save(fullfile(out_dir, 'dpd_memoryless_baseline.mat'), 'cfg', 'T', 'post_coeff');

  disp(T);
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
  if mod(nused, 2) ~= 0
    error('nused must be even.');
  end
  neg = (nfft/2 - nused/2 + 1):(nfft/2);
  pos = (nfft/2 + 2):(nfft/2 + 1 + nused/2);
  used = [neg pos];
end

function s = qammod_square(idx, M)
  m = sqrt(M);
  if abs(m - round(m)) > 0
    error('qam_order must be a square QAM size.');
  end
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
  lhs = A' * A + ridge * eye(size(A, 2));
  rhs = A' * target(:);
  coeff = lhs \ rhs;
end

function y = apply_memoryless_poly(x, coeff, order)
  A = poly_basis(x, order);
  y = A * coeff;
end

function A = poly_basis(x, order)
  x = x(:);
  powers = 1:2:order;
  A = zeros(numel(x), numel(powers));
  for k = 1:numel(powers)
    p = powers(k);
    A(:, k) = x .* (abs(x).^(p - 1));
  end
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
  row = struct( ...
    'Case', string(""), ...
    'EVM_percent', NaN, ...
    'SNDR_dB', NaN, ...
    'ACLR_L_dBc', NaN, ...
    'ACLR_R_dBc', NaN, ...
    'ACLR_avg_dBc', NaN, ...
    'PAPR_dB', NaN);
end

function [ya, xa] = align_gain(y, x)
  y = y(:);
  x = x(:);
  n = min(numel(y), numel(x));
  y = y(1:n);
  x = x(1:n);
  g = (y' * x) / (y' * y + eps);
  ya = y * g;
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
  if numel(y) < nfft
    nfft = 2^nextpow2(numel(y));
  end
  win = hann_local(min(4096, numel(y)));
  noverlap = floor(numel(win)/2);
  [Pxx, f] = welch_psd(y, win, noverlap, nfft, Fs);

  main = abs(f) <= BWch/2;
  left = (f >= -adjOffset - BWch/2) & (f <= -adjOffset + BWch/2);
  right = (f >= adjOffset - BWch/2) & (f <= adjOffset + BWch/2);

  pch = sum(Pxx(main)) + eps;
  pl = sum(Pxx(left)) + eps;
  pr = sum(Pxx(right)) + eps;

  m.ACLR_L_dBc = 10*log10(pl / pch);
  m.ACLR_R_dBc = 10*log10(pr / pch);
end

function [Pavg, f] = welch_psd(x, win, noverlap, nfft, Fs)
  step = numel(win) - noverlap;
  nseg = max(1, floor((numel(x) - noverlap) / step));
  Pavg = zeros(nfft, 1);
  wnorm = sum(abs(win).^2);
  for s = 1:nseg
    idx0 = (s - 1) * step + 1;
    idx = idx0:(idx0 + numel(win) - 1);
    if idx(end) > numel(x)
      break;
    end
    X = fftshift(fft(x(idx) .* win, nfft));
    Pavg = Pavg + (abs(X).^2) / max(wnorm, eps);
  end
  Pavg = Pavg / max(nseg, 1);
  f = ((0:nfft-1).' - nfft/2) / nfft * Fs;
end

function w = hann_local(n)
  if n <= 1
    w = ones(n, 1);
  else
    k = (0:n-1).';
    w = 0.5 - 0.5*cos(2*pi*k/(n-1));
  end
end

function write_summary_md(T, cfg, coeff, path)
  fid = fopen(path, 'w');
  if fid < 0
    error('Cannot write %s', path);
  end
  cleanup = onCleanup(@() fclose(fid));

  fprintf(fid, '# Memoryless Polynomial DPD Baseline\n\n');
  fprintf(fid, 'This is a MATLAB-only baseline for the planned AI-assisted TX calibration path.\n\n');
  fprintf(fid, '## Configuration\n\n');
  fprintf(fid, '- QAM order: %d\n', cfg.qam_order);
  fprintf(fid, '- NFFT: %d\n', cfg.nfft);
  fprintf(fid, '- Used subcarriers: %d\n', cfg.nused);
  fprintf(fid, '- Symbols: %d\n', cfg.nsym);
  fprintf(fid, '- Polynomial order: %d\n', cfg.poly_order);
  fprintf(fid, '- Input backoff: %.4f\n', cfg.input_backoff);
  fprintf(fid, '- DPD drive limit: %.4f\n\n', cfg.dpd_drive_limit);

  fprintf(fid, '## Learned Coefficients\n\n');
  fprintf(fid, '| Term | Real | Imag |\n');
  fprintf(fid, '|---:|---:|---:|\n');
  powers = 1:2:cfg.poly_order;
  for k = 1:numel(coeff)
    fprintf(fid, '| x*abs(x)^%d | %.12g | %.12g |\n', powers(k)-1, real(coeff(k)), imag(coeff(k)));
  end
  fprintf(fid, '\n## Metrics\n\n');
  fprintf(fid, '| Case | EVM %% | SNDR dB | ACLR_L dBc | ACLR_R dBc | ACLR_avg dBc | PAPR dB |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
  for k = 1:height(T)
    fprintf(fid, '| %s | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f |\n', ...
      T.Case(k), T.EVM_percent(k), T.SNDR_dB(k), T.ACLR_L_dBc(k), ...
      T.ACLR_R_dBc(k), T.ACLR_avg_dBc(k), T.PAPR_dB(k));
  end
end

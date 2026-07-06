function R = interp_frontend_float(varargin)
% Floating-point reference for the DSM interpolation frontend.
%
% Modes:
%   0 bypass
%   1 x4  halfband FIR cascade
%   2 x8  halfband FIR cascade
%   3 x16 halfband FIR cascade
%   4 x32 halfband x4 + CIC-equivalent FIR x8 + compensation FIR

  cfg = local_cfg(varargin{:});
  if ~exist(cfg.out_dir, 'dir')
    mkdir(cfg.out_dir);
  end

  rng(cfg.seed);
  [xi, xq] = make_stimulus(cfg.n_input, cfg.signal_bw);

  modes = 0:4;
  rows = cell(numel(modes), 1);
  for k = 1:numel(modes)
    mode = modes(k);
    mcfg = mode_cfg(mode);
    [yi, yq, st] = run_float_chain(xi, xq, mcfg);

    write_vector(fullfile(cfg.out_dir, sprintf('mode%d_float_iq.csv', mode)), yi, yq);
    write_response(fullfile(cfg.out_dir, sprintf('mode%d_response.csv', mode)), st.h_total, cfg.n_fft);

    rows{k} = {mode, mcfg.interp, numel(st.h_total), st.group_delay_out, ...
               response_ripple_db(st.h_total, mcfg.interp, cfg.signal_bw, cfg.n_fft), ...
               max(abs(yi + 1j*yq))};
  end

  R = cell2table(vertcat(rows{:}), 'VariableNames', ...
      {'mode','interp','fir_equiv_taps','group_delay_out','passband_ripple_db','peak_abs'});
  writetable(R, fullfile(cfg.out_dir, 'interp_frontend_float_summary.csv'));
  save(fullfile(cfg.out_dir, 'interp_frontend_float_coeffs.mat'), 'R');
end

function cfg = local_cfg(varargin)
  cfg.n_input = 2048;
  cfg.signal_bw = 0.08;       % Fraction of input sample rate, one-sided.
  cfg.n_fft = 16384;
  cfg.seed = 7;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'interp_frontend');
  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end
end

function m = mode_cfg(mode)
  m.mode = mode;
  switch mode
    case 0
      m.interp = 1;
      m.hb_stages = 0;
      m.use_cic = false;
    case 1
      m.interp = 4;
      m.hb_stages = 2;
      m.use_cic = false;
    case 2
      m.interp = 8;
      m.hb_stages = 3;
      m.use_cic = false;
    case 3
      m.interp = 16;
      m.hb_stages = 4;
      m.use_cic = false;
    case 4
      m.interp = 32;
      m.hb_stages = 2;
      m.use_cic = true;
      m.cic_rate = 8;
      m.cic_order = 4;
    otherwise
      error('Unsupported interpolation mode %d', mode);
  end
  m.hb_taps = 47;
  m.comp_taps = 63;
end

function [yi, yq, st] = run_float_chain(xi, xq, m)
  yi = xi(:);
  yq = xq(:);
  h_total = 1;
  rate = 1;

  for s = 1:m.hb_stages
    h = halfband_interp_coeff(m.hb_taps);
    yi = interp_by_fir(yi, 2, h);
    yq = interp_by_fir(yq, 2, h);
    h_total = cascade_impulse(h_total, rate, h, 2);
    rate = rate * 2;
  end

  if m.use_cic
    hcic = cic_interp_impulse(m.cic_rate, m.cic_order);
    yi = interp_by_fir(yi, m.cic_rate, hcic);
    yq = interp_by_fir(yq, m.cic_rate, hcic);
    h_total = cascade_impulse(h_total, rate, hcic, m.cic_rate);
    rate = rate * m.cic_rate;

    hcomp = cic_comp_coeff(m.comp_taps, m.cic_rate, m.cic_order);
    yi = filter(hcomp, 1, yi);
    yq = filter(hcomp, 1, yq);
    h_total = conv(h_total, hcomp);
  end

  st.h_total = h_total(:);
  st.group_delay_out = (numel(h_total) - 1) / 2;
end

function [xi, xq] = make_stimulus(n, bw)
  t = (0:n-1).';
  tones = [0.011 0.019 0.037 0.061] * min(1, bw / 0.08);
  x = zeros(n, 1);
  for k = 1:numel(tones)
    ph = 2*pi*rand(1);
    x = x + exp(1j * (2*pi*tones(k)*t + ph));
  end
  x = x / max(abs(x)) * 0.65;
  xi = real(x);
  xq = imag(x);
end

function h = halfband_interp_coeff(ntaps)
  if mod(ntaps, 2) == 0
    error('Halfband tap count must be odd');
  end
  mid = (ntaps - 1) / 2;
  n = (0:ntaps-1) - mid;
  h = sinc_local(0.5 * n);
  w = hamming_local(ntaps);
  h = h .* w;
  h(abs(h) < 1e-14) = 0;
  h = h * (2 / sum(h));       % Interpolation-by-2 DC gain.
end

function h = cic_interp_impulse(rate, order)
  h = ones(1, rate);
  for k = 2:order
    h = conv(h, ones(1, rate));
  end
  h = h / (rate^(order - 1)); % Interpolation DC gain = rate.
end

function h = cic_comp_coeff(ntaps, rate, order)
  ngrid = 512;
  f = linspace(0, 0.5, ngrid).';
  fp = 0.025;
  fs = 0.060;
  cic = abs(sin(pi*f*rate) ./ (rate * sin(pi*f)));
  cic(1) = 1;
  cic = cic .^ order;
  desired = zeros(size(f));
  pass = f <= fp;
  trans = f > fp & f < fs;
  desired(pass) = 1 ./ max(cic(pass), 0.08);
  desired(trans) = linspace(desired(find(pass, 1, 'last')), 0, nnz(trans)).';
  weight = ones(size(f));
  weight(pass) = 8;
  h = fir_ls_linear_phase(ntaps, f, desired, weight);
  h = h * (1 / sum(h));
end

function h = fir_ls_linear_phase(ntaps, f, desired, weight)
  mid = (ntaps - 1) / 2;
  k = 0:mid;
  A = cos(2*pi*f*k);
  W = diag(weight);
  c = (A' * W * A) \ (A' * W * desired);
  h = zeros(1, ntaps);
  h(mid + 1) = c(1);
  for n = 1:mid
    h(mid + 1 - n) = c(n + 1) / 2;
    h(mid + 1 + n) = c(n + 1) / 2;
  end
end

function y = interp_by_fir(x, L, h)
  xu = zeros(numel(x) * L, 1);
  xu(1:L:end) = x(:);
  y = filter(h(:), 1, xu);
end

function h = cascade_impulse(h0, old_rate, hstage, L)
  h0u = zeros(1, numel(h0) * L);
  h0u(1:L:end) = h0;
  hstage_at_out = hstage;
  h = conv(h0u, hstage_at_out);
  %#ok<NASGU> old_rate is kept for readability of the cascade operation.
end

function write_vector(path, yi, yq)
  T = table((0:numel(yi)-1).', yi(:), yq(:), 'VariableNames', {'n','i','q'});
  writetable(T, path);
end

function write_response(path, h, nfft)
  H = fft(h(:), nfft);
  f = (0:nfft/2).' / nfft;
  mag = 20*log10(abs(H(1:nfft/2+1)) + 1e-15);
  f = f(:);
  mag = mag(:);
  n = min(numel(f), numel(mag));
  T = table(f(1:n), mag(1:n), 'VariableNames', {'normalized_freq','mag_db'});
  writetable(T, path);
end

function r = response_ripple_db(h, interp, bw, nfft)
  H = fft(h(:), nfft);
  f = (0:nfft/2).' / nfft;
  mag = 20*log10(abs(H(1:nfft/2+1)) / interp + 1e-15);
  idx = f <= bw / max(interp, 1);
  r = max(mag(idx)) - min(mag(idx));
end

function y = sinc_local(x)
  y = ones(size(x));
  nz = abs(x) > 1e-12;
  y(nz) = sin(pi*x(nz)) ./ (pi*x(nz));
end

function w = hamming_local(n)
  k = 0:n-1;
  w = 0.54 - 0.46*cos(2*pi*k/(n-1));
end

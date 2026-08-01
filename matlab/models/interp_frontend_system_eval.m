function T = interp_frontend_system_eval(varargin)
% End-to-end behavioral metrics for the interpolation frontend plus DUC/DSM.
%
% Baseline chain:
%   16-QAM OFDM source -> interpolation frontend -> DSM -> Fs/4 DUC
%   -> ideal downconversion/reconstruction -> symbol-rate alignment
%   -> EVM/SNDR/ACLR.
%
% Optional impairments are disabled by default and are intended for robustness
% sweeps, not for the clean IP baseline.

  cfg = default_cfg();
  for k = 1:2:numel(varargin)
    cfg.(varargin{k}) = varargin{k + 1};
  end
  if ~exist(cfg.out_dir, 'dir')
    mkdir(cfg.out_dir);
  end

  rng(cfg.seed);
  [x_ref, meta] = make_ofdm_source(cfg);
  rows = cell(numel(cfg.modes), 1);

  for im = 1:numel(cfg.modes)
    mode = cfg.modes(im);
    mcfg = mode_cfg(mode);
    mcfg.interp_impl = upper(string(cfg.interp_impl));
    x_tx = interp_chain_complex(x_ref, mcfg);
    x_tx = x_tx / max(abs(x_tx)) * cfg.dsm_drive_peak;

    xi = int64(round(real(x_tx) * 32767));
    xq = int64(round(imag(x_tx) * 32767));
    native_i = real(x_tx);
    native_q = imag(x_tx);
    arch = lower(string(cfg.architecture));
    if strcmpi(cfg.dsm_alg, 'none')
      arch = "none";
    end
    switch arch
      case "none"
        rf = fs4_duc(real(x_tx), imag(x_tx));
      case "iq_lpdsm_fs4"
        yi = dsm_bittrue_dispatch(xi, cfg.dsm_alg, cfg.mb_q_bits);
        yq = dsm_bittrue_dispatch(xq, cfg.dsm_alg, cfg.mb_q_bits);
        native_i = dsm_output_to_float(yi, cfg.dsm_alg, cfg.mb_q_bits);
        native_q = dsm_output_to_float(yq, cfg.dsm_alg, cfg.mb_q_bits);
        rf = fs4_duc(native_i, native_q);
      case "rf_bp_dsm"
        rf_pre = fs4_duc(real(x_tx), imag(x_tx));
        rf = rf_bandpass_dsm(rf_pre, cfg.rf_dsm_bits);
      otherwise
        error('Unknown architecture: %s', string(cfg.architecture));
    end
    rf = apply_rf_impairments(rf, cfg);

    [y_bb, decim_phase] = reconstruct_from_fs4(rf, mcfg.interp, cfg, x_ref);
    [y_al, x_al, delay] = align_and_gain(y_bb, x_ref, cfg.align_max_lag);
    q = lp_calc_sndr_evm(y_al, x_al);
    [y_native, native_phase] = reconstruct_native_iq(native_i, native_q, mcfg.interp, cfg, x_ref);
    [yn_al, xn_al, native_delay] = align_and_gain(y_native, x_ref, cfg.align_max_lag);
    qn = lp_calc_sndr_evm(yn_al, xn_al);
    ac = aclr_local(rf, mcfg.interp, meta.occupied_bw_norm, cfg);

    rows{im} = {mode, mcfg.interp, string(cfg.dsm_alg), delay, ...
                arch, decim_phase, q.EVM_rms_percent, q.SNDR_dB, ac.ACLR_L_dBc, ...
                ac.ACLR_R_dBc, mean([ac.ACLR_L_dBc ac.ACLR_R_dBc]), ...
                native_delay, native_phase, qn.EVM_rms_percent, qn.SNDR_dB, ...
                papr_db(x_ref), papr_db(rf), ...
                cfg.awgn_snr_db, cfg.phase_noise_rms_deg, ...
                cfg.clip_level, cfg.pa_alpha};
  end

  T = cell2table(vertcat(rows{:}), 'VariableNames', ...
      {'mode','interp','dsm_alg','align_delay','architecture','decim_phase','RF_recovered_EVM_percent','RF_recovered_SNDR_dB', ...
       'ACLR_L_dBc','ACLR_R_dBc','ACLR_avg_dBc', ...
       'native_align_delay','native_decim_phase','native_EVM_percent','native_SNDR_dB', ...
       'PAPR_BB_dB','PAPR_RF_dB', ...
       'awgn_snr_db','phase_noise_rms_deg','clip_level','pa_alpha'});
  writetable(T, fullfile(cfg.out_dir, 'interp_frontend_system_metrics.csv'));
end

function cfg = default_cfg()
  repo_matlab = fileparts(fileparts(mfilename('fullpath')));
  cfg.out_dir = fullfile(repo_matlab, 'out', 'interp_frontend');
  cfg.seed = 11;
  cfg.modes = 0:4;
  cfg.interp_impl = 'I0';
  cfg.architecture = 'iq_lpdsm_fs4';
  cfg.dsm_alg = 'ef2';
  cfg.mb_q_bits = 4;
  cfg.rf_dsm_bits = 4;
  cfg.dsm_drive_peak = 0.45;
  cfg.nfft = 64;
  cfg.ncp = 16;
  cfg.nsym = 24;
  cfg.qam_order = 16;
  cfg.used_sc = [-12:-1 1:12];
  cfg.align_max_lag = 3000;
  cfg.recon_taps = 191;
  cfg.rf_bpf_enable = true;
  cfg.rf_bpf_bw_scale = 1.4;
  cfg.rf_bpf_trans_scale = 0.6;
  cfg.psd_nfft = 8192;
  cfg.awgn_snr_db = Inf;
  cfg.phase_noise_rms_deg = 0;
  cfg.clip_level = Inf;
  cfg.pa_alpha = 0;
end

function m = mode_cfg(mode)
  switch mode
    case 0
      m.interp = 1; m.hb_stages = 0; m.use_cic = false;
    case 1
      m.interp = 4; m.hb_stages = 2; m.use_cic = false;
    case 2
      m.interp = 8; m.hb_stages = 3; m.use_cic = false;
    case 3
      m.interp = 16; m.hb_stages = 4; m.use_cic = false;
    case 4
      m.interp = 32; m.hb_stages = 2; m.use_cic = true;
      m.cic_rate = 8; m.cic_order = 4;
    otherwise
      error('Unsupported interpolation mode %d', mode);
  end
  m.hb_taps = 47;
  m.comp_taps = 63;
end

function [x, meta] = make_ofdm_source(cfg)
  used = cfg.used_sc(:);
  data = qammod_square(randi([0 cfg.qam_order-1], numel(used), cfg.nsym), cfg.qam_order);
  X = zeros(cfg.nfft, cfg.nsym);
  bins = mod(used, cfg.nfft) + 1;
  X(bins, :) = data;
  td = ifft(X, cfg.nfft, 1) * sqrt(cfg.nfft);
  cp = [td(end-cfg.ncp+1:end, :); td];
  x = cp(:);
  x = x / rms_local(x) * 0.25;
  meta.occupied_bw_norm = numel(used) / cfg.nfft;
end

function s = qammod_square(idx, M)
  L = sqrt(M);
  if abs(L - round(L)) > 0
    error('Only square QAM is supported');
  end
  idx = double(idx);
  i = mod(idx, L);
  q = floor(idx / L);
  a = 2*i - L + 1;
  b = 2*q - L + 1;
  s = a + 1j*b;
  s = s / sqrt(mean(abs(s(:)).^2));
end

function y = interp_chain_complex(x, m)
  y = x(:);
  if (m.interp == 32) && strcmp(m.interp_impl, "I2")
    h = monolithic_x32_coeff(m);
    y = interp_by_fir(y, 32, h);
    return;
  end
  for s = 1:m.hb_stages
    y = interp_by_fir(y, 2, halfband_interp_coeff(m.hb_taps));
  end
  if m.use_cic
    y = interp_by_fir(y, m.cic_rate, cic_interp_impulse(m.cic_rate, m.cic_order));
    y = filter(cic_comp_coeff(m.comp_taps, m.cic_rate, m.cic_order), 1, y);
  end
end

function h = monolithic_x32_coeff(m)
  h = 1;
  h = cascade_interp_coeff(h, halfband_interp_coeff(m.hb_taps), 2);
  h = cascade_interp_coeff(h, halfband_interp_coeff(m.hb_taps), 2);
  h = cascade_interp_coeff(h, cic_interp_impulse(m.cic_rate, m.cic_order), m.cic_rate);
  h = conv(h, cic_comp_coeff(m.comp_taps, m.cic_rate, m.cic_order));
  h = round(h * 2^16) / 2^16;
  if numel(h) ~= 1195
    error('Unexpected I2 monolithic tap count: %d', numel(h));
  end
end

function h = cascade_interp_coeff(h0, hs, rate)
  up = zeros(1, (numel(h0)-1) * rate + 1);
  up(1:rate:end) = h0;
  h = conv(up, hs);
end

function rf = fs4_duc(i_pm, q_pm)
  n = (0:numel(i_pm)-1).';
  ph = mod(n, 4);
  rf = zeros(numel(i_pm), 1);
  rf(ph == 0) = +i_pm(ph == 0);
  rf(ph == 1) = +q_pm(ph == 1);
  rf(ph == 2) = -i_pm(ph == 2);
  rf(ph == 3) = -q_pm(ph == 3);
end

function [y, best_phase] = reconstruct_from_fs4(rf, interp, cfg, x_ref)
  if cfg.rf_bpf_enable
    rf = apply_ideal_rf_bandpass(rf, interp, cfg);
  end
  n = (0:numel(rf)-1).';
  phi = phase_noise_trace(numel(rf), cfg.phase_noise_rms_deg);
  rfp = rf(:) .* cos(phi);
  ph = mod(n, 4);
  i_sparse = zeros(size(rfp));
  q_sparse = zeros(size(rfp));
  i_sparse(ph == 0) = +rfp(ph == 0);
  q_sparse(ph == 1) = +rfp(ph == 1);
  i_sparse(ph == 2) = -rfp(ph == 2);
  q_sparse(ph == 3) = -rfp(ph == 3);
  h = lowpass_coeff(cfg.recon_taps, 0.42 / max(interp, 1));
  z = 4 * (filter(h, 1, i_sparse) + 1j * filter(h, 1, q_sparse));
  gd = floor(numel(h) / 2);
  z = z(gd+1:end);
  best_evm = inf;
  best_phase = 0;
  y = z(1:interp:end);
  for ph = 0:max(interp - 1, 0)
    yc = z(ph+1:interp:end);
    [ya, xa] = align_and_gain(yc, x_ref, cfg.align_max_lag);
    e = mean(abs(ya - xa).^2) / (mean(abs(xa).^2) + eps);
    if e < best_evm
      best_evm = e;
      best_phase = ph;
      y = yc;
    end
  end
end

function y = rf_bandpass_dsm(x, nbits)
  x = x(:);
  levels = 2^nbits;
  qmax = levels/2 - 1;
  y = zeros(size(x));
  e1 = 0;
  e2 = 0;
  for n = 1:numel(x)
    % NTF approximately (1 + z^-2), placing quantization-noise zeros near
    % Fs/4 after the real RF sequence is formed.
    v = x(n) - e2;
    q = round(v * qmax);
    q = min(max(q, -qmax), qmax);
    y(n) = q / qmax;
    e0 = y(n) - v;
    e2 = e1;
    e1 = e0;
  end
end

function y = apply_ideal_rf_bandpass(x, interp, cfg)
  Fs = interp;
  fc = Fs / 4;
  BW = occupied_bw_from_ref(cfg) * cfg.rf_bpf_bw_scale;
  trans = max(BW * cfg.rf_bpf_trans_scale, 1 / max(numel(x), 1));
  n = numel(x);
  X = fftshift(fft(x(:)));
  f = ((0:n-1).' - floor(n/2)) * (Fs / n);
  g = raised_cosine_band(abs(f), fc - BW/2, fc + BW/2, trans);
  y = real(ifft(ifftshift(X .* g)));
end

function BW = occupied_bw_from_ref(cfg)
  BW = numel(cfg.used_sc) / cfg.nfft;
end

function g = raised_cosine_band(fabs, f1, f2, trans)
  g = zeros(size(fabs));
  pass = fabs >= f1 & fabs <= f2;
  g(pass) = 1;
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

function [y, best_phase] = reconstruct_native_iq(i_data, q_data, interp, cfg, x_ref)
  h = lowpass_coeff(cfg.recon_taps, 0.42 / max(interp, 1));
  z = filter(h, 1, i_data(:)) + 1j * filter(h, 1, q_data(:));
  gd = floor(numel(h) / 2);
  z = z(gd+1:end);
  best_evm = inf;
  best_phase = 0;
  y = z(1:interp:end);
  for ph = 0:max(interp - 1, 0)
    yc = z(ph+1:interp:end);
    [ya, xa] = align_and_gain(yc, x_ref, cfg.align_max_lag);
    e = mean(abs(ya - xa).^2) / (mean(abs(xa).^2) + eps);
    if e < best_evm
      best_evm = e;
      best_phase = ph;
      y = yc;
    end
  end
end

function y = dsm_output_to_float(raw, alg, mb_q_bits)
  alg = lower(string(alg));
  if startsWith(alg, "mb_")
    qmax = 2^(mb_q_bits - 1) - 1;
    y = double(raw(:)) / qmax;
  elseif startsWith(alg, "mash")
    y = double(raw(:));
    scale = max(abs(y));
    if scale > 0
      y = y / scale;
    end
  else
    y = bits_to_pm(raw);
  end
end

function y = dsm_bittrue_dispatch(x, alg, mb_q_bits)
  alg = lower(string(alg));
  if startsWith(alg, "mb_")
    y = dsm_multibit_model(x, extractAfter(alg, "mb_"), mb_q_bits);
  else
    y = p0_dsm_bittrue(x, alg);
  end
end

function rf = apply_rf_impairments(rf, cfg)
  rf = rf(:);
  if isfinite(cfg.clip_level)
    rf = min(max(rf, -cfg.clip_level), cfg.clip_level);
  end
  if cfg.pa_alpha ~= 0
    rf = rf - cfg.pa_alpha * rf.^3;
  end
  if isfinite(cfg.awgn_snr_db)
    p = mean(abs(rf).^2);
    sigma = sqrt(p / 10^(cfg.awgn_snr_db / 10));
    rf = rf + sigma * randn(size(rf));
  end
end

function phi = phase_noise_trace(n, rms_deg)
  if rms_deg == 0
    phi = zeros(n, 1);
  else
    phi = randn(n, 1) * (rms_deg * pi / 180);
  end
end

function [y_al, x_al, best_lag] = align_and_gain(y, x, max_lag)
  y = y(:); x = x(:);
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
    if numel(xx) < 256
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
  trim = min(128, floor(numel(best_x) / 8));
  y_al = best_y(1+trim:end-trim);
  x_al = best_x(1+trim:end-trim);
end

function m = aclr_local(rf, interp, occupied_bw_norm, cfg)
  Fs = interp;
  BWch = min(0.80, occupied_bw_norm);
  adj = BWch;
  nfft = min(cfg.psd_nfft, 2^floor(log2(numel(rf))));
  win = hann_local(min(2048, nfft));
  noverlap = floor(numel(win) / 2);
  [Pxx, f] = pwelch(rf(:), win, noverlap, nfft, Fs, 'centered');
  df = mean(diff(f));
  Pch = band_power(Pxx, f, Fs/4 - BWch/2, Fs/4 + BWch/2, df);
  Pl = band_power(Pxx, f, Fs/4 - adj - BWch/2, Fs/4 - adj + BWch/2, df);
  Pr = band_power(Pxx, f, Fs/4 + adj - BWch/2, Fs/4 + adj + BWch/2, df);
  m.ACLR_L_dBc = 10*log10((Pl + eps) / (Pch + eps));
  m.ACLR_R_dBc = 10*log10((Pr + eps) / (Pch + eps));
end

function P = band_power(Pxx, f, f1, f2, df)
  idx = f >= f1 & f <= f2;
  P = sum(Pxx(idx)) * df;
end

function pm = bits_to_pm(b)
  pm = double(b(:));
  pm(pm == 0) = -1;
end

function h = halfband_interp_coeff(ntaps)
  mid = (ntaps - 1) / 2;
  n = (0:ntaps-1) - mid;
  h = sinc_local(0.5 * n) .* hamming_local(ntaps);
  h(abs(h) < 1e-14) = 0;
  h = h * (2 / sum(h));
end

function h = cic_interp_impulse(rate, order)
  h = ones(1, rate);
  for k = 2:order
    h = conv(h, ones(1, rate));
  end
  h = h / (rate^(order - 1));
end

function h = cic_comp_coeff(ntaps, rate, order)
  ngrid = 512;
  f = linspace(0, 0.5, ngrid).';
  fp = 0.025; fs = 0.060;
  cic = abs(sin(pi*f*rate) ./ (rate * sin(pi*f)));
  cic(1) = 1;
  cic = cic .^ order;
  desired = zeros(size(f));
  pass = f <= fp;
  trans = f > fp & f < fs;
  desired(pass) = 1 ./ max(cic(pass), 0.08);
  desired(trans) = linspace(desired(find(pass, 1, 'last')), 0, nnz(trans)).';
  weight = ones(size(f)); weight(pass) = 8;
  h = fir_ls_linear_phase(ntaps, f, desired, weight);
  h = h * (1 / sum(h));
end

function h = lowpass_coeff(ntaps, fc)
  mid = (ntaps - 1) / 2;
  n = (0:ntaps-1) - mid;
  h = 2 * fc * sinc_local(2 * fc * n) .* hamming_local(ntaps);
  h = h / sum(h);
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

function v = papr_db(x)
  v = 10*log10(max(abs(x(:)).^2) / (mean(abs(x(:)).^2) + eps));
end

function r = rms_local(x)
  r = sqrt(mean(abs(x(:)).^2));
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

function w = hann_local(n)
  k = (0:n-1).';
  w = 0.5 - 0.5*cos(2*pi*k/(n-1));
end

function R = interp_frontend_fixed(varargin)
% Fixed-point reference and bit-true vector export for dsm_interp_frontend.

  cfg = local_cfg(varargin{:});
  if ~exist(cfg.out_dir, 'dir')
    mkdir(cfg.out_dir);
  end

  interp_frontend_float('n_input', cfg.n_input, 'signal_bw', cfg.signal_bw, ...
                        'seed', cfg.seed, 'out_dir', cfg.out_dir);

  rng(cfg.seed);
  [xi_f, xq_f] = make_stimulus(cfg.n_input, cfg.signal_bw);
  xi = sat_int(round(xi_f * (2^(cfg.in_frac))), cfg.in_w);
  xq = sat_int(round(xq_f * (2^(cfg.in_frac))), cfg.in_w);
  write_int_vector(fullfile(cfg.out_dir, 'input_iq_q1_15.csv'), xi, xq);

  modes = 0:4;
  rows = cell(numel(modes), 1);
  for k = 1:numel(modes)
    mode = modes(k);
    mcfg = mode_cfg(mode);
    [yf_i, yf_q] = run_float_chain_public(xi_f, xq_f, mcfg);
    [yi, yq, st] = run_fixed_chain(xi, xq, mcfg, cfg);

    yf_i_q = sat_int(round(yf_i * (2^cfg.out_frac)), cfg.out_w);
    yf_q_q = sat_int(round(yf_q * (2^cfg.out_frac)), cfg.out_w);
    n = min(numel(yi), numel(yf_i_q));
    err = double(yi(1:n) - yf_i_q(1:n)) + 1j * double(yq(1:n) - yf_q_q(1:n));
    ref = double(yf_i_q(1:n)) + 1j * double(yf_q_q(1:n));
    fixed_model_error_snr_db = 20*log10(rms_local(ref) / max(rms_local(err), 1e-12));
    fixed_model_error_evm_pct = 100 * rms_local(err) / max(rms_local(ref), 1e-12);

    write_int_vector(fullfile(cfg.out_dir, sprintf('mode%d_fixed_iq_q1_15.csv', mode)), yi, yq);
    write_coeffs(fullfile(cfg.out_dir, sprintf('mode%d_coefficients.csv', mode)), st.coeff_sets);

    rows{k} = {mode, mcfg.interp, st.num_mult_coeff, st.latency_est, ...
               st.saturation_count, st.overflow_count, ...
               fixed_model_error_snr_db, fixed_model_error_evm_pct};
  end

  R = cell2table(vertcat(rows{:}), 'VariableNames', ...
      {'mode','interp','stored_coefficients','latency_est','saturation_count', ...
       'overflow_count','fixed_model_error_snr_db','fixed_model_error_evm_pct'});
  writetable(R, fullfile(cfg.out_dir, 'interp_frontend_fixed_summary.csv'));
end

function cfg = local_cfg(varargin)
  cfg.n_input = 2048;
  cfg.signal_bw = 0.08;
  cfg.seed = 7;
  cfg.in_w = 16;
  cfg.in_frac = 15;
  cfg.coeff_w = 18;
  cfg.coeff_frac = 16;
  cfg.acc_w = 40;
  cfg.out_w = 16;
  cfg.out_frac = 15;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'interp_frontend');
  for n = 1:2:numel(varargin)
    cfg.(varargin{n}) = varargin{n + 1};
  end
end

function m = mode_cfg(mode)
  switch mode
    case 0
      m.mode = 0; m.interp = 1; m.hb_stages = 0; m.use_cic = false;
    case 1
      m.mode = 1; m.interp = 4; m.hb_stages = 2; m.use_cic = false;
    case 2
      m.mode = 2; m.interp = 8; m.hb_stages = 3; m.use_cic = false;
    case 3
      m.mode = 3; m.interp = 16; m.hb_stages = 4; m.use_cic = false;
    case 4
      m.mode = 4; m.interp = 32; m.hb_stages = 2; m.use_cic = true;
      m.cic_rate = 8; m.cic_order = 4;
    otherwise
      error('Unsupported mode');
  end
  m.hb_taps = 47;
  m.comp_taps = 63;
end

function [yi, yq, st] = run_fixed_chain(xi, xq, m, cfg)
  yi = int64(xi(:));
  yq = int64(xq(:));
  coeff_sets = {};
  sat_count = 0;
  ovf_count = 0;
  latency = 0;

  for s = 1:m.hb_stages
    hq = quant_coeff(halfband_interp_coeff_local(m.hb_taps), cfg);
    coeff_sets{end + 1} = hq; %#ok<AGROW>
    [yi, sat_i, ovf_i] = interp_fir_fixed(yi, 2, hq, cfg);
    [yq, sat_q, ovf_q] = interp_fir_fixed(yq, 2, hq, cfg);
    sat_count = sat_count + sat_i + sat_q;
    ovf_count = ovf_count + ovf_i + ovf_q;
    latency = latency * 2 + floor(numel(hq) / 2);
  end

  if m.use_cic
    hq = quant_coeff(cic_interp_impulse_local(m.cic_rate, m.cic_order), cfg);
    coeff_sets{end + 1} = hq; %#ok<AGROW>
    [yi, sat_i, ovf_i] = interp_fir_fixed(yi, m.cic_rate, hq, cfg);
    [yq, sat_q, ovf_q] = interp_fir_fixed(yq, m.cic_rate, hq, cfg);
    sat_count = sat_count + sat_i + sat_q;
    ovf_count = ovf_count + ovf_i + ovf_q;
    latency = latency * m.cic_rate + floor((m.cic_rate * m.cic_order) / 2);

    hq = quant_coeff(cic_comp_coeff_local(m.comp_taps, m.cic_rate, m.cic_order), cfg);
    coeff_sets{end + 1} = hq; %#ok<AGROW>
    [yi, sat_i, ovf_i] = fir_fixed(yi, hq, cfg);
    [yq, sat_q, ovf_q] = fir_fixed(yq, hq, cfg);
    sat_count = sat_count + sat_i + sat_q;
    ovf_count = ovf_count + ovf_i + ovf_q;
    latency = latency + floor(numel(hq) / 2);
  end

  st.coeff_sets = coeff_sets;
  st.num_mult_coeff = sum(cellfun(@numel, coeff_sets));
  st.saturation_count = sat_count;
  st.overflow_count = ovf_count;
  st.latency_est = latency;
end

function [y, sat_count, ovf_count] = interp_fir_fixed(x, L, hq, cfg)
  xu = zeros(numel(x) * L, 1, 'int64');
  xu(1:L:end) = x(:);
  [y, sat_count, ovf_count] = fir_fixed(xu, hq, cfg);
end

function [y, sat_count, ovf_count] = fir_fixed(x, hq, cfg)
  acc = filter(double(hq(:)), 1, double(x(:)));
  max_acc = 2^(cfg.acc_w - 1) - 1;
  min_acc = -2^(cfg.acc_w - 1);
  ovf = acc > max_acc | acc < min_acc;
  ovf_count = nnz(ovf);
  acc = min(max(acc, min_acc), max_acc);
  val = round_shift_vec(acc, cfg.coeff_frac);
  y = sat_int(val, cfg.out_w);
  sat_count = nnz(double(y) ~= val);
end

function hq = quant_coeff(h, cfg)
  hq = sat_int(round(h(:) * 2^cfg.coeff_frac), cfg.coeff_w);
end

function y = sat_int(x, w)
  x = int64(x);
  maxv = int64(2^(w - 1) - 1);
  minv = int64(-2^(w - 1));
  y = min(max(x, minv), maxv);
end

function [y, sat] = sat_int_count(x, w)
  y = sat_int(x, w);
  sat = any(y ~= int64(x));
end

function y = round_shift(x, sh)
  if sh <= 0
    y = x;
  elseif x >= 0
    y = bitshift(x + int64(2^(sh - 1)), -sh);
  else
    y = -bitshift((-x) + int64(2^(sh - 1)), -sh);
  end
end

function y = round_shift_vec(x, sh)
  if sh <= 0
    y = x;
    return;
  end
  y = zeros(size(x));
  pos = x >= 0;
  y(pos) = floor((x(pos) + 2^(sh - 1)) / 2^sh);
  y(~pos) = -floor((-x(~pos) + 2^(sh - 1)) / 2^sh);
end

function write_int_vector(path, yi, yq)
  T = table((0:numel(yi)-1).', int64(yi(:)), int64(yq(:)), ...
            'VariableNames', {'n','i_q1_15','q_q1_15'});
  writetable(T, path);
end

function write_coeffs(path, coeff_sets)
  stage = [];
  tap = [];
  coeff = [];
  for s = 1:numel(coeff_sets)
    c = coeff_sets{s};
    stage = [stage; repmat(s, numel(c), 1)]; %#ok<AGROW>
    tap = [tap; (0:numel(c)-1).']; %#ok<AGROW>
    coeff = [coeff; int64(c(:))]; %#ok<AGROW>
  end
  T = table(stage, tap, coeff, 'VariableNames', {'stage','tap','coeff_q2_16'});
  writetable(T, path);
end

function r = rms_local(x)
  r = sqrt(mean(abs(x(:)).^2));
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

function [yi, yq] = run_float_chain_public(xi, xq, m)
  yi = xi(:); yq = xq(:);
  for s = 1:m.hb_stages
    h = halfband_interp_coeff_local(m.hb_taps);
    yi = interp_by_fir_float(yi, 2, h);
    yq = interp_by_fir_float(yq, 2, h);
  end
  if m.use_cic
    h = cic_interp_impulse_local(m.cic_rate, m.cic_order);
    yi = interp_by_fir_float(yi, m.cic_rate, h);
    yq = interp_by_fir_float(yq, m.cic_rate, h);
    h = cic_comp_coeff_local(m.comp_taps, m.cic_rate, m.cic_order);
    yi = filter(h, 1, yi);
    yq = filter(h, 1, yq);
  end
end

function y = interp_by_fir_float(x, L, h)
  xu = zeros(numel(x) * L, 1);
  xu(1:L:end) = x(:);
  y = filter(h(:), 1, xu);
end

function h = halfband_interp_coeff_local(ntaps)
  mid = (ntaps - 1) / 2;
  n = (0:ntaps-1) - mid;
  h = sinc_local(0.5 * n) .* hamming_local(ntaps);
  h(abs(h) < 1e-14) = 0;
  h = h * (2 / sum(h));
end

function h = cic_interp_impulse_local(rate, order)
  h = ones(1, rate);
  for k = 2:order
    h = conv(h, ones(1, rate));
  end
  h = h / (rate^(order - 1));
end

function h = cic_comp_coeff_local(ntaps, rate, order)
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

function y = sinc_local(x)
  y = ones(size(x));
  nz = abs(x) > 1e-12;
  y(nz) = sin(pi*x(nz)) ./ (pi*x(nz));
end

function w = hamming_local(n)
  k = 0:n-1;
  w = 0.54 - 0.46*cos(2*pi*k/(n-1));
end

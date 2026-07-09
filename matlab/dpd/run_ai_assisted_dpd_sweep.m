function [T, D] = run_ai_assisted_dpd_sweep(varargin)
% run_ai_assisted_dpd_sweep
% Software calibration loop for AI-assisted TX calibration development.
%
% The current implementation uses deterministic optimization rather than a
% neural network: for each PA/input/OFDM scenario it fits initial polynomial
% DPD coefficients, then runs a fixed-point coordinate search over the Q2.14
% C1/C3/C5 words before exporting the package to the PS calibration app.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});

  scenarios = build_scenarios();
  rows = repmat(empty_row(), numel(scenarios), 1);
  lut_words = strings(numel(scenarios), 2^cfg.lut_aw);
  opt_trace = repmat(empty_trace_row(), 0, 1);

  for k = 1:numel(scenarios)
    sc = scenarios(k);
    rng(cfg.seed + k - 1);

    local_cfg = cfg;
    local_cfg.input_backoff = sc.input_backoff;
    local_cfg.nused = sc.nused;
    local_cfg.qam_order = sc.qam_order;
    local_cfg.pa = sc.pa;

    x = make_ofdm_source(local_cfg);
    x = local_cfg.input_backoff * x(:) / max(abs(x(:)) + eps);

    y_pa = memoryless_pa(x, local_cfg.pa);
    coeff_float = fit_memoryless_poly(y_pa, x, local_cfg.poly_order, local_cfg.ridge);
    coeff_q0 = quantize_signed(coeff_float, local_cfg.coeff_frac, local_cfg.coeff_w);
    [coeff_q, tr] = coordinate_search_poly(x, coeff_q0, local_cfg, k, sc.name);
    opt_trace = [opt_trace; tr(:)]; %#ok<AGROW>
    lut_q = train_lut_dpd(y_pa, x, local_cfg);

    x_dpd_initial = dpd_poly_fixed_model(x, coeff_q0, local_cfg);
    y_initial = memoryless_pa(limit_drive(x_dpd_initial, local_cfg.dpd_drive_limit), local_cfg.pa);
    initial_dpd = eval_case(x, y_initial, local_cfg);

    x_dpd_fixed = dpd_poly_fixed_model(x, coeff_q, local_cfg);
    x_lut_fixed = dpd_lut_fixed_model(x, lut_q, local_cfg);
    y_fixed = memoryless_pa(limit_drive(x_dpd_fixed, local_cfg.dpd_drive_limit), local_cfg.pa);
    y_lut = memoryless_pa(limit_drive(x_lut_fixed, local_cfg.dpd_drive_limit), local_cfg.pa);

    no_dpd = eval_case(x, y_pa, local_cfg);
    fixed_dpd = eval_case(x, y_fixed, local_cfg);
    lut_dpd = eval_case(x, y_lut, local_cfg);

    rows(k) = empty_row();
    rows(k).Scenario = string(sc.name);
    rows(k).QAM = local_cfg.qam_order;
    rows(k).UsedSubcarriers = local_cfg.nused;
    rows(k).InputBackoff = local_cfg.input_backoff;
    rows(k).NoDPD_EVM_percent = no_dpd.EVM_percent;
    rows(k).NoDPD_SNDR_dB = no_dpd.SNDR_dB;
    rows(k).NoDPD_ACLR_avg_dBc = no_dpd.ACLR_avg_dBc;
    rows(k).FixedDPD_EVM_percent = fixed_dpd.EVM_percent;
    rows(k).FixedDPD_SNDR_dB = fixed_dpd.SNDR_dB;
    rows(k).FixedDPD_ACLR_avg_dBc = fixed_dpd.ACLR_avg_dBc;
    rows(k).InitialPoly_EVM_percent = initial_dpd.EVM_percent;
    rows(k).InitialPoly_SNDR_dB = initial_dpd.SNDR_dB;
    rows(k).OptimizedPoly_Loss = scalar_loss(fixed_dpd, local_cfg);
    rows(k).LUTDPD_EVM_percent = lut_dpd.EVM_percent;
    rows(k).LUTDPD_SNDR_dB = lut_dpd.SNDR_dB;
    rows(k).LUTDPD_ACLR_avg_dBc = lut_dpd.ACLR_avg_dBc;
    rows(k).EVM_Improvement_x = no_dpd.EVM_percent / max(fixed_dpd.EVM_percent, eps);
    rows(k).SNDR_Improvement_dB = fixed_dpd.SNDR_dB - no_dpd.SNDR_dB;
    rows(k).C1_hex = packed_coeff_hex(coeff_q(1));
    rows(k).C3_hex = packed_coeff_hex(coeff_q(2));
    rows(k).C5_hex = packed_coeff_hex(coeff_q(3));
    rows(k).LUT0_hex = packed_coeff_hex(lut_q(1));
    rows(k).LUT15_hex = packed_coeff_hex(lut_q(end));
    for b = 1:numel(lut_q)
      lut_words(k, b) = packed_coeff_hex(lut_q(b));
    end
  end

  T = struct2table(rows);
  Trace = struct2table(opt_trace);
  D = struct();
  D.lut_words = lut_words;
  D.scenario = T.Scenario;
  D.c1_hex = T.C1_hex;
  D.c3_hex = T.C3_hex;
  D.c5_hex = T.C5_hex;

  out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  if ~exist(out_dir, 'dir')
    mkdir(out_dir);
  end

  writetable(T, fullfile(out_dir, 'ai_assisted_dpd_sweep.csv'));
  writetable(Trace, fullfile(out_dir, 'ai_assisted_dpd_coordinate_trace.csv'));
  write_summary_md(T, cfg, fullfile(out_dir, 'ai_assisted_dpd_sweep.md'));
  save(fullfile(out_dir, 'ai_assisted_dpd_sweep.mat'), 'cfg', 'T', 'Trace', 'D', 'scenarios');
  disp(T);
end

function cfg = default_cfg()
  cfg.seed = 31;
  cfg.nfft = 256;
  cfg.ncp = 32;
  cfg.nsym = 12;
  cfg.nused = 48;
  cfg.qam_order = 16;
  cfg.fs_hz = 100e6;
  cfg.channel_bw_hz = 20e6;
  cfg.adjacent_offset_hz = 20e6;
  cfg.input_backoff = 0.58;
  cfg.dpd_drive_limit = 0.92;
  cfg.poly_order = 5;
  cfg.ridge = 1e-7;
  cfg.coord_search_enable = true;
  cfg.coord_max_iter = 1;
  cfg.coord_initial_step = 64;
  cfg.coord_min_step = 64;
  cfg.coord_eval_max_samples = Inf;
  cfg.loss_evm_weight = 10000;
  cfg.loss_sndr_weight = 50;
  cfg.loss_aclr_target_dBc = -45;
  cfg.loss_aclr_weight = 200;
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_w = 16;
  cfg.coeff_frac = 14;
  cfg.lut_aw = 4;
  cfg.pa.c1 = 1.0 + 0.00j;
  cfg.pa.c3 = -0.52 + 0.24j;
  cfg.pa.c5 = 0.18 - 0.16j;
end

function [best_q, trace] = coordinate_search_poly(x, coeff_q0, cfg, scenario_idx, scenario_name)
  if ~cfg.coord_search_enable
    best_q = coeff_q0;
    trace = empty_trace_row();
    trace.ScenarioIndex = scenario_idx;
    trace.Scenario = string(scenario_name);
    trace.Iteration = 0;
    trace.Step = 0;
    trace.Loss = eval_poly_loss(x, best_q, cfg);
    trace.Accepted = true;
    trace.C1_hex = packed_coeff_hex(best_q(1));
    trace.C3_hex = packed_coeff_hex(best_q(2));
    trace.C5_hex = packed_coeff_hex(best_q(3));
    return;
  end

  best_q = coeff_q0(:).';
  x_eval = x(1:min(numel(x), cfg.coord_eval_max_samples));
  best_loss = eval_poly_loss(x_eval, best_q, cfg);
  trace = repmat(empty_trace_row(), 0, 1);
  step = cfg.coord_initial_step;
  iter = 0;

  trace(end+1) = make_trace_row(scenario_idx, scenario_name, iter, step, ...
    best_loss, true, best_q); %#ok<AGROW>

  while step >= cfg.coord_min_step && iter < cfg.coord_max_iter
    iter = iter + 1;
    accepted_any = false;
    for coeff_idx = 1:numel(best_q)
      for part = 1:2
        for dir = [-1 1]
          cand_q = best_q;
          c = cand_q(coeff_idx);
          if part == 1
            c = complex(real(c) + dir * step, imag(c));
          else
            c = complex(real(c), imag(c) + dir * step);
          end
          cand_q(coeff_idx) = clamp_coeff(c, cfg.coeff_w);
          cand_loss = eval_poly_loss(x_eval, cand_q, cfg);
          accepted = cand_loss < best_loss;
          trace(end+1) = make_trace_row(scenario_idx, scenario_name, iter, ...
            step, cand_loss, accepted, cand_q); %#ok<AGROW>
          if accepted
            best_q = cand_q;
            best_loss = cand_loss;
            accepted_any = true;
          end
        end
      end
    end
    if ~accepted_any
      step = floor(step / 2);
    end
  end
end

function y = clamp_coeff(c, width)
  maxv = 2^(width-1) - 1;
  minv = -2^(width-1);
  y = complex(min(max(round(real(c)), minv), maxv), ...
              min(max(round(imag(c)), minv), maxv));
end

function loss = eval_poly_loss(x, coeff_q, cfg)
  x_dpd = dpd_poly_fixed_model(x, coeff_q, cfg);
  y = memoryless_pa(limit_drive(x_dpd, cfg.dpd_drive_limit), cfg.pa);
  m = eval_case(x, y, cfg);
  loss = scalar_loss(m, cfg);
end

function loss = scalar_loss(m, cfg)
  aclr_penalty = max(m.ACLR_avg_dBc - cfg.loss_aclr_target_dBc, 0);
  loss = m.EVM_percent * cfg.loss_evm_weight ...
       - m.SNDR_dB * cfg.loss_sndr_weight ...
       + aclr_penalty * cfg.loss_aclr_weight;
end

function row = make_trace_row(scenario_idx, scenario_name, iter, step, loss, accepted, coeff_q)
  row = empty_trace_row();
  row.ScenarioIndex = scenario_idx;
  row.Scenario = string(scenario_name);
  row.Iteration = iter;
  row.Step = step;
  row.Loss = loss;
  row.Accepted = accepted;
  row.C1_hex = packed_coeff_hex(coeff_q(1));
  row.C3_hex = packed_coeff_hex(coeff_q(2));
  row.C5_hex = packed_coeff_hex(coeff_q(3));
end

function scenarios = build_scenarios()
  scenarios = repmat(struct('name', "", 'input_backoff', 0, 'nused', 0, ...
    'qam_order', 0, 'pa', struct('c1', 0, 'c3', 0, 'c5', 0)), 6, 1);

  scenarios(1).name = "pa_nominal_16qam_48sc_bo058";
  scenarios(1).input_backoff = 0.58;
  scenarios(1).nused = 48;
  scenarios(1).qam_order = 16;
  scenarios(1).pa = struct('c1', 1.0 + 0.00j, 'c3', -0.52 + 0.24j, 'c5', 0.18 - 0.16j);

  scenarios(2).name = "pa_nominal_16qam_48sc_bo070";
  scenarios(2).input_backoff = 0.70;
  scenarios(2).nused = 48;
  scenarios(2).qam_order = 16;
  scenarios(2).pa = scenarios(1).pa;

  scenarios(3).name = "pa_strong_16qam_48sc_bo058";
  scenarios(3).input_backoff = 0.58;
  scenarios(3).nused = 48;
  scenarios(3).qam_order = 16;
  scenarios(3).pa = struct('c1', 1.0 + 0.02j, 'c3', -0.72 + 0.34j, 'c5', 0.26 - 0.23j);

  scenarios(4).name = "pa_weak_16qam_48sc_bo058";
  scenarios(4).input_backoff = 0.58;
  scenarios(4).nused = 48;
  scenarios(4).qam_order = 16;
  scenarios(4).pa = struct('c1', 1.0 - 0.01j, 'c3', -0.36 + 0.16j, 'c5', 0.10 - 0.08j);

  scenarios(5).name = "pa_nominal_64qam_48sc_bo058";
  scenarios(5).input_backoff = 0.58;
  scenarios(5).nused = 48;
  scenarios(5).qam_order = 64;
  scenarios(5).pa = scenarios(1).pa;

  scenarios(6).name = "pa_nominal_16qam_96sc_bo052";
  scenarios(6).input_backoff = 0.52;
  scenarios(6).nused = 96;
  scenarios(6).qam_order = 16;
  scenarios(6).pa = scenarios(1).pa;
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
  coeff = (A' * A + ridge * eye(size(A, 2))) \ (A' * target(:));
end

function A = poly_basis(x, order)
  x = x(:);
  powers = 1:2:order;
  A = zeros(numel(x), numel(powers));
  for k = 1:numel(powers)
    A(:, k) = x .* (abs(x).^(powers(k) - 1));
  end
end

function q = quantize_signed(x, frac, width)
  maxv = 2^(width-1) - 1;
  minv = -2^(width-1);
  qr = min(max(round(real(x) * 2^frac), minv), maxv);
  qi = min(max(round(imag(x) * 2^frac), minv), maxv);
  q = complex(qr, qi);
end

function y = dpd_poly_fixed_model(x, coeff_q, cfg)
  xi = real(quantize_signed(real(x), cfg.input_frac, cfg.input_w));
  xq = real(quantize_signed(imag(x), cfg.input_frac, cfg.input_w));
  c1r = real(coeff_q(1)); c1i = imag(coeff_q(1));
  c3r = real(coeff_q(2)); c3i = imag(coeff_q(2));
  c5r = real(coeff_q(3)); c5i = imag(coeff_q(3));
  i = int64(xi(:));
  q = int64(xq(:));
  r2 = bitsra(i.*i + q.*q, cfg.input_frac);
  r4 = bitsra(r2.*r2, cfg.input_frac);
  gr = int64(c1r) + bitsra(int64(c3r).*r2, cfg.input_frac) + bitsra(int64(c5r).*r4, cfg.input_frac);
  gi = int64(c1i) + bitsra(int64(c3i).*r2, cfg.input_frac) + bitsra(int64(c5i).*r4, cfg.input_frac);
  io = bitsra(i.*gr - q.*gi, cfg.coeff_frac);
  qo = bitsra(i.*gi + q.*gr, cfg.coeff_frac);
  yi = reshape(saturate_int(io, cfg.input_w), size(x));
  yq = reshape(saturate_int(qo, cfg.input_w), size(x));
  y = double(yi) / 2^cfg.input_frac + 1j * double(yq) / 2^cfg.input_frac;
end

function lut_q = train_lut_dpd(pa_out, target, cfg)
  nbin = 2^cfg.lut_aw;
  idx = lut_index_float(pa_out, cfg);
  lut = ones(nbin, 1);
  last = 1 + 0j;
  for b = 1:nbin
    sel = idx == (b - 1);
    if any(sel)
      xb = pa_out(sel);
      yb = target(sel);
      lut(b) = (xb' * yb) / (xb' * xb + eps);
      last = lut(b);
    else
      lut(b) = last;
    end
  end
  lut_q = quantize_signed(lut, cfg.coeff_frac, cfg.coeff_w);
end

function y = dpd_lut_fixed_model(x, lut_q, cfg)
  xi = real(quantize_signed(real(x), cfg.input_frac, cfg.input_w));
  xq = real(quantize_signed(imag(x), cfg.input_frac, cfg.input_w));
  idx = lut_index_int(xi, xq, cfg);
  i = int64(xi(:));
  q = int64(xq(:));
  c = lut_q(idx(:) + 1);
  gr = int64(real(c(:)));
  gi = int64(imag(c(:)));
  io = bitsra(i.*gr - q.*gi, cfg.coeff_frac);
  qo = bitsra(i.*gi + q.*gr, cfg.coeff_frac);
  yi = reshape(saturate_int(io, cfg.input_w), size(x));
  yq = reshape(saturate_int(qo, cfg.input_w), size(x));
  y = double(yi) / 2^cfg.input_frac + 1j * double(yq) / 2^cfg.input_frac;
end

function idx = lut_index_float(x, cfg)
  q = quantize_signed(real(x), cfg.input_frac, cfg.input_w) + ...
      1j * quantize_signed(imag(x), cfg.input_frac, cfg.input_w);
  idx = lut_index_int(real(q), imag(q), cfg);
end

function idx = lut_index_int(xi, xq, cfg)
  mag = max(abs(double(xi)), abs(double(xq)));
  idx = floor(mag / 2^(cfg.input_w - 1 - cfg.lut_aw));
  idx = min(max(idx, 0), 2^cfg.lut_aw - 1);
end

function y = saturate_int(x, width)
  maxv = int64(2^(width-1) - 1);
  minv = int64(-2^(width-1));
  y = min(max(int64(x), minv), maxv);
end

function y = limit_drive(x, limit)
  scale = limit / max(abs(x) + eps);
  if scale < 1
    y = x * scale;
  else
    y = x;
  end
end

function row = eval_case(ref, y, cfg)
  [ya, xa] = align_gain(y, ref);
  ev = calc_evm_sndr(ya, xa);
  ac = calc_aclr(y, cfg.fs_hz, cfg.channel_bw_hz, cfg.adjacent_offset_hz);
  row.EVM_percent = ev.EVM_percent;
  row.SNDR_dB = ev.SNDR_dB;
  row.ACLR_avg_dBc = mean([ac.ACLR_L_dBc ac.ACLR_R_dBc]);
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

function s = packed_coeff_hex(c)
  re = twos_u16(real(c));
  im = twos_u16(imag(c));
  s = string(sprintf("0x%04X%04X", im, re));
end

function u = twos_u16(v)
  v = int32(v);
  if v < 0
    u = uint32(v + 65536);
  else
    u = uint32(v);
  end
end

function row = empty_row()
  row = struct('Scenario', string(""), 'QAM', NaN, 'UsedSubcarriers', NaN, ...
    'InputBackoff', NaN, 'NoDPD_EVM_percent', NaN, 'NoDPD_SNDR_dB', NaN, ...
    'NoDPD_ACLR_avg_dBc', NaN, 'FixedDPD_EVM_percent', NaN, ...
    'FixedDPD_SNDR_dB', NaN, 'FixedDPD_ACLR_avg_dBc', NaN, ...
    'InitialPoly_EVM_percent', NaN, 'InitialPoly_SNDR_dB', NaN, ...
    'OptimizedPoly_Loss', NaN, ...
    'LUTDPD_EVM_percent', NaN, 'LUTDPD_SNDR_dB', NaN, ...
    'LUTDPD_ACLR_avg_dBc', NaN, ...
    'EVM_Improvement_x', NaN, 'SNDR_Improvement_dB', NaN, ...
    'C1_hex', string(""), 'C3_hex', string(""), 'C5_hex', string(""), ...
    'LUT0_hex', string(""), 'LUT15_hex', string(""));
end

function row = empty_trace_row()
  row = struct('ScenarioIndex', NaN, 'Scenario', string(""), ...
    'Iteration', NaN, 'Step', NaN, 'Loss', NaN, 'Accepted', false, ...
    'C1_hex', string(""), 'C3_hex', string(""), 'C5_hex', string(""));
end

function write_summary_md(T, cfg, path)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot write %s', path); end
  cleanup = onCleanup(@() fclose(fid));

  fprintf(fid, '# AI-Assisted DPD Software Calibration Sweep\n\n');
  fprintf(fid, 'This is a software-side calibration loop for the AI-assisted TX calibration path.\n');
  fprintf(fid, 'The current calibration engine uses deterministic polynomial fitting; future AI models can replace or guide this coefficient search while keeping the same RTL coefficient interface.\n\n');
  fprintf(fid, '## Fixed-Point Interface\n\n');
  fprintf(fid, '- DPD input/output: signed Q1.%d, %d-bit complex I/Q\n', cfg.input_frac, cfg.input_w);
  fprintf(fid, '- DPD coefficients: signed Q2.%d, %d-bit complex values\n', cfg.coeff_frac, cfg.coeff_w);
  fprintf(fid, '- AXI-Lite coefficient packing: `{imag[15:0], real[15:0]}`\n');
  fprintf(fid, '- LUT DPD entries: %d complex gain bins\n\n', 2^cfg.lut_aw);
  fprintf(fid, '## Optimization Loop\n\n');
  fprintf(fid, 'For each scenario, the polynomial DPD starts from an indirect-learning least-squares fit.\n');
  fprintf(fid, 'The exported `C1/C3/C5` package is then refined by a fixed-point coordinate search directly in Q2.%d coefficient space.\n', cfg.coeff_frac);
  fprintf(fid, 'The scalar loss combines EVM, SNDR, and ACLR target penalty, so this is a real software optimization loop rather than a static coefficient table.\n');
  fprintf(fid, 'The per-candidate search trace is written to `ai_assisted_dpd_coordinate_trace.csv`.\n\n');
  fprintf(fid, '## Results\n\n');
  fprintf(fid, '| Scenario | QAM | Used SC | Backoff | No DPD EVM %% | Initial Poly EVM %% | Optimized Poly EVM %% | LUT EVM %% | No DPD SNDR dB | Optimized Poly SNDR dB | LUT SNDR dB | Loss | C1 | C3 | C5 | LUT0 | LUT15 |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|---|\n');
  for k = 1:height(T)
    fprintf(fid, '| %s | %d | %d | %.3f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.3f | `%s` | `%s` | `%s` | `%s` | `%s` |\n', ...
      T.Scenario(k), T.QAM(k), T.UsedSubcarriers(k), T.InputBackoff(k), ...
      T.NoDPD_EVM_percent(k), T.InitialPoly_EVM_percent(k), ...
      T.FixedDPD_EVM_percent(k), T.LUTDPD_EVM_percent(k), ...
      T.NoDPD_SNDR_dB(k), T.FixedDPD_SNDR_dB(k), T.LUTDPD_SNDR_dB(k), ...
      T.OptimizedPoly_Loss(k), T.C1_hex(k), T.C3_hex(k), T.C5_hex(k), ...
      T.LUT0_hex(k), T.LUT15_hex(k));
  end
end

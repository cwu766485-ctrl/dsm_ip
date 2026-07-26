function [Results, Summary, Coefficients, Artifacts] = run_dpd_memory_poly_training_comparison(varargin)
% Train Q2.14 memoryless and memory-polynomial DPD on one behavioral PA.
% Fit, validation, and test OFDM waveforms use disjoint random seeds.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});
  pa = nominal_memory_pa();

  fit_x = make_source_quantized(cfg, cfg.fit_seed, cfg.train_nsym);
  fit_y = observe_pa(fit_x, pa, cfg, cfg.fit_seed + cfg.noise_seed_offset);
  val_x = make_source_quantized(cfg, cfg.validation_seed, cfg.validation_nsym);
  val_no = observe_pa(val_x, pa, cfg, ...
    cfg.validation_seed + cfg.noise_seed_offset);
  val_no_metrics = evaluate_metrics(val_x, val_no, cfg);

  memoryless = train_model(fit_y, fit_x, val_x, pa, 1, ...
    val_no_metrics.ACLR_avg_dBc, [], cfg);
  memory_poly = train_model(fit_y, fit_x, val_x, pa, cfg.memory_taps, ...
    memoryless.validation.ACLR_avg_dBc, memoryless, cfg);

  rows = repmat(empty_result(), numel(cfg.test_seeds) * 3, 1);
  row_idx = 0;
  modes = ["No DPD", "Memoryless DPD", "Memory-polynomial DPD"];
  for seed = cfg.test_seeds(:).'
    ref = make_source_quantized(cfg, seed, cfg.test_nsym);
    rng(seed + cfg.noise_seed_offset, 'twister');
    unit_noise = (randn(size(ref)) + 1j * randn(size(ref))) / sqrt(2);
    for mode_idx = 1:numel(modes)
      mode = modes(mode_idx);
      if mode_idx == 1
        dpd_out = ref;
        dpd_saturation_count = 0;
      elseif mode_idx == 2
        [dpd_out, dpd_saturation_count] = dpd_fixed_model(ref, ...
          memoryless.coeff_q, memoryless.taps, cfg);
      else
        [dpd_out, dpd_saturation_count] = dpd_fixed_model(ref, ...
          memory_poly.coeff_q, memory_poly.taps, cfg);
      end
      [pa_in, drive_limit_count] = limit_drive(dpd_out, cfg.dpd_drive_limit);
      clean = behavioral_pa(pa_in, pa, cfg);
      observed = add_noise(clean, unit_noise, cfg.observation_snr_dB);
      metrics = evaluate_metrics(ref, observed, cfg);

      row_idx = row_idx + 1;
      rows(row_idx).TestSeed = seed;
      rows(row_idx).Mode = mode;
      rows(row_idx).EVM_percent = metrics.EVM_percent;
      rows(row_idx).NMSE_dB = metrics.NMSE_dB;
      rows(row_idx).SNDR_dB = metrics.SNDR_dB;
      rows(row_idx).ACLR_L_dBc = metrics.ACLR_L_dBc;
      rows(row_idx).ACLR_R_dBc = metrics.ACLR_R_dBc;
      rows(row_idx).ACLR_avg_dBc = metrics.ACLR_avg_dBc;
      rows(row_idx).DPDSaturationCount = dpd_saturation_count;
      rows(row_idx).DriveLimitCount = drive_limit_count;
    end
  end

  Results = struct2table(rows);
  Summary = summarize_results(Results, modes);
  Coefficients = coefficient_table(memoryless, memory_poly, cfg.orders);
  Artifacts = struct('cfg', cfg, 'pa', pa, 'memoryless', memoryless, ...
    'memory_poly', memory_poly, 'validation_no_dpd', val_no_metrics);

  if cfg.write_outputs
    out_dir = cfg.out_dir;
    if isempty(out_dir)
      out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'out', 'dpd');
    end
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    writetable(Results, fullfile(out_dir, 'dpd_memory_poly_comparison.csv'));
    writetable(Summary, fullfile(out_dir, 'dpd_memory_poly_comparison_summary.csv'));
    writetable(Coefficients, fullfile(out_dir, 'dpd_memory_poly_coefficients.csv'));
    write_summary(fullfile(out_dir, 'dpd_memory_poly_comparison.md'), ...
      Results, Summary, Coefficients, memoryless, memory_poly, cfg);
    save(fullfile(out_dir, 'dpd_memory_poly_comparison.mat'), 'cfg', 'pa', ...
      'Results', 'Summary', 'Coefficients', 'memoryless', 'memory_poly');
  end

  if cfg.verbose
    disp(Summary);
    disp(Coefficients);
  end
end

function cfg = default_cfg()
  cfg.fit_seed = 101;
  cfg.validation_seed = 137;
  cfg.test_seeds = [211, 223, 239];
  cfg.noise_seed_offset = 10000;
  cfg.nfft = 512;
  cfg.ncp = 64;
  cfg.train_nsym = 64;
  cfg.validation_nsym = 24;
  cfg.test_nsym = 32;
  cfg.nused = 96;
  cfg.qam_order = 64;
  cfg.input_backoff = 0.58;
  cfg.fs_hz = 200e6;
  cfg.channel_bw_hz = 1.10 * cfg.fs_hz * cfg.nused / cfg.nfft;
  cfg.adjacent_offset_hz = 1.20 * cfg.channel_bw_hz;
  cfg.pa_linear_fir = [0.92+0.00j, 0.10-0.035j, -0.025+0.018j];
  cfg.pa_sat_level = 0.92;
  cfg.pa_smooth_sat_p = 3.0;
  cfg.pa_gain_drift_ppm = 1800;
  cfg.pa_phase_drift_deg = 1.8;
  cfg.pa_phase_ripple_deg = 0.45;
  cfg.observation_snr_dB = 43;
  cfg.dpd_drive_limit = 0.92;
  cfg.memory_taps = 4;
  cfg.orders = [1, 3, 5];
  cfg.ridge_grid = [1e-8, 1e-7, 1e-6, 1e-5, 1e-4, 1e-3, 1e-2, 1e-1, 1];
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_w = 16;
  cfg.coeff_frac = 14;
  cfg.align_max_delay = 16;
  cfg.fit_discard = 64;
  cfg.joint_aclr_weight = 2.0;
  cfg.joint_aclr_tolerance_dB = 0.05;
  cfg.safety_penalty = 1e6;
  cfg.memory_blend_grid = 0:0.05:1;
  cfg.out_dir = '';
  cfg.write_outputs = true;
  cfg.verbose = true;
end

function pa = nominal_memory_pa()
  pa.c1 = [1.0+0.00j; 0.04-0.015j; -0.012+0.008j];
  pa.c3 = [-0.52+0.24j; -0.09+0.04j; 0.025-0.012j];
  pa.c5 = [0.18-0.16j; 0.035-0.018j; -0.010+0.006j];
end

function model = train_model(fit_y, fit_x, val_x, pa, taps, aclr_reference, ...
    baseline, cfg)
  basis = memory_poly_basis(fit_y, taps, cfg.orders);
  keep = (cfg.fit_discard + 1):numel(fit_x);
  A = basis(keep, :);
  target = fit_x(keep);
  gram_scale = trace(A' * A) / max(size(A, 2), 1);
  best_score = inf;
  best = struct();
  for ridge = cfg.ridge_grid(:).'
    fitted_float = (A' * A + ridge * gram_scale * eye(size(A, 2))) \ ...
      (A' * target);
    if isempty(baseline)
      blend_grid = 1;
      baseline_float = zeros(size(fitted_float));
    else
      blend_grid = cfg.memory_blend_grid;
      baseline_float = zeros(size(fitted_float));
      baseline_float(1:numel(baseline.coeff_float)) = baseline.coeff_float;
    end
    for blend = blend_grid
      coeff_float = baseline_float + blend * (fitted_float - baseline_float);
      coeff_q = quantize_coeff(coeff_float, cfg);
      [val_dpd, sat_count] = dpd_fixed_model(val_x, coeff_q, taps, cfg);
      [val_pa_in, drive_count] = limit_drive(val_dpd, cfg.dpd_drive_limit);
      val_y = observe_pa(val_pa_in, pa, cfg, ...
        cfg.validation_seed + cfg.noise_seed_offset);
      metrics = evaluate_metrics(val_x, val_y, cfg);
      aclr_excess = max(metrics.ACLR_avg_dBc - aclr_reference - ...
        cfg.joint_aclr_tolerance_dB, 0);
      unsafe_count = sat_count + drive_count;
      score = metrics.EVM_percent + cfg.safety_penalty * ...
        (aclr_excess + unsafe_count);
      if score < best_score
        best_score = score;
        best.coeff_float = coeff_float;
        best.coeff_q = coeff_q;
        best.ridge = ridge;
        best.blend = blend;
        best.validation = metrics;
        best.validation_saturation_count = sat_count;
        best.validation_drive_limit_count = drive_count;
        best.validation_score = score;
        best.aclr_reference_dBc = aclr_reference;
      end
    end
  end
  model = best;
  model.taps = taps;
end

function A = memory_poly_basis(x, taps, orders)
  x = x(:);
  A = zeros(numel(x), taps * numel(orders));
  col = 0;
  for tap = 0:taps-1
    delayed = [zeros(tap, 1); x(1:end-tap)];
    for order = orders
      col = col + 1;
      A(:, col) = delayed .* abs(delayed).^(order - 1);
    end
  end
end

function coeff_q = quantize_coeff(coeff, cfg)
  maxv = 2^(cfg.coeff_w - 1) - 1;
  minv = -2^(cfg.coeff_w - 1);
  qr = min(max(round(real(coeff) * 2^cfg.coeff_frac), minv), maxv);
  qi = min(max(round(imag(coeff) * 2^cfg.coeff_frac), minv), maxv);
  coeff_q = complex(qr, qi);
end

function [y, saturation_count] = dpd_fixed_model(x, coeff_q, taps, cfg)
  q = quantize_q15(x, cfg);
  acc_i = zeros(numel(x), 1, 'int64');
  acc_q = zeros(numel(x), 1, 'int64');
  for tap = 1:taps
    delay = tap - 1;
    ii = [zeros(delay, 1, 'int64'); q.i(1:end-delay)];
    qq = [zeros(delay, 1, 'int64'); q.q(1:end-delay)];
    base = delay * numel(cfg.orders);
    r2 = bitsra(ii.*ii + qq.*qq, cfg.input_frac);
    gr = int64(0);
    gi = int64(0);
    radial_power = int64(1);
    for order_idx = 1:numel(cfg.orders)
      order = cfg.orders(order_idx);
      if mod(order, 2) ~= 1
        error('DPD orders must be odd positive integers.');
      end
      if order_idx == 1
        if order ~= 1
          error('The first DPD order must be one.');
        end
        gr = gr + int64(real(coeff_q(base + order_idx)));
        gi = gi + int64(imag(coeff_q(base + order_idx)));
      else
        radial_power = bitsra(radial_power .* r2, cfg.input_frac);
        gr = gr + bitsra(int64(real(coeff_q(base + order_idx))) .* ...
          radial_power, cfg.input_frac);
        gi = gi + bitsra(int64(imag(coeff_q(base + order_idx))) .* ...
          radial_power, cfg.input_frac);
      end
    end
    acc_i = acc_i + bitsra(ii.*gr - qq.*gi, cfg.coeff_frac);
    acc_q = acc_q + bitsra(ii.*gi + qq.*gr, cfg.coeff_frac);
  end
  [yi, sat_i] = saturate_int(acc_i, cfg.input_w);
  [yq, sat_q] = saturate_int(acc_q, cfg.input_w);
  saturation_count = sum(sat_i | sat_q);
  y = double(yi) / 2^cfg.input_frac + 1j * double(yq) / 2^cfg.input_frac;
end

function x = make_source_quantized(cfg, seed, nsym)
  rng(seed, 'twister');
  used = used_subcarriers(cfg.nfft, cfg.nused);
  X = zeros(cfg.nfft, nsym);
  indices = randi([0 cfg.qam_order-1], numel(used), nsym);
  X(used, :) = qammod_square(indices, cfg.qam_order);
  td = ifft(ifftshift(X, 1), cfg.nfft, 1);
  td_cp = [td(end-cfg.ncp+1:end, :); td];
  x = td_cp(:);
  x = cfg.input_backoff * x / max(abs(x) + eps);
  q = quantize_q15(x, cfg);
  x = double(q.i) / 2^cfg.input_frac + 1j * double(q.q) / 2^cfg.input_frac;
end

function used = used_subcarriers(nfft, nused)
  neg = (nfft/2 - nused/2 + 1):(nfft/2);
  pos = (nfft/2 + 2):(nfft/2 + 1 + nused/2);
  used = [neg pos];
end

function symbols = qammod_square(indices, M)
  side = sqrt(M);
  ii = mod(indices, side);
  qq = floor(indices ./ side);
  symbols = complex(2*ii - (side - 1), 2*qq - (side - 1));
  symbols = symbols / sqrt(mean(abs(symbols(:)).^2));
end

function q = quantize_q15(x, cfg)
  scale = 2^cfg.input_frac;
  maxv = int64(2^(cfg.input_w - 1) - 1);
  minv = -int64(2^(cfg.input_w - 1));
  q.i = min(max(int64(round(real(x(:)) * scale)), minv), maxv);
  q.q = min(max(int64(round(imag(x(:)) * scale)), minv), maxv);
end

function y = observe_pa(x, pa, cfg, noise_seed)
  clean = behavioral_pa(x, pa, cfg);
  rng(noise_seed, 'twister');
  unit_noise = (randn(size(clean)) + 1j * randn(size(clean))) / sqrt(2);
  y = add_noise(clean, unit_noise, cfg.observation_snr_dB);
end

function y = behavioral_pa(x, pa, cfg)
  x = x(:);
  y = zeros(size(x));
  for tap = 1:numel(pa.c1)
    delayed = [zeros(tap-1, 1); x(1:end-tap+1)];
    r2 = abs(delayed).^2;
    y = y + pa.c1(tap).*delayed + pa.c3(tap).*delayed.*r2 + ...
      pa.c5(tap).*delayed.*r2.^2;
  end
  magnitude = abs(y);
  scale = 1 ./ ((1 + (magnitude / cfg.pa_sat_level).^(2*cfg.pa_smooth_sat_p)) ...
    .^(1/(2*cfg.pa_smooth_sat_p)));
  y = filter(cfg.pa_linear_fir(:), 1, y .* scale);
  n = (0:numel(y)-1).';
  t = n / max(numel(y)-1, 1);
  gain = 1 + cfg.pa_gain_drift_ppm * 1e-6 * (2*t - 1);
  phase = deg2rad(cfg.pa_phase_drift_deg * (2*t - 1) + ...
    cfg.pa_phase_ripple_deg * sin(2*pi*3*t));
  y = y .* gain .* exp(1j*phase);
end

function y = add_noise(clean, unit_noise, snr_dB)
  noise_power = mean(abs(clean).^2) / 10^(snr_dB/10);
  y = clean + sqrt(noise_power) * unit_noise;
end

function [y, limited_count] = limit_drive(x, limit)
  magnitude = abs(x);
  limited = magnitude > limit;
  y = x;
  y(limited) = x(limited) .* (limit ./ magnitude(limited));
  limited_count = sum(limited);
end

function metrics = evaluate_metrics(ref, y, cfg)
  [aligned, aligned_ref] = align_gain_delay(y, ref, cfg.align_max_delay);
  error_signal = aligned - aligned_ref;
  signal_power = mean(abs(aligned_ref).^2);
  error_power = mean(abs(error_signal).^2);
  metrics.EVM_percent = 100 * sqrt((error_power + eps) / (signal_power + eps));
  metrics.NMSE_dB = 10 * log10((error_power + eps) / (signal_power + eps));
  metrics.SNDR_dB = -metrics.NMSE_dB;
  aclr = calc_aclr(aligned, cfg.fs_hz, cfg.channel_bw_hz, ...
    cfg.adjacent_offset_hz);
  metrics.ACLR_L_dBc = aclr.ACLR_L_dBc;
  metrics.ACLR_R_dBc = aclr.ACLR_R_dBc;
  metrics.ACLR_avg_dBc = mean([aclr.ACLR_L_dBc, aclr.ACLR_R_dBc]);
end

function [best_y, best_x] = align_gain_delay(y, x, max_delay)
  best_error = inf;
  best_y = [];
  best_x = [];
  for delay = -max_delay:max_delay
    if delay >= 0
      yy = y(1+delay:end);
      xx = x(1:min(numel(x), numel(yy)));
      yy = yy(1:numel(xx));
    else
      xx = x(1-delay:end);
      yy = y(1:min(numel(y), numel(xx)));
      xx = xx(1:numel(yy));
    end
    gain = (yy' * xx) / (yy' * yy + eps);
    yy = yy * gain;
    mse = mean(abs(yy - xx).^2);
    if mse < best_error
      best_error = mse;
      best_y = yy;
      best_x = xx;
    end
  end
end

function metrics = calc_aclr(y, Fs, channel_bw, adjacent_offset)
  nfft = 8192;
  win = hann_local(min(4096, numel(y)));
  [psd, frequency] = welch_psd(y, win, floor(numel(win)/2), nfft, Fs);
  main = abs(frequency) <= channel_bw/2;
  left = frequency >= -adjacent_offset-channel_bw/2 & ...
    frequency <= -adjacent_offset+channel_bw/2;
  right = frequency >= adjacent_offset-channel_bw/2 & ...
    frequency <= adjacent_offset+channel_bw/2;
  main_power = sum(psd(main)) + eps;
  metrics.ACLR_L_dBc = 10*log10((sum(psd(left)) + eps) / main_power);
  metrics.ACLR_R_dBc = 10*log10((sum(psd(right)) + eps) / main_power);
end

function [average_psd, frequency] = welch_psd(x, win, overlap, nfft, Fs)
  step = numel(win) - overlap;
  nseg = max(1, floor((numel(x) - overlap) / step));
  average_psd = zeros(nfft, 1);
  used = 0;
  for segment = 1:nseg
    first = (segment - 1) * step + 1;
    indices = first:(first + numel(win) - 1);
    if indices(end) > numel(x), break; end
    spectrum = fftshift(fft(x(indices) .* win, nfft));
    average_psd = average_psd + abs(spectrum).^2 / sum(abs(win).^2);
    used = used + 1;
  end
  average_psd = average_psd / max(used, 1);
  frequency = ((0:nfft-1).' - nfft/2) / nfft * Fs;
end

function w = hann_local(n)
  index = (0:n-1).';
  w = 0.5 - 0.5*cos(2*pi*index/max(n-1, 1));
end

function [value, saturated] = saturate_int(value, width)
  maximum = int64(2^(width-1) - 1);
  minimum = -int64(2^(width-1));
  saturated = value > maximum | value < minimum;
  value = min(max(value, minimum), maximum);
end

function Summary = summarize_results(Results, modes)
  rows = repmat(struct('Mode', string(""), 'Mean_EVM_percent', NaN, ...
    'Mean_NMSE_dB', NaN, 'Mean_SNDR_dB', NaN, 'Mean_ACLR_avg_dBc', NaN, ...
    'Total_DPDSaturationCount', NaN, 'Total_DriveLimitCount', NaN), ...
    numel(modes), 1);
  for index = 1:numel(modes)
    selected = Results.Mode == modes(index);
    rows(index).Mode = modes(index);
    rows(index).Mean_EVM_percent = mean(Results.EVM_percent(selected));
    rows(index).Mean_NMSE_dB = mean(Results.NMSE_dB(selected));
    rows(index).Mean_SNDR_dB = mean(Results.SNDR_dB(selected));
    rows(index).Mean_ACLR_avg_dBc = mean(Results.ACLR_avg_dBc(selected));
    rows(index).Total_DPDSaturationCount = sum(Results.DPDSaturationCount(selected));
    rows(index).Total_DriveLimitCount = sum(Results.DriveLimitCount(selected));
  end
  Summary = struct2table(rows);
end

function T = coefficient_table(memoryless, memory_poly, orders)
  rows = repmat(struct('Model', string(""), 'Tap', NaN, 'Order', NaN, ...
    'FloatReal', NaN, 'FloatImag', NaN, 'Q2_14_Real', NaN, ...
    'Q2_14_Imag', NaN, 'PackedHex', string("")), ...
    memoryless.taps * numel(orders) + memory_poly.taps * numel(orders), 1);
  row = 0;
  models = {memoryless, memory_poly};
  names = ["Memoryless DPD", "Memory-polynomial DPD"];
  for model_idx = 1:2
    model = models{model_idx};
    for tap = 0:model.taps-1
      for order_idx = 1:numel(orders)
        row = row + 1;
        index = tap * numel(orders) + order_idx;
        rows(row).Model = names(model_idx);
        rows(row).Tap = tap;
        rows(row).Order = orders(order_idx);
        rows(row).FloatReal = real(model.coeff_float(index));
        rows(row).FloatImag = imag(model.coeff_float(index));
        rows(row).Q2_14_Real = real(model.coeff_q(index));
        rows(row).Q2_14_Imag = imag(model.coeff_q(index));
        rows(row).PackedHex = packed_hex(model.coeff_q(index));
      end
    end
  end
  T = struct2table(rows(1:row));
end

function value = packed_hex(coeff)
  value = string(sprintf('0x%04X%04X', twos_u16(imag(coeff)), ...
    twos_u16(real(coeff))));
end

function value = twos_u16(value)
  value = int32(value);
  if value < 0
    value = uint32(value + 65536);
  else
    value = uint32(value);
  end
end

function row = empty_result()
  row = struct('TestSeed', NaN, 'Mode', string(""), 'EVM_percent', NaN, ...
    'NMSE_dB', NaN, 'SNDR_dB', NaN, 'ACLR_L_dBc', NaN, ...
    'ACLR_R_dBc', NaN, 'ACLR_avg_dBc', NaN, ...
    'DPDSaturationCount', NaN, 'DriveLimitCount', NaN);
end

function write_summary(path, Results, Summary, Coefficients, ml, mp, cfg)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot write %s', path); end
  cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '# Memory-Polynomial DPD Training Comparison\n\n');
  fprintf(fid, 'Fit, validation, and test OFDM waveforms use disjoint seeds. All test modes share the same behavioral PA and per-seed observation-noise realization.\n\n');
  fprintf(fid, '- Waveform: %d-QAM, %d/%d occupied subcarriers, backoff %.2f\n', ...
    cfg.qam_order, cfg.nused, cfg.nfft, cfg.input_backoff);
  fprintf(fid, '- Behavioral PA: three nonlinear memory taps, soft saturation, three-tap linear FIR, gain/phase drift, and %.1f dB observation SNR\n', cfg.observation_snr_dB);
  fprintf(fid, '- Datapath: Q1.15 samples and Q2.14 complex coefficients\n');
  fprintf(fid, '- Memoryless selected ridge: %.3g; validation EVM: %.6f%%\n', ...
    ml.ridge, ml.validation.EVM_percent);
  fprintf(fid, '- Memory-polynomial selected ridge: %.3g; validation EVM: %.6f%%\n\n', ...
    mp.ridge, mp.validation.EVM_percent);
  fprintf(fid, '## Test Summary\n\n');
  fprintf(fid, '| Mode | Mean EVM %% | Mean NMSE dB | Mean SNDR dB | Mean ACLR dBc | DPD saturation | Drive limited |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
  for index = 1:height(Summary)
    fprintf(fid, '| %s | %.6f | %.6f | %.6f | %.6f | %d | %d |\n', ...
      Summary.Mode(index), Summary.Mean_EVM_percent(index), ...
      Summary.Mean_NMSE_dB(index), Summary.Mean_SNDR_dB(index), ...
      Summary.Mean_ACLR_avg_dBc(index), ...
      Summary.Total_DPDSaturationCount(index), Summary.Total_DriveLimitCount(index));
  end
  fprintf(fid, '\n## Per-Seed Results\n\n');
  fprintf(fid, '| Seed | Mode | EVM %% | NMSE dB | ACLR dBc | DPD saturation | Drive limited |\n');
  fprintf(fid, '|---:|---|---:|---:|---:|---:|---:|\n');
  for index = 1:height(Results)
    fprintf(fid, '| %d | %s | %.6f | %.6f | %.6f | %d | %d |\n', ...
      Results.TestSeed(index), Results.Mode(index), Results.EVM_percent(index), ...
      Results.NMSE_dB(index), Results.ACLR_avg_dBc(index), ...
      Results.DPDSaturationCount(index), Results.DriveLimitCount(index));
  end
  fprintf(fid, '\n## Quantized Coefficients\n\n');
  fprintf(fid, '| Model | Tap | Order | Q2.14 real | Q2.14 imag | Packed word |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---|\n');
  for index = 1:height(Coefficients)
    fprintf(fid, '| %s | %d | %d | %d | %d | `%s` |\n', ...
      Coefficients.Model(index), Coefficients.Tap(index), ...
      Coefficients.Order(index), Coefficients.Q2_14_Real(index), ...
      Coefficients.Q2_14_Imag(index), Coefficients.PackedHex(index));
  end
  fprintf(fid, '\nThese are behavioral simulation results, not measurements from a physical PA or calibrated RF receiver.\n');
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0
    error('Arguments must be key/value pairs.');
  end
  for index = 1:2:numel(varargin)
    if ~isfield(cfg, varargin{index})
      error('Unknown configuration field: %s', varargin{index});
    end
    cfg.(varargin{index}) = varargin{index+1};
  end
end

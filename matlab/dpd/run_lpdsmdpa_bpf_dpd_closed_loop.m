function [Results, Coefficients, Artifacts] = run_lpdsmdpa_bpf_dpd_closed_loop(varargin)
% Run a system-level DPD experiment through a 1-bit switched-DPA+BPF endpoint.
% This is a behavioral model, not a transistor, ADS, or physical-PA simulation.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});
  fit_reference = make_ofdm(cfg, cfg.fit_seed, cfg.fit_nsym);
  validation_references = cell(numel(cfg.validation_seeds), 1);
  for k = 1:numel(cfg.validation_seeds)
    validation_references{k} = make_ofdm(cfg, cfg.validation_seeds(k), cfg.validation_nsym);
  end
  identity_q = identity_coeff_q(cfg);

  % The one-bit DPA endpoint is non-smooth, so do not use a postdistorter as a
  % predistorter. Search the actual Q2.14 pre-DPD words with ILC-style
  % coordinate updates on fit data and select the accepted checkpoint on a
  % disjoint validation waveform.
  [coeff_q, TrainingTrace, Validation] = train_q214_ilc( ...
    fit_reference, validation_references, identity_q, cfg);
  coeff_float = double(coeff_q) / 2^cfg.coeff_frac;

  modes = ["No DPD", "Q2.14 Memory-Poly DPD"];
  rows = repmat(empty_row(), numel(cfg.test_seeds) * numel(modes), 1);
  row = 0;
  for seed = cfg.test_seeds(:).'
    ref = make_ofdm(cfg, seed, cfg.test_nsym);
    for mode_idx = 1:numel(modes)
      switch mode_idx
        case 1
          dpd_out = ref;
          saturation_count = 0;
        case 2
          [dpd_out, saturation_count] = apply_q214_memory_poly(ref, coeff_q, cfg);
          [dpd_out, drive_limited] = limit_drive(dpd_out, cfg.dpd_drive_limit);
          saturation_count = saturation_count + drive_limited;
      end
      [feedback, endpoint] = switched_dpa_feedback(dpd_out, cfg);
      metrics = evaluate_feedback(ref, feedback, cfg);

      row = row + 1;
      rows(row).Seed = seed;
      rows(row).Mode = modes(mode_idx);
      rows(row).EVM_percent = metrics.evm_percent;
      rows(row).SNDR_dB = metrics.sndr_dB;
      rows(row).ACLR_dBc = metrics.aclr_dBc;
      rows(row).DPDLimitCount = saturation_count;
      rows(row).RFBitOneFraction = endpoint.rf_bit_one_fraction;
      rows(row).DPAOutputRMS = endpoint.dpa_output_rms;
    end
  end
  Results = struct2table(rows);
  Coefficients = make_coefficient_table(coeff_float, coeff_q, cfg);
  QualityGate = evaluate_quality_gate(Results, Validation, cfg);
  Artifacts = struct('cfg', cfg, 'fit_reference', fit_reference, ...
    'validation_references', {validation_references}, 'coeff_float', coeff_float, ...
    'coeff_q', coeff_q, 'training_trace', TrainingTrace, ...
    'validation', Validation, 'quality_gate', QualityGate);

  if cfg.write_outputs
    out_dir = cfg.out_dir;
    if isempty(out_dir)
      out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
    end
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    writetable(Results, fullfile(out_dir, 'lpdsmdpa_bpf_dpd_closed_loop.csv'));
    % Candidate coefficients are diagnostic evidence only.  A separate release
    % file is emitted only after the independent quality gate accepts them.
    writetable(Coefficients, fullfile(out_dir, 'lpdsmdpa_bpf_dpd_candidate_coefficients.csv'));
    writetable(TrainingTrace, fullfile(out_dir, 'lpdsmdpa_bpf_dpd_training_trace.csv'));
    writetable(Validation, fullfile(out_dir, 'lpdsmdpa_bpf_dpd_validation.csv'));
    writetable(QualityGate, fullfile(out_dir, 'lpdsmdpa_bpf_dpd_quality_gate.csv'));
    release_path = fullfile(out_dir, 'lpdsmdpa_bpf_dpd_release_coefficients.csv');
    if QualityGate.Status == "ACCEPT"
      writetable(Coefficients, release_path);
    elseif exist(release_path, 'file')
      delete(release_path);
    end
    write_report(fullfile(out_dir, 'lpdsmdpa_bpf_dpd_closed_loop.md'), ...
      Results, Coefficients, TrainingTrace, Validation, QualityGate, cfg);
    save(fullfile(out_dir, 'lpdsmdpa_bpf_dpd_closed_loop.mat'), ...
      'Results', 'Coefficients', 'Artifacts');
  end
  if cfg.verbose
    disp(Results);
    disp(Coefficients);
  end
end

function cfg = default_cfg()
  cfg.fit_seed = 101;
  cfg.validation_seed = 137; % Retained for backwards-compatible callers.
  cfg.validation_seeds = [137 149 163];
  cfg.test_seeds = [211 223 239];
  cfg.fit_nsym = 24;
  cfg.validation_nsym = 20;
  cfg.test_nsym = 16;
  cfg.nfft = 128;
  cfg.ncp = 16;
  cfg.nused = 12;
  cfg.qam_order = 16;
  cfg.bb_fs_hz = 3.125e6;
  cfg.osr = 32;
  cfg.fs_hz = cfg.bb_fs_hz * cfg.osr;
  cfg.if_hz = cfg.fs_hz / 4;
  cfg.channel_bw_hz = cfg.bb_fs_hz * cfg.nused / cfg.nfft;
  cfg.bpf_bw_hz = 2.0 * cfg.channel_bw_hz;
  cfg.rx_lpf_bw_hz = 1.25 * cfg.channel_bw_hz;
  cfg.input_backoff = 0.45;
  cfg.dpd_drive_limit = 0.75;
  cfg.memory_taps = 4;
  cfg.orders = [1 3 5];
  cfg.coeff_w = 16;
  cfg.coeff_frac = 14;
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_safe_abs = 24576;
  % High-order terms are attenuated by |x|^2 and |x|^4 at the configured
  % input backoff.  Start wide enough to explore a useful predistortion range,
  % then refine in Q2.14 steps.  A point is still retained only after every
  % validation condition passes.
  cfg.ilc_steps = [8192 4096 2048 1024 512 256 128];
  cfg.ilc_max_passes = 1;
  cfg.validation_oob_tolerance_dB = 0.0;
  cfg.dpa_high_level = 1.00;
  cfg.dpa_low_level = -0.94;
  cfg.dpa_switch_asymmetry = 0.035;
  cfg.dpa_thermal_alpha = 0.992;
  cfg.dpa_thermal_compression = 0.24;
  cfg.dpa_memory_fir = [0.88 0.16 -0.05];
  cfg.observation_snr_dB = 46;
  cfg.out_dir = '';
  cfg.write_outputs = true;
  cfg.verbose = true;
end

function x = make_ofdm(cfg, seed, nsym)
  rng(seed, 'twister');
  X = zeros(cfg.nfft, nsym);
  used = [(cfg.nfft/2-cfg.nused/2+1):(cfg.nfft/2), ...
    (cfg.nfft/2+2):(cfg.nfft/2+1+cfg.nused/2)];
  side = sqrt(cfg.qam_order);
  symbol_index = randi([0 cfg.qam_order - 1], numel(used), nsym);
  i = mod(symbol_index, side);
  q = floor(symbol_index / side);
  X(used, :) = complex(2*i-(side-1), 2*q-(side-1));
  X = X / sqrt(mean(abs(X(used, :)).^2, 'all'));
  x = ifft(ifftshift(X, 1), cfg.nfft, 1);
  x = [x(end-cfg.ncp+1:end, :); x];
  x = x(:);
  x = cfg.input_backoff * x / max(abs(x) + eps);
  x = quantize_q15(x, cfg);
end

function [feedback, endpoint] = switched_dpa_feedback(x, cfg)
  % This first system model uses ideal band-limited interpolation. It preserves
  % the x32 rate and suppresses zero-order-hold images, but deliberately does
  % not claim I0 FIR bit-true equivalence.
  high_rate = bandlimited_interpolate(x(:), cfg.osr);
  i_bit = lpdsm2_bit_dsm(real(high_rate), cfg);
  q_bit = lpdsm2_bit_dsm(imag(high_rate), cfg);
  phase = mod((0:numel(high_rate)-1).', 4);
  rf_signed = i_bit;
  rf_signed(phase == 1) = q_bit(phase == 1);
  rf_signed(phase == 2) = -i_bit(phase == 2);
  rf_signed(phase == 3) = -q_bit(phase == 3);
  rf_bit = rf_signed > 0;

  % The DPA model exposes switch asymmetry, pulse-density thermal memory, and
  % finite output bandwidth before the explicit 25 MHz output BPF.
  on_fraction = filter(1-cfg.dpa_thermal_alpha, [1 -cfg.dpa_thermal_alpha], ...
    double(rf_bit));
  thermal_gain = 1 - cfg.dpa_thermal_compression * (on_fraction - 0.5);
  levels = cfg.dpa_low_level + (cfg.dpa_high_level-cfg.dpa_low_level) * double(rf_bit);
  levels = levels .* (1 + cfg.dpa_switch_asymmetry * rf_signed) .* thermal_gain;
  dpa_out = filter(cfg.dpa_memory_fir(:), 1, levels);
  bpf_out = fft_bandpass(dpa_out, cfg.fs_hz, cfg.if_hz, cfg.bpf_bw_hz);
  mixed = 2 * bpf_out .* exp(-1j * 2*pi*cfg.if_hz/cfg.fs_hz * (0:numel(bpf_out)-1).');
  baseband = fft_lowpass(mixed, cfg.fs_hz, cfg.rx_lpf_bw_hz);
  % Fs/4 merge emits Re{(I - jQ)exp(j*pi*n/2)}. Conjugate after coherent
  % downconversion to restore the project's original I + jQ convention.
  feedback = conj(baseband(1:cfg.osr:end));
  feedback = feedback(1:numel(x));
  noise_power = mean(abs(feedback).^2) / 10^(cfg.observation_snr_dB/10);
  % Derive a repeatable noise state from the input without perturbing the
  % caller's global random stream used for separate OFDM test cases.
  prior_rng = rng;
  restore_rng = onCleanup(@() rng(prior_rng)); %#ok<NASGU>
  rng(numel(x) + round(1000*mean(abs(x))), 'twister');
  feedback = feedback + sqrt(noise_power/2) * ...
    (randn(size(feedback)) + 1j*randn(size(feedback)));
  endpoint = struct('rf_bit_one_fraction', mean(rf_bit), ...
    'dpa_output_rms', sqrt(mean(abs(bpf_out).^2)));
end

function bits = lpdsm2_bit_dsm(x, cfg)
% Reuse the project's verified Q1.15 LPDSM2 behavioral model.
  q15 = int64(saturate_round(x(:)*2^cfg.input_frac, cfg.input_w));
  bits = 2 * double(dsm_singlebit_model(q15, 'lp2')) - 1;
end

function y = bandlimited_interpolate(x, factor)
  n = numel(x);
  X = fftshift(fft(x(:)));
  Y = zeros(n * factor, 1);
  first = floor((numel(Y) - n) / 2) + 1;
  Y(first:first+n-1) = X;
  y = ifft(ifftshift(Y)) * factor;
end

function q = identity_coeff_q(cfg)
  q = complex(zeros(cfg.memory_taps * numel(cfg.orders), 1));
  q(1) = 2^cfg.coeff_frac;
end

function [best_q, Trace, Validation] = train_q214_ilc(fit_ref, validation_refs, identity_q, cfg)
% ILC-style black-box coefficient search against the actual 1-bit endpoint.
% Coordinate moves use the fit waveform for search direction, but a retained
% training update and a release checkpoint must both satisfy every disjoint
% validation condition.  This intentionally prevents an average-only fit gain
% from steering the coordinate search toward a non-generalizing coefficient.
  current_q = identity_q;
  [fit_metrics, fit_limits] = evaluate_q214_endpoint(fit_ref, current_q, cfg);
  [baseline_val, baseline_val_limits] = evaluate_validation_set(validation_refs, identity_q, cfg);
  best_q = current_q;
  best_validation = baseline_val;
  best_limits = baseline_val_limits;
  trace_rows = repmat(empty_trace_row(), 0, 1);
  trace_rows(end+1) = make_trace_row(0, 0, 0, current_q, fit_metrics, ...
    fit_limits, baseline_val, baseline_val_limits, true, "identity"); %#ok<AGROW>
  iteration = 0;
  for step = cfg.ilc_steps
    for pass = 1:cfg.ilc_max_passes
      accepted_pass = false;
      for index = 1:numel(current_q)
        for component = 1:2
          for direction = [-1 1]
            iteration = iteration + 1;
            candidate = perturb_coeff(current_q, index, component, direction * step, cfg);
            [candidate_fit, candidate_fit_limits] = evaluate_q214_endpoint(fit_ref, candidate, cfg);
            accepted_fit = candidate_fit_limits == 0 && ...
              candidate_fit.aclr_dBc <= fit_metrics.aclr_dBc + cfg.validation_oob_tolerance_dB && ...
              fit_loss(candidate_fit) < fit_loss(fit_metrics) - 1e-9;
            candidate_val = best_validation;
            candidate_val_limits = best_limits;
            checkpoint = false;
            if accepted_fit
              [candidate_val, candidate_val_limits] = ...
                evaluate_validation_set(validation_refs, candidate, cfg);
              checkpoint = all(candidate_val_limits == 0) && ...
                validates(candidate_val, baseline_val, cfg) && ...
                validation_loss(candidate_val) < validation_loss(best_validation) - 1e-9;
            end
            trace_rows(end+1) = make_trace_row(iteration, step, pass, candidate, ...
              candidate_fit, candidate_fit_limits, candidate_val, ...
              candidate_val_limits, accepted_fit, "coordinate"); %#ok<AGROW>
            if accepted_fit && checkpoint
              current_q = candidate;
              fit_metrics = candidate_fit;
              accepted_pass = true;
              best_q = candidate;
              best_validation = candidate_val;
              best_limits = candidate_val_limits;
            end
          end
        end
      end
      if ~accepted_pass, break; end
    end
  end
  Trace = struct2table(trace_rows);
  Validation = make_validation_table(baseline_val, best_validation, best_limits, cfg.validation_seeds);
end

function [metrics, limits] = evaluate_validation_set(references, coeff_q, cfg)
  metrics = repmat(struct('evm_percent', NaN, 'sndr_dB', NaN, 'aclr_dBc', NaN), numel(references), 1);
  limits = zeros(numel(references), 1);
  for k = 1:numel(references)
    [metrics(k), limits(k)] = evaluate_q214_endpoint(references{k}, coeff_q, cfg);
  end
end

function [metrics, limits] = evaluate_q214_endpoint(ref, coeff_q, cfg)
  [drive, limits] = apply_q214_memory_poly(ref, coeff_q, cfg);
  [drive, drive_limits] = limit_drive(drive, cfg.dpd_drive_limit);
  limits = limits + drive_limits;
  feedback = switched_dpa_feedback(drive, cfg);
  metrics = evaluate_feedback(ref, feedback, cfg);
end

function q = perturb_coeff(q, index, component, delta, cfg)
  value = q(index);
  if component == 1
    value = complex(real(value) + delta, imag(value));
  else
    value = complex(real(value), imag(value) + delta);
  end
  q(index) = complex(clamp_integer(real(value), cfg.coeff_safe_abs), ...
    clamp_integer(imag(value), cfg.coeff_safe_abs));
end

function value = clamp_integer(value, bound)
  value = min(max(round(value), -bound), bound);
end

function value = fit_loss(metrics)
  value = metrics.evm_percent - 0.10 * metrics.sndr_dB + 0.05 * metrics.aclr_dBc;
end

function value = validation_loss(metrics)
  value = mean([metrics.evm_percent]) - 0.10 * mean([metrics.sndr_dB]);
end

function accepted = validates(candidate, baseline, cfg)
  accepted = all([candidate.evm_percent] < [baseline.evm_percent]) && ...
    all([candidate.sndr_dB] > [baseline.sndr_dB]) && ...
    all([candidate.aclr_dBc] <= [baseline.aclr_dBc] + cfg.validation_oob_tolerance_dB);
end

function [y, saturation_count] = apply_q214_memory_poly(x, coeff_q, cfg)
  q = quantize_q15(x, cfg);
  acc_i = zeros(numel(x), 1, 'int64');
  acc_q = zeros(numel(x), 1, 'int64');
  for tap = 0:cfg.memory_taps-1
    ii = [zeros(tap, 1, 'int64'); int64(real(q(1:end-tap)) * 2^cfg.input_frac)];
    qq = [zeros(tap, 1, 'int64'); int64(imag(q(1:end-tap)) * 2^cfg.input_frac)];
    r2 = bitsra(ii.*ii + qq.*qq, cfg.input_frac);
    radial = int64(2^cfg.input_frac);
    gr = int64(0); gi = int64(0);
    for k = 1:numel(cfg.orders)
      c = coeff_q(tap*numel(cfg.orders)+k);
      if k > 1, radial = bitsra(radial .* r2, cfg.input_frac); end
      gr = gr + bitsra(int64(real(c)) .* radial, cfg.input_frac);
      gi = gi + bitsra(int64(imag(c)) .* radial, cfg.input_frac);
    end
    acc_i = acc_i + bitsra(ii.*gr - qq.*gi, cfg.coeff_frac);
    acc_q = acc_q + bitsra(ii.*gi + qq.*gr, cfg.coeff_frac);
  end
  [yi, sat_i] = saturate_int(acc_i, cfg.input_w);
  [yq, sat_q] = saturate_int(acc_q, cfg.input_w);
  saturation_count = sum(sat_i | sat_q);
  y = double(yi)/2^cfg.input_frac + 1j*double(yq)/2^cfg.input_frac;
end

function A = memory_poly_basis(x, taps, orders)
  x = x(:); A = zeros(numel(x), taps*numel(orders)); col = 0;
  for tap = 0:taps-1
    delayed = [zeros(tap, 1); x(1:end-tap)];
    for order = orders
      col = col + 1;
      A(:, col) = delayed .* abs(delayed).^(order-1);
    end
  end
end

function q = quantize_coeff(x, cfg)
  q = complex(saturate_round(real(x)*2^cfg.coeff_frac, cfg.coeff_w), ...
    saturate_round(imag(x)*2^cfg.coeff_frac, cfg.coeff_w));
end

function x = quantize_q15(x, cfg)
  x = complex(saturate_round(real(x)*2^cfg.input_frac, cfg.input_w), ...
    saturate_round(imag(x)*2^cfg.input_frac, cfg.input_w)) / 2^cfg.input_frac;
end

function y = saturate_round(x, width)
  y = min(max(round(x), -2^(width-1)), 2^(width-1)-1);
end

function [y, count] = limit_drive(x, limit)
  y = x(:); over = abs(y) > limit;
  y(over) = y(over) .* limit ./ abs(y(over));
  count = sum(over);
end

function y = fft_bandpass(x, fs, fc, bw)
  f = fft_frequency(numel(x), fs); X = fft(x(:));
  y = real(ifft(X .* ((abs(f-fc) <= bw/2) | (abs(f+fc) <= bw/2))));
end

function y = fft_lowpass(x, fs, bw)
  f = fft_frequency(numel(x), fs);
  y = ifft(fft(x(:)) .* (abs(f) <= bw/2));
end

function f = fft_frequency(n, fs)
  k = (0:n-1).'; k(k >= ceil(n/2)) = k(k >= ceil(n/2)) - n; f = k*fs/n;
end

function m = evaluate_feedback(ref, feedback, cfg)
  [y, x] = align_gain_delay(feedback, ref, 8);
  err = y-x; signal = mean(abs(x).^2); noise = mean(abs(err).^2);
  m.evm_percent = 100*sqrt(noise/(signal+eps));
  m.sndr_dB = 10*log10((signal+eps)/(noise+eps));
  ac = fft_lowpass(y, cfg.bb_fs_hz, cfg.channel_bw_hz);
  m.aclr_dBc = 10*log10((mean(abs(y-ac).^2)+eps)/(mean(abs(ac).^2)+eps));
end

function [best_y, best_x] = align_gain_delay(y, x, max_delay)
  best_error = inf; best_y = []; best_x = [];
  for delay = -max_delay:max_delay
    if delay >= 0
      yy = y(1+delay:end); xx = x(1:numel(yy));
    else
      xx = x(1-delay:end); yy = y(1:numel(xx));
    end
    gain = (yy' * xx) / (yy' * yy + eps); yy = yy * gain;
    err = mean(abs(yy-xx).^2);
    if err < best_error, best_error = err; best_y = yy; best_x = xx; end
  end
end

function T = make_coefficient_table(coeff_float, coeff_q, cfg)
  rows = repmat(struct('Tap', 0, 'Order', 0, 'FloatReal', 0, 'FloatImag', 0, ...
    'Q2_14_Real', 0, 'Q2_14_Imag', 0, 'PackedHex', ""), numel(coeff_q), 1);
  for k = 1:numel(coeff_q)
    rows(k).Tap = floor((k-1)/numel(cfg.orders));
    rows(k).Order = cfg.orders(mod(k-1, numel(cfg.orders))+1);
    rows(k).FloatReal = real(coeff_float(k)); rows(k).FloatImag = imag(coeff_float(k));
    rows(k).Q2_14_Real = real(coeff_q(k)); rows(k).Q2_14_Imag = imag(coeff_q(k));
    rows(k).PackedHex = string(sprintf('0x%04X%04X', twos_u16(imag(coeff_q(k))), twos_u16(real(coeff_q(k)))));
  end
  T = struct2table(rows);
end

function value = twos_u16(value)
  value = round(value); if value < 0, value = value + 65536; end
end

function [value, saturated] = saturate_int(value, width)
  hi = int64(2^(width-1)-1); lo = -int64(2^(width-1));
  saturated = value > hi | value < lo; value = min(max(value, lo), hi);
end

function row = empty_row()
  row = struct('Seed', 0, 'Mode', "", 'EVM_percent', NaN, 'SNDR_dB', NaN, ...
    'ACLR_dBc', NaN, 'DPDLimitCount', 0, 'RFBitOneFraction', NaN, 'DPAOutputRMS', NaN);
end

function T = make_validation_table(baseline, selected, limits, seeds)
  rows = repmat(empty_validation_row(), 2*numel(seeds), 1);
  row = 0;
  for k = 1:numel(seeds)
    row = row + 1;
    rows(row) = validation_metric_row(seeds(k), "No DPD", baseline(k), 0);
    row = row + 1;
    rows(row) = validation_metric_row(seeds(k), "Selected Q2.14 DPD", selected(k), limits(k));
  end
  T = struct2table(rows);
end

function row = empty_validation_row()
  row = struct('Seed', 0, 'Mode', "", 'EVM_percent', NaN, 'SNDR_dB', NaN, ...
    'ACLR_dBc', NaN, 'DPDLimitCount', 0);
end

function row = validation_metric_row(seed, mode, metrics, limits)
  row = struct('Seed', seed, 'Mode', mode, 'EVM_percent', metrics.evm_percent, ...
    'SNDR_dB', metrics.sndr_dB, 'ACLR_dBc', metrics.aclr_dBc, ...
    'DPDLimitCount', limits);
end

function T = evaluate_quality_gate(results, validation, cfg)
  no_dpd = results(results.Mode == "No DPD", :);
  q214 = results(results.Mode == "Q2.14 Memory-Poly DPD", :);
  validation_no_dpd = validation(validation.Mode == "No DPD", :);
  validation_q214 = validation(validation.Mode == "Selected Q2.14 DPD", :);
  evm_improvement = mean(no_dpd.EVM_percent) - mean(q214.EVM_percent);
  sndr_improvement = mean(q214.SNDR_dB) - mean(no_dpd.SNDR_dB);
  oob_improvement = mean(no_dpd.ACLR_dBc) - mean(q214.ACLR_dBc);
  validation_evm_improvement = validation_no_dpd.EVM_percent - validation_q214.EVM_percent;
  validation_sndr_improvement = validation_q214.SNDR_dB - validation_no_dpd.SNDR_dB;
  validation_oob_delta = validation_q214.ACLR_dBc - validation_no_dpd.ACLR_dBc;
  test_evm_pass = q214.EVM_percent < no_dpd.EVM_percent;
  test_sndr_pass = q214.SNDR_dB > no_dpd.SNDR_dB;
  test_oob_pass = q214.ACLR_dBc <= no_dpd.ACLR_dBc;
  validation_evm_pass = validation_evm_improvement > 0;
  validation_sndr_pass = validation_sndr_improvement > 0;
  validation_oob_pass = validation_oob_delta <= cfg.validation_oob_tolerance_dB;
  accepted = all(validation_evm_pass) && all(validation_sndr_pass) && ...
    all(validation_oob_pass) && all(validation_q214.DPDLimitCount == 0) && ...
    all(test_evm_pass) && all(test_sndr_pass) && all(test_oob_pass) && ...
    all(q214.DPDLimitCount == 0);
  status = "REJECT";
  if accepted, status = "ACCEPT"; end
  T = table(status, mean(validation_evm_improvement), mean(validation_sndr_improvement), ...
    max(validation_oob_delta), sum(validation_evm_pass), sum(validation_sndr_pass), ...
    sum(validation_oob_pass), sum(validation_q214.DPDLimitCount), evm_improvement, ...
    sndr_improvement, oob_improvement, sum(test_evm_pass), sum(test_sndr_pass), ...
    sum(test_oob_pass), sum(q214.DPDLimitCount), 'VariableNames', {'Status', ...
    'ValidationMeanEVMImprovement_percent', 'ValidationMeanSNDRImprovement_dB', ...
    'ValidationWorstOutOfBandDelta_dB', 'ValidationEVMPassCount', ...
    'ValidationSNDRPassCount', 'ValidationOutOfBandPassCount', ...
    'ValidationQ214LimitCount', 'TestEVMImprovement_percent', ...
    'TestSNDRImprovement_dB', 'TestOutOfBandImprovement_dB', ...
    'TestEVMPassCount', 'TestSNDRPassCount', 'TestOutOfBandPassCount', ...
    'TestQ214LimitCount'});
end

function row = empty_trace_row()
  row = struct('Iteration', 0, 'StepLSB', 0, 'Pass', 0, 'Source', "", ...
    'FitEVM_percent', NaN, 'FitSNDR_dB', NaN, 'FitACLR_dBc', NaN, ...
    'FitLimitCount', 0, 'ValidationEVM_percent', NaN, ...
    'ValidationSNDR_dB', NaN, 'ValidationACLR_dBc', NaN, ...
    'ValidationLimitCount', 0, 'ValidationNoLimitCount', 0, ...
    'ValidationConditionCount', 0, ...
    'AcceptedOnFit', false, ...
    'C1Re', 0, 'C1Im', 0, 'C3Re', 0, 'C3Im', 0, 'C5Re', 0, 'C5Im', 0);
end

function row = make_trace_row(iteration, step, pass, coeff_q, fit, fit_limits, val, val_limits, accepted, source)
  row = empty_trace_row();
  row.Iteration = iteration; row.StepLSB = step; row.Pass = pass; row.Source = source;
  row.FitEVM_percent = fit.evm_percent; row.FitSNDR_dB = fit.sndr_dB;
  row.FitACLR_dBc = fit.aclr_dBc; row.FitLimitCount = fit_limits;
  row.ValidationEVM_percent = mean([val.evm_percent]);
  row.ValidationSNDR_dB = mean([val.sndr_dB]);
  row.ValidationACLR_dBc = mean([val.aclr_dBc]);
  row.ValidationLimitCount = sum(val_limits);
  row.ValidationConditionCount = numel(val);
  row.ValidationNoLimitCount = sum(val_limits == 0);
  row.AcceptedOnFit = accepted;
  row.C1Re = real(coeff_q(1)); row.C1Im = imag(coeff_q(1));
  row.C3Re = real(coeff_q(2)); row.C3Im = imag(coeff_q(2));
  row.C5Re = real(coeff_q(3)); row.C5Im = imag(coeff_q(3));
end

function write_report(path, results, coefficients, trace, validation, quality_gate, cfg)
  fid = fopen(path, 'w'); if fid < 0, error('Cannot write %s', path); end
  cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '# LPDSM2 1-bit DPA+BPF DPD Closed-Loop Experiment\n\n');
  fprintf(fid, 'This is a MATLAB behavioral model, not ADS, transistor, EM, or measured-PA evidence.\n\n');
  fprintf(fid, '## Frozen Model\n\n');
  fprintf(fid, '- 3.125 MS/s complex baseband; x%d to %.0f MS/s; Fs/4 IF %.0f MHz.\n', ...
    cfg.osr, cfg.fs_hz/1e6, cfg.if_hz/1e6);
  fprintf(fid, '- The project LPDSM2 Q1.15 behavioral model and Fs/4 I/Q merge produce `rf_bit`.\n');
  fprintf(fid, '- Baseband-to-100-MS/s interpolation is ideal band-limited interpolation for this first system endpoint, not I0 FIR bit-true reconstruction.\n');
  fprintf(fid, '- DPA: switch-level asymmetry, pulse-density thermal compression, finite FIR memory, and %.3f MHz ideal output BPF.\n', cfg.bpf_bw_hz/1e6);
  fprintf(fid, '- Training: Q2.14 identity-start ILC coordinate search on seed %d; every validation seed [%s] constrains each accepted move; test seeds are [%s].\n', cfg.fit_seed, num2str(cfg.validation_seeds), num2str(cfg.test_seeds));
  fprintf(fid, '- Feedback: coherent downconversion, %.3f MHz low-pass, x%d decimation, and %.1f dB additive observation SNR.\n\n', cfg.rx_lpf_bw_hz/1e6, cfg.osr, cfg.observation_snr_dB);
  fprintf(fid, '## Validation Checkpoint\n\n| Seed | Mode | EVM %% | SNDR dB | Out-of-band ratio dBc | Limits |\n|---:|---|---:|---:|---:|---:|\n');
  for k = 1:height(validation)
    fprintf(fid, '| %d | %s | %.4f | %.4f | %.4f | %d |\n', validation.Seed(k), validation.Mode(k), validation.EVM_percent(k), validation.SNDR_dB(k), validation.ACLR_dBc(k), validation.DPDLimitCount(k));
  end
  fprintf(fid, '\nTraining trace contains %d evaluated Q2.14 candidates. A move is retained only when all validation conditions pass the EVM/SNDR/OOB/limit constraints.\n\n', height(trace));
  fprintf(fid, '## Coefficient Quality Gate\n\n');
  fprintf(fid, '| Status | Validation mean EVM improvement %% | Validation mean SNDR improvement dB | Validation EVM/SNDR/OOB pass count | Validation limits | Test EVM/SNDR/OOB pass count | Test limits |\n|---|---:|---:|---:|---:|---:|---:|\n');
  fprintf(fid, '| %s | %.4f | %.4f | %d/%d/%d | %d | %d/%d/%d | %d |\n\n', quality_gate.Status, quality_gate.ValidationMeanEVMImprovement_percent, quality_gate.ValidationMeanSNDRImprovement_dB, quality_gate.ValidationEVMPassCount, quality_gate.ValidationSNDRPassCount, quality_gate.ValidationOutOfBandPassCount, quality_gate.ValidationQ214LimitCount, quality_gate.TestEVMPassCount, quality_gate.TestSNDRPassCount, quality_gate.TestOutOfBandPassCount, quality_gate.TestQ214LimitCount);
  if quality_gate.Status == "REJECT"
    fprintf(fid, 'The Q2.14 coefficients are rejected: do not program them into RTL or hardware. Every independent test seed must improve EVM, SNDR, and out-of-band ratio with zero limits; an average-only gain is insufficient.\n\n');
  end
  fprintf(fid, '## Per-Seed Results\n\n| Seed | Mode | EVM %% | SNDR dB | Out-of-band ratio dBc | DPD limits | rf_bit one fraction | DPA RMS |\n|---:|---|---:|---:|---:|---:|---:|---:|\n');
  for k = 1:height(results)
    fprintf(fid, '| %d | %s | %.4f | %.4f | %.4f | %d | %.6f | %.6f |\n', results.Seed(k), results.Mode(k), results.EVM_percent(k), results.SNDR_dB(k), results.ACLR_dBc(k), results.DPDLimitCount(k), results.RFBitOneFraction(k), results.DPAOutputRMS(k));
  end
  fprintf(fid, '\n## Q2.14 Coefficients\n\n| Tap | Order | Real | Imag | Packed word |\n|---:|---:|---:|---:|---|\n');
  for k = 1:height(coefficients)
    fprintf(fid, '| %d | %d | %d | %d | `%s` |\n', coefficients.Tap(k), coefficients.Order(k), coefficients.Q2_14_Real(k), coefficients.Q2_14_Imag(k), coefficients.PackedHex(k));
  end
  if quality_gate.Status == "ACCEPT"
    fprintf(fid, '\nThe released Q2.14 table is compatible in shape with the current four-tap C1/C3/C5 Memory-Poly DPD. It still requires MATLAB-to-RTL per-sample bit-true verification before RTL or board use.\n');
  else
    fprintf(fid, '\nThis candidate Q2.14 table is diagnostic only and was not released for RTL or board use.\n');
  end
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0, error('Arguments must be name/value pairs.'); end
  for k = 1:2:numel(varargin)
    name = char(varargin{k}); if ~isfield(cfg, name), error('Unknown option: %s', name); end
    cfg.(name) = varargin{k+1};
  end
end

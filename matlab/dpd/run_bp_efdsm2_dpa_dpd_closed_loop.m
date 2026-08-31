function [Results, Summary, Coefficients, Artifacts] = run_bp_efdsm2_dpa_dpd_closed_loop(varargin)
% Run the frozen BP-EFDSM2 route through a behavioral switching-DPA endpoint.
% This is a model-level experiment, not ADS, transistor, or measured-RF data.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});
  fit_ref = make_ofdm(cfg, cfg.fit_seed, cfg.fit_nsym);
  val_ref = cell(numel(cfg.validation_seeds), 1);
  for k = 1:numel(cfg.validation_seeds)
    val_ref{k} = make_ofdm(cfg, cfg.validation_seeds(k), cfg.validation_nsym);
  end

  ml_cfg = cfg;
  ml_cfg.memory_taps = 1;
  ml_identity = identity_q(ml_cfg);
  mp_identity = identity_q(cfg);
  if cfg.enable_dpd_comparison
    [ml_q, ml_trace, ml_val] = train_q214(fit_ref, val_ref, ml_identity, ml_cfg);
    [mp_q, mp_trace, mp_val] = train_q214(fit_ref, val_ref, mp_identity, cfg);
    modes = ["No DPD", "Q2.14 Memoryless DPD", "Q2.14 Memory-Poly DPD"];
  else
    ml_q = ml_identity; mp_q = mp_identity;
    ml_trace = table(); mp_trace = table(); ml_val = table(); mp_val = table();
    modes = "No DPD";
  end
  rows = repmat(empty_row(), numel(cfg.test_seeds) * numel(modes), 1);
  row = 0;
  for seed = cfg.test_seeds(:).'
    ref = make_ofdm(cfg, seed, cfg.test_nsym);
    for mode_index = 1:numel(modes)
      if mode_index == 1
        drive = ref;
        dpd_limits = 0;
      elseif mode_index == 2
        [drive, dpd_limits] = apply_q214_memory_poly(ref, ml_q, ml_cfg);
        [drive, drive_rms_scale] = normalize_dpd_drive(drive, ref, ml_cfg);
        [drive, drive_limits] = limit_drive(drive, ml_cfg.dpd_drive_limit);
        dpd_limits = dpd_limits + drive_limits;
      else
        [drive, dpd_limits] = apply_q214_memory_poly(ref, mp_q, cfg);
        [drive, drive_rms_scale] = normalize_dpd_drive(drive, ref, cfg);
        [drive, drive_limits] = limit_drive(drive, cfg.dpd_drive_limit);
        dpd_limits = dpd_limits + drive_limits;
      end
      if mode_index == 1, drive_rms_scale = 1; end
      [feedback, endpoint] = bp_efdsm2_switching_dpa(drive, cfg);
      metrics = evaluate_feedback(ref, feedback, endpoint.rf_waveform, endpoint.rf_waveform_unfiltered, cfg);
      row = row + 1;
      rows(row).Seed = seed;
      rows(row).Mode = modes(mode_index);
      rows(row).EVM_percent = metrics.evm_percent;
      rows(row).SNDR_dB = metrics.sndr_dB;
      rows(row).ACLR_dBc = metrics.aclr_dBc;
      rows(row).PA_ACLR_dBc = metrics.pa_aclr_dBc;
      rows(row).Pout_mW = 1e3 * endpoint.pout_w;
      rows(row).Pdc_mW = 1e3 * endpoint.pdc_w;
      rows(row).Efficiency_percent = 100 * endpoint.efficiency;
      rows(row).DPDLimitCount = dpd_limits;
      rows(row).RFBitOneFraction = endpoint.rf_bit_one_fraction;
      rows(row).DriveRMSScale = drive_rms_scale;
    end
  end

  Results = struct2table(rows);
  Summary = summarize_modes(Results, modes);
  Coefficients = [make_coefficient_table("Memoryless DPD", ml_q, ml_cfg); ...
                  make_coefficient_table("Memory-Polynomial DPD", mp_q, cfg)];
  Artifacts = struct('cfg', cfg, 'memoryless_q', ml_q, 'memory_poly_q', mp_q, ...
    'memoryless_trace', ml_trace, 'memory_poly_trace', mp_trace, ...
    'memoryless_validation', ml_val, 'memory_poly_validation', mp_val);

  if cfg.write_outputs
    if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end
    writetable(Results, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_dpd_results.csv'));
    writetable(Summary, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_dpd_summary.csv'));
    writetable(Coefficients, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_dpd_coefficients.csv'));
    writetable(ml_trace, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_memoryless_trace.csv'));
    writetable(mp_trace, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_memory_poly_trace.csv'));
    writetable(ml_val, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_memoryless_validation.csv'));
    writetable(mp_val, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_memory_poly_validation.csv'));
    write_report(fullfile(cfg.out_dir, 'bp_efdsm2_dpa_dpd_report.md'), Summary, cfg);
    save(fullfile(cfg.out_dir, 'bp_efdsm2_dpa_dpd_results.mat'), ...
      'Results', 'Summary', 'Coefficients', 'Artifacts');
  end
  if cfg.verbose, disp(Summary); end
end

function cfg = default_cfg()
  cfg.fit_seed = 101;
  cfg.validation_seeds = [137 149];
  cfg.test_seeds = [211 223 239];
  cfg.fit_nsym = 10;
  cfg.validation_nsym = 8;
  cfg.test_nsym = 12;
  cfg.nfft = 128;
  cfg.ncp = 16;
  cfg.nused = 12;
  cfg.qam_order = 16;
  cfg.bb_fs_hz = 3.125e6;
  cfg.osr = 32;
  cfg.fs_hz = cfg.bb_fs_hz * cfg.osr;
  cfg.if_hz = cfg.fs_hz / 4;
  cfg.channel_bw_hz = cfg.bb_fs_hz * cfg.nused / cfg.nfft;
  % The occupied OFDM half-band is channel_bw_hz/2. Keep a modest guard band
  % rather than passing most of the one-bit quantization noise to the receiver.
  cfg.output_bpf_bw_hz = 1.50 * cfg.channel_bw_hz;
  cfg.rx_lpf_bw_hz = 1.25 * cfg.channel_bw_hz;
  cfg.adjacent_offset_hz = 2.5 * cfg.channel_bw_hz;
  cfg.input_backoff = 0.45;
  cfg.dpd_drive_limit = 0.78;
  cfg.memory_taps = 4;
  cfg.orders = [1 3 5];
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.coeff_w = 16;
  cfg.coeff_frac = 14;
  cfg.coeff_safe_abs = 24576;
  cfg.acc_w = 28;
  cfg.ilc_steps = [2048 1024 512];
  cfg.vdd_v = 3.3;
  cfg.load_ohm = 50;
  cfg.dpa_low_level_v = -3.12;
  cfg.dpa_high_level_v = 3.30;
  cfg.switch_asymmetry = 0.012;
  cfg.thermal_alpha = 0.996;
  cfg.thermal_compression = 0.10;
  cfg.dpa_memory_fir = [0.92 0.10 -0.025];
  cfg.ron_ohm = 0.20;
  cfg.switch_node_cap_f = 1.0e-12;
  cfg.gate_energy_j = 0.10e-12;
  % A DPD with C1 > 1 can otherwise appear to improve EVM simply because it
  % drives the one-bit modulator and DPA harder. Match post-DPD input RMS to
  % the no-DPD waveform before the declared drive limiter for a fair first
  % comparison. This is a modeled digital-gain setting, not DPD arithmetic.
  cfg.power_comparison_mode = "match_input_rms";
  % `ideal_switch` isolates BP EFDSM2+BPF+receiver reconstruction. `full`
  % additionally enables switching asymmetry, thermal memory, and output FIR.
  cfg.endpoint_stage = "full";
  cfg.enable_dpd_comparison = true;
  cfg.modulator_mode = "ef2";
  cfg.bp_b1 = 0;
  cfg.bp_b2 = -1;
  cfg.dither_lsb = 0;
  cfg.dither_seed = 17;
  cfg.bpf_model = "analog_2nd_order";
  cfg.bpf_q = 50;
  cfg.bpf_insertion_loss_dB = 0.60;
  cfg.bpf_center_offset_hz = 0;
  cfg.metric_guard_symbols = 1;
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  cfg.write_outputs = true;
  cfg.verbose = true;
end

function x = make_ofdm(cfg, seed, nsym)
  rng(seed, 'twister');
  X = zeros(cfg.nfft, nsym);
  used = [(cfg.nfft/2-cfg.nused/2+1):(cfg.nfft/2), ...
    (cfg.nfft/2+2):(cfg.nfft/2+1+cfg.nused/2)];
  side = sqrt(cfg.qam_order);
  index = randi([0 cfg.qam_order-1], numel(used), nsym);
  X(used, :) = complex(2*mod(index, side)-(side-1), ...
    2*floor(index/side)-(side-1));
  X = X / sqrt(mean(abs(X(used, :)).^2, 'all'));
  x = ifft(ifftshift(X, 1), cfg.nfft, 1);
  x = [x(end-cfg.ncp+1:end, :); x];
  x = x(:);
  x = cfg.input_backoff * x / max(abs(x) + eps);
  x = quantize_q15(x, cfg);
end

function [feedback, endpoint] = bp_efdsm2_switching_dpa(x, cfg)
  hi = bandlimited_interpolate(x, cfg.osr);
  phase = mod((0:numel(hi)-1).', 4);
  if_sample = real(hi);
  if_sample(phase == 1) = imag(hi(phase == 1));
  if_sample(phase == 2) = -real(hi(phase == 2));
  if_sample(phase == 3) = -imag(hi(phase == 3));
  [rf_code, rf_bit] = bp_modulator_code(if_sample, cfg);
  signed_bit = 2*double(rf_bit)-1;
  if cfg.endpoint_stage == "ideal_switch"
    thermal_gain = ones(size(rf_bit));
  else
    on_fraction = filter(1-cfg.thermal_alpha, [1 -cfg.thermal_alpha], double(rf_bit));
    thermal_gain = 1 - cfg.thermal_compression * (on_fraction - 0.5);
  end
  if string(cfg.modulator_mode) == "mash11"
    % MASH11 is a native four-level output. It is evaluated through a
    % symmetric multilevel driver model and is not a one-bit DPA claim.
    qlevel = double(2^(cfg.input_w-1)-1);
    levels = (cfg.dpa_high_level_v-cfg.dpa_low_level_v) / 2 * double(rf_code) / (3*qlevel);
  else
    levels = cfg.dpa_low_level_v + (cfg.dpa_high_level_v-cfg.dpa_low_level_v) * double(rf_bit);
  end
  if cfg.endpoint_stage == "ideal_switch" || string(cfg.modulator_mode) == "mash11"
    dpa_out = levels;
  else
    levels = levels .* (1 + cfg.switch_asymmetry * signed_bit) .* thermal_gain;
    dpa_out = filter(cfg.dpa_memory_fir(:), 1, levels);
  end
  rf = analog_output_bpf(dpa_out, cfg);
  n = (0:numel(rf)-1).';
  bb = fft_lowpass(2 * rf .* exp(1j*2*pi*cfg.if_hz/cfg.fs_hz*n), cfg.fs_hz, cfg.rx_lpf_bw_hz);
  feedback = select_decimation_phase(bb, x, cfg);

  pout_w = mean(rf.^2) / cfg.load_ohm;
  transitions = sum(abs(diff(double(rf_bit))));
  conduction_w = mean((abs(rf) / cfg.load_ohm).^2) * cfg.ron_ohm;
  switching_w = transitions / max(numel(rf)-1, 1) * cfg.switch_node_cap_f * cfg.vdd_v^2 * cfg.fs_hz;
  gate_w = cfg.gate_energy_j * cfg.fs_hz;
  pdc_w = pout_w + conduction_w + switching_w + gate_w;
  endpoint = struct('rf_waveform', rf, 'rf_waveform_unfiltered', dpa_out, ...
    'rf_bit_one_fraction', mean(rf_bit), ...
    'pout_w', pout_w, 'pdc_w', pdc_w, 'efficiency', pout_w / max(pdc_w, eps));
end

function [code, bits] = bp_modulator_code(x, cfg)
  mode = lower(string(cfg.modulator_mode));
  switch mode
    case "single"
      code = bp_single_code(x, cfg);
    case "ef2"
      code = bp_ef2_code(x, cfg);
    case "mash11"
      code = bp_mash11_code(x, cfg);
    otherwise
      error('Unknown modulator_mode: %s', cfg.modulator_mode);
  end
  bits = code >= 0;
end

function code = bp_ef2_code(x, cfg)
  xq = int64(saturate_round(x(:)*2^cfg.input_frac, cfg.input_w));
  e1 = int64(0); e2 = int64(0);
  code = zeros(numel(xq), 1, 'int64');
  vmax = int64(2^(cfg.acc_w-1)-1); vmin = -int64(2^(cfg.acc_w-1));
  qlevel = int64(2^(cfg.input_w-1)-1);
  for k = 1:numel(xq)
    dither = int64(cfg.dither_lsb * (mod(k*17 + cfg.dither_seed, 5) - 2));
    v = int64(xq(k)) + int64(round(cfg.bp_b1*double(e1) + cfg.bp_b2*double(e2))) + dither;
    v = min(max(v, vmin), vmax);
    bit = v >= 0;
    code(k) = int64(2*bit-1) * qlevel;
    e0 = v - code(k);
    e2 = e1;
    e1 = e0;
  end
end

function code = bp_single_code(x, cfg)
  xq = int64(saturate_round(x(:)*2^cfg.input_frac, cfg.input_w));
  s1 = int64(0); s2 = int64(0); yreg = int64(1);
  code = zeros(numel(xq), 1, 'int64');
  vmax = int64(2^(cfg.acc_w-1)-1); vmin = -int64(2^(cfg.acc_w-1));
  qlevel = int64(2^(cfg.input_w-1)-1);
  for k = 1:numel(xq)
    code(k) = (2*yreg-1)*qlevel;
    q = code(k);
    s1n = min(max(xq(k)-q-s2, vmin), vmax);
    s2n = s1; yreg = int64((-s2n) >= 0); s1 = s1n; s2 = s2n;
  end
end

function code = bp_mash11_code(x, cfg)
  xq = int64(saturate_round(x(:)*2^cfg.input_frac, cfg.input_w));
  qlevel = int64(2^(cfg.input_w-1)-1);
  e1 = int64([0 0]); e2 = int64([0 0]);
  y1reg = int64(1); y2reg = int64(1); y2d1 = int64(1); y2d2 = int64(1);
  code = zeros(numel(xq), 1, 'int64');
  vmax = int64(2^(cfg.acc_w-1)-1); vmin = -int64(2^(cfg.acc_w-1));
  for k = 1:numel(xq)
    code(k) = int64((2*y1reg-1) - ((2*y2reg-1) + (2*y2d2-1)));
    v1 = min(max(xq(k) - e1(2), vmin), vmax);
    q1 = int64(2*int64(v1 >= 0)-1)*qlevel;
    e1next = v1 - q1; y1next = int64(v1 >= 0);
    v2 = fix(double(e1(1))/16) - e2(2);
    v2 = min(max(int64(v2), vmin), vmax);
    q2 = int64(2*int64(v2 >= 0)-1)*qlevel;
    e2next = v2 - q2; y2next = int64(v2 >= 0);
    e1 = [e1next e1(1)]; e2 = [e2next e2(1)];
    y2d2 = y2d1; y2d1 = y2reg; y1reg = y1next; y2reg = y2next;
  end
  code = code * qlevel;
end

function [best_q, Trace, Validation] = train_q214(fit_ref, validation_refs, initial_q, cfg)
  current_q = initial_q;
  [fit_metric, fit_limits] = endpoint_metric(fit_ref, current_q, cfg);
  baseline = validation_metrics(validation_refs, initial_q, cfg);
  best_q = current_q; best_val = baseline;
  trace = repmat(empty_trace_row(), 0, 1);
  iteration = 0;
  for step = cfg.ilc_steps
    improved = false;
    for index = 1:numel(current_q)
      for component = 1:2
        for direction = [-1 1]
          iteration = iteration + 1;
          candidate = perturb_coeff(current_q, index, component, direction*step, cfg);
          [candidate_fit, candidate_limits] = endpoint_metric(fit_ref, candidate, cfg);
          candidate_val = validation_metrics(validation_refs, candidate, cfg);
          accepted = candidate_limits == 0 && candidate_fit.aclr_dBc <= fit_metric.aclr_dBc && ...
            all([candidate_val.evm_percent] < [baseline.evm_percent]) && ...
            all([candidate_val.sndr_dB] > [baseline.sndr_dB]) && ...
            all([candidate_val.aclr_dBc] <= [baseline.aclr_dBc]) && ...
            mean([candidate_val.evm_percent]) < mean([best_val.evm_percent]);
          trace(end+1) = make_trace_row(iteration, step, candidate_fit, candidate_limits, candidate_val, accepted); %#ok<AGROW>
          if accepted
            current_q = candidate; fit_metric = candidate_fit;
            best_q = candidate; best_val = candidate_val; improved = true;
          end
        end
      end
    end
    if ~improved, continue; end
  end
  Trace = struct2table(trace);
  Validation = validation_table(baseline, best_val, cfg.validation_seeds);
end

function [metric, limits] = endpoint_metric(ref, coeff_q, cfg)
  [drive, limits] = apply_q214_memory_poly(ref, coeff_q, cfg);
  [drive, ~] = normalize_dpd_drive(drive, ref, cfg);
  [drive, drive_limits] = limit_drive(drive, cfg.dpd_drive_limit);
  limits = limits + drive_limits;
  [feedback, endpoint] = bp_efdsm2_switching_dpa(drive, cfg);
  metric = evaluate_feedback(ref, feedback, endpoint.rf_waveform, endpoint.rf_waveform_unfiltered, cfg);
end

function metrics = validation_metrics(refs, coeff_q, cfg)
  metrics = repmat(struct('evm_percent', NaN, 'sndr_dB', NaN, 'aclr_dBc', NaN, ...
    'pa_aclr_dBc', NaN), numel(refs), 1);
  for k = 1:numel(refs), [metrics(k), ~] = endpoint_metric(refs{k}, coeff_q, cfg); end
end

function [y, saturation_count] = apply_q214_memory_poly(x, coeff_q, cfg)
  q = quantize_q15(x, cfg); acc_i = zeros(numel(q), 1, 'int64'); acc_q = acc_i;
  for tap = 0:cfg.memory_taps-1
    ii = [zeros(tap, 1, 'int64'); int64(real(q(1:end-tap))*2^cfg.input_frac)];
    qq = [zeros(tap, 1, 'int64'); int64(imag(q(1:end-tap))*2^cfg.input_frac)];
    r2 = bitsra(ii.*ii + qq.*qq, cfg.input_frac); radial = int64(2^cfg.input_frac);
    gr = int64(0); gi = int64(0);
    for k = 1:numel(cfg.orders)
      if k > 1, radial = bitsra(radial.*r2, cfg.input_frac); end
      c = coeff_q(tap*numel(cfg.orders)+k);
      gr = gr + bitsra(int64(real(c)).*radial, cfg.input_frac);
      gi = gi + bitsra(int64(imag(c)).*radial, cfg.input_frac);
    end
    acc_i = acc_i + bitsra(ii.*gr - qq.*gi, cfg.coeff_frac);
    acc_q = acc_q + bitsra(ii.*gi + qq.*gr, cfg.coeff_frac);
  end
  [yi, sat_i] = saturate_int(acc_i, cfg.input_w); [yq, sat_q] = saturate_int(acc_q, cfg.input_w);
  saturation_count = sum(sat_i | sat_q);
  y = double(yi)/2^cfg.input_frac + 1j*double(yq)/2^cfg.input_frac;
end

function m = evaluate_feedback(ref, feedback, rf_filtered, rf_pa, cfg)
  [y, x] = align_gain_delay(feedback, ref, 8);
  % Use the same receiver metric family as the BP DSM architecture audit:
  % remove CP, FFT, and equalize one complex gain per occupied subcarrier.
  % A time-domain single-gain error would count benign BPF passband tilt as
  % modulation error and is not comparable to the earlier 3.56%% DSM result.
  [m.evm_percent, m.sndr_dB] = ofdm_evm_sndr(y, x, cfg);
  m.aclr_dBc = rf_aclr(rf_filtered, cfg);
  m.pa_aclr_dBc = rf_aclr(rf_pa, cfg);
end

function [evm_percent, sndr_dB] = ofdm_evm_sndr(y, x, cfg)
  symbol_length = cfg.nfft + cfg.ncp;
  count = floor(min(numel(y), numel(x)) / symbol_length);
  if count <= 2*cfg.metric_guard_symbols
    error('Not enough whole OFDM symbols for EVM after transient guard.');
  end
  y = reshape(y(1:count*symbol_length), symbol_length, count);
  x = reshape(x(1:count*symbol_length), symbol_length, count);
  use = (cfg.metric_guard_symbols+1):(count-cfg.metric_guard_symbols);
  bins = [(cfg.nfft-cfg.nused/2+1):cfg.nfft, 2:(cfg.nused/2+1)];
  yf = fft(y(cfg.ncp+1:end, use), cfg.nfft, 1);
  xf = fft(x(cfg.ncp+1:end, use), cfg.nfft, 1);
  yf = yf(bins, :); xf = xf(bins, :);
  channel = sum(yf .* conj(xf), 2) ./ (sum(abs(xf).^2, 2) + eps);
  error = yf ./ (channel + eps) - xf;
  signal_power = sum(abs(xf).^2, 'all');
  error_power = sum(abs(error).^2, 'all');
  evm_percent = 100*sqrt(error_power/(signal_power+eps));
  sndr_dB = 10*log10((signal_power+eps)/(error_power+eps));
end

function aclr = rf_aclr(rf, cfg)
  f = fft_frequency(numel(rf), cfg.fs_hz); p = abs(fft(rf)).^2;
  main = (abs(abs(f)-cfg.if_hz) <= cfg.channel_bw_hz/2);
  left = (abs(abs(f)-(cfg.if_hz-cfg.adjacent_offset_hz)) <= cfg.channel_bw_hz/2);
  right = (abs(abs(f)-(cfg.if_hz+cfg.adjacent_offset_hz)) <= cfg.channel_bw_hz/2);
  aclr = 10*log10((max(sum(p(left)), sum(p(right)))+eps)/(sum(p(main))+eps));
end

function y = analog_output_bpf(x, cfg)
% Causal second-order analog RLC band-pass equivalent using bilinear transform.
  if string(cfg.bpf_model) == "ideal_fft"
    y = fft_bandpass(x, cfg.fs_hz, cfg.if_hz, cfg.output_bpf_bw_hz);
    return;
  end
  if string(cfg.bpf_model) ~= "analog_2nd_order"
    error('Unknown bpf_model: %s', cfg.bpf_model);
  end
  fs = cfg.fs_hz; fc = cfg.if_hz + cfg.bpf_center_offset_hz;
  if ~(fc > 0 && fc < fs/2 && cfg.bpf_q > 0), error('Invalid analog BPF parameters.'); end
  k = 2*fs; w0 = 2*fs*tan(pi*fc/fs); b = w0/cfg.bpf_q;
  a0 = k^2 + b*k + w0^2; a1 = 2*(w0^2-k^2); a2 = k^2-b*k+w0^2;
  b0 = b*k; b1 = 0; b2 = -b*k; gain = 10^(-cfg.bpf_insertion_loss_dB/20);
  xa1=0; xa2=0; ya1=0; ya2=0; x=x(:); y=zeros(size(x));
  for n=1:numel(x)
    yn=(b0*x(n)+b1*xa1+b2*xa2-a1*ya1-a2*ya2)/a0;
    y(n)=gain*yn; xa2=xa1; xa1=x(n); ya2=ya1; ya1=yn;
  end
end

function y = bandlimited_interpolate(x, factor)
  n = numel(x); X = fftshift(fft(x(:))); Y = zeros(n*factor,1);
  first = floor((numel(Y)-n)/2)+1; Y(first:first+n-1) = X;
  y = ifft(ifftshift(Y))*factor;
end

function y = fft_bandpass(x, fs, fc, bw)
  f = fft_frequency(numel(x), fs); y = real(ifft(fft(x(:)).*((abs(f-fc)<=bw/2)|(abs(f+fc)<=bw/2))));
end

function y = fft_lowpass(x, fs, bw)
  f = fft_frequency(numel(x), fs); y = ifft(fft(x(:)).*(abs(f)<=bw/2));
end

function f = fft_frequency(n, fs)
  k = (0:n-1).'; k(k>=ceil(n/2)) = k(k>=ceil(n/2))-n; f = k*fs/n;
end

function feedback = select_decimation_phase(bb, ref, cfg)
  best_error = inf; feedback = bb(1:cfg.osr:end);
  for phase = 0:cfg.osr-1
    candidate = bb(phase+1:cfg.osr:end); n = min(numel(candidate), numel(ref));
    if n < 32, continue; end
    [y, x] = align_gain_delay(candidate(1:n), ref(1:n), 8);
    value = mean(abs(y-x).^2)/(mean(abs(x).^2)+eps);
    if value < best_error, best_error = value; feedback = candidate(1:n); end
  end
end

function [best_y, best_x] = align_gain_delay(y, x, max_delay)
  best_error = inf; best_y = []; best_x = [];
  for delay = -max_delay:max_delay
    if delay >= 0, yy = y(1+delay:end); xx = x(1:numel(yy));
    else, xx = x(1-delay:end); yy = y(1:numel(xx)); end
    gain = (yy'*xx)/(yy'*yy+eps); yy = yy*gain; value = mean(abs(yy-xx).^2);
    if value < best_error, best_error = value; best_y = yy; best_x = xx; end
  end
end

function q = identity_q(cfg)
  q = complex(zeros(cfg.memory_taps*numel(cfg.orders),1)); q(1) = 2^cfg.coeff_frac;
end

function q = quantize_q15(x, cfg)
  q = complex(saturate_round(real(x)*2^cfg.input_frac, cfg.input_w), ...
    saturate_round(imag(x)*2^cfg.input_frac, cfg.input_w))/2^cfg.input_frac;
end

function [y, count] = limit_drive(x, limit)
  y = x(:); over = abs(y)>limit; y(over) = y(over).*limit./abs(y(over)); count = sum(over);
end

function [y, scale] = normalize_dpd_drive(x, reference, cfg)
  y = x(:);
  scale = 1;
  if string(cfg.power_comparison_mode) == "match_input_rms"
    scale = rms(abs(reference(:))) / max(rms(abs(y)), eps);
    y = quantize_q15(y * scale, cfg);
  elseif string(cfg.power_comparison_mode) ~= "none"
    error('Unknown power_comparison_mode: %s', cfg.power_comparison_mode);
  end
end

function q = perturb_coeff(q, index, component, delta, cfg)
  value = q(index);
  if component == 1, value = complex(real(value)+delta, imag(value));
  else, value = complex(real(value), imag(value)+delta); end
  q(index) = complex(clamp(real(value),cfg.coeff_safe_abs), clamp(imag(value),cfg.coeff_safe_abs));
end

function value = clamp(value, bound), value = min(max(round(value),-bound),bound); end
function y = saturate_round(x, width), y = min(max(round(x),-2^(width-1)),2^(width-1)-1); end
function [value, saturated] = saturate_int(value, width)
  hi = int64(2^(width-1)-1); lo = -int64(2^(width-1)); saturated = value>hi | value<lo; value = min(max(value,lo),hi);
end

function row = empty_row()
  row = struct('Seed',0,'Mode',"",'EVM_percent',NaN,'SNDR_dB',NaN,'ACLR_dBc',NaN,'PA_ACLR_dBc',NaN, ...
    'Pout_mW',NaN,'Pdc_mW',NaN,'Efficiency_percent',NaN,'DPDLimitCount',0,'RFBitOneFraction',NaN,'DriveRMSScale',NaN);
end

function row = empty_trace_row()
  row = struct('Iteration',0,'StepLSB',0,'FitEVM_percent',NaN,'FitSNDR_dB',NaN, ...
    'FitACLR_dBc',NaN,'FitLimitCount',0,'ValidationMeanEVM_percent',NaN, ...
    'ValidationMeanSNDR_dB',NaN,'ValidationMeanACLR_dBc',NaN,'Accepted',false);
end

function row = make_trace_row(iteration, step, fit, limits, validation, accepted)
  row = empty_trace_row(); row.Iteration = iteration; row.StepLSB = step;
  row.FitEVM_percent = fit.evm_percent; row.FitSNDR_dB = fit.sndr_dB; row.FitACLR_dBc = fit.aclr_dBc;
  row.FitLimitCount = limits; row.ValidationMeanEVM_percent = mean([validation.evm_percent]);
  row.ValidationMeanSNDR_dB = mean([validation.sndr_dB]); row.ValidationMeanACLR_dBc = mean([validation.aclr_dBc]);
  row.Accepted = accepted;
end

function T = validation_table(baseline, selected, seeds)
  rows = repmat(struct('Seed',0,'Mode',"",'EVM_percent',NaN,'SNDR_dB',NaN,'ACLR_dBc',NaN),2*numel(seeds),1);
  for k = 1:numel(seeds)
    rows(2*k-1) = struct('Seed',seeds(k),'Mode',"No DPD",'EVM_percent',baseline(k).evm_percent,'SNDR_dB',baseline(k).sndr_dB,'ACLR_dBc',baseline(k).aclr_dBc);
    rows(2*k) = struct('Seed',seeds(k),'Mode',"Selected DPD",'EVM_percent',selected(k).evm_percent,'SNDR_dB',selected(k).sndr_dB,'ACLR_dBc',selected(k).aclr_dBc);
  end
  T = struct2table(rows);
end

function T = summarize_modes(results, modes)
  rows = repmat(struct('Mode',"",'MeanEVM_percent',NaN,'MeanSNDR_dB',NaN,'MeanACLR_dBc',NaN,'MeanPA_ACLR_dBc',NaN, ...
    'MeanPout_mW',NaN,'MeanPdc_mW',NaN,'MeanEfficiency_percent',NaN,'MeanDriveRMSScale',NaN,'TotalDPDLimitCount',0),numel(modes),1);
  for k = 1:numel(modes)
    s = results(results.Mode==modes(k),:); rows(k).Mode = modes(k);
    rows(k).MeanEVM_percent = mean(s.EVM_percent); rows(k).MeanSNDR_dB = mean(s.SNDR_dB);
    rows(k).MeanACLR_dBc = mean(s.ACLR_dBc); rows(k).MeanPout_mW = mean(s.Pout_mW);
    rows(k).MeanPA_ACLR_dBc = mean(s.PA_ACLR_dBc);
    rows(k).MeanPdc_mW = mean(s.Pdc_mW); rows(k).MeanEfficiency_percent = mean(s.Efficiency_percent);
    rows(k).MeanDriveRMSScale = mean(s.DriveRMSScale);
    rows(k).TotalDPDLimitCount = sum(s.DPDLimitCount);
  end
  T = struct2table(rows);
end

function T = make_coefficient_table(model, coeff_q, cfg)
  rows = repmat(struct('Model',"",'Tap',0,'Order',0,'Q2_14_Real',0,'Q2_14_Imag',0),numel(coeff_q),1);
  for k = 1:numel(coeff_q)
    rows(k).Model = model; rows(k).Tap = floor((k-1)/numel(cfg.orders));
    rows(k).Order = cfg.orders(mod(k-1,numel(cfg.orders))+1); rows(k).Q2_14_Real = real(coeff_q(k)); rows(k).Q2_14_Imag = imag(coeff_q(k));
  end
  T = struct2table(rows);
end

function write_report(path, summary, cfg)
  fid = fopen(path,'w'); assert(fid>=0,'Cannot write %s',path); cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid,'# BP-EFDSM2 Behavioral Switching-DPA DPD Experiment\n\n');
  fprintf(fid,'Model boundary: Q1.15 DPD, ideal band-limited x32 interpolation, Fs/4 BP EFDSM2, behavioral switching DPA, ideal output BPF, coherent DDC, CP removal, FFT, per-subcarrier equalization, and Q2.14 DPD training. It is not ADS, transistor, EM, board, or measured RF evidence.\n\n');
  fprintf(fid,'Endpoint stage: %s. DPD power comparison: %s.\n\n',cfg.endpoint_stage,cfg.power_comparison_mode);
  fprintf(fid,'| Mode | EVM %% | SNDR dB | Filtered ACLR dBc | PA-side ACLR dBc | Pout mW | Pdc mW | Efficiency %% | Drive RMS scale | DPD limits |\n|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
  for k = 1:height(summary)
    fprintf(fid,'| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.3f | %.6f | %d |\n',summary.Mode(k),summary.MeanEVM_percent(k),summary.MeanSNDR_dB(k),summary.MeanACLR_dBc(k),summary.MeanPA_ACLR_dBc(k),summary.MeanPout_mW(k),summary.MeanPdc_mW(k),summary.MeanEfficiency_percent(k),summary.MeanDriveRMSScale(k),summary.TotalDPDLimitCount(k));
  end
  fprintf(fid,'\nDPA parameters: VDD %.2f V, %.1f ohm declared load, RON %.3f ohm, switch-node capacitance %.3g F. Pdc is a behavioral loss estimate, not a circuit supply-current result.\n',cfg.vdd_v,cfg.load_ohm,cfg.ron_ohm,cfg.switch_node_cap_f);
  fprintf(fid,'Analog BPF: %s, Q=%.2f, insertion loss=%.3f dB, center offset=%.3f Hz. Filtered ACLR is antenna-side; PA-side ACLR is diagnostic.\n',cfg.bpf_model,cfg.bpf_q,cfg.bpf_insertion_loss_dB,cfg.bpf_center_offset_hz);
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin),2)~=0, error('Use name/value pairs.'); end
  for k = 1:2:numel(varargin)
    name = char(varargin{k}); if ~isfield(cfg,name), error('Unknown option: %s',name); end
    cfg.(name) = varargin{k+1};
  end
end

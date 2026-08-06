function T = run_dpd_memory_pa_observation_sweep(varargin)
% run_dpd_memory_pa_observation_sweep
% DPD system-level sweep with a more realistic PA and an assumed RF
% observation chain.
%
% The purpose is diagnostic. It separates native complex-baseband metrics from
% RF-recovered metrics that depend on reconstruction/downconversion
% assumptions.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});

  scenarios = build_scenarios(cfg);
  rows = repmat(empty_row(), numel(scenarios), 1);
  opt_trace = repmat(empty_trace_row(), 0, 1);

  for k = 1:numel(scenarios)
    sc = scenarios(k);
    rng(cfg.seed + k - 1);

    local_cfg = cfg;
    local_cfg.pa = sc.pa;
    local_cfg.input_backoff = sc.input_backoff;
    local_cfg.nused = sc.nused;
    local_cfg.qam_order = sc.qam_order;
    local_cfg.pa.c1 = local_cfg.pa.c1 * sc.pa_relative_gain_scale;
    local_cfg.pa.c3 = local_cfg.pa.c3 * sc.pa_relative_gain_scale;
    local_cfg.pa.c5 = local_cfg.pa.c5 * sc.pa_relative_gain_scale;
    local_cfg.pa_memory_taps = sc.pa_memory_taps;
    local_cfg.pa_sat_level = sc.pa_sat_level;
    local_cfg.pa_gain_drift_ppm = sc.pa_gain_drift_ppm;
    local_cfg.pa_phase_drift_deg = sc.pa_phase_drift_deg;
    local_cfg.pa_phase_ripple_deg = sc.pa_phase_ripple_deg;
    local_cfg.temperature_delta_c = sc.temperature_delta_c;
    local_cfg.temp_gainco_ppm_per_c = sc.temp_gainco_ppm_per_c;
    local_cfg.temp_phaseco_deg_per_c = sc.temp_phaseco_deg_per_c;
    local_cfg.observation_snr_dB = sc.observation_snr_dB;
    local_cfg.pa = trim_pa_taps(local_cfg.pa, local_cfg.pa_memory_taps);
    local_cfg = configure_observation_bandwidth(local_cfg);

    x = make_ofdm_source(local_cfg);
    x = local_cfg.input_backoff * x(:) / max(abs(x(:)) + eps);

    y_no = realistic_pa_observe(x, local_cfg);
    if isempty(local_cfg.seed_coeff_q)
      coeff = fit_memoryless_poly(y_no, x, local_cfg.poly_order, local_cfg.ridge);
      coeff_q_initial = quantize_signed(coeff, local_cfg.coeff_frac, local_cfg.coeff_w);
    else
      coeff_q_initial = validate_seed_coeff_q(local_cfg.seed_coeff_q, local_cfg);
    end
    coeff_q_initial = apply_seed_package(coeff_q_initial, local_cfg.seed_package_id, local_cfg);
    [coeff_q_opt, tr] = coordinate_search_poly(x, coeff_q_initial, local_cfg, k, sc.name);
    opt_trace = [opt_trace; tr(:)]; %#ok<AGROW>

    lut_q = train_lut_dpd(y_no, x, local_cfg);

    x_poly_initial = dpd_poly_fixed_model(x, coeff_q_initial, local_cfg);
    x_poly_opt = dpd_poly_fixed_model(x, coeff_q_opt, local_cfg);
    x_lut = dpd_lut_fixed_model(x, lut_q, local_cfg);

    x_poly_initial_limited = limit_drive(x_poly_initial, local_cfg.dpd_drive_limit);
    x_poly_opt_limited = limit_drive(x_poly_opt, local_cfg.dpd_drive_limit);
    x_lut_limited = limit_drive(x_lut, local_cfg.dpd_drive_limit);
    y_poly_initial = realistic_pa_observe(x_poly_initial_limited, local_cfg);
    y_poly_opt = realistic_pa_observe(x_poly_opt_limited, local_cfg);
    y_lut = realistic_pa_observe(x_lut_limited, local_cfg);

    native_no = eval_native(x, y_no, local_cfg);
    native_poly_initial = eval_native(x, y_poly_initial, local_cfg);
    native_poly_opt = eval_native(x, y_poly_opt, local_cfg);
    native_lut = eval_native(x, y_lut, local_cfg);
    rf_no = eval_rf_recovered(x, y_no, local_cfg);
    rf_poly_initial = eval_rf_recovered(x, y_poly_initial, local_cfg);
    rf_poly_opt = eval_rf_recovered(x, y_poly_opt, local_cfg);
    rf_lut = eval_rf_recovered(x, y_lut, local_cfg);
    mon_no = behavioral_monitor_proxy(x, x, y_no, local_cfg);
    mon_poly_initial = behavioral_monitor_proxy(x, x_poly_initial_limited, y_poly_initial, local_cfg);
    mon_poly_opt = behavioral_monitor_proxy(x, x_poly_opt_limited, y_poly_opt, local_cfg);
    mon_lut = behavioral_monitor_proxy(x, x_lut_limited, y_lut, local_cfg);

    rows(k) = empty_row();
    rows(k).Scenario = string(sc.name);
    rows(k).QAM = local_cfg.qam_order;
    rows(k).UsedSubcarriers = local_cfg.nused;
    rows(k).InputBackoff = local_cfg.input_backoff;
    rows(k).DPA_RelativeGainScale = sc.pa_relative_gain_scale;
    rows(k).DPA_RelativePowerDelta_dB = 20*log10(sc.pa_relative_gain_scale);
    rows(k).DPA_SaturationLevel = local_cfg.pa_sat_level;
    rows(k).DPA_MemoryTaps = local_cfg.pa_memory_taps;
    rows(k).DPA_ObservationSNR_dB = local_cfg.observation_snr_dB;
    rows(k).DPA_GainDrift_ppm = local_cfg.pa_gain_drift_ppm;
    rows(k).DPA_PhaseDrift_deg = local_cfg.pa_phase_drift_deg;
    rows(k).DPA_TemperatureDelta_C = local_cfg.temperature_delta_c;
    rows(k).DPA_OutputRMS = sqrt(mean(abs(y_no).^2));
    rows(k).DPA_OutputPowerProxy = mean(abs(y_no).^2);
    rows(k).DPA_OutputPeak = max(abs(y_no));
    rows(k).Native_NoDPD_EVM_percent = native_no.EVM_percent;
    rows(k).Native_InitialPoly_EVM_percent = native_poly_initial.EVM_percent;
    rows(k).Native_OptimizedPoly_EVM_percent = native_poly_opt.EVM_percent;
    rows(k).Native_LUT_EVM_percent = native_lut.EVM_percent;
    rows(k).Native_NoDPD_SNDR_dB = native_no.SNDR_dB;
    rows(k).Native_InitialPoly_SNDR_dB = native_poly_initial.SNDR_dB;
    rows(k).Native_OptimizedPoly_SNDR_dB = native_poly_opt.SNDR_dB;
    rows(k).Native_LUT_SNDR_dB = native_lut.SNDR_dB;
    rows(k).Native_NoDPD_ACLR_avg_dBc = native_no.ACLR_avg_dBc;
    rows(k).Native_InitialPoly_ACLR_avg_dBc = native_poly_initial.ACLR_avg_dBc;
    rows(k).Native_OptimizedPoly_ACLR_avg_dBc = native_poly_opt.ACLR_avg_dBc;
    rows(k).Native_LUT_ACLR_avg_dBc = native_lut.ACLR_avg_dBc;
    rows(k).RF_NoDPD_EVM_percent = rf_no.EVM_percent;
    rows(k).RF_InitialPoly_EVM_percent = rf_poly_initial.EVM_percent;
    rows(k).RF_OptimizedPoly_EVM_percent = rf_poly_opt.EVM_percent;
    rows(k).RF_LUT_EVM_percent = rf_lut.EVM_percent;
    rows(k).RF_NoDPD_SNDR_dB = rf_no.SNDR_dB;
    rows(k).RF_InitialPoly_SNDR_dB = rf_poly_initial.SNDR_dB;
    rows(k).RF_OptimizedPoly_SNDR_dB = rf_poly_opt.SNDR_dB;
    rows(k).RF_LUT_SNDR_dB = rf_lut.SNDR_dB;
    rows(k).RF_NoDPD_ACLR_avg_dBc = rf_no.ACLR_avg_dBc;
    rows(k).RF_InitialPoly_ACLR_avg_dBc = rf_poly_initial.ACLR_avg_dBc;
    rows(k).RF_OptimizedPoly_ACLR_avg_dBc = rf_poly_opt.ACLR_avg_dBc;
    rows(k).RF_LUT_ACLR_avg_dBc = rf_lut.ACLR_avg_dBc;
    rows(k).Mon_InitialPoly_InputPower = mon_poly_initial.input_power;
    rows(k).Mon_InitialPoly_OutputPower = mon_poly_initial.output_power;
    rows(k).Mon_InitialPoly_Peak = mon_poly_initial.peak;
    rows(k).Mon_InitialPoly_AvgMag = mon_poly_initial.avg_mag;
    rows(k).Mon_InitialPoly_EVMProxy = mon_poly_initial.evm_proxy;
    rows(k).Mon_InitialPoly_ACPRProxy = mon_poly_initial.acpr_proxy;
    rows(k).Mon_InitialPoly_SpecBin0 = mon_poly_initial.spec_bin0;
    rows(k).Mon_InitialPoly_SpecBin1 = mon_poly_initial.spec_bin1;
    rows(k).Mon_InitialPoly_SpecBin2 = mon_poly_initial.spec_bin2;
    rows(k).Mon_InitialPoly_SpecAdj = mon_poly_initial.spec_adj;
    rows(k).Mon_InitialPoly_Clip = mon_poly_initial.clip;
    rows(k).Mon_InitialPoly_Saturation = mon_poly_initial.saturation;
    rows(k).Mon_OptimizedPoly_InputPower = mon_poly_opt.input_power;
    rows(k).Mon_OptimizedPoly_OutputPower = mon_poly_opt.output_power;
    rows(k).Mon_OptimizedPoly_Peak = mon_poly_opt.peak;
    rows(k).Mon_OptimizedPoly_AvgMag = mon_poly_opt.avg_mag;
    rows(k).Mon_OptimizedPoly_EVMProxy = mon_poly_opt.evm_proxy;
    rows(k).Mon_OptimizedPoly_ACPRProxy = mon_poly_opt.acpr_proxy;
    rows(k).Mon_OptimizedPoly_SpecBin0 = mon_poly_opt.spec_bin0;
    rows(k).Mon_OptimizedPoly_SpecBin1 = mon_poly_opt.spec_bin1;
    rows(k).Mon_OptimizedPoly_SpecBin2 = mon_poly_opt.spec_bin2;
    rows(k).Mon_OptimizedPoly_SpecAdj = mon_poly_opt.spec_adj;
    rows(k).Mon_OptimizedPoly_Clip = mon_poly_opt.clip;
    rows(k).Mon_OptimizedPoly_Saturation = mon_poly_opt.saturation;
    rows(k).OptimizedPoly_Loss = scalar_loss(native_poly_opt, local_cfg);
    rows(k).SeedPackage = local_cfg.seed_package_id;
    rows(k).InitialPoly_Loss = scalar_loss(native_poly_initial, local_cfg);
    rows(k).Initial_C1_hex = packed_coeff_hex(coeff_q_initial(1));
    rows(k).Initial_C3_hex = packed_coeff_hex(coeff_q_initial(2));
    rows(k).Initial_C5_hex = packed_coeff_hex(coeff_q_initial(3));
    rows(k).C1_hex = packed_coeff_hex(coeff_q_opt(1));
    rows(k).C3_hex = packed_coeff_hex(coeff_q_opt(2));
    rows(k).C5_hex = packed_coeff_hex(coeff_q_opt(3));
    rows(k).LUT0_hex = packed_coeff_hex(lut_q(1));
    rows(k).LUT15_hex = packed_coeff_hex(lut_q(end));
  end

  T = struct2table(rows);
  Trace = struct2table(opt_trace);
  if cfg.write_outputs
    out_dir = cfg.out_dir;
    if isempty(out_dir)
      out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
    end
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    writetable(T, fullfile(out_dir, 'dpd_memory_pa_observation_sweep.csv'));
    writetable(Trace, fullfile(out_dir, 'dpd_memory_pa_observation_coordinate_trace.csv'));
    write_summary_md(T, cfg, fullfile(out_dir, 'dpd_memory_pa_observation_sweep.md'));
    save(fullfile(out_dir, 'dpd_memory_pa_observation_sweep.mat'), 'cfg', 'T', 'Trace', 'scenarios');
  end
  if cfg.verbose, disp(T); end
end

function cfg = default_cfg()
  cfg.seed = 41;
  cfg.nfft = 256;
  cfg.ncp = 32;
  cfg.nsym = 16;
  cfg.nused = 48;
  cfg.qam_order = 16;
  cfg.fs_hz = 100e6;
  cfg.channel_bw_hz = 20e6;
  cfg.adjacent_offset_hz = 20e6;
  cfg.if_hz = 25e6;
  cfg.rf_bp_bw_hz = 36e6;
  cfg.rx_lpf_bw_hz = 24e6;
  cfg.pa_linear_fir = [0.92+0.00j, 0.10-0.035j, -0.025+0.018j];
  cfg.pa_gain_scale = 1.0;
  cfg.pa_memory_taps = 3;
  cfg.pa_gain_drift_ppm = 1800;
  cfg.pa_phase_drift_deg = 1.8;
  cfg.pa_phase_ripple_deg = 0.45;
  cfg.temperature_delta_c = 0;
  cfg.temp_gainco_ppm_per_c = 120;
  cfg.temp_phaseco_deg_per_c = 0.08;
  cfg.pa_sat_level = 0.92;
  cfg.pa_smooth_sat_p = 3.0;
  cfg.observation_snr_dB = 43;
  cfg.input_backoff = 0.58;
  cfg.dpd_drive_limit = 0.92;
  cfg.poly_order = 5;
  cfg.ridge = 1e-7;
  cfg.input_w = 16;
  cfg.input_frac = 15;
  cfg.monitor_clip_level = 31130;
  cfg.coeff_w = 16;
  cfg.coeff_frac = 14;
  cfg.lut_aw = 4;
  cfg.coord_search_enable = true;
  cfg.coord_max_iter = 1;
  cfg.coord_initial_step = 64;
  cfg.coord_min_step = 64;
  cfg.loss_evm_weight = 10000;
  cfg.loss_sndr_weight = 50;
  cfg.loss_aclr_target_dBc = -45;
  cfg.loss_aclr_weight = 200;
  cfg.out_dir = '';
  cfg.write_outputs = true;
  cfg.verbose = true;
  cfg.scenario_set = 'baseline';
  % Six deterministic Q2.14 perturbation packages for simulation-only policy
  % benchmarking. Package zero preserves the fitted seed exactly.
  cfg.seed_package_id = 0;
  % A supplied seed is an externally generated Q2.14 starting package. It is
  % used by the benchmark to avoid fitting separately to a held PA profile.
  cfg.seed_coeff_q = [];
  cfg.scenario_filter = '';
end

function scenarios = build_scenarios(cfg)
  nominal_pa = make_memory_pa([1.0+0.00j, 0.04-0.015j, -0.012+0.008j], ...
    [-0.52+0.24j, -0.09+0.04j, 0.025-0.012j], ...
    [0.18-0.16j, 0.035-0.018j, -0.010+0.006j]);
  strong_pa = make_memory_pa([1.0+0.02j, 0.07-0.03j, -0.018+0.012j], ...
    [-0.72+0.34j, -0.13+0.06j, 0.035-0.018j], ...
    [0.26-0.23j, 0.055-0.030j, -0.016+0.010j]);

  if strcmp(cfg.scenario_set, 'dpa_characterization')
    scenarios = [ ...
      scenario_dpa('dpa_nominal', 0.58, 48, 16, nominal_pa, 1.00, 0.92, 3, 43, 1800, 1.8, 0), ...
      scenario_dpa('dpa_gain_low', 0.58, 48, 16, nominal_pa, 0.85, 0.92, 3, 43, 1800, 1.8, 0), ...
      scenario_dpa('dpa_gain_high', 0.58, 48, 16, nominal_pa, 1.15, 0.92, 3, 43, 1800, 1.8, 0), ...
      scenario_dpa('dpa_compression_soft', 0.58, 48, 16, nominal_pa, 1.00, 1.10, 3, 43, 1800, 1.8, 0), ...
      scenario_dpa('dpa_compression_strong', 0.58, 48, 16, nominal_pa, 1.00, 0.74, 3, 43, 1800, 1.8, 0), ...
      scenario_dpa('dpa_memoryless', 0.58, 48, 16, nominal_pa, 1.00, 0.92, 1, 43, 1800, 1.8, 0), ...
      scenario_dpa('dpa_memory_long', 0.58, 48, 16, strong_pa, 1.00, 0.92, 3, 43, 1800, 1.8, 0), ...
      scenario_dpa('dpa_noise_low', 0.58, 48, 16, nominal_pa, 1.00, 0.92, 3, 50, 1800, 1.8, 0), ...
      scenario_dpa('dpa_noise_high', 0.58, 48, 16, nominal_pa, 1.00, 0.92, 3, 35, 1800, 1.8, 0), ...
      scenario_dpa('dpa_temp_cold', 0.58, 48, 16, nominal_pa, 1.00, 0.92, 3, 43, 1800, 1.8, -40), ...
      scenario_dpa('dpa_temp_hot', 0.58, 48, 16, nominal_pa, 1.00, 0.92, 3, 43, 1800, 1.8, 60), ...
      scenario_dpa('dpa_combined_corner', 0.52, 48, 16, strong_pa, 1.10, 0.78, 3, 35, 3500, 3.0, 60) ...
    ];
  elseif strcmp(cfg.scenario_set, 'extended')
    scenarios = [ ...
      scenario('memory_pa_nominal_16qam_48sc_bo058', 0.58, 48, 16, nominal_pa), ...
      scenario('memory_pa_nominal_16qam_48sc_bo070', 0.70, 48, 16, nominal_pa), ...
      scenario('memory_pa_nominal_16qam_96sc_bo058', 0.58, 96, 16, nominal_pa), ...
      scenario('memory_pa_nominal_16qam_96sc_bo070', 0.70, 96, 16, nominal_pa), ...
      scenario('memory_pa_nominal_64qam_48sc_bo058', 0.58, 48, 64, nominal_pa), ...
      scenario('memory_pa_nominal_64qam_48sc_bo070', 0.70, 48, 64, nominal_pa), ...
      scenario('memory_pa_nominal_64qam_96sc_bo058', 0.58, 96, 64, nominal_pa), ...
      scenario('memory_pa_nominal_64qam_96sc_bo070', 0.70, 96, 64, nominal_pa) ...
    ];
  elseif strcmp(cfg.scenario_set, 'baseline')
    scenarios = [ ...
      scenario('memory_pa_nominal_16qam_48sc_bo058', 0.58, 48, 16, nominal_pa), ...
      scenario('memory_pa_strong_16qam_48sc_bo058', 0.58, 48, 16, strong_pa), ...
      scenario('memory_pa_nominal_64qam_96sc_bo052', 0.52, 96, 64, nominal_pa) ...
    ];
  else
    error('Unknown scenario_set: %s', cfg.scenario_set);
  end

  for k = 1:numel(scenarios)
    scenarios(k).pa = apply_pa_profile(scenarios(k).pa, cfg);
  end
  if ~isempty(cfg.scenario_filter)
    scenarios = scenarios(string({scenarios.name}) == string(cfg.scenario_filter));
    if isempty(scenarios), error('scenario_filter did not match a scenario.'); end
  end
end

function sc = scenario(name, backoff, nused, qam, pa)
  sc = scenario_dpa(name, backoff, nused, qam, pa, 1.0, 0.92, 3, 43, 1800, 1.8, 0);
end

function sc = scenario_dpa(name, backoff, nused, qam, pa, relative_gain_scale, sat_level, taps, snr_dB, gain_drift_ppm, phase_drift_deg, temperature_delta_c)
  sc = struct('name', string(name), 'input_backoff', backoff, 'nused', nused, ...
    'qam_order', qam, 'pa', pa, 'pa_relative_gain_scale', relative_gain_scale, ...
    'pa_sat_level', sat_level, 'pa_memory_taps', taps, ...
    'observation_snr_dB', snr_dB, 'pa_gain_drift_ppm', gain_drift_ppm, ...
    'pa_phase_drift_deg', phase_drift_deg, 'pa_phase_ripple_deg', 0.45, ...
    'temperature_delta_c', temperature_delta_c, 'temp_gainco_ppm_per_c', 120, ...
    'temp_phaseco_deg_per_c', 0.08);
end

function cfg = configure_observation_bandwidth(cfg)
% Keep the modeled RF observation bandwidth matched to the OFDM occupancy.
  if cfg.nused > 48
    cfg.nfft = 512;
    cfg.ncp = 64;
    cfg.fs_hz = 200e6;
    cfg.if_hz = 50e6;
  end
  occupied_bw_hz = cfg.fs_hz * cfg.nused / cfg.nfft;
  cfg.channel_bw_hz = 1.10 * occupied_bw_hz;
  cfg.adjacent_offset_hz = 1.20 * cfg.channel_bw_hz;
  cfg.rf_bp_bw_hz = 1.25 * cfg.channel_bw_hz;
  cfg.rx_lpf_bw_hz = 1.10 * cfg.channel_bw_hz;
end

function pa = apply_pa_profile(pa, cfg)
  ntap = min(max(round(cfg.pa_memory_taps), 1), numel(pa.c1));
  pa.c1 = pa.c1(1:ntap);
  pa.c3 = pa.c3(1:ntap);
  pa.c5 = pa.c5(1:ntap);
  pa.c1 = pa.c1 * cfg.pa_gain_scale;
end

function pa = trim_pa_taps(pa, taps)
  ntap = min(max(round(taps), 1), numel(pa.c1));
  pa.c1 = pa.c1(1:ntap);
  pa.c3 = pa.c3(1:ntap);
  pa.c5 = pa.c5(1:ntap);
end

function pa = make_memory_pa(c1, c3, c5)
  pa.c1 = c1(:);
  pa.c3 = c3(:);
  pa.c5 = c5(:);
end

function y = memory_pa(x, pa)
  x = x(:);
  y = zeros(size(x));
  ntap = numel(pa.c1);
  for m = 1:ntap
    xd = [zeros(m-1, 1); x(1:end-m+1)];
    r2 = abs(xd).^2;
    y = y + pa.c1(m).*xd + pa.c3(m).*xd.*r2 + pa.c5(m).*xd.*(r2.^2);
  end
end

function y = realistic_pa_observe(x, cfg)
  y = memory_pa(x, cfg.pa);
  y = apply_soft_saturation(y, cfg.pa_sat_level, cfg.pa_smooth_sat_p);
  y = filter(cfg.pa_linear_fir(:), 1, y);
  y = apply_gain_phase_drift(y, cfg);
  y = add_observation_noise(y, cfg.observation_snr_dB);
end

function y = apply_soft_saturation(x, sat_level, p)
  r = abs(x(:));
  scale = 1 ./ ((1 + (r ./ max(sat_level, eps)).^(2*p)).^(1/(2*p)));
  y = x(:) .* scale;
end

function y = apply_gain_phase_drift(x, cfg)
  n = (0:numel(x)-1).';
  t = n / max(numel(x)-1, 1);
  gain = 1 + cfg.temperature_delta_c * cfg.temp_gainco_ppm_per_c * 1e-6 + ...
    cfg.pa_gain_drift_ppm * 1e-6 * (2*t - 1);
  phase = deg2rad(cfg.temperature_delta_c * cfg.temp_phaseco_deg_per_c + ...
    cfg.pa_phase_drift_deg * (2*t - 1) + ...
    cfg.pa_phase_ripple_deg * sin(2*pi*3*t));
  y = x(:) .* gain .* exp(1j*phase);
end

function y = add_observation_noise(x, snr_dB)
  p = mean(abs(x(:)).^2);
  np = p / 10^(snr_dB/10);
  noise = sqrt(np/2) * (randn(size(x(:))) + 1j*randn(size(x(:))));
  y = x(:) + noise;
end

function m = eval_native(ref, y, cfg)
  [ya, xa] = align_gain_delay(y, ref, 8);
  ev = calc_evm_sndr(ya, xa);
  ac = calc_aclr(ya, cfg.fs_hz, cfg.channel_bw_hz, cfg.adjacent_offset_hz);
  m.EVM_percent = ev.EVM_percent;
  m.SNDR_dB = ev.SNDR_dB;
  m.ACLR_avg_dBc = mean([ac.ACLR_L_dBc ac.ACLR_R_dBc]);
end

function m = eval_rf_recovered(ref, y, cfg)
  rf = complex_to_real_rf(y, cfg.fs_hz, cfg.if_hz);
  rf = ideal_bandpass_real(rf, cfg.fs_hz, cfg.if_hz, cfg.rf_bp_bw_hz);
  bb = real_rf_to_complex_bb(rf, cfg.fs_hz, cfg.if_hz);
  bb = ideal_lowpass_complex(bb, cfg.fs_hz, cfg.rx_lpf_bw_hz);
  [ya, xa] = align_gain_delay(bb, ref, 16);
  ev = calc_evm_sndr(ya, xa);
  ac = calc_aclr(ya, cfg.fs_hz, cfg.channel_bw_hz, cfg.adjacent_offset_hz);
  m.EVM_percent = ev.EVM_percent;
  m.SNDR_dB = ev.SNDR_dB;
  m.ACLR_avg_dBc = mean([ac.ACLR_L_dBc ac.ACLR_R_dBc]);
end

function m = behavioral_monitor_proxy(ref, dpd_in, observed, cfg)
% Match the lightweight PL monitor operations with behavioral PA observations.
% Output-related fields use the post-PA complex observation, so they are not a
% bit-true replacement for the RTL DSM output-monitor data path. Saturation
% follows the DPD Q1.15 output limit, matching the PL counter's meaning.
  ref_q = quantize_complex_q15(ref, cfg);
  in_q = quantize_complex_q15(dpd_in, cfg);
  out_q = quantize_complex_q15(observed, cfg);
  in_mag = mag_l1_q15(in_q, cfg);
  out_scalar = out_q.i;
  out_mag = abs_int64(out_scalar);
  [in_peak, in_avg] = peak_and_avg(in_mag);
  [out_peak, out_avg] = peak_and_avg(out_mag);
  evm_proxy = sum(abs_int64(in_q.i - ref_q.i) + ...
    abs_int64(in_q.q - ref_q.q));
  acpr_proxy = sum(abs_int64(diff(out_scalar)));
  [spec_bin0, spec_bin1, spec_bin2] = fixed_bin_proxy(out_scalar);

  m = struct();
  m.input_power = sat_u32(sum(in_mag));
  m.output_power = sat_u32(sum(out_mag));
  m.peak = pack_u16(out_peak, in_peak);
  m.avg_mag = pack_u16(out_avg, in_avg);
  m.evm_proxy = sat_u32(evm_proxy);
  m.acpr_proxy = sat_u32(acpr_proxy);
  m.spec_bin0 = spec_bin0;
  m.spec_bin1 = spec_bin1;
  m.spec_bin2 = spec_bin2;
  m.spec_adj = sat_u32(int64(spec_bin0) + int64(spec_bin2));
  m.clip = sat_u32(sum(abs_int64(in_q.i) >= cfg.monitor_clip_level | ...
    abs_int64(in_q.q) >= cfg.monitor_clip_level));
  m.saturation = sat_u32(sum(abs_int64(in_q.i) >= 32767 | ...
    abs_int64(in_q.q) >= 32767));
end

function q = quantize_complex_q15(x, cfg)
  scale = 2^cfg.input_frac;
  limit = int64(2^(cfg.input_w - 1) - 1);
  lower = -int64(2^(cfg.input_w - 1));
  qr = min(max(int64(round(real(x(:)) * scale)), lower), limit);
  qi = min(max(int64(round(imag(x(:)) * scale)), lower), limit);
  q = struct('i', qr, 'q', qi);
end

function mag = mag_l1_q15(q, cfg)
  mag = min(abs_int64(q.i) + abs_int64(q.q), ...
    int64(2^(cfg.input_w - 1) - 1));
end

function [peak, avg] = peak_and_avg(values)
  values = int64(values(:));
  peak = min(max(values, [], 'omitnan'), int64(65535));
  avg = int64(0);
  for k = 1:numel(values)
    avg = avg + floor((values(k) - avg) / 16);
  end
  avg = min(max(avg, int64(0)), int64(65535));
end

function [bin0, bin1, bin2] = fixed_bin_proxy(values)
  values = int64(values(:));
  phase = mod((0:numel(values)-1).', 4);
  bin0 = sat_u32(abs_int64(sum(values)));
  bin2 = sat_u32(abs_int64(sum(values .* int64(1 - 2 * mod(phase, 2)))));
  bin1_i = sum(values(phase == 0)) - sum(values(phase == 2));
  bin1_q = sum(values(phase == 3)) - sum(values(phase == 1));
  bin1 = sat_u32(abs_int64(bin1_i) + abs_int64(bin1_q));
end

function y = abs_int64(x)
  y = abs(int64(x));
end

function value = sat_u32(value)
  value = double(min(max(int64(value), int64(0)), int64(2^32 - 1)));
end

function word = pack_u16(high, low)
  word = double(bitshift(uint32(min(high, int64(65535))), 16) + ...
    uint32(min(low, int64(65535))));
end

function rf = complex_to_real_rf(x, Fs, Fif)
  n = (0:numel(x)-1).';
  rf = real(x(:) .* exp(1j*2*pi*Fif/Fs*n));
end

function bb = real_rf_to_complex_bb(rf, Fs, Fif)
  n = (0:numel(rf)-1).';
  bb = 2 * rf(:) .* exp(-1j*2*pi*Fif/Fs*n);
end

function y = ideal_bandpass_real(x, Fs, Fc, BW)
  n = numel(x);
  f = fft_freq(n, Fs);
  X = fft(x(:));
  mask = (abs(f - Fc) <= BW/2) | (abs(f + Fc) <= BW/2);
  y = real(ifft(X .* mask));
end

function y = ideal_lowpass_complex(x, Fs, BW)
  n = numel(x);
  f = fft_freq(n, Fs);
  X = fft(x(:));
  y = ifft(X .* (abs(f) <= BW/2));
end

function f = fft_freq(n, Fs)
  k = (0:n-1).';
  k(k >= ceil(n/2)) = k(k >= ceil(n/2)) - n;
  f = k * Fs / n;
end

function [ya, xa] = align_gain_delay(y, x, max_delay)
  y = y(:);
  x = x(:);
  best_err = inf;
  ya = [];
  xa = [];
  for d = -max_delay:max_delay
    if d >= 0
      yy = y(1+d:end);
      xx = x(1:min(numel(x), numel(yy)));
      yy = yy(1:numel(xx));
    else
      xx = x(1-d:end);
      yy = y(1:min(numel(y), numel(xx)));
      xx = xx(1:numel(yy));
    end
    if numel(xx) < 32, continue; end
    yy = yy * ((yy' * xx) / (yy' * yy + eps));
    err = mean(abs(yy - xx).^2);
    if err < best_err
      best_err = err;
      ya = yy;
      xa = xx;
    end
  end
end

function coeff = fit_memoryless_poly(in_sig, target, order, ridge)
  A = poly_basis(in_sig, order);
  coeff = (A' * A + ridge * eye(size(A, 2))) \ (A' * target(:));
end

function [best_q, trace] = coordinate_search_poly(x, coeff_q0, cfg, scenario_idx, scenario_name)
  best_q = coeff_q0(:).';
  best_loss = eval_poly_loss(x, best_q, cfg);
  trace = repmat(empty_trace_row(), 0, 1);
  trace(end+1) = make_trace_row(scenario_idx, scenario_name, 0, ...
    cfg.coord_initial_step, best_loss, true, best_q); %#ok<AGROW>

  if ~cfg.coord_search_enable
    return;
  end

  step = cfg.coord_initial_step;
  iter = 0;
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
          cand_loss = eval_poly_loss(x, cand_q, cfg);
          accepted = cand_loss < best_loss;
          trace(end+1) = make_trace_row(scenario_idx, scenario_name, ...
            iter, step, cand_loss, accepted, cand_q); %#ok<AGROW>
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

function loss = eval_poly_loss(x, coeff_q, cfg)
  x_dpd = dpd_poly_fixed_model(x, coeff_q, cfg);
  y = realistic_pa_observe(limit_drive(x_dpd, cfg.dpd_drive_limit), cfg);
  m = eval_native(x, y, cfg);
  loss = scalar_loss(m, cfg);
end

function loss = scalar_loss(m, cfg)
  aclr_penalty = max(m.ACLR_avg_dBc - cfg.loss_aclr_target_dBc, 0);
  loss = m.EVM_percent * cfg.loss_evm_weight ...
       - m.SNDR_dB * cfg.loss_sndr_weight ...
       + aclr_penalty * cfg.loss_aclr_weight;
end

function coeff_q = apply_seed_package(coeff_q, package_id, cfg)
% Keep package deltas in coefficient LSBs so they map directly to the
% board-visible Q2.14 polynomial representation.
  offsets = [ ...
    0,   0,   0; ...
    48, -32,  16; ...
   -48,  32, -16; ...
    24,  40, -24; ...
   -24, -40,  24; ...
    64,  16, -40 ...
  ];
  if ~isscalar(package_id) || package_id < 0 || package_id >= size(offsets, 1) || ...
      package_id ~= floor(package_id)
    error('seed_package_id must be an integer in [0, %d].', size(offsets, 1) - 1);
  end
  delta = offsets(package_id + 1, :);
  coeff_q = coeff_q(:).';
  for k = 1:numel(coeff_q)
    coeff_q(k) = clamp_coeff(coeff_q(k) + complex(delta(k), 0), cfg.coeff_w);
  end
end

function coeff_q = validate_seed_coeff_q(coeff_q, cfg)
  if ~isnumeric(coeff_q) || numel(coeff_q) ~= 3 || any(~isfinite(real(coeff_q(:)))) || ...
      any(~isfinite(imag(coeff_q(:))))
    error('seed_coeff_q must contain three finite complex Q2.14 coefficients.');
  end
  coeff_q = coeff_q(:).';
  for k = 1:numel(coeff_q)
    coeff_q(k) = clamp_coeff(coeff_q(k), cfg.coeff_w);
  end
end

function y = clamp_coeff(c, width)
  maxv = 2^(width-1) - 1;
  minv = -2^(width-1);
  y = complex(min(max(round(real(c)), minv), maxv), ...
              min(max(round(imag(c)), minv), maxv));
end

function A = poly_basis(x, order)
  x = x(:);
  powers = 1:2:order;
  A = zeros(numel(x), numel(powers));
  for k = 1:numel(powers)
    A(:, k) = x .* (abs(x).^(powers(k) - 1));
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
  s = complex(2*ii - (m - 1), 2*qq - (m - 1));
  s = s / sqrt(mean(abs(s(:)).^2));
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
  i = int64(xi(:));
  q = int64(xq(:));
  r2 = bitsra(i.*i + q.*q, cfg.input_frac);
  r4 = bitsra(r2.*r2, cfg.input_frac);
  gr = int64(real(coeff_q(1))) + bitsra(int64(real(coeff_q(2))).*r2, cfg.input_frac) + bitsra(int64(real(coeff_q(3))).*r4, cfg.input_frac);
  gi = int64(imag(coeff_q(1))) + bitsra(int64(imag(coeff_q(2))).*r2, cfg.input_frac) + bitsra(int64(imag(coeff_q(3))).*r4, cfg.input_frac);
  yi = reshape(saturate_int(bitsra(i.*gr - q.*gi, cfg.coeff_frac), cfg.input_w), size(x));
  yq = reshape(saturate_int(bitsra(i.*gi + q.*gr, cfg.coeff_frac), cfg.input_w), size(x));
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
  y = min(max(int64(x), int64(-2^(width-1))), int64(2^(width-1)-1));
end

function y = limit_drive(x, limit)
  scale = limit / max(abs(x) + eps);
  y = x * min(scale, 1);
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
  used = 0;
  for s = 1:nseg
    idx0 = (s - 1) * step + 1;
    idx = idx0:(idx0 + numel(win) - 1);
    if idx(end) > numel(x), break; end
    X = fftshift(fft(x(idx) .* win, nfft));
    Pavg = Pavg + abs(X).^2 / max(sum(abs(win).^2), eps);
    used = used + 1;
  end
  Pavg = Pavg / max(used, 1);
  f = ((0:nfft-1).' - nfft/2) / nfft * Fs;
end

function w = hann_local(n)
  k = (0:n-1).';
  w = 0.5 - 0.5*cos(2*pi*k/max(n-1, 1));
end

function s = packed_coeff_hex(c)
  s = string(sprintf("0x%04X%04X", twos_u16(imag(c)), twos_u16(real(c))));
end

function u = twos_u16(v)
  v = int32(v);
  if v < 0, u = uint32(v + 65536); else, u = uint32(v); end
end

function row = empty_row()
  row = struct('Scenario', string(""), 'QAM', NaN, 'UsedSubcarriers', NaN, ...
    'InputBackoff', NaN, 'DPA_RelativeGainScale', NaN, ...
    'DPA_RelativePowerDelta_dB', NaN, ...
    'DPA_SaturationLevel', NaN, 'DPA_MemoryTaps', NaN, ...
    'DPA_ObservationSNR_dB', NaN, 'DPA_GainDrift_ppm', NaN, ...
    'DPA_PhaseDrift_deg', NaN, 'DPA_TemperatureDelta_C', NaN, ...
    'DPA_OutputRMS', NaN, 'DPA_OutputPowerProxy', NaN, ...
    'DPA_OutputPeak', NaN, ...
    'Native_NoDPD_EVM_percent', NaN, 'Native_InitialPoly_EVM_percent', NaN, ...
    'Native_OptimizedPoly_EVM_percent', NaN, 'Native_LUT_EVM_percent', NaN, ...
    'Native_NoDPD_SNDR_dB', NaN, 'Native_InitialPoly_SNDR_dB', NaN, ...
    'Native_OptimizedPoly_SNDR_dB', NaN, 'Native_LUT_SNDR_dB', NaN, ...
    'Native_NoDPD_ACLR_avg_dBc', NaN, 'Native_InitialPoly_ACLR_avg_dBc', NaN, ...
    'Native_OptimizedPoly_ACLR_avg_dBc', NaN, 'Native_LUT_ACLR_avg_dBc', NaN, ...
    'RF_NoDPD_EVM_percent', NaN, 'RF_InitialPoly_EVM_percent', NaN, ...
    'RF_OptimizedPoly_EVM_percent', NaN, 'RF_LUT_EVM_percent', NaN, ...
    'RF_NoDPD_SNDR_dB', NaN, 'RF_InitialPoly_SNDR_dB', NaN, ...
    'RF_OptimizedPoly_SNDR_dB', NaN, 'RF_LUT_SNDR_dB', NaN, ...
    'RF_NoDPD_ACLR_avg_dBc', NaN, 'RF_InitialPoly_ACLR_avg_dBc', NaN, ...
    'RF_OptimizedPoly_ACLR_avg_dBc', NaN, 'RF_LUT_ACLR_avg_dBc', NaN, ...
    'Mon_InitialPoly_InputPower', NaN, 'Mon_InitialPoly_OutputPower', NaN, ...
    'Mon_InitialPoly_Peak', NaN, 'Mon_InitialPoly_AvgMag', NaN, ...
    'Mon_InitialPoly_EVMProxy', NaN, 'Mon_InitialPoly_ACPRProxy', NaN, ...
    'Mon_InitialPoly_SpecBin0', NaN, 'Mon_InitialPoly_SpecBin1', NaN, ...
    'Mon_InitialPoly_SpecBin2', NaN, 'Mon_InitialPoly_SpecAdj', NaN, ...
    'Mon_InitialPoly_Clip', NaN, 'Mon_InitialPoly_Saturation', NaN, ...
    'Mon_OptimizedPoly_InputPower', NaN, 'Mon_OptimizedPoly_OutputPower', NaN, ...
    'Mon_OptimizedPoly_Peak', NaN, 'Mon_OptimizedPoly_AvgMag', NaN, ...
    'Mon_OptimizedPoly_EVMProxy', NaN, 'Mon_OptimizedPoly_ACPRProxy', NaN, ...
    'Mon_OptimizedPoly_SpecBin0', NaN, 'Mon_OptimizedPoly_SpecBin1', NaN, ...
    'Mon_OptimizedPoly_SpecBin2', NaN, 'Mon_OptimizedPoly_SpecAdj', NaN, ...
    'Mon_OptimizedPoly_Clip', NaN, 'Mon_OptimizedPoly_Saturation', NaN, ...
    'OptimizedPoly_Loss', NaN, 'InitialPoly_Loss', NaN, 'SeedPackage', NaN, ...
    'Initial_C1_hex', string(""), 'Initial_C3_hex', string(""), ...
    'Initial_C5_hex', string(""), ...
    'C1_hex', string(""), 'C3_hex', string(""), 'C5_hex', string(""), ...
    'LUT0_hex', string(""), 'LUT15_hex', string(""));
end

function row = empty_trace_row()
  row = struct('ScenarioIndex', NaN, 'Scenario', string(""), ...
    'Iteration', NaN, 'Step', NaN, 'Loss', NaN, 'Accepted', false, ...
    'C1_hex', string(""), 'C3_hex', string(""), 'C5_hex', string(""));
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

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0, error('Arguments must be key/value pairs.'); end
  for k = 1:2:numel(varargin)
    if ~isfield(cfg, varargin{k}), error('Unknown configuration field: %s', varargin{k}); end
    cfg.(varargin{k}) = varargin{k+1};
  end
end

function write_summary_md(T, cfg, path)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot write %s', path); end
  cleanup = onCleanup(@() fclose(fid));
  fprintf(fid, '# Memory-PA DPD Observation Sweep\n\n');
  fprintf(fid, 'This diagnostic sweep adds PA memory effects, soft saturation, linear frequency response, gain/phase drift, observation noise, and an assumed RF observation chain.\n\n');
  fprintf(fid, '## Observation Assumptions\n\n');
  fprintf(fid, '- Complex baseband sample rate: %.3f MHz\n', cfg.fs_hz/1e6);
  fprintf(fid, '- RF IF: %.3f MHz\n', cfg.if_hz/1e6);
  fprintf(fid, '- Ideal RF band-pass width: %.3f MHz\n', cfg.rf_bp_bw_hz/1e6);
  fprintf(fid, '- Ideal RX low-pass width: %.3f MHz\n\n', cfg.rx_lpf_bw_hz/1e6);
  fprintf(fid, '- Observation SNR: %.2f dB\n', cfg.observation_snr_dB);
  fprintf(fid, '- PA saturation level: %.3f\n', cfg.pa_sat_level);
  fprintf(fid, '- Gain drift: %.1f ppm\n', cfg.pa_gain_drift_ppm);
  fprintf(fid, '- Phase drift: %.3f degree\n\n', cfg.pa_phase_drift_deg);
  fprintf(fid, '## Results\n\n');
  fprintf(fid, '| Scenario | Native no-DPD EVM %% | Native initial poly EVM %% | Native optimized poly EVM %% | Native LUT EVM %% | Native no-DPD SNDR dB | Native optimized poly SNDR dB | Native LUT SNDR dB | RF no-DPD EVM %% | RF optimized poly EVM %% | RF LUT EVM %% | RF no-DPD SNDR dB | RF optimized poly SNDR dB | RF LUT SNDR dB | Native optimized ACLR dBc | C1 | C3 | C5 | LUT0 | LUT15 |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|---|\n');
  for k = 1:height(T)
    fprintf(fid, '| %s | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | %.6f | `%s` | `%s` | `%s` | `%s` | `%s` |\n', ...
      T.Scenario(k), T.Native_NoDPD_EVM_percent(k), ...
      T.Native_InitialPoly_EVM_percent(k), T.Native_OptimizedPoly_EVM_percent(k), ...
      T.Native_LUT_EVM_percent(k), T.Native_NoDPD_SNDR_dB(k), ...
      T.Native_OptimizedPoly_SNDR_dB(k), T.Native_LUT_SNDR_dB(k), ...
      T.RF_NoDPD_EVM_percent(k), T.RF_OptimizedPoly_EVM_percent(k), ...
      T.RF_LUT_EVM_percent(k), T.RF_NoDPD_SNDR_dB(k), ...
      T.RF_OptimizedPoly_SNDR_dB(k), T.RF_LUT_SNDR_dB(k), ...
      T.Native_OptimizedPoly_ACLR_avg_dBc(k), ...
      T.C1_hex(k), T.C3_hex(k), T.C5_hex(k), T.LUT0_hex(k), T.LUT15_hex(k));
  end
end

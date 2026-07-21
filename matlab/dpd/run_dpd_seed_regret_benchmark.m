function T = run_dpd_seed_regret_benchmark(varargin)
% run_dpd_seed_regret_benchmark
% Build simulation-only labels for package selection and the decision to run
% one bounded DPD local-search round. The underlying fixed-point DPD and
% memory-PA model remain in run_dpd_memory_pa_observation_sweep.

  cfg = struct('seeds', [41 53 67], 'nsym', 8, 'out_dir', '', ...
    'write_outputs', true, 'verbose', true);
  cfg = parse_kv(cfg, varargin{:});
  if isempty(cfg.out_dir)
    cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  end
  if cfg.write_outputs && ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end

  profiles = build_profiles();
  rows = repmat(empty_row(), 0, 1);
  scenarios = scenario_names();
  for seed = cfg.seeds(:).'
    for s = 1:numel(scenarios)
      reference = run_dpd_memory_pa_observation_sweep('seed', seed, 'nsym', cfg.nsym, ...
        'scenario_set', 'extended', 'scenario_filter', scenarios(s), 'seed_package_id', 0, ...
        'write_outputs', false, 'verbose', false);
      reference_coeff_q = coeff_from_hex(reference.Initial_C1_hex(1), ...
        reference.Initial_C3_hex(1), reference.Initial_C5_hex(1));
      for p = 1:numel(profiles)
        profile = profiles(p);
      for package_id = 0:5
        S = run_dpd_memory_pa_observation_sweep('seed', seed, 'nsym', cfg.nsym, ...
          'pa_gain_scale', profile.gain_scale, 'pa_sat_level', profile.sat_level, ...
          'pa_memory_taps', profile.memory_taps, ...
          'observation_snr_dB', profile.observation_snr_dB, ...
          'pa_gain_drift_ppm', profile.gain_drift_ppm, ...
          'pa_phase_drift_deg', profile.phase_drift_deg, ...
          'pa_phase_ripple_deg', profile.phase_ripple_deg, ...
          'seed_coeff_q', reference_coeff_q, 'seed_package_id', package_id, ...
          'scenario_set', 'extended', 'scenario_filter', scenarios(s), ...
          'write_outputs', false, 'verbose', false);
        for k = 1:height(S)
          row = empty_row();
          row.profile_id = profile.id;
          row.waveform_id = waveform_id(S.Scenario(k));
          row.run_id = sprintf('%s_%s_seed%d_pkg%d', profile.id, row.waveform_id, seed, package_id);
          row.simulation_seed = seed;
          row.seed_package = package_id;
          row.qam = S.QAM(k);
          row.bandwidth_mhz = bandwidth_mhz(S.UsedSubcarriers(k));
          row.used_subcarriers = S.UsedSubcarriers(k);
          row.input_backoff = S.InputBackoff(k);
          row.gain_scale = profile.gain_scale;
          row.sat_level = profile.sat_level;
          row.memory_taps = profile.memory_taps;
          row.observation_snr_dB = profile.observation_snr_dB;
          row.gain_drift_ppm = profile.gain_drift_ppm;
          row.phase_drift_deg = profile.phase_drift_deg;
          row.phase_ripple_deg = profile.phase_ripple_deg;
          row.initial_cost = S.InitialPoly_Loss(k);
          row.final_cost = S.OptimizedPoly_Loss(k);
          row.initial_evm_pct = S.RF_InitialPoly_EVM_percent(k);
          row.final_evm_pct = S.RF_OptimizedPoly_EVM_percent(k);
          row.initial_aclr_db = S.RF_InitialPoly_ACLR_avg_dBc(k);
          row.final_aclr_db = S.RF_OptimizedPoly_ACLR_avg_dBc(k);
          row.candidate_count_local = 14;
          row.input_power = S.Mon_InitialPoly_InputPower(k);
          row.output_power = S.Mon_InitialPoly_OutputPower(k);
          row.peak = S.Mon_InitialPoly_Peak(k);
          row.avg_mag = S.Mon_InitialPoly_AvgMag(k);
          row.evm_proxy = S.Mon_InitialPoly_EVMProxy(k);
          row.acpr_proxy = S.Mon_InitialPoly_ACPRProxy(k);
          row.spec_bin0 = S.Mon_InitialPoly_SpecBin0(k);
          row.spec_bin1 = S.Mon_InitialPoly_SpecBin1(k);
          row.spec_bin2 = S.Mon_InitialPoly_SpecBin2(k);
          row.spec_adj = S.Mon_InitialPoly_SpecAdj(k);
          row.clip = S.Mon_InitialPoly_Clip(k);
          row.saturation = S.Mon_InitialPoly_Saturation(k);
          row.c1_hex = S.Initial_C1_hex(k);
          row.c3_hex = S.Initial_C3_hex(k);
          row.c5_hex = S.Initial_C5_hex(k);
          row.dsm_config_id = "efdsm_1bit_osr32_interp0";
          row.dsm_algorithm = 2;
          row.simulation_model = "memory_pa_observation_v1";
          rows(end+1) = row; %#ok<AGROW>
        end
      end
    end
    end
  end

  T = struct2table(rows);
  T = label_regret(T);
  if cfg.write_outputs
    csv_path = fullfile(cfg.out_dir, 'dpd_seed_regret_benchmark.csv');
    writetable(T, csv_path);
    save(fullfile(cfg.out_dir, 'dpd_seed_regret_benchmark.mat'), 'cfg', 'profiles', 'T');
    write_summary(T, cfg, fullfile(cfg.out_dir, 'dpd_seed_regret_benchmark.md'));
    fprintf('Wrote seed/regret benchmark: %s\n', csv_path);
  end
  if cfg.verbose, disp(T(1:min(12, height(T)), :)); end
end

function T = label_regret(T)
  T.best_seed = zeros(height(T), 1);
  T.best_final_cost = zeros(height(T), 1);
  T.initial_regret_to_best = zeros(height(T), 1);
  T.local_search_regret = zeros(height(T), 1);
  T.final_regret_to_best = zeros(height(T), 1);
  keys = strcat(T.profile_id, "|", T.waveform_id, "|", string(T.simulation_seed));
  for k = 1:height(T)
    same = keys == keys(k);
    [best_cost, idx] = min(T.final_cost(same));
    candidates = find(same);
    T.best_seed(k) = T.seed_package(candidates(idx));
    T.best_final_cost(k) = best_cost;
    T.initial_regret_to_best(k) = max(T.initial_cost(k) - best_cost, 0);
    T.local_search_regret(k) = max(T.initial_cost(k) - T.final_cost(k), 0);
    T.final_regret_to_best(k) = max(T.final_cost(k) - best_cost, 0);
  end
end

function profiles = build_profiles()
  profiles = [ ...
    profile('baseline', 1.00, 0.92, 3, 43, 1800, 1.8, 0.45), ...
    profile('gain_mid_low', 0.91, 0.92, 3, 43, 1800, 1.8, 0.45), ...
    profile('gain_low', 0.82, 0.92, 3, 43, 1800, 1.8, 0.45), ...
    profile('gain_high', 1.08, 0.92, 3, 43, 1800, 1.8, 0.45), ...
    profile('sat_mid', 1.00, 0.82, 3, 43, 1800, 1.8, 0.45), ...
    profile('sat_early', 1.00, 0.72, 3, 43, 1800, 1.8, 0.45), ...
    profile('memory_short', 1.00, 0.92, 1, 43, 1800, 1.8, 0.45), ...
    profile('noise_mid', 1.00, 0.92, 3, 36, 1800, 1.8, 0.45), ...
    profile('noise_high', 1.00, 0.92, 3, 28, 1800, 1.8, 0.45), ...
    profile('thermal_mild', 1.00, 0.92, 3, 43, 4000, 3.5, 0.90), ...
    profile('thermal_drift', 1.00, 0.92, 3, 43, 8000, 6.0, 1.50), ...
    profile('combined_stress', 0.82, 0.72, 3, 28, 8000, 6.0, 1.50) ...
  ];
end

function names = scenario_names()
  names = [ ...
    "memory_pa_nominal_16qam_48sc_bo058", ...
    "memory_pa_nominal_16qam_48sc_bo070", ...
    "memory_pa_nominal_16qam_96sc_bo058", ...
    "memory_pa_nominal_16qam_96sc_bo070", ...
    "memory_pa_nominal_64qam_48sc_bo058", ...
    "memory_pa_nominal_64qam_48sc_bo070", ...
    "memory_pa_nominal_64qam_96sc_bo058", ...
    "memory_pa_nominal_64qam_96sc_bo070" ...
  ];
end

function coeff_q = coeff_from_hex(c1, c3, c5)
  words = [c1, c3, c5];
  coeff_q = zeros(1, 3);
  for k = 1:numel(words)
    value = char(words(k));
    raw = uint32(sscanf(value(3:end), '%x'));
    re = signed_u16(bitand(raw, uint32(65535)));
    im = signed_u16(bitshift(raw, -16));
    coeff_q(k) = complex(re, im);
  end
end

function value = signed_u16(raw)
  value = double(raw);
  if value >= 32768, value = value - 65536; end
end

function p = profile(id, gain, sat, taps, snr, gain_drift, phase_drift, ripple)
  p = struct('id', string(id), 'gain_scale', gain, 'sat_level', sat, ...
    'memory_taps', taps, 'observation_snr_dB', snr, ...
    'gain_drift_ppm', gain_drift, 'phase_drift_deg', phase_drift, ...
    'phase_ripple_deg', ripple);
end

function id = waveform_id(name)
  text = char(name);
  if contains(text, '64qam'), qam = 'qam64'; else, qam = 'qam16'; end
  if contains(text, '96sc'), bw = 'bw40'; else, bw = 'bw20'; end
  if contains(text, 'bo070'), bo = 'bo070'; else, bo = 'bo058'; end
  id = string(sprintf('%s_%s_%s', qam, bw, bo));
end

function bw = bandwidth_mhz(nused)
  bw = 20;
  if nused > 48, bw = 40; end
end

function row = empty_row()
  row = struct('profile_id', "", 'waveform_id', "", 'run_id', "", ...
    'simulation_seed', NaN, 'seed_package', NaN, 'qam', NaN, ...
    'bandwidth_mhz', NaN, 'used_subcarriers', NaN, 'input_backoff', NaN, ...
    'gain_scale', NaN, 'sat_level', NaN, 'memory_taps', NaN, ...
    'observation_snr_dB', NaN, 'gain_drift_ppm', NaN, ...
    'phase_drift_deg', NaN, 'phase_ripple_deg', NaN, ...
    'initial_cost', NaN, 'final_cost', NaN, 'initial_evm_pct', NaN, ...
    'final_evm_pct', NaN, 'initial_aclr_db', NaN, 'final_aclr_db', NaN, ...
    'candidate_count_local', NaN, 'input_power', NaN, 'output_power', NaN, ...
    'peak', NaN, 'avg_mag', NaN, 'evm_proxy', NaN, 'acpr_proxy', NaN, ...
    'spec_bin0', NaN, 'spec_bin1', NaN, 'spec_bin2', NaN, 'spec_adj', NaN, ...
    'clip', NaN, 'saturation', NaN, 'c1_hex', "", 'c3_hex', "", ...
    'c5_hex', "", 'dsm_config_id', "", 'dsm_algorithm', NaN, ...
    'simulation_model', "");
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0, error('Arguments must be name/value pairs.'); end
  for k = 1:2:numel(varargin)
    key = char(varargin{k});
    if ~isfield(cfg, key), error('Unknown option: %s', key); end
    cfg.(key) = varargin{k+1};
  end
end

function write_summary(T, cfg, path)
  fid = fopen(path, 'w');
  assert(fid >= 0, 'Cannot open summary output.');
  cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '# Seed/Regret Behavioral PA Benchmark\n\n');
  fprintf(fid, 'This data set is simulation-only. It fixes DSM provenance to EFDSM 1-bit, OSR 32, bypass interpolation; it does not measure a physical PA or RF receiver.\n\n');
  fprintf(fid, '- Records: `%d` (12 PA profiles x 8 waveforms x %d random seeds x 6 seed packages)\n', height(T), numel(cfg.seeds));
  fprintf(fid, '- Local search label: initial seed plus 12 Q2.14 coefficient perturbations and one final replay (`14` candidates).\n');
  fprintf(fid, '- Labels: initial/final cost, true best package, initial/local/final regret, RF-recovered EVM/ACLR proxies, and first-candidate monitor state.\n');
end

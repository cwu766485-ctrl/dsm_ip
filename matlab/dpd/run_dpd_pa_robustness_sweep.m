function T = run_dpd_pa_robustness_sweep(varargin)
% run_dpd_pa_robustness_sweep
% Sweep memory-PA/observation mismatch axes and produce simulation-only policy
% gate evidence. The predictor intentionally sees waveform features only; PA
% profile changes are held out to test residual-triggered fallback.

  cfg = struct('seeds', [41 53 67], 'nsym', 8, 'evm_limit_pct', 8.0, ...
    'aclr_limit_dbc', -20.0, 'direct_regret_budget', 100, ...
    'direct_feature_distance_ppm', 100000, 'regret_neighbors', 5, 'out_dir', '');
  cfg = parse_kv(cfg, varargin{:});
  if isempty(cfg.out_dir)
    cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  end
  if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end

  profiles = build_profiles();
  samples = repmat(empty_sample(), 0, 1);
  for p = 1:numel(profiles)
    profile = profiles(p);
    for seed = cfg.seeds(:).'
      S = run_dpd_memory_pa_observation_sweep('seed', seed, 'nsym', cfg.nsym, ...
        'pa_gain_scale', profile.gain_scale, 'pa_sat_level', profile.sat_level, ...
        'pa_memory_taps', profile.memory_taps, ...
        'observation_snr_dB', profile.observation_snr_dB, ...
        'pa_gain_drift_ppm', profile.gain_drift_ppm, ...
        'pa_phase_drift_deg', profile.phase_drift_deg, ...
        'pa_phase_ripple_deg', profile.phase_ripple_deg, ...
        'scenario_set', 'extended', ...
        'write_outputs', false, 'verbose', false);
      for row = 1:height(S)
        sample = empty_sample();
        sample.profile_id = profile.id;
        sample.scenario_id = sprintf('%s_%s', profile.id, source_id(S.Scenario(row)));
        sample.run_id = sprintf('%s_seed%d', sample.scenario_id, seed);
        sample.pa_strength_db = 20 * log10(profile.gain_scale);
        sample.qam = S.QAM(row);
        sample.bandwidth_mhz = bandwidth_mhz(S.UsedSubcarriers(row));
        sample.used_subcarriers = S.UsedSubcarriers(row);
        sample.input_backoff = S.InputBackoff(row);
        sample.gain_scale = profile.gain_scale;
        sample.sat_level = profile.sat_level;
        sample.memory_taps = profile.memory_taps;
        sample.observation_snr_dB = profile.observation_snr_dB;
        sample.gain_drift_ppm = profile.gain_drift_ppm;
        sample.phase_drift_deg = profile.phase_drift_deg;
        sample.phase_ripple_deg = profile.phase_ripple_deg;
        sample.evm_pct = S.RF_OptimizedPoly_EVM_percent(row);
        sample.aclr_db = S.RF_OptimizedPoly_ACLR_avg_dBc(row);
        sample.measured_cost = policy_cost(sample.evm_pct, sample.aclr_db);
        sample.initial_cost = policy_cost(S.RF_InitialPoly_EVM_percent(row), ...
          S.RF_InitialPoly_ACLR_avg_dBc(row));
        sample.local_search_regret = max(sample.initial_cost - sample.measured_cost, 0);
        sample.initial_feedback_pass = S.RF_InitialPoly_EVM_percent(row) <= ...
          cfg.evm_limit_pct && S.RF_InitialPoly_ACLR_avg_dBc(row) <= cfg.aclr_limit_dbc;
        sample.feedback_pass = sample.evm_pct <= cfg.evm_limit_pct && ...
          sample.aclr_db <= cfg.aclr_limit_dbc;
        % The first candidate is the only state available before choosing search.
        sample.input_power = S.Mon_InitialPoly_InputPower(row);
        sample.output_power = S.Mon_InitialPoly_OutputPower(row);
        sample.peak = S.Mon_InitialPoly_Peak(row);
        sample.avg_mag = S.Mon_InitialPoly_AvgMag(row);
        sample.evm_proxy = S.Mon_InitialPoly_EVMProxy(row);
        sample.acpr_proxy = S.Mon_InitialPoly_ACPRProxy(row);
        sample.spec_bin0 = S.Mon_InitialPoly_SpecBin0(row);
        sample.spec_bin1 = S.Mon_InitialPoly_SpecBin1(row);
        sample.spec_bin2 = S.Mon_InitialPoly_SpecBin2(row);
        sample.spec_adj = S.Mon_InitialPoly_SpecAdj(row);
        sample.clip = S.Mon_InitialPoly_Clip(row);
        sample.saturation = S.Mon_InitialPoly_Saturation(row);
        sample.simulation_model = "memory_pa_observation_v1";
        sample.simulation_config_id = sprintf('nsym%d_evm%.2f_aclr%.2f', ...
          cfg.nsym, cfg.evm_limit_pct, cfg.aclr_limit_dbc);
        sample.simulation_seed = seed;
        sample.observation_id = sprintf('matlab_memory_pa_%s_seed%d', profile.id, seed);
        samples(end+1) = sample; %#ok<AGROW>
      end
    end
  end

  % Leave one hidden PA profile out. Same-waveform rows from other profiles
  % remain available, so nearest distance may be zero and residual matters.
  for k = 1:numel(samples)
    profile_ids = string({samples.profile_id});
    training = samples(profile_ids ~= samples(k).profile_id);
    [predicted, nearest, dispersion] = predict_cost(training, samples(k));
    samples(k).predicted_cost = predicted;
    samples(k).nearest_distance_ppm = round(nearest * 1e6);
    samples(k).relative_stddev_ppm = round(dispersion * 1e6 / max(predicted, 1));
    samples(k).runtime_residual_ppm = round(abs(samples(k).measured_cost - predicted) * ...
      1e6 / max(predicted, 1));
  end

  T = struct2table(samples);
  csv_path = fullfile(cfg.out_dir, 'dpd_pa_robustness_simulation.csv');
  writetable(T, csv_path);
  Gate = evaluate_monitor_loso(T, profiles);
  [Regret, RegretDecisions] = evaluate_regret_loso(T, profiles, cfg);
  writetable(Gate, fullfile(cfg.out_dir, 'dpd_pa_monitor_gate_loso.csv'));
  writetable(Regret, fullfile(cfg.out_dir, 'dpd_pa_regret_policy_loso.csv'));
  writetable(RegretDecisions, fullfile(cfg.out_dir, 'dpd_pa_regret_policy_decisions.csv'));
  write_summary(T, Gate, Regret, cfg, profiles, fullfile(cfg.out_dir, 'dpd_pa_robustness_simulation.md'));
  save(fullfile(cfg.out_dir, 'dpd_pa_robustness_simulation.mat'), 'cfg', 'T', 'Gate', 'Regret', 'RegretDecisions', 'profiles');
  fprintf('Wrote PA robustness simulation: %s\n', csv_path);
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

function p = profile(id, gain, sat, taps, snr, gain_drift, phase_drift, ripple)
  p = struct('id', string(id), 'gain_scale', gain, 'sat_level', sat, ...
    'memory_taps', taps, 'observation_snr_dB', snr, ...
    'gain_drift_ppm', gain_drift, 'phase_drift_deg', phase_drift, ...
    'phase_ripple_deg', ripple);
end

function id = source_id(name)
  text = char(name);
  if contains(text, '64qam')
    qam = 'qam64';
  else
    qam = 'qam16';
  end
  if contains(text, '96sc'), bw = 'bw40'; else, bw = 'bw20'; end
  if contains(text, 'bo070'), bo = 'bo070'; else, bo = 'bo058'; end
  id = sprintf('%s_%s_%s', qam, bw, bo);
end

function bw = bandwidth_mhz(nused)
  bw = 20;
  if nused > 48, bw = 40; end
end

function cost = policy_cost(evm_pct, aclr_db)
  cost = round(evm_pct * 10000 + max(aclr_db + 45, 0) * 200);
end

function [predicted, nearest, dispersion] = predict_cost(training, target)
  dist = zeros(numel(training), 1);
  costs = zeros(numel(training), 1);
  for k = 1:numel(training)
    dist(k) = visible_distance(training(k), target);
    costs(k) = training(k).measured_cost;
  end
  weights = 1 ./ (1e-6 + dist);
  predicted = round(sum(weights .* costs) / sum(weights));
  nearest = min(dist);
  dispersion = sqrt(sum(weights .* (costs - predicted).^2) / sum(weights));
end

function d = visible_distance(left, right)
  d = abs(left.qam - right.qam) / max([left.qam, right.qam, 1.0]) + ...
      abs(left.bandwidth_mhz - right.bandwidth_mhz) / ...
      max([left.bandwidth_mhz, right.bandwidth_mhz, 0.001]) + ...
      abs(left.used_subcarriers - right.used_subcarriers) / ...
      max([left.used_subcarriers, right.used_subcarriers, 1.0]) + ...
      abs(left.input_backoff - right.input_backoff) / ...
      max([left.input_backoff, right.input_backoff, 0.01]);
end

function row = empty_sample()
  row = struct('profile_id', "", 'scenario_id', "", 'run_id', "", ...
    'pa_strength_db', NaN, 'qam', NaN, 'bandwidth_mhz', NaN, ...
    'used_subcarriers', NaN, 'input_backoff', NaN, 'gain_scale', NaN, ...
    'sat_level', NaN, 'memory_taps', NaN, 'observation_snr_dB', NaN, ...
    'gain_drift_ppm', NaN, 'phase_drift_deg', NaN, 'phase_ripple_deg', NaN, ...
    'predicted_cost', NaN, 'measured_cost', NaN, 'initial_cost', NaN, ...
    'local_search_regret', NaN, 'initial_feedback_pass', false, ...
    'nearest_distance_ppm', NaN, ...
    'relative_stddev_ppm', NaN, 'runtime_residual_ppm', NaN, ...
    'input_power', NaN, 'output_power', NaN, 'peak', NaN, 'avg_mag', NaN, ...
    'evm_proxy', NaN, 'acpr_proxy', NaN, 'spec_bin0', NaN, 'spec_bin1', NaN, ...
    'spec_bin2', NaN, 'spec_adj', NaN, 'clip', NaN, 'saturation', NaN, ...
    'feedback_pass', false, 'evm_pct', NaN, ...
    'aclr_db', NaN, 'simulation_model', "", 'simulation_config_id', "", ...
    'simulation_seed', NaN, 'observation_id', "");
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0, error('Arguments must be name/value pairs.'); end
  for k = 1:2:numel(varargin)
    key = char(varargin{k});
    if ~isfield(cfg, key), error('Unknown option: %s', key); end
    cfg.(key) = varargin{k+1};
  end
end

function Gate = evaluate_monitor_loso(T, profiles)
  rows = repmat(empty_gate_row(), numel(profiles), 1);
  for p = 1:numel(profiles)
    held = T(T.profile_id == profiles(p).id, :);
    training = T(T.profile_id ~= profiles(p).id, :);
    legacy = fit_legacy_gate(training);
    train_legacy_direct = apply_legacy_gate(training, legacy);
    [center, train_monitor_distance] = monitor_center_distance(training, training.feedback_pass);
    held_monitor_distance = monitor_distance_to_center(held, center);
    [weighted_center, train_weighted_distance] = weighted_monitor_center_distance(training, training.feedback_pass);
    held_weighted_distance = weighted_monitor_distance_to_center(held, weighted_center);
    monitor_limit = fit_monitor_limit(training.feedback_pass, train_legacy_direct, ...
      train_monitor_distance);
    weighted_limit = fit_monitor_limit(training.feedback_pass, train_legacy_direct, ...
      train_weighted_distance);
    held_legacy_direct = apply_legacy_gate(held, legacy);
    held_monitor_direct = held_legacy_direct & held_monitor_distance <= monitor_limit;
    held_weighted_direct = held_legacy_direct & held_weighted_distance <= weighted_limit;

    rows(p).profile_id = profiles(p).id;
    rows(p).training_records = height(training);
    rows(p).held_records = height(held);
    rows(p).legacy_false_direct = sum(held_legacy_direct & ~held.feedback_pass);
    rows(p).legacy_true_direct = sum(held_legacy_direct & held.feedback_pass);
    rows(p).raw_monitor_false_direct = sum(held_monitor_direct & ~held.feedback_pass);
    rows(p).raw_monitor_true_direct = sum(held_monitor_direct & held.feedback_pass);
    rows(p).monitor_false_direct = sum(held_weighted_direct & ~held.feedback_pass);
    rows(p).monitor_true_direct = sum(held_weighted_direct & held.feedback_pass);
    rows(p).legacy_distance_ppm = legacy.distance_ppm;
    rows(p).legacy_dispersion_ppm = legacy.dispersion_ppm;
    rows(p).legacy_residual_ppm = legacy.residual_ppm;
    rows(p).raw_monitor_distance_ppm = monitor_limit;
    rows(p).raw_median_held_monitor_distance_ppm = round(median(held_monitor_distance));
    rows(p).monitor_distance_ppm = weighted_limit;
    rows(p).median_held_monitor_distance_ppm = round(median(held_weighted_distance));
    rows(p).legacy_training_false_direct = legacy.false_direct;
    rows(p).raw_monitor_training_false_direct = sum(train_legacy_direct & ...
      train_monitor_distance <= monitor_limit & ~training.feedback_pass);
    rows(p).monitor_training_false_direct = sum(train_legacy_direct & ...
      train_weighted_distance <= weighted_limit & ~training.feedback_pass);
  end
  Gate = struct2table(rows);
end

function gate = fit_legacy_gate(T)
  distance = T.nearest_distance_ppm;
  dispersion = T.relative_stddev_ppm;
  residual = T.runtime_residual_ppm;
  candidates = {unique([0; distance]), unique([0; dispersion]), unique([0; residual])};
  best = struct('false_direct', inf, 'true_direct', -1, 'count', 0, ...
    'distance_ppm', 0, 'dispersion_ppm', 0, 'residual_ppm', 0);
  for a = 1:numel(candidates{1})
    for b = 1:numel(candidates{2})
      direct_ab = distance <= candidates{1}(a) & dispersion <= candidates{2}(b);
      for c = 1:numel(candidates{3})
        direct = direct_ab & residual <= candidates{3}(c);
        count = sum(direct);
        if count == 0, continue; end
        false_direct = sum(direct & ~T.feedback_pass);
        true_direct = sum(direct & T.feedback_pass);
        % A gate that never permits a known-good run is only a full-search
        % policy. Keep one passing direct decision to compare gate utility.
        if true_direct == 0, continue; end
        if false_direct < best.false_direct || ...
            (false_direct == best.false_direct && true_direct > best.true_direct) || ...
            (false_direct == best.false_direct && true_direct == best.true_direct && count > best.count)
          best = struct('false_direct', false_direct, 'true_direct', true_direct, ...
            'count', count, 'distance_ppm', candidates{1}(a), ...
            'dispersion_ppm', candidates{2}(b), 'residual_ppm', candidates{3}(c));
        end
      end
    end
  end
  gate = best;
end

function direct = apply_legacy_gate(T, gate)
  direct = T.nearest_distance_ppm <= gate.distance_ppm & ...
    T.relative_stddev_ppm <= gate.dispersion_ppm & ...
    T.runtime_residual_ppm <= gate.residual_ppm;
end

function [center, distance] = monitor_center_distance(T, select)
  fields = monitor_fields();
  selected = T(select, :);
  if isempty(selected), selected = T; end
  center = zeros(1, numel(fields));
  for k = 1:numel(fields)
    center(k) = median(selected.(fields{k}));
  end
  distance = monitor_distance_to_center(T, center);
end

function distance = monitor_distance_to_center(T, center)
  fields = monitor_fields();
  distance = zeros(height(T), 1);
  for row = 1:height(T)
    terms = zeros(1, numel(fields));
    for k = 1:numel(fields)
      terms(k) = abs(T.(fields{k})(row) - center(k)) * 1e6 / max(abs(center(k)), 1);
    end
    distance(row) = mean(terms);
  end
end

function [center, distance] = weighted_monitor_center_distance(T, select)
  features = weighted_monitor_features(T);
  selected = features(select, :);
  if isempty(selected), selected = features; end
  center = median(selected, 1);
  distance = weighted_feature_distance(features, center);
end

function distance = weighted_monitor_distance_to_center(T, center)
  distance = weighted_feature_distance(weighted_monitor_features(T), center);
end

function features = weighted_monitor_features(T)
% Ratios suppress waveform-length scaling; shape/error terms receive priority.
  features = [ ...
    T.output_power ./ max(T.input_power, 1), ...
    upper_u16(T.peak) ./ max(upper_u16(T.avg_mag), 1), ...
    T.evm_proxy ./ max(T.input_power, 1), ...
    T.acpr_proxy ./ max(T.output_power, 1), ...
    T.spec_adj ./ max(T.spec_bin1, 1), ...
    T.spec_bin2 ./ max(T.spec_bin0, 1), ...
    T.clip ./ max(T.input_power ./ 32767, 1), ...
    T.saturation ./ max(T.input_power ./ 32767, 1) ...
  ];
end

function distance = weighted_feature_distance(features, center)
  weights = [1.0 1.0 2.5 2.0 2.5 1.5 3.0 3.0];
  relative = abs(features - center) ./ max(abs(center), 1e-9);
  distance = relative * weights.' / sum(weights) * 1e6;
end

function value = upper_u16(word)
  value = floor(word / 2^16);
end

function limit = fit_monitor_limit(pass, legacy_direct, distance)
  candidates = unique([0; distance]);
  best_false = inf;
  best_true = -1;
  limit = 0;
  for k = 1:numel(candidates)
    direct = legacy_direct & distance <= candidates(k);
    if ~any(direct), continue; end
    false_direct = sum(direct & ~pass);
    true_direct = sum(direct & pass);
    if true_direct == 0, continue; end
    if false_direct < best_false || ...
        (false_direct == best_false && true_direct > best_true)
      best_false = false_direct;
      best_true = true_direct;
      limit = candidates(k);
    end
  end
end

function fields = monitor_fields()
  fields = {'input_power', 'output_power', 'peak', 'avg_mag', 'evm_proxy', ...
    'acpr_proxy', 'spec_bin0', 'spec_bin1', 'spec_bin2', 'spec_adj', ...
    'clip', 'saturation'};
end

function [Summary, Decisions] = evaluate_regret_loso(T, profiles, cfg)
% Predict first-candidate cost regret before deciding whether to search.
  summary_rows = repmat(empty_regret_summary_row(), numel(profiles), 1);
  decision_rows = repmat(empty_regret_decision_row(), 0, 1);
  for p = 1:numel(profiles)
    held = T(T.profile_id == profiles(p).id, :);
    training = T(T.profile_id ~= profiles(p).id, :);
    [predicted, uncertainty, nearest] = predict_regret(training, held, cfg.regret_neighbors);
    upper = max(0, round(predicted + uncertainty));
    hard_fault = held.clip ~= 0 | held.saturation ~= 0;
    feature_known = nearest * 1e6 <= cfg.direct_feature_distance_ppm;
    direct = upper <= cfg.direct_regret_budget & feature_known & ~hard_fault;

    for row = 1:height(held)
      decision = empty_regret_decision_row();
      decision.profile_id = held.profile_id(row);
      decision.scenario_id = held.scenario_id(row);
      decision.run_id = held.run_id(row);
      decision.predicted_regret = round(predicted(row));
      decision.predicted_uncertainty = round(uncertainty(row));
      decision.predicted_upper_regret = upper(row);
      decision.actual_regret = held.local_search_regret(row);
      decision.initial_cost = held.initial_cost(row);
      decision.local_search_cost = held.measured_cost(row);
      decision.initial_feedback_pass = held.initial_feedback_pass(row);
      decision.hard_monitor_fault = hard_fault(row);
      decision.nearest_feature_distance_ppm = round(nearest(row) * 1e6);
      decision.regret_budget = cfg.direct_regret_budget;
      decision.feature_distance_limit_ppm = cfg.direct_feature_distance_ppm;
      decision.gate_decision = string(ternary(direct(row), 'direct', 'local_search'));
      decision.candidate_count_model = ternary(direct(row), 1, 14);
      decision_rows(end+1) = decision; %#ok<AGROW>
    end

    direct_rows = held(direct, :);
    summary_rows(p).profile_id = profiles(p).id;
    summary_rows(p).training_records = height(training);
    summary_rows(p).held_records = height(held);
    summary_rows(p).direct_records = sum(direct);
    summary_rows(p).local_search_records = sum(~direct);
    summary_rows(p).candidate_count_model = sum(ternary(direct, 1, 14));
    summary_rows(p).direct_mean_actual_regret = selected_mean(held.local_search_regret, direct);
    summary_rows(p).direct_max_actual_regret = selected_max(held.local_search_regret, direct);
    summary_rows(p).direct_initial_feedback_failures = sum(~direct_rows.initial_feedback_pass);
    summary_rows(p).direct_hard_monitor_faults = sum(hard_fault & direct);
    summary_rows(p).feature_distance_rejects = sum(~feature_known);
    summary_rows(p).mean_predicted_upper_regret = mean(upper);
  end
  Summary = struct2table(summary_rows);
  Decisions = struct2table(decision_rows);
end

function [predicted, uncertainty, nearest] = predict_regret(training, held, max_neighbors)
  train_features = regret_features(training);
  held_features = regret_features(held);
  center = median(train_features, 1);
  scale = iqr(train_features, 1);
  scale(scale < 1e-9) = 1.0;
  train_features = (train_features - center) ./ scale;
  held_features = (held_features - center) ./ scale;
  target = training.local_search_regret;
  predicted = zeros(height(held), 1);
  uncertainty = zeros(height(held), 1);
  nearest = zeros(height(held), 1);
  for row = 1:height(held)
    distance = sqrt(sum((train_features - held_features(row, :)).^2, 2));
    [sorted_distance, order] = sort(distance, 'ascend');
    count = min(max_neighbors, numel(order));
    order = order(1:count);
    weights = 1 ./ (1e-6 + sorted_distance(1:count));
    value = sum(weights .* target(order)) / sum(weights);
    predicted(row) = value;
    uncertainty(row) = sqrt(sum(weights .* (target(order) - value).^2) / sum(weights));
    nearest(row) = sorted_distance(1);
  end
end

function features = regret_features(T)
% Visible waveform metadata and first-candidate monitor ratios only.
  features = [T.qam / 64, T.bandwidth_mhz / 40, T.used_subcarriers / 96, ...
    T.input_backoff, weighted_monitor_features(T)];
end

function value = selected_mean(values, select)
  if any(select), value = mean(values(select)); else, value = 0; end
end

function value = selected_max(values, select)
  if any(select), value = max(values(select)); else, value = 0; end
end

function value = ternary(condition, when_true, when_false)
  if isscalar(condition)
    if condition, value = when_true; else, value = when_false; end
  else
    value = when_false * ones(size(condition));
    value(condition) = when_true;
  end
end

function row = empty_gate_row()
  row = struct('profile_id', "", 'training_records', NaN, 'held_records', NaN, ...
    'legacy_false_direct', NaN, 'legacy_true_direct', NaN, ...
    'raw_monitor_false_direct', NaN, 'raw_monitor_true_direct', NaN, ...
    'monitor_false_direct', NaN, 'monitor_true_direct', NaN, ...
    'legacy_distance_ppm', NaN, 'legacy_dispersion_ppm', NaN, ...
    'legacy_residual_ppm', NaN, 'raw_monitor_distance_ppm', NaN, ...
    'raw_median_held_monitor_distance_ppm', NaN, ...
    'monitor_distance_ppm', NaN, 'median_held_monitor_distance_ppm', NaN, ...
    'legacy_training_false_direct', NaN, 'raw_monitor_training_false_direct', NaN, ...
    'monitor_training_false_direct', NaN);
end

function row = empty_regret_summary_row()
  row = struct('profile_id', "", 'training_records', NaN, 'held_records', NaN, ...
    'direct_records', NaN, 'local_search_records', NaN, 'candidate_count_model', NaN, ...
    'direct_mean_actual_regret', NaN, 'direct_max_actual_regret', NaN, ...
    'direct_initial_feedback_failures', NaN, 'direct_hard_monitor_faults', NaN, ...
    'feature_distance_rejects', NaN, 'mean_predicted_upper_regret', NaN);
end

function row = empty_regret_decision_row()
  row = struct('profile_id', "", 'scenario_id', "", 'run_id', "", ...
    'predicted_regret', NaN, 'predicted_uncertainty', NaN, ...
    'predicted_upper_regret', NaN, 'actual_regret', NaN, 'initial_cost', NaN, ...
    'local_search_cost', NaN, 'initial_feedback_pass', false, ...
    'hard_monitor_fault', false, 'nearest_feature_distance_ppm', NaN, ...
    'regret_budget', NaN, 'feature_distance_limit_ppm', NaN, ...
    'gate_decision', "", 'candidate_count_model', NaN);
end

function write_summary(T, Gate, Regret, cfg, profiles, path)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot open %s', path); end
  cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '# PA Robustness Simulation\n\n');
  fprintf(fid, 'This is behavioral MATLAB evidence. The policy predictor sees QAM, bandwidth, subcarriers, and backoff, but does not see hidden PA-profile variation.\n\n');
  fprintf(fid, 'The monitor fields use the same names and lightweight operations as the PL monitor registers. Input-side values follow Q1.15 L1 magnitude/correction arithmetic; output-related values use the post-PA behavioral complex observation. They are aligned behavioral proxies, not RTL bit-true DSM outputs or RF measurements.\n\n');
  fprintf(fid, '- Profiles: `%d`\n', numel(profiles));
  fprintf(fid, '- Waveforms per profile/seed: `8` (QAM16/QAM64, 20/40 MHz, 0.58/0.70 backoff)\n');
  fprintf(fid, '- Seeds: `%s`\n', mat2str(cfg.seeds));
  fprintf(fid, '- OFDM symbols per run: `%d`\n', cfg.nsym);
  fprintf(fid, '- Simulated pass limits: EVM `%.3f %%`, ACLR `%.3f dBc`\n\n', cfg.evm_limit_pct, cfg.aclr_limit_dbc);
  fprintf(fid, '| Profile | Gain | Sat | Taps | SNR dB | Gain drift ppm | Phase drift deg | Pass rate | Median residual ppm |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
  for p = 1:numel(profiles)
    rows = T(T.profile_id == profiles(p).id, :);
    residual = abs(rows.measured_cost - rows.predicted_cost) .* 1e6 ./ max(rows.predicted_cost, 1);
    fprintf(fid, '| %s | %.2f | %.2f | %d | %.1f | %.0f | %.2f | %.3f | %.0f |\n', ...
      profiles(p).id, profiles(p).gain_scale, profiles(p).sat_level, ...
      profiles(p).memory_taps, profiles(p).observation_snr_dB, ...
      profiles(p).gain_drift_ppm, profiles(p).phase_drift_deg, ...
      mean(rows.feedback_pass), median(residual));
  end
  fprintf(fid, '\n## Leave-One-PA-Profile Monitor Gate\n\n');
  fprintf(fid, 'For each held PA profile, all other profiles train a least-risk legacy gate over scenario distance, selected-cost dispersion, and cost residual. The weighted monitor gate uses scale-robust gain ratio, output peak/average ratio, correction/slew ratios, spectral shape ratios, and clip/saturation rates. `False direct` means the gate would skip local search for a simulated EVM/ACLR failure.\n\n');
  fprintf(fid, '| Held profile | Legacy false direct | Legacy true direct | Monitor false direct | Monitor true direct | Monitor tolerance ppm | Median held monitor distance ppm |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
  for k = 1:height(Gate)
    fprintf(fid, '| %s | %d | %d | %d | %d | %d | %d |\n', ...
      Gate.profile_id(k), Gate.legacy_false_direct(k), Gate.legacy_true_direct(k), ...
      Gate.monitor_false_direct(k), Gate.monitor_true_direct(k), ...
      Gate.monitor_distance_ppm(k), Gate.median_held_monitor_distance_ppm(k));
  end
  fprintf(fid, '\nTotals: legacy false/true direct `%d` / `%d`; monitor-gated false/true direct `%d` / `%d`.\n', ...
    sum(Gate.legacy_false_direct), sum(Gate.legacy_true_direct), ...
    sum(Gate.monitor_false_direct), sum(Gate.monitor_true_direct));
  fprintf(fid, '\n## Regret-Prediction Policy\n\n');
  fprintf(fid, 'For each held PA profile, a five-neighbor predictor is trained on visible waveform metadata and first-candidate monitor-state ratios. It predicts the cost reduction from one local-search round (`initial cost - local-search cost`). The direct decision requires the predicted regret plus one weighted-neighbor standard deviation to remain within the configured cost budget, a nearest normalized feature distance within the configured in-distribution limit, and zero clip/saturation. Hard runtime faults remain independent fallback triggers on the board.\n\n');
  fprintf(fid, '- Direct regret budget: `%d` cost units\n\n', cfg.direct_regret_budget);
  fprintf(fid, '- Direct feature-distance limit: `%d ppm`\n\n', cfg.direct_feature_distance_ppm);
  fprintf(fid, '| Held profile | Direct | Local search | Candidate model | Direct mean regret | Direct max regret | Direct initial feedback failures |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|\n');
  for k = 1:height(Regret)
    fprintf(fid, '| %s | %d | %d | %d | %.0f | %.0f | %d |\n', ...
      Regret.profile_id(k), Regret.direct_records(k), ...
      Regret.local_search_records(k), Regret.candidate_count_model(k), ...
      Regret.direct_mean_actual_regret(k), Regret.direct_max_actual_regret(k), ...
      Regret.direct_initial_feedback_failures(k));
  end
  fprintf(fid, '\nTotals: `%d` direct and `%d` local-search decisions; candidate model `%d` versus `%d` if every record used 14 candidates.\n', ...
    sum(Regret.direct_records), sum(Regret.local_search_records), ...
    sum(Regret.candidate_count_model), 14 * sum(Regret.held_records));
end

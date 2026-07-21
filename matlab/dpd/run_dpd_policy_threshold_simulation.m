function T = run_dpd_policy_threshold_simulation(varargin)
% run_dpd_policy_threshold_simulation
% Calibrate policy-gate evidence from the existing memory-PA/observation model.
% The output is simulation-only and must not be described as board or RF lab data.

  cfg = struct('seeds', [41 53 67], 'evm_limit_pct', 8.0, ...
    'aclr_limit_dbc', -20.0, 'out_dir', '');
  cfg = parse_kv(cfg, varargin{:});
  if isempty(cfg.out_dir)
    cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  end
  if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end

  samples = repmat(empty_sample(), 0, 1);
  for seed = cfg.seeds(:).'
    S = run_dpd_memory_pa_observation_sweep('seed', seed);
    for row = 1:height(S)
      sample = empty_sample();
      sample.scenario_id = scenario_id(S.Scenario(row));
      sample.run_id = sprintf('%s_seed%d', sample.scenario_id, seed);
      sample.pa_strength_db = pa_strength(S.Scenario(row));
      sample.qam = S.QAM(row);
      sample.bandwidth_mhz = bandwidth_mhz(S.UsedSubcarriers(row));
      sample.used_subcarriers = S.UsedSubcarriers(row);
      sample.input_backoff = S.InputBackoff(row);
      sample.evm_pct = S.RF_OptimizedPoly_EVM_percent(row);
      sample.aclr_db = S.RF_OptimizedPoly_ACLR_avg_dBc(row);
      sample.measured_cost = policy_cost(sample.evm_pct, sample.aclr_db);
      sample.feedback_pass = sample.evm_pct <= cfg.evm_limit_pct && ...
        sample.aclr_db <= cfg.aclr_limit_dbc;
      sample.simulation_model = "memory_pa_observation_v1";
      sample.simulation_config_id = sprintf('evm%.2f_aclr%.2f', ...
        cfg.evm_limit_pct, cfg.aclr_limit_dbc);
      sample.simulation_seed = seed;
      sample.observation_id = sprintf('matlab_memory_pa_seed%d', seed);
      samples(end+1) = sample; %#ok<AGROW>
    end
  end

  for k = 1:numel(samples)
    scenario_ids = string({samples.scenario_id});
    training = samples(scenario_ids ~= samples(k).scenario_id);
    [predicted, nearest, dispersion] = predict_cost(training, samples(k));
    samples(k).predicted_cost = predicted;
    samples(k).nearest_distance_ppm = round(nearest * 1e6);
    samples(k).relative_stddev_ppm = round(dispersion * 1e6 / max(predicted, 1));
  end

  T = struct2table(samples);
  csv_path = fullfile(cfg.out_dir, 'dpd_policy_threshold_simulation.csv');
  writetable(T, csv_path);
  write_summary(T, cfg, fullfile(cfg.out_dir, 'dpd_policy_threshold_simulation.md'));
  save(fullfile(cfg.out_dir, 'dpd_policy_threshold_simulation.mat'), 'cfg', 'T');
  fprintf('Wrote simulation policy feedback: %s\n', csv_path);
end

function id = scenario_id(name)
  text = char(name);
  if contains(text, 'strong_16qam')
    id = "sim_memory_pa_strong_qam16_bw20_bo058";
  elseif contains(text, '64qam')
    id = "sim_memory_pa_nominal_qam64_bw40_bo052";
  else
    id = "sim_memory_pa_nominal_qam16_bw20_bo058";
  end
end

function strength = pa_strength(name)
  strength = 0.0;
  if contains(char(name), 'strong_')
    strength = 6.0;
  end
end

function bw = bandwidth_mhz(nused)
  bw = 20.0;
  if nused > 48, bw = 40.0; end
end

function cost = policy_cost(evm_pct, aclr_db)
  cost = round(evm_pct * 10000 + max(aclr_db + 45, 0) * 200);
end

function [predicted, nearest, dispersion] = predict_cost(training, target)
  dist = zeros(numel(training), 1);
  costs = zeros(numel(training), 1);
  for k = 1:numel(training)
    dist(k) = scenario_distance(training(k), target);
    costs(k) = training(k).measured_cost;
  end
  weights = 1 ./ (1e-6 + dist);
  predicted = round(sum(weights .* costs) / sum(weights));
  nearest = min(dist);
  dispersion = sqrt(sum(weights .* (costs - predicted).^2) / sum(weights));
end

function d = scenario_distance(left, right)
  d = abs(left.pa_strength_db - right.pa_strength_db) / ...
      max([abs(left.pa_strength_db), abs(right.pa_strength_db), 1.0]) + ...
      abs(left.qam - right.qam) / max([left.qam, right.qam, 1.0]) + ...
      abs(left.bandwidth_mhz - right.bandwidth_mhz) / ...
      max([left.bandwidth_mhz, right.bandwidth_mhz, 0.001]) + ...
      abs(left.used_subcarriers - right.used_subcarriers) / ...
      max([left.used_subcarriers, right.used_subcarriers, 1.0]) + ...
      abs(left.input_backoff - right.input_backoff) / ...
      max([left.input_backoff, right.input_backoff, 0.01]);
end

function row = empty_sample()
  row = struct('scenario_id', "", 'run_id', "", 'pa_strength_db', NaN, ...
    'qam', NaN, 'bandwidth_mhz', NaN, 'used_subcarriers', NaN, ...
    'input_backoff', NaN, 'predicted_cost', NaN, 'measured_cost', NaN, ...
    'nearest_distance_ppm', NaN, 'relative_stddev_ppm', NaN, ...
    'feedback_pass', false, 'evm_pct', NaN, 'aclr_db', NaN, ...
    'simulation_model', "", 'simulation_config_id', "", ...
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

function write_summary(T, cfg, path)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot open %s', path); end
  cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '# Simulated DPD Policy Threshold Evidence\n\n');
  fprintf(fid, 'This artifact uses the MATLAB memory-PA and observation-receiver model. It is not a board or RF laboratory measurement.\n\n');
  fprintf(fid, '- Seeds: `%s`\n', mat2str(cfg.seeds));
  fprintf(fid, '- Simulated EVM pass limit: `%.3f %%`\n', cfg.evm_limit_pct);
  fprintf(fid, '- Simulated ACLR pass limit: `%.3f dBc`\n\n', cfg.aclr_limit_dbc);
  fprintf(fid, '| Scenario | Seed | Predicted cost | Measured cost | Distance ppm | Dispersion ppm | EVM %% | ACLR dBc | Pass |\n');
  fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---|\n');
  for k = 1:height(T)
    fprintf(fid, '| %s | %d | %d | %d | %d | %d | %.4f | %.4f | %d |\n', ...
      T.scenario_id(k), T.simulation_seed(k), T.predicted_cost(k), ...
      T.measured_cost(k), T.nearest_distance_ppm(k), ...
      T.relative_stddev_ppm(k), T.evm_pct(k), T.aclr_db(k), T.feedback_pass(k));
  end
end

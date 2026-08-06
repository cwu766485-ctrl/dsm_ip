function [Summary, Detail, Model] = run_dpa_ai_seeded_calibration(varargin)
% Run a PS-side AI-seeded calibration experiment against the 1-bit DPA model.
%
% A small ridge-regression model maps feedback-only monitor features to a
% Q2.14 first-tap C1/C3/C5 starting point. The existing constrained ILC
% search then verifies every update on independent validation waveforms. The
% four-tap Memory-Poly5 hardware shape is retained; the predictor deliberately
% seeds only tap zero and cannot directly release coefficients to RTL.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});
  train_conditions = make_train_conditions();
  test_conditions = make_test_conditions();
  feature_count = 5;
  train_x = zeros(numel(train_conditions), feature_count);
  train_y = zeros(numel(train_conditions), 6);
  train_rows = repmat(empty_detail_row(), numel(train_conditions), 1);

  for k = 1:numel(train_conditions)
    [results, ~, artifacts] = run_case(train_conditions(k), cfg, [], "identity");
    train_x(k, :) = feedback_features(results);
    train_y(k, :) = first_tap_words(artifacts.coeff_q);
    train_rows(k) = make_detail_row(train_conditions(k).Name, "training identity-search", ...
      results, artifacts, train_x(k, :), artifacts.initial_coeff_q);
  end
  Model = train_ridge_predictor(train_x, train_y, cfg.ridge);

  detail_rows = repmat(empty_detail_row(), numel(test_conditions) * 4, 1);
  row = 0;
  for k = 1:numel(test_conditions)
    condition = test_conditions(k);
    [identity_results, ~, identity_artifacts] = run_case(condition, cfg, [], "identity");
    features = feedback_features(identity_results);
    predicted_words = predict_first_tap(Model, features, cfg.coeff_safe_abs);
    predicted_q = inject_first_tap(identity_artifacts.identity_coeff_q, predicted_words);

    seed_cfg = cfg;
    seed_cfg.ilc_steps = [];
    [seed_results, ~, seed_artifacts] = run_case(condition, seed_cfg, predicted_q, "ridge-ai-seed");
    [refined_results, ~, refined_artifacts] = run_case(condition, cfg, predicted_q, "ridge-ai-seed");

    row = row + 1;
    detail_rows(row) = make_detail_row(condition.Name, "no DPD", identity_results, ...
      identity_artifacts, features, identity_artifacts.identity_coeff_q);
    row = row + 1;
    detail_rows(row) = make_detail_row(condition.Name, "identity seed plus guarded search", ...
      identity_results, identity_artifacts, features, identity_artifacts.initial_coeff_q);
    row = row + 1;
    detail_rows(row) = make_detail_row(condition.Name, "ridge AI seed only", ...
      seed_results, seed_artifacts, features, predicted_q);
    row = row + 1;
    detail_rows(row) = make_detail_row(condition.Name, "ridge AI seed plus guarded search", ...
      refined_results, refined_artifacts, features, predicted_q);
  end
  Detail = struct2table([train_rows; detail_rows]);
  Summary = summarize_detail(Detail);

  if cfg.write_outputs
    out_dir = cfg.out_dir;
    if isempty(out_dir)
      out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
    end
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    writetable(Summary, fullfile(out_dir, 'dpa_ai_seeded_calibration_summary.csv'));
    writetable(Detail, fullfile(out_dir, 'dpa_ai_seeded_calibration_detail.csv'));
    writematrix(Model.weights, fullfile(out_dir, 'dpa_ai_seeded_calibration_ridge_weights.csv'));
    write_report(fullfile(out_dir, 'dpa_ai_seeded_calibration.md'), Summary, Detail, Model, cfg);
    save(fullfile(out_dir, 'dpa_ai_seeded_calibration.mat'), 'Summary', 'Detail', 'Model', ...
      'train_conditions', 'test_conditions', 'cfg');
  end
  if cfg.verbose
    disp(Summary);
  end
end

function cfg = default_cfg()
  cfg.fit_nsym = 6;
  cfg.validation_nsym = 4;
  cfg.test_nsym = 5;
  cfg.nfft = 64;
  cfg.ncp = 8;
  cfg.nused = 8;
  cfg.qam_order = 16;
  cfg.ilc_steps = [4096 2048];
  cfg.ilc_max_passes = 1;
  cfg.ridge = 1e-2;
  cfg.coeff_safe_abs = 24576;
  cfg.write_outputs = true;
  cfg.out_dir = '';
  cfg.verbose = true;
end

function conditions = make_train_conditions()
  conditions = [ ...
    condition("train_a", 0.020, 0.16, 0.990, [0.90 0.12 -0.02], 47), ...
    condition("train_b", 0.035, 0.22, 0.992, [0.88 0.16 -0.05], 46), ...
    condition("train_c", 0.050, 0.28, 0.993, [0.86 0.18 -0.06], 45), ...
    condition("train_d", 0.028, 0.30, 0.989, [0.89 0.14 -0.04], 44), ...
    condition("train_e", 0.060, 0.20, 0.994, [0.85 0.20 -0.07], 43), ...
    condition("train_f", 0.040, 0.26, 0.991, [0.87 0.17 -0.05], 46), ...
    condition("train_g", 0.052, 0.24, 0.993, [0.86 0.19 -0.06], 44), ...
    condition("train_h", 0.024, 0.18, 0.990, [0.91 0.11 -0.03], 47)];
end

function conditions = make_test_conditions()
  conditions = [ ...
    condition("test_mid", 0.043, 0.25, 0.992, [0.87 0.17 -0.05], 45), ...
    condition("test_compressed", 0.056, 0.29, 0.994, [0.85 0.19 -0.07], 43), ...
    condition("test_light", 0.030, 0.19, 0.990, [0.90 0.13 -0.03], 47)];
end

function c = condition(name, asymmetry, compression, alpha, memory_fir, snr_dB)
  c = struct('Name', string(name), 'Asymmetry', asymmetry, 'Compression', compression, ...
    'ThermalAlpha', alpha, 'MemoryFIR', memory_fir, 'ObservationSNR_dB', snr_dB);
end

function [results, coefficients, artifacts] = run_case(condition, cfg, initial_q, source)
  args = {'fit_nsym', cfg.fit_nsym, 'validation_nsym', cfg.validation_nsym, ...
    'test_nsym', cfg.test_nsym, 'nfft', cfg.nfft, 'ncp', cfg.ncp, ...
    'nused', cfg.nused, 'qam_order', cfg.qam_order, 'ilc_steps', cfg.ilc_steps, ...
    'ilc_max_passes', cfg.ilc_max_passes, 'coeff_safe_abs', cfg.coeff_safe_abs, ...
    'dpa_switch_asymmetry', condition.Asymmetry, ...
    'dpa_thermal_compression', condition.Compression, ...
    'dpa_thermal_alpha', condition.ThermalAlpha, ...
    'dpa_memory_fir', condition.MemoryFIR, ...
    'observation_snr_dB', condition.ObservationSNR_dB, ...
    'initial_coeff_q', initial_q, 'initial_source', source, ...
    'write_outputs', false, 'verbose', false};
  [results, coefficients, artifacts] = run_lpdsmdpa_bpf_dpd_closed_loop(args{:});
end

function f = feedback_features(results)
  no_dpd = results(results.Mode == "No DPD", :);
  f = [mean(no_dpd.EVM_percent), mean(no_dpd.SNDR_dB), mean(no_dpd.ACLR_dBc), ...
    mean(no_dpd.DPAOutputRMS), mean(no_dpd.RFBitOneFraction)];
end

function words = first_tap_words(coeff_q)
  words = [real(coeff_q(1:3)).'; imag(coeff_q(1:3)).'];
end

function model = train_ridge_predictor(features, targets, ridge)
  model.mean = mean(features, 1);
  model.scale = std(features, 0, 1);
  model.scale(model.scale < eps) = 1;
  x = (features - model.mean) ./ model.scale;
  x = [ones(size(x, 1), 1), x];
  regularizer = diag([0, repmat(ridge, 1, size(x, 2)-1)]);
  model.weights = (x' * x + regularizer) \ (x' * targets);
end

function words = predict_first_tap(model, features, bound)
  x = [(features - model.mean) ./ model.scale];
  words = [1 x] * model.weights;
  words = min(max(round(words), -bound), bound);
end

function coeff_q = inject_first_tap(identity_q, words)
  coeff_q = identity_q;
  coeff_q(1:3) = complex(words(1:3), words(4:6));
end

function row = make_detail_row(condition, mode, results, artifacts, features, seed_q)
  if mode == "no DPD"
    selected = results(results.Mode == "No DPD", :);
  else
    selected = results(results.Mode == "Q2.14 Memory-Poly DPD", :);
  end
  row = empty_detail_row();
  row.Condition = condition;
  row.Mode = mode;
  row.EVM_percent = mean(selected.EVM_percent);
  row.SNDR_dB = mean(selected.SNDR_dB);
  row.ACLR_dBc = mean(selected.ACLR_dBc);
  row.DPDLimitCount = sum(selected.DPDLimitCount);
  row.CandidateEvaluations = height(artifacts.training_trace);
  row.QualityGate = string(artifacts.quality_gate.Status);
  row.MonitorEVM_percent = features(1);
  row.MonitorSNDR_dB = features(2);
  row.MonitorACLR_dBc = features(3);
  row.MonitorOutputRMS = features(4);
  row.MonitorRFBitOneFraction = features(5);
  row.SeedC1Re = real(seed_q(1)); row.SeedC1Im = imag(seed_q(1));
  row.SeedC3Re = real(seed_q(2)); row.SeedC3Im = imag(seed_q(2));
  row.SeedC5Re = real(seed_q(3)); row.SeedC5Im = imag(seed_q(3));
end

function Summary = summarize_detail(detail)
  modes = ["no DPD", "identity seed plus guarded search", ...
    "ridge AI seed only", "ridge AI seed plus guarded search"];
  rows = repmat(struct('Mode', "", 'MeanEVM_percent', NaN, 'MeanSNDR_dB', NaN, ...
    'MeanACLR_dBc', NaN, 'MeanCandidateEvaluations', NaN, 'SafeTestCount', 0), numel(modes), 1);
  for k = 1:numel(modes)
    selected = detail(detail.Mode == modes(k) & startsWith(detail.Condition, "test_"), :);
    rows(k).Mode = modes(k);
    rows(k).MeanEVM_percent = mean(selected.EVM_percent);
    rows(k).MeanSNDR_dB = mean(selected.SNDR_dB);
    rows(k).MeanACLR_dBc = mean(selected.ACLR_dBc);
    rows(k).MeanCandidateEvaluations = mean(selected.CandidateEvaluations);
    rows(k).SafeTestCount = sum(selected.DPDLimitCount == 0);
  end
  Summary = struct2table(rows);
end

function row = empty_detail_row()
  row = struct('Condition', "", 'Mode', "", 'EVM_percent', NaN, 'SNDR_dB', NaN, ...
    'ACLR_dBc', NaN, 'DPDLimitCount', 0, 'CandidateEvaluations', 0, ...
    'QualityGate', "", 'MonitorEVM_percent', NaN, 'MonitorSNDR_dB', NaN, ...
    'MonitorACLR_dBc', NaN, 'MonitorOutputRMS', NaN, ...
    'MonitorRFBitOneFraction', NaN, 'SeedC1Re', 0, 'SeedC1Im', 0, ...
    'SeedC3Re', 0, 'SeedC3Im', 0, 'SeedC5Re', 0, 'SeedC5Im', 0);
end

function write_report(path, summary, detail, model, cfg)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot write %s', path); end
  cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '# DPA Feedback AI-Seeded Calibration Experiment\n\n');
  fprintf(fid, 'This is a behavioral 1-bit DPA+BPF feedback experiment. It is not ADS, EM, package, or silicon evidence. The ADS transient license must be available before retraining from circuit observations.\n\n');
  fprintf(fid, 'A ridge-regression seed model consumes only no-DPD feedback monitors: EVM, SNDR, out-of-band ratio, DPA output RMS, and RF-bit one fraction. It predicts the first-tap Q2.14 C1/C3/C5 words; the four-tap Memory-Poly5 structure is retained and a bounded coordinate search validates every accepted change.\n\n');
  fprintf(fid, '## Test Summary\n\n| Mode | Mean EVM %% | Mean SNDR dB | Mean out-of-band ratio dBc | Mean candidates | Zero-limit tests |\n|---|---:|---:|---:|---:|---:|\n');
  for k = 1:height(summary)
    fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.1f | %d |\n', summary.Mode(k), summary.MeanEVM_percent(k), summary.MeanSNDR_dB(k), summary.MeanACLR_dBc(k), summary.MeanCandidateEvaluations(k), summary.SafeTestCount(k));
  end
  fprintf(fid, '\nThe AI model is an initial-point predictor, not a replacement for safety-gated calibration. No coefficient table produced by this experiment is released to RTL.\n');
  fprintf(fid, '\nRidge configuration: lambda=%.3g; predictor inputs=%d; output words=6.\n', cfg.ridge, numel(model.mean));
  fprintf(fid, 'Detailed monitor traces and predicted seed words are in `dpa_ai_seeded_calibration_detail.csv`.\n');
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0, error('Arguments must be name/value pairs.'); end
  for k = 1:2:numel(varargin)
    name = char(varargin{k});
    if ~isfield(cfg, name), error('Unknown option: %s', name); end
    cfg.(name) = varargin{k+1};
  end
end

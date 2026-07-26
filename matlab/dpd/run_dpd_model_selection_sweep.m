function [Results, Recommendation] = run_dpd_model_selection_sweep(varargin)
% Select a fixed-point memory-polynomial DPD complexity from PA conditions.
% This is a model-selection tool, not a substitute for PA characterization.

  cfg = default_cfg();
  cfg = parse_kv(cfg, varargin{:});
  rows = repmat(empty_row(), numel(cfg.backoff_grid) * ...
    numel(cfg.saturation_grid) * numel(cfg.depth_grid) * ...
    numel(cfg.order_grid), 1);
  row = 0;

  for backoff = cfg.backoff_grid
    for saturation = cfg.saturation_grid
      for depth = cfg.depth_grid
        for order = cfg.order_grid
          orders = 1:2:order;
          [~, summary] = run_dpd_memory_poly_training_comparison( ...
            'input_backoff', backoff, ...
            'pa_sat_level', saturation, ...
            'memory_taps', depth, ...
            'orders', orders, ...
            'train_nsym', cfg.train_nsym, ...
            'validation_nsym', cfg.validation_nsym, ...
            'test_nsym', cfg.test_nsym, ...
            'test_seeds', cfg.test_seeds, ...
            'write_outputs', false, ...
            'verbose', false);
          selected = summary(summary.Mode == "Memory-polynomial DPD", :);
          row = row + 1;
          rows(row).InputBackoff = backoff;
          rows(row).PASaturation = saturation;
          rows(row).PolyOrder = order;
          rows(row).MemoryDepth = depth;
          rows(row).EVM_percent = selected.Mean_EVM_percent;
          rows(row).SNDR_dB = selected.Mean_SNDR_dB;
          rows(row).ACLR_dBc = selected.Mean_ACLR_avg_dBc;
          rows(row).DPDSaturationCount = selected.Total_DPDSaturationCount;
          rows(row).DriveLimitCount = selected.Total_DriveLimitCount;
          rows(row).MultiplierProxy = depth * numel(orders) * 4;
          rows(row).StateProxy = depth * 2;
        end
      end
    end
  end
  Results = struct2table(rows(1:row));

  % A candidate that clips is rejected.  The remaining score trades EVM,
  % adjacent-channel quality, and a deliberately simple hardware proxy.
  Results.Safe = Results.DPDSaturationCount == 0 & Results.DriveLimitCount == 0;
  aclr_penalty = max(Results.ACLR_dBc - cfg.target_aclr_dBc, 0);
  Results.Score = 100 * Results.EVM_percent + 2 * aclr_penalty + ...
    cfg.resource_weight * Results.MultiplierProxy + ...
    cfg.state_weight * Results.StateProxy;
  Results.Score(~Results.Safe) = inf;
  [~, best_index] = min(Results.Score);
  Recommendation = Results(best_index, :);

  if cfg.write_outputs
    if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end
    writetable(Results, fullfile(cfg.out_dir, 'dpd_model_selection_sweep.csv'));
    writetable(Recommendation, fullfile(cfg.out_dir, 'dpd_model_selection_recommendation.csv'));
    write_markdown(fullfile(cfg.out_dir, 'dpd_model_selection_sweep.md'), ...
      Results, Recommendation, cfg);
    save(fullfile(cfg.out_dir, 'dpd_model_selection_sweep.mat'), ...
      'Results', 'Recommendation', 'cfg');
  end
  if cfg.verbose
    disp(Recommendation);
  end
end

function cfg = default_cfg()
  root = fileparts(fileparts(mfilename('fullpath')));
  cfg.backoff_grid = [0.48 0.58];
  cfg.saturation_grid = [0.82 0.92];
  cfg.order_grid = [3 5 7];
  cfg.depth_grid = [1 2 4 6];
  cfg.target_aclr_dBc = -35;
  cfg.resource_weight = 0.015;
  cfg.state_weight = 0.010;
  cfg.train_nsym = 16;
  cfg.validation_nsym = 8;
  cfg.test_nsym = 8;
  cfg.test_seeds = 211;
  cfg.out_dir = fullfile(root, 'out', 'dpd');
  cfg.write_outputs = true;
  cfg.verbose = true;
end

function write_markdown(path, results, recommendation, cfg)
  fid = fopen(path, 'w');
  if fid < 0, error('Cannot write %s', path); end
  cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
  fprintf(fid, '# DPD Model-Selection Sweep\n\n');
  fprintf(fid, 'This behavioral sweep covers PA saturation and input-backoff corners. It ranks Q1.15/Q2.14 memory-polynomial candidates using EVM, ACLR, clipping, and structural resource proxies. It is not physical PA characterization.\n\n');
  fprintf(fid, '## Recommendation\n\n');
  fprintf(fid, '| Order | Depth | Backoff | PA saturation | EVM %% | SNDR dB | ACLR dBc | Multiplier proxy | State proxy |\n');
  fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
  fprintf(fid, '| %d | %d | %.2f | %.2f | %.6f | %.3f | %.3f | %d | %d |\n\n', ...
    recommendation.PolyOrder, recommendation.MemoryDepth, recommendation.InputBackoff, ...
    recommendation.PASaturation, recommendation.EVM_percent, recommendation.SNDR_dB, ...
    recommendation.ACLR_dBc, recommendation.MultiplierProxy, recommendation.StateProxy);
  fprintf(fid, 'Target ACLR: %.1f dBc. Candidates with fixed-point DPD or drive clipping are rejected.\n\n', cfg.target_aclr_dBc);
  fprintf(fid, '## All Candidates\n\n');
  fprintf(fid, '| Order | Depth | Backoff | PA saturation | EVM %% | SNDR dB | ACLR dBc | DPD sat | Drive limit | Safe | Score |\n');
  fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|\n');
  for n = 1:height(results)
    fprintf(fid, '| %d | %d | %.2f | %.2f | %.6f | %.3f | %.3f | %d | %d | %d | %.3f |\n', ...
      results.PolyOrder(n), results.MemoryDepth(n), results.InputBackoff(n), ...
      results.PASaturation(n), results.EVM_percent(n), results.SNDR_dB(n), ...
      results.ACLR_dBc(n), results.DPDSaturationCount(n), ...
      results.DriveLimitCount(n), results.Safe(n), results.Score(n));
  end
end

function row = empty_row()
  row = struct('InputBackoff', NaN, 'PASaturation', NaN, 'PolyOrder', NaN, ...
    'MemoryDepth', NaN, 'EVM_percent', NaN, 'SNDR_dB', NaN, ...
    'ACLR_dBc', NaN, 'DPDSaturationCount', NaN, ...
    'DriveLimitCount', NaN, 'MultiplierProxy', NaN, 'StateProxy', NaN);
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin), 2) ~= 0, error('Arguments must be key/value pairs.'); end
  for n = 1:2:numel(varargin)
    if ~isfield(cfg, varargin{n}), error('Unknown configuration field: %s', varargin{n}); end
    cfg.(varargin{n}) = varargin{n+1};
  end
end

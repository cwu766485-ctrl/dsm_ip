function Summary = run_bp_efdsm2_dpa_stage_diagnostic(varargin)
% Quantify the BP-EFDSM2 reconstruction baseline before DPA impairments.
% The function runs no-DPD only so the stages expose endpoint loss, not DPD fit.

  cfg = struct('out_dir', '', 'fit_nsym', 4, 'validation_nsym', 4, ...
    'test_nsym', 12, 'write_outputs', true, 'verbose', false);
  cfg = parse_kv(cfg, varargin{:});
  if isempty(cfg.out_dir)
    cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', 'dpd');
  end
  stages = ["ideal_switch" "full"];
  all_rows = cell(numel(stages), 1);
  for k = 1:numel(stages)
    [Results, ~] = run_bp_efdsm2_dpa_dpd_closed_loop( ...
      'endpoint_stage', stages(k), 'power_comparison_mode', "match_input_rms", ...
      'fit_nsym', cfg.fit_nsym, 'validation_nsym', cfg.validation_nsym, ...
      'test_nsym', cfg.test_nsym, 'write_outputs', false, 'verbose', cfg.verbose);
    row = Results(Results.Mode == "No DPD", :);
    row.Stage = repmat(stages(k), height(row), 1);
    row = movevars(row, 'Stage', 'Before', 1);
    all_rows{k} = row;
  end
  T = vertcat(all_rows{:});
  Summary = groupsummary(T, 'Stage', 'mean', {'EVM_percent','SNDR_dB','ACLR_dBc','Pout_mW','Pdc_mW','Efficiency_percent'});
  if cfg.write_outputs
    writetable(T, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_stage_diagnostic_results.csv'));
    writetable(Summary, fullfile(cfg.out_dir, 'bp_efdsm2_dpa_stage_diagnostic_summary.csv'));
  end
  disp(Summary);
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin),2)~=0, error('Use name/value pairs.'); end
  for k = 1:2:numel(varargin)
    name = char(varargin{k}); if ~isfield(cfg,name), error('Unknown option: %s',name); end
    cfg.(name) = varargin{k+1};
  end
end

function T = run_frontend_dsm_pareto_matrix(varargin)
% Run the 4 x 6 x32 interpolation/DSM combined decision matrix.
%
% I0, I1 and I3 share the same intended x32 transfer response.  I2 is the
% equivalent complete response as one monolithic filter. RTL/XSim verifies
% every implementation-specific fixed-point contract.

  cfg = default_cfg();
  for k = 1:2:numel(varargin)
    cfg.(varargin{k}) = varargin{k + 1};
  end
  if ~exist(cfg.out_dir, 'dir')
    mkdir(cfg.out_dir);
  end

  rows = cell(numel(cfg.interp_ids) * numel(cfg.dsm_ids), 1);
  row = 0;
  for ii = 1:numel(cfg.interp_ids)
    interp_id = string(cfg.interp_ids{ii});
    for dd = 1:numel(cfg.dsm_ids)
      dsm_id = string(cfg.dsm_ids{dd});
      alg = algorithm_for_id(dsm_id);
      [nominal, sensitivity] = run_one(interp_id, dsm_id, alg, cfg);
      row = row + 1;
      rows{row} = {interp_id, interp_description(interp_id), dsm_id, alg, ...
        nominal.native_EVM_percent, nominal.native_SNDR_dB, nominal.ACLR_avg_dBc, ...
        nominal.RF_recovered_EVM_percent, nominal.RF_recovered_SNDR_dB, ...
        output_code_width(dsm_id, cfg.mb_q_bits), output_code_max(dsm_id, cfg.mb_q_bits), ...
        sensitivity.evm_span_percent, sensitivity.sndr_span_dB, sensitivity.aclr_span_dB};
    end
  end

  T = cell2table(vertcat(rows{:}), 'VariableNames', {
    'interp_id', 'interp_description', 'dsm_id', 'dsm_alg', ...
    'native_EVM_percent', 'native_SNDR_dB', 'ACLR_avg_dBc', ...
    'RF_recovered_EVM_percent', 'RF_recovered_SNDR_dB', ...
    'output_code_width_bits', 'output_code_abs_max', ...
    'recon_EVM_span_percent', 'recon_SNDR_span_dB', 'recon_ACLR_span_dB'});
  writetable(T, fullfile(cfg.out_dir, cfg.out_filename));
end

function cfg = default_cfg()
  repo_matlab = fileparts(fileparts(mfilename('fullpath')));
  cfg.out_dir = fullfile(repo_matlab, 'out', 'frontend_dsm_pareto');
  cfg.out_filename = 'frontend_dsm_pareto_matrix.csv';
  cfg.interp_ids = {'I0', 'I1', 'I2', 'I3'};
  cfg.dsm_ids = {'D0', 'D1', 'D2', 'D3', 'D5', 'D6'};
  cfg.seed = 11;
  cfg.mb_q_bits = 4;
  cfg.recon_bw_scales = [1.2 1.4 1.6];
end

function [nominal, sensitivity] = run_one(interp_id, dsm_id, alg, cfg)
  metrics = cell(numel(cfg.recon_bw_scales), 1);
  for kk = 1:numel(cfg.recon_bw_scales)
    tmp = fullfile(cfg.out_dir, sprintf('tmp_%s_%s_bw_%03d', interp_id, dsm_id, ...
      round(100 * cfg.recon_bw_scales(kk))));
    interp_frontend_system_eval( ...
      'out_dir', tmp, 'seed', cfg.seed, 'modes', 4, ...
      'interp_impl', char(interp_id), ...
      'dsm_alg', char(alg), 'mb_q_bits', cfg.mb_q_bits, ...
      'rf_bpf_bw_scale', cfg.recon_bw_scales(kk));
    metrics{kk} = readtable(fullfile(tmp, 'interp_frontend_system_metrics.csv'));
  end
  nominal_index = find(abs(cfg.recon_bw_scales - 1.4) < 1e-12, 1);
  if isempty(nominal_index)
    nominal_index = 1;
  end
  nominal = metrics{nominal_index};
  nominal = table2struct(nominal(1, :));

  evm = cellfun(@(x) x.native_EVM_percent(1), metrics);
  sndr = cellfun(@(x) x.native_SNDR_dB(1), metrics);
  aclr = cellfun(@(x) x.ACLR_avg_dBc(1), metrics);
  sensitivity.evm_span_percent = max(evm) - min(evm);
  sensitivity.sndr_span_dB = max(sndr) - min(sndr);
  sensitivity.aclr_span_dB = max(aclr) - min(aclr);
end

function alg = algorithm_for_id(dsm_id)
  switch dsm_id
    case "D0", alg = "ef1";
    case "D1", alg = "lp2";
    case "D2", alg = "ef2";
    case "D3", alg = "mash11";
    case "D4", alg = "mash111";
    case "D5", alg = "mb_ef1";
    case "D6", alg = "mb_ef2";
    otherwise, error('Unsupported DSM ID: %s', dsm_id);
  end
end

function text = interp_description(interp_id)
  switch interp_id
    case "I0", text = "HBx4 + CIC-equivalent FIR x8 + compensation FIR";
    case "I1", text = "HBx4 + direct CIC x8 + compensation FIR";
    case "I2", text = "monolithic x32 pure FIR (1195 tap)";
    case "I3", text = "HBx4 + polyphase CIC-equivalent FIR x8 + compensation FIR";
    otherwise, error('Unsupported interpolation ID: %s', interp_id);
  end
end

function width = output_code_width(dsm_id, mb_q_bits)
  switch dsm_id
    case {"D0", "D1", "D2"}, width = 1;
    case "D3", width = 3;
    case "D4", width = 4;
    otherwise, width = mb_q_bits;
  end
end

function peak = output_code_max(dsm_id, mb_q_bits)
  switch dsm_id
    case {"D0", "D1", "D2"}, peak = 1;
    case "D3", peak = 3;
    case "D4", peak = 7;
    otherwise, peak = 2^(mb_q_bits - 1) - 1;
  end
end

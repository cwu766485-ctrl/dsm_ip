function [Results, Summary] = run_bp_modulator_dpa_comparison(varargin)
% Compare BP single-loop, BP EFDSM2, and native multilevel BP MASH11.
% This is a common modulator/filter/receiver study with no DPD. MASH11 is a
% four-level output contract, so binary-DPA Pdc and efficiency are invalid.

  cfg = struct('out_dir','', 'input_backoffs',[0.35 0.45 0.55], ...
    'modulator_modes',["single" "ef2" "mash11"], 'b1_values',0, ...
    'b2_values',-1, 'dither_values',0, 'test_seeds',[211 223 239], ...
    'write_outputs',true, 'verbose',true);
  cfg = parse_kv(cfg, varargin{:});
  if isempty(cfg.out_dir), cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','dpd'); end
  cells = cell(0,1);
  for mode = string(cfg.modulator_modes)
    for backoff = cfg.input_backoffs
      for b1 = cfg.b1_values
        for b2 = cfg.b2_values
          for dither = cfg.dither_values
            [r, ~] = run_bp_efdsm2_dpa_dpd_closed_loop( ...
              'modulator_mode', mode, 'input_backoff', backoff, ...
              'bp_b1', b1, 'bp_b2', b2, 'dither_lsb', dither, ...
              'test_seeds', cfg.test_seeds, 'enable_dpd_comparison', false, ...
              'endpoint_stage', "ideal_switch", 'write_outputs', false, 'verbose', false);
            r.Modulator = repmat(mode, height(r), 1);
            if mode == "mash11"
              r.OutputContract = repmat("four-level {-3,-1,+1,+3}", height(r), 1);
              r.Pout_mW(:) = NaN;
              r.Pdc_mW(:) = NaN;
              r.Efficiency_percent(:) = NaN;
            else
              r.OutputContract = repmat("one-bit {-1,+1}", height(r), 1);
            end
            r.InputBackoff = repmat(backoff, height(r), 1);
            r.B1 = repmat(b1, height(r), 1); r.B2 = repmat(b2, height(r), 1);
            r.DitherLSB = repmat(dither, height(r), 1);
            cells{end+1} = r; %#ok<AGROW>
          end
        end
      end
    end
  end
  Results = vertcat(cells{:});
  Summary = groupsummary(Results, {'Modulator','OutputContract','InputBackoff','B1','B2','DitherLSB'}, 'mean', ...
    {'EVM_percent','SNDR_dB','ACLR_dBc','Pout_mW','Pdc_mW','Efficiency_percent'});
  if cfg.write_outputs
    writetable(Results, fullfile(cfg.out_dir,'bp_modulator_dpa_comparison_results.csv'));
    writetable(Summary, fullfile(cfg.out_dir,'bp_modulator_dpa_comparison_summary.csv'));
  end
  if cfg.verbose, disp(Summary); end
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin),2)~=0, error('Use name/value pairs.'); end
  for k=1:2:numel(varargin)
    name=char(varargin{k}); if ~isfield(cfg,name), error('Unknown option: %s',name); end
    cfg.(name)=varargin{k+1};
  end
end

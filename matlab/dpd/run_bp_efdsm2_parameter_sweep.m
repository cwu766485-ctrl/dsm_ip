function [Results, Best] = run_bp_efdsm2_parameter_sweep(varargin)
% Search BP EFDSM2 operating points without changing its one-bit contract.
% This is a model optimization gate; candidates require later RTL bit-true
% and timing checks before they can replace the frozen coefficients.
  cfg = struct('out_dir','', 'input_backoffs',0.45, ...
    'b1_values',[-0.10 0 0.10], 'b2_values',[-1.10 -1 -0.90], ...
    'dither_values',[0 1 2], 'test_seeds',[211 223 239], 'write_outputs',true, 'verbose',true);
  cfg = parse_kv(cfg, varargin{:});
  args = {'input_backoffs',cfg.input_backoffs,'b1_values',cfg.b1_values,'b2_values',cfg.b2_values, ...
    'dither_values',cfg.dither_values,'test_seeds',cfg.test_seeds,'write_outputs',false,'verbose',false};
  [~, Results] = run_bp_modulator_dpa_comparison(args{:});
  Results = Results(Results.Modulator == "ef2", :);
  % Input backoff is held at one nominal operating point. Otherwise a global
  % "best" merely picks a different transmit-power point rather than a better
  % EFDSM2 loop. EVM is primary; SNDR/ACLR remain reported tie-break evidence.
  Results.Score = Results.mean_EVM_percent;
  % This sweep contains no DPD coefficient search. A row is therefore stable
  % when it returned finite metrics; fixed-point state saturation is clamped
  % inside the modulator and must be inspected in a later RTL trace.
  Results.Stable = isfinite(Results.mean_EVM_percent) & isfinite(Results.mean_SNDR_dB);
  Results = sortrows(Results, {'Stable','Score'}, {'descend','ascend'});
  if ~any(Results.Stable), error('No finite EFDSM2 sweep point was found.'); end
  Best = Results(find(Results.Stable,1,'first'), :);
  if cfg.write_outputs
    if isempty(cfg.out_dir), cfg.out_dir=fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','dpd'); end
    writetable(Results, fullfile(cfg.out_dir,'bp_efdsm2_parameter_sweep.csv'));
    writetable(Best, fullfile(cfg.out_dir,'bp_efdsm2_parameter_best.csv'));
  end
  if cfg.verbose, disp(Best); end
end

function cfg = parse_kv(cfg, varargin)
  if mod(numel(varargin),2)~=0, error('Use name/value pairs.'); end
  for k=1:2:numel(varargin)
    name=char(varargin{k}); if ~isfield(cfg,name), error('Unknown option: %s',name); end
    cfg.(name)=varargin{k+1};
  end
end

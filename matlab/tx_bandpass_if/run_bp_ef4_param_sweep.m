function results = run_bp_ef4_param_sweep(varargin)
% RUN_BP_EF4_PARAM_SWEEP Screen BP-EFDSM4 feedback and drive candidates.
% This is a behavioral feasibility search, not an RTL coefficient signoff.

  cfg.bandwidth_hz = 40e6; cfg.nfft = 8192; cfg.ncp = 1024; cfg.nsym = 4;
  cfg.drives = [0.08 0.10 0.12 0.15 0.18];
  cfg.c2_nums = [-3 -2 -1]; cfg.c4_nums = [-2 -1 0];
  cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','bp_ef4_param_sweep');
  for k = 1:2:numel(varargin), cfg.(varargin{k}) = varargin{k+1}; end
  if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end
  rows = []; r = 0;
  for c2 = cfg.c2_nums
    for c4 = cfg.c4_nums
      for drive = cfg.drives
        r = r + 1;
        run_dir = fullfile(cfg.out_dir,sprintf('c2_%+d_c4_%+d_d_%03d',c2,c4,round(1000*drive)));
        t = run_256qam_dsm_if_screen('bandwidth_hz',cfg.bandwidth_hz,'nfft',cfg.nfft, ...
          'ncp',cfg.ncp,'nsym',cfg.nsym,'drive',drive,'bp_ef4_c2_num',c2, ...
          'bp_ef4_c4_num',c4,'out_dir',run_dir);
        hit = t(t.Candidate == "bp_efdsm4",:);
        rows(r,:) = [c2 c4 drive hit.EVM_percent hit.SNDR_dB hit.ACLR_dBc]; %#ok<AGROW>
      end
    end
  end
  results = array2table(rows,'VariableNames',{'C2_NUM','C4_NUM','Drive','EVM_percent','SNDR_dB','ACLR_dBc'});
  results.Pass = results.EVM_percent <= 3.5 & results.SNDR_dB >= 29.12;
  results = sortrows(results,{'Pass','EVM_percent'},{'descend','ascend'});
  writetable(results,fullfile(cfg.out_dir,'summary.csv')); disp(results);
end

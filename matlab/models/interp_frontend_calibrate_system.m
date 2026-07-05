function T = interp_frontend_calibrate_system(varargin)
% Calibration sweep for the interpolation + DSM + Fs/4 DUC system model.
%
% The sweep intentionally reports both RF-domain metrics and native-domain
% metrics. Native-domain metrics reconstruct I/Q DSM outputs before Fs/4 merge;
% RF-domain metrics reconstruct the emitted Fs/4 real stream. A large gap
% between them indicates DUC/RF reconstruction or quantization-noise folding.

  cfg = local_cfg();
  for k = 1:2:numel(varargin)
    cfg.(varargin{k}) = varargin{k + 1};
  end
  if ~exist(cfg.out_dir, 'dir')
    mkdir(cfg.out_dir);
  end

  rows = {};
  row = 0;
  for ia = 1:numel(cfg.algorithms)
    alg = cfg.algorithms{ia};
    for ib = 1:numel(cfg.used_sc_counts)
      used = make_used_sc(cfg.used_sc_counts(ib));
      for id = 1:numel(cfg.drive_peaks)
        drive = cfg.drive_peaks(id);
        for ir = 1:numel(cfg.recon_taps_list)
          rtaps = cfg.recon_taps_list(ir);
          Tnow = interp_frontend_system_eval( ...
              'modes', cfg.modes, ...
              'architecture', cfg.architecture, ...
              'dsm_alg', alg, ...
              'used_sc', used, ...
              'dsm_drive_peak', drive, ...
              'recon_taps', rtaps, ...
              'rf_bpf_enable', cfg.rf_bpf_enable, ...
              'out_dir', cfg.out_dir);
          for n = 1:height(Tnow)
            row = row + 1;
            rows(row, :) = {string(alg), cfg.used_sc_counts(ib), drive, rtaps, ...
                            Tnow.mode(n), Tnow.interp(n), ...
                            Tnow.RF_recovered_EVM_percent(n), Tnow.RF_recovered_SNDR_dB(n), Tnow.ACLR_avg_dBc(n), ...
                            Tnow.native_EVM_percent(n), Tnow.native_SNDR_dB(n), ...
                            Tnow.PAPR_BB_dB(n), Tnow.PAPR_RF_dB(n)}; %#ok<AGROW>
          end
        end
      end
    end
  end

  T = cell2table(rows, 'VariableNames', ...
      {'algorithm','used_sc_count','dsm_drive_peak','recon_taps','mode','interp', ...
       'RF_recovered_EVM_percent','RF_recovered_SNDR_dB','RF_ACLR_avg_dBc', ...
       'native_EVM_percent','native_SNDR_dB','PAPR_BB_dB','PAPR_RF_dB'});
  T = sortrows(T, {'RF_recovered_EVM_percent','native_EVM_percent'}, {'ascend','ascend'});
  writetable(T, fullfile(cfg.out_dir, 'interp_frontend_system_calibration.csv'));

  Tnative = sortrows(T, {'native_EVM_percent','RF_recovered_EVM_percent'}, {'ascend','ascend'});
  writetable(Tnative, fullfile(cfg.out_dir, 'interp_frontend_system_calibration_by_native.csv'));
end

function cfg = local_cfg()
  repo_matlab = fileparts(fileparts(mfilename('fullpath')));
  cfg.out_dir = fullfile(repo_matlab, 'out', 'interp_frontend');
  cfg.algorithms = {'none','lp2','ef2','mash22'};
  cfg.architecture = 'iq_lpdsm_fs4';
  cfg.modes = 2:4;
  cfg.used_sc_counts = [8 16 24];
  cfg.drive_peaks = [0.25 0.45];
  cfg.recon_taps_list = [191 511];
  cfg.rf_bpf_enable = true;
end

function used = make_used_sc(nused)
  if mod(nused, 2) ~= 0
    error('used_sc_count must be even');
  end
  h = nused / 2;
  used = [-h:-1 1:h];
end

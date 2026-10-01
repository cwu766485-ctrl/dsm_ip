function [PerSeed,SkuSummary] = run_tid32_thermo_sku_matrix(varargin)
%RUN_TID32_THERMO_SKU_MATRIX Fair 250-MHz full-chain thermo SKU matrix.
%
% This experiment fixes the useful 256-QAM OFDM payload, three isolated
% fit/validation/test seed sets, synthetic mild switching-DPA corner, fair-RMS
% drive, BPF/DDC bandwidth, and 3.5-GHz Fs/4 architecture.  It varies only
% the hardware-selectable thermo level, x2 interpolation coefficient family,
% and instantiated identity memory-DPD depth.  The identity wrapper is
% deliberately tap0=1 and all delayed coefficients=0, so DPD depth changes
% RTL PPA but must not be presented as an RF-quality improvement.

cfg = local_default_cfg();
for k = 1:2:numel(varargin), cfg.(varargin{k}) = varargin{k+1}; end

interp = local_interpolators();
interp = interp(ismember([interp.Taps], cfg.interp_taps));
assert(~isempty(interp), 'No selected interpolation SKU.');
rows = table();
for levels = reshape(cfg.thermo_levels,1,[])
    for i = 1:numel(interp)
        for dpd_taps = reshape(cfg.dpd_taps,1,[])
            result = run_tid32_thermo3_profile_bandwidth_sweep( ...
                'profile_names', "mild", ...
                'bandwidths_hz', cfg.bandwidth_hz, ...
                'seed_sets', cfg.seed_sets, ...
                'fit_nsym', cfg.fit_nsym, 'val_nsym', cfg.val_nsym, ...
                'test_nsym', cfg.test_nsym, ...
                'enable_dpd_training', false, ...
                'dpd_active_taps', dpd_taps, ...
                'thermo_levels', levels, 'thermo5_step', cfg.thermo5_step, ...
                'interp_even_coeff', interp(i).Coeff, ...
                'input_normalization', "fair_rms", 'rms_drive', cfg.rms_drive, ...
                'bpf_passband_factor', cfg.bpf_passband_factor, ...
                'write_outputs', false);
            result = result(result.Mode == "identity_untrained", :);
            assert(all(result.RawWordMismatches == 0), ...
                'Raw-word contract failed for thermo%d/i%d/d%d.', levels, interp(i).Taps, dpd_taps);
            result.ThermoLevels = repmat(levels,height(result),1);
            result.InterpTaps = repmat(interp(i).Taps,height(result),1);
            result.InterpName = repmat(string(interp(i).Name),height(result),1);
            result.DPDMaxTaps = repmat(dpd_taps,height(result),1);
            result.DPDActiveTaps = repmat(dpd_taps,height(result),1);
            result.DPDMode = repmat("identity_memory_poly",height(result),1);
            rows = [rows; result]; %#ok<AGROW>
        end
    end
end

PerSeed = rows;
SkuSummary = local_summarize(rows);
if cfg.write_outputs
    if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end
    writetable(PerSeed,fullfile(cfg.out_dir,'thermo_sku_algorithm_per_seed.csv'));
    writetable(SkuSummary,fullfile(cfg.out_dir,'thermo_sku_algorithm_summary.csv'));
end
disp(SkuSummary(:,{'ThermoLevels','InterpTaps','DPDMaxTaps','WorstEVM_percent', ...
    'WorstSNDR_dB','WorstFilteredACLR_dBc','AllPass256QAM','RawWordMismatches'}));
end

function cfg = local_default_cfg()
cfg.thermo_levels = [3 5];
cfg.interp_taps = [2 3 4];
cfg.dpd_taps = [1 2 4];
cfg.bandwidth_hz = 250e6;
cfg.seed_sets = [101 137 211; 307 349 401; 503 547 601];
cfg.fit_nsym = 12; cfg.val_nsym = 10; cfg.test_nsym = 12;
cfg.thermo5_step = 7168;
cfg.rms_drive = 0.095;
cfg.bpf_passband_factor = 1.50;
cfg.write_outputs = true;
cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','thermo_sku_matrix');
end

function i = local_interpolators()
i(1) = struct('Taps',2,'Name',"linear_2tap",'Coeff',[1 1]/2);
i(2) = struct('Taps',3,'Name',"causal_quadratic_3tap",'Coeff',[3 6 -1]/8);
i(3) = struct('Taps',4,'Name',"causal_cubic_4tap",'Coeff',[5 15 -5 1]/16);
end

function summary = local_summarize(rows)
keys = unique(rows(:,{'ThermoLevels','InterpTaps','DPDMaxTaps'}),'rows','stable');
n = height(keys);
summary = table('Size',[n 11], ...
    'VariableTypes',{'double','double','double','double','double','double','double','logical','double','string','string'}, ...
    'VariableNames',{'ThermoLevels','InterpTaps','DPDMaxTaps','WorstEVM_percent', ...
    'WorstSNDR_dB','WorstPA_ACLR_dBc','WorstFilteredACLR_dBc','AllPass256QAM', ...
    'RawWordMismatches','AlgorithmEvidence','DPDInterpretation'});
for k=1:n
    hit = rows.ThermoLevels == keys.ThermoLevels(k) & ...
          rows.InterpTaps == keys.InterpTaps(k) & ...
          rows.DPDMaxTaps == keys.DPDMaxTaps(k);
    r = rows(hit,:);
    summary{k,1:3} = keys{k,1:3};
    summary.WorstEVM_percent(k) = max(r.EVM_percent);
    summary.WorstSNDR_dB(k) = min(r.SNDR_dB);
    summary.WorstPA_ACLR_dBc(k) = max(r.PA_ACLR_dBc);
    summary.WorstFilteredACLR_dBc(k) = max(r.Filtered_ACLR_dBc);
    % Derive the SKU gate directly from the published acceptance contract.
    % This avoids a stale/format-dependent per-row flag from becoming the
    % authority for an otherwise bit-true matrix summary.
    summary.AllPass256QAM(k) = all(r.EVM_percent <= 3.5 & ...
        r.SNDR_dB >= 29.12 & r.RawWordMismatches == 0);
    summary.RawWordMismatches(k) = sum(r.RawWordMismatches);
    summary.AlgorithmEvidence(k) = "3 isolated synthetic-mild held-out seeds, fair-RMS";
    summary.DPDInterpretation(k) = "identity: tap0=1, delayed coefficients=0";
end
end

function Summary = run_tid32_thermo3_profile_bandwidth_sweep(varargin)
%RUN_TID32_THERMO3_PROFILE_BANDWIDTH_SWEEP Reproducible digital/PA sweep.
% Runs the full ingress->interpolation->memory-DPD->thermo3->DPA/BPF/DDC
% behavioural chain.  The three profiles are intentionally synthetic design
% corners, not a fit or claim for a physical PA.  Every row uses isolated
% fit/validation/test seeds and the same QAM receiver metric as the baseline.

cfg = local_default_cfg();
for k = 1:2:numel(varargin), cfg.(varargin{k}) = varargin{k+1}; end

profiles = local_profiles();
profiles = profiles(ismember(string({profiles.Name}), string(cfg.profile_names)));
assert(~isempty(profiles), 'No selected PA simulation profile.');

rows = table();
for p = 1:numel(profiles)
    for b = reshape(cfg.bandwidths_hz, 1, [])
        for s = 1:size(cfg.seed_sets,1)
            seed = cfg.seed_sets(s,:);
            args = local_profile_args(profiles(p));
            actual_bw = local_actual_bandwidth(b);
            % A fixed high-Q 3.5-GHz BPF cannot pass a wide occupied signal.
            % In wideband mode constrain the analog 3-dB bandwidth to at
            % least bpf_passband_factor*occupied BW; DDC uses the matching
            % baseband low-pass factor.  This is a reproducible receiver
            % design choice, never a substitute for an NTF improvement.
            if isfinite(cfg.bpf_passband_factor)
                effective_q=min(profiles(p).bpf_q, 3.5e9/(cfg.bpf_passband_factor*actual_bw));
                args(end+1:end+2)={'bpf_q',effective_q}; %#ok<AGROW>
            else
                effective_q=profiles(p).bpf_q;
            end
            [result, ~, detail] = run_tid32_thermo3_frontend_pa_dpd( ...
                'bandwidth_hz', b, ...
                'fit_seed', seed(1), 'val_seed', seed(2), 'test_seed', seed(3), ...
                'fit_nsym', cfg.fit_nsym, 'val_nsym', cfg.val_nsym, 'test_nsym', cfg.test_nsym, ...
                'enable_dpd_training', cfg.enable_dpd_training, ...
                'dpd_active_taps', cfg.dpd_active_taps, ...
                'dpd_fit_ridge', cfg.dpd_fit_ridge, ...
                'dpd_limit', cfg.dpd_limit, 'bpf_bw_factor', cfg.bpf_bw_factor, ...
                'rx_bw_factor', cfg.rx_bw_factor, 'thermo_levels', cfg.thermo_levels, ...
                'thermo5_step', cfg.thermo5_step, ...
                'input_normalization', cfg.input_normalization, 'rms_drive', cfg.rms_drive, ...
                'write_outputs', false, ...
                args{:});
            result.Profile = repmat(string(profiles(p).Name),height(result),1);
            result.ProfileKind = repmat(string(profiles(p).Kind),height(result),1);
            result.RequestedBandwidth_Hz = repmat(b,height(result),1);
            result.ActualBandwidth_Hz = repmat(actual_bw,height(result),1);
            % The receiver evaluates a 7-GS/s complex baseband stream after
            % Fs/4 DDC.  Keep this OSR convention aligned with the existing
            % 17.08984375-MHz baseline (OSR = 409.6), not raw serial line rate.
            result.OSR = repmat(7e9/local_actual_bandwidth(b),height(result),1);
            result.EffectiveBPF_Q = repmat(effective_q,height(result),1);
            result.FitSeed = repmat(seed(1),height(result),1);
            result.ValidationSeed = repmat(seed(2),height(result),1);
            result.TestSeed = repmat(seed(3),height(result),1);
            result.DPAProfile = repmat(detail.pa_profile.Value(1),height(result),1);
            rows = [rows; result]; %#ok<AGROW>
        end
    end
end

Summary = rows;
if cfg.write_outputs
    if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end
    writetable(Summary, fullfile(cfg.out_dir,'tid32_thermo3_profile_bandwidth_sweep.csv'));
end
disp(Summary(:,{'Profile','RequestedBandwidth_Hz','ActualBandwidth_Hz','OSR', ...
    'FitSeed','Mode','EVM_percent','SNDR_dB','PA_ACLR_dBc','Filtered_ACLR_dBc', ...
    'Pass256QAM','HeldOutDeploymentAccepted'}));
end

function cfg = local_default_cfg()
cfg.profile_names = ["mild", "nominal", "severe"];
cfg.bandwidths_hz = [17.09e6 20e6 40e6 80e6 100e6 160e6 200e6];
cfg.seed_sets = [101 137 211; 307 349 401; 503 547 601];
cfg.fit_nsym = 12; cfg.val_nsym = 10; cfg.test_nsym = 12;
cfg.enable_dpd_training = false;
cfg.dpd_active_taps = 4;
cfg.dpd_fit_ridge = 0.25;
cfg.dpd_limit = 0.78;
cfg.thermo_levels = 3;
cfg.thermo5_step = 7168;
cfg.input_normalization = "peak";
cfg.rms_drive = 0.11;
cfg.bpf_passband_factor = NaN; % NaN preserves the native profile Q.
cfg.bpf_bw_factor = 1.50;
cfg.rx_bw_factor = 1.50;
cfg.write_outputs = true;
cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','tid32_thermo3_profile_bandwidth_sweep');
end

function p = local_profiles()
% Each corner keeps the same 3.5-GHz Fs/4 architecture and drive.  Only the
% behavioral switching-PA/BPF uncertainty changes, so comparison is fair.
p(1) = struct('Name',"mild",'Kind',"synthetic_low_distortion", ...
    'pa_p_gain',1.004,'pa_m_gain',0.996, ...
    'pa_p_fir',[0.975 0.025 0.000],'pa_m_fir',[0.970 0.030 0.000], ...
    'pa_p_thermal_alpha',0.75,'pa_m_thermal_alpha',0.72, ...
    'pa_p_amam',0.040,'pa_m_amam',0.035, ...
    'pa_p_switch_asym',0.006,'pa_m_switch_asym',-0.005, ...
    'pa_p_ampm_rad',0.025,'pa_m_ampm_rad',-0.020, ...
    'bpf_q',140,'bpf_insertion_loss_db',0.30);
p(2) = struct('Name',"nominal",'Kind',"synthetic_nominal", ...
    'pa_p_gain',1.012,'pa_m_gain',0.988, ...
    'pa_p_fir',[0.950 0.075 -0.025],'pa_m_fir',[0.935 0.090 -0.030], ...
    'pa_p_thermal_alpha',0.90,'pa_m_thermal_alpha',0.88, ...
    'pa_p_amam',0.120,'pa_m_amam',0.100, ...
    'pa_p_switch_asym',0.016,'pa_m_switch_asym',-0.012, ...
    'pa_p_ampm_rad',0.080,'pa_m_ampm_rad',-0.065, ...
    'bpf_q',100,'bpf_insertion_loss_db',0.60);
p(3) = struct('Name',"severe",'Kind',"synthetic_high_distortion", ...
    'pa_p_gain',1.025,'pa_m_gain',0.975, ...
    'pa_p_fir',[0.900 0.130 -0.030],'pa_m_fir',[0.875 0.150 -0.035], ...
    'pa_p_thermal_alpha',0.96,'pa_m_thermal_alpha',0.94, ...
    'pa_p_amam',0.220,'pa_m_amam',0.190, ...
    'pa_p_switch_asym',0.040,'pa_m_switch_asym',-0.032, ...
    'pa_p_ampm_rad',0.180,'pa_m_ampm_rad',-0.145, ...
    'bpf_q',60,'bpf_insertion_loss_db',1.20);
end

function args = local_profile_args(p)
fields = fieldnames(p); args = {'pa_profile', "behavioral_switching_dpa_" + p.Name};
for k = 1:numel(fields)
    if fields{k} ~= "Name" && fields{k} ~= "Kind"
        args(end+1:end+2) = {fields{k}, p.(fields{k})}; %#ok<AGROW>
    end
end
end

function bw = local_actual_bandwidth(requested)
nfft=4096; fs=1.75e9; nused=2*floor(requested/(2*(fs/nfft))); bw=nused*(fs/nfft);
end

function Summary = run_tid32_thermo_algorithm_ppa_screen(varargin)
%RUN_TID32_THERMO_ALGORITHM_PPA_SCREEN Reproducible thermo quality/PPA screen.
%
% This screen holds the digital sample rate (14 GS/s raw, 218.75-MHz
% 64-sample output word) and OFDM receiver contract fixed.  It records the
% three-seed EVM/SNDR result for the two supported thermometric architectures
% and joins each result to the signed-off routed FPGA resource/timing point.
%
% It intentionally does not invent PPA for interpolation-tap or DPD-tap
% alternatives.  Those dimensions require a parameterized RTL configuration
% and a separate routed implementation before they can appear in this table.

cfg.bandwidths_hz = [100e6 250e6];
cfg.seeds = [101 307 503];
cfg.nsym = 8;
cfg.input_normalization = "fair_rms";
cfg.rms_drive = 0.11;
cfg.receiver_mode = "fs4_ddc";
cfg.thermo3_offsets = [4096 8192 12288];
cfg.thermo5_steps = [4096 6144 7168 8192];
cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'out', ...
    'tid32_thermo_algorithm_ppa_screen');
for k = 1:2:numel(varargin), cfg.(varargin{k}) = varargin{k+1}; end
if ~exist(cfg.out_dir, 'dir'), mkdir(cfg.out_dir); end

% Source: docs/THERMO3_THERMO5_ROUTED_PPA.md.  These are not extrapolated.
ppa = struct( ...
    'thermo3', struct('WNS_ns', 0.290, 'WHS_ns', 0.027, 'CLB_LUT', 59921, ...
                      'CLB_FF', 83797, 'BRAM', 6.5, 'DSP', 2030), ...
    'thermo5', struct('WNS_ns', 0.308, 'WHS_ns', 0.027, 'CLB_LUT', 71869, ...
                      'CLB_FF', 97249, 'BRAM', 6.5, 'DSP', 2032));

rows = table();
for bw = reshape(cfg.bandwidths_hz, 1, [])
    for offset = reshape(cfg.thermo3_offsets, 1, [])
        rows = [rows; local_run("thermo3", bw, offset, cfg, ppa.thermo3)]; %#ok<AGROW>
    end
    for step = reshape(cfg.thermo5_steps, 1, [])
        rows = [rows; local_run("thermo5", bw, step, cfg, ppa.thermo5)]; %#ok<AGROW>
    end
end
Summary = rows;
writetable(Summary, fullfile(cfg.out_dir, 'tid32_thermo_algorithm_ppa_screen.csv'));
end

function rows = local_run(architecture, requested_bw, code_step, cfg, ppa)
rows = table();
for seed = reshape(cfg.seeds, 1, [])
    if architecture == "thermo3"
        r = run_256qam_tid32_ofdm_demod('implementation', "tid32_thermo3", ...
            'bandwidth_hz', requested_bw, 'thermo_offset', code_step, ...
            'seed', seed, 'nsym', cfg.nsym, ...
            'input_normalization', cfg.input_normalization, 'rms_drive', cfg.rms_drive, ...
            'receiver_mode', cfg.receiver_mode);
    else
        r = run_256qam_tid32_ofdm_demod('implementation', "tid32_thermo5", ...
            'bandwidth_hz', requested_bw, 'thermo5_step', code_step, ...
            'seed', seed, 'nsym', cfg.nsym, ...
            'input_normalization', cfg.input_normalization, 'rms_drive', cfg.rms_drive, ...
            'receiver_mode', cfg.receiver_mode);
    end
    r.Architecture = string(architecture);
    r.CodeOffsetOrStep = code_step;
    r.Seed = seed;
    r.RoutedPPAConfig = "default_only";
    r.CoreMHz = 218.75;
    r.WNS_ns = ppa.WNS_ns; r.WHS_ns = ppa.WHS_ns;
    r.CLB_LUT = ppa.CLB_LUT; r.CLB_FF = ppa.CLB_FF;
    r.BRAM = ppa.BRAM; r.DSP = ppa.DSP;
    rows = [rows; r]; %#ok<AGROW>
end
end

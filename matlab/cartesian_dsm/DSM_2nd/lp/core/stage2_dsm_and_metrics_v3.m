%% ============================================================
% stage2_dsm_and_metrics_v3.m
%
% Reads COE I/Q (int16 Q1.15), runs Cartesian 1st-order 1-bit LPDSM,
% then computes "paper-grade" metrics:
%   1) ACPR/ACLR (L/R) by PSD integration
%   2) In-band SNDR (reconstruct+decimate+align+LS gain)
%   3) EVM (%) (same chain as SNDR)
%   4) Overload monitor (integrator state peak/RMS)
%   5) Noise-shaping slope estimation (OOB region fit)
%   6) Crest factor after reconstruction
%
% v2 Fixes:
%   [FIX] Pin/Ptot  ACPR/ACLRNDRVM
%   [FIX] LPF++
%% ============================================================

function metrics = stage2_dsm_and_metrics_v3(metaFile, order, enable_dc_removal)
% metrics = stage2_dsm_and_metrics_v3(metaFile, order, enable_dc_removal)
% metaFile: meta/*.mat 
% order: 1 or 2
% enable_dc_removal: true/false, default false

if nargin<2, order = 1; end
if nargin<3, enable_dc_removal = false; end

%% -----------------------------
% 1) Known system params ( stage1_meta*.mat 
%% -----------------------------
S = load(metaFile);
meta = S.meta;

OSR   = meta.OSR;
Fs_bb = meta.Fs_bb;
Fs_dsm= meta.Fs_dsm;
Delta_f = meta.Delta_f;
active_bins = meta.active_bins;

% v2 
bw_margin_sc = 1;
BWch = (max(abs(active_bins)) + bw_margin_sc) * Delta_f * 2;
adjOffset = BWch;

root_dir = fileparts(mfilename('fullpath'));
out_res  = fullfile(root_dir,'results');
if ~exist(out_res,'dir'), mkdir(out_res); end

[~,metaName,~] = fileparts(metaFile);
tag = erase(metaName,'stage1_meta_'); %  "M16_..._OSR16_..."
coeI = fullfile(root_dir,'coe',['I_' tag '.coe']);
coeQ = fullfile(root_dir,'coe',['Q_' tag '.coe']);
assert(exist(coeI,'file')==2, 'Cannot find %s', coeI);
assert(exist(coeQ,'file')==2, 'Cannot find %s', coeQ);

%% -----------------------------
% 2) Read COE -> float
%% -----------------------------
I_rom = read_coe_int16_hex(coeI);
Q_rom = read_coe_int16_hex(coeQ);

scale = double(2^15 - 1);
I_in = double(I_rom) / scale;
Q_in = double(Q_rom) / scale;

% ===== optional DC removal =====
if enable_dc_removal
    I_in = I_in - mean(I_in);
    Q_in = Q_in - mean(Q_in);
end

fprintf('Loaded COE: N=%d samples\n', numel(I_in));
fprintf('I_in range: [%.4f, %.4f]\n', min(I_in), max(I_in));
fprintf('Q_in range: [%.4f, %.4f]\n', min(Q_in), max(Q_in));
if enable_dc_removal
    fprintf('DC after removal: mean(I)=%.3e, mean(Q)=%.3e\n', ...
            mean(I_in), mean(Q_in));
else
    fprintf('DC (no removal): mean(I)=%.3e, mean(Q)=%.3e\n', ...
            mean(I_in), mean(Q_in));
end


%  >1 
clip = 0.999;
I_in = max(min(I_in, +clip), -clip);
Q_in = max(min(Q_in, +clip), -clip);

x_ref = I_in + 1j*Q_in;     % DSM input @ Fs_dsm
 


%% -----------------------------
% 3) Run DSM (Cartesian 1st-order 1-bit) with monitor
%% -----------------------------
if order==1
    [yI, vI] = dsm1_lp_1bit_monitor(I_in);
    [yQ, vQ] = dsm1_lp_1bit_monitor(Q_in);
    ov_note = 'order1: v=integrator';
elseif order==2
    leak = 0; v_limit = inf;  %  leak=1e-4 v_limit=5
    [yI, v2I, ~] = dsm2_lp_1bit_monitor(I_in, leak, v_limit);
    [yQ, v2Q, ~] = dsm2_lp_1bit_monitor(Q_in, leak, v_limit);
    vI = v2I; vQ = v2Q;        % overload v2
    ov_note = sprintf('order2: leak=%g vlim=%g', leak, v_limit);
else
    error('order must be 1 or 2');
end


fprintf('yI unique: '); disp(unique(yI).');
fprintf('yQ unique: '); disp(unique(yQ).');

y_bb = yI + 1j*yQ;           % DSM output @ Fs_dsm (analysis baseband)

%% -----------------------------
% 3.5) Digital upconversion (TI-style, Fs = 4*fc)
%% -----------------------------
rfCfg = struct();
rfCfg.enable = true;

% TI trick: choose fc = Fs_dsm/4.
% This simplifies LO to sequences [1 0 -1 0] and [0 1 0 -1].
rfCfg.fc = Fs_dsm/4;   % Normalized carrier freq = 0.25
rfCfg.mode = 'TI_4fc'; 

if rfCfg.enable
    N = numel(yI);
    n = (0:N-1).';

    % Generate LO sequences (equivalent to cos/sin at fc=Fs/4)
    % mod(n,4) produces 0,1,2,3 repeating
    loI_4 = [ 1; 0; -1; 0];
    loQ_4 = [ 0; 1;  0; -1];
    
    loI = loI_4(mod(n,4)+1);
    loQ = loQ_4(mod(n,4)+1);

    % TI-style Mixing: Time-Interleaving + Sign Change
    % IMPORTANT OBSERVATION:
    % Since loI and loQ are orthogonal (never non-zero at the same time),
    % and yI/yQ are binary (+/-1), the resulting s_rf is ALSO binary {-1, 1}.
    % This is ideal for driving 1-bit PAs directly without H-Bridge!
    s_rf = yI(:).*loI + yQ(:).*loQ;   % Real passband sequence @ Fs_dsm

    metrics.fc = rfCfg.fc;
    metrics.rf_mode = rfCfg.mode;
    metrics.rf_levels = unique(s_rf).';
end
fprintf('RF levels (should be -1/1): '); disp(metrics.rf_levels);




% Overload monitor (paperRMS/)
ov = struct();
ov.vI_peak = max(abs(vI)); ov.vQ_peak = max(abs(vQ));
ov.vI_rms  = rms(vI);       ov.vQ_rms  = rms(vQ);
fprintf('Overload monitor: vI_peak=%.2f, vQ_peak=%.2f, vI_rms=%.2f, vQ_rms=%.2f\n', ...
    ov.vI_peak, ov.vQ_peak, ov.vI_rms, ov.vQ_rms);

%% ===================== Stage2: Save intermediate signals =====================

% Create signals output directory
out_signals = fullfile(root_dir,'signals');
if ~exist(out_signals,'dir'), mkdir(out_signals); end

% Initialize structures for saving (will be filled after processing)
dsm_signals = struct();
dsm_signals.I_in = I_in;
dsm_signals.Q_in = Q_in;
dsm_signals.yI = yI;
dsm_signals.yQ = yQ;
dsm_signals.y_bb = y_bb;
dsm_signals.vI = vI;
dsm_signals.vQ = vQ;
dsm_signals.order = order;
dsm_signals.OSR = OSR;
dsm_signals.Fs_dsm = Fs_dsm;

% Save RF upconverted signal if exists
if exist('s_rf','var')
    dsm_signals.s_rf = s_rf;
end

yI_01 = uint8((yI+1)/2);
yQ_01 = uint8((yQ+1)/2);
writematrix(yI_01, fullfile(out_res, sprintf('yI_1bit_01_%s_order%d.csv', tag, order)));
writematrix(yQ_01, fullfile(out_res, sprintf('yQ_1bit_01_%s_order%d.csv', tag, order)));

%% -----------------------------
% 5) Metrics: ACPR/ACLR via PSD integration (Welch)  [FIX: auto cfg]
%% -----------------------------
Nsig = numel(y_bb);

psdCfg = struct();
% <= 2^kFFT
psdCfg.winLen  = 2^floor(log2(min(4096, Nsig)));     % <= Nsig
psdCfg.winLen  = max(psdCfg.winLen, 256);            % 56
psdCfg.winLen  = min(psdCfg.winLen, Nsig);           % 

psdCfg.overlap = floor(psdCfg.winLen/2);             % 50% overlap
psdCfg.nfft    = max(8192, 4*psdCfg.winLen);         % 
psdCfg.window  = hamming(psdCfg.winLen);

fprintf('Welch cfg: N=%d, winLen=%d, overlap=%d, nfft=%d\n', ...
    Nsig, psdCfg.winLen, psdCfg.overlap, psdCfg.nfft);

% ===== 5.1)  ACPR/ACLR psdOutslope ====
[metrics_acpr, psdOut] = calc_acpr_aclr_from_psd(y_bb, Fs_dsm, BWch, adjOffset, psdCfg);

fprintf('ACPR/ACLR (L/R) = [%.2f, %.2f] dBc\n', ...
    metrics_acpr.ACPR_L_dBc, metrics_acpr.ACPR_R_dBc);

% Populate metrics struct (do NOT reset - preserve RF fields from 3.5)
if ~isfield(metrics, 'tag')
    metrics = struct();
    metrics.tag = tag;
    metrics.order = order;
    metrics.OSR = OSR;
    metrics.Fs_dsm = Fs_dsm;
    metrics.BWch = BWch;
end

metrics.ACPR_L_dBc = metrics_acpr.ACPR_L_dBc;
metrics.ACPR_R_dBc = metrics_acpr.ACPR_R_dBc;

%% -----------------------------
% 5.2) RF PSD + RF->BB ACPR (recommended)
%% -----------------------------
if exist('s_rf','var')

    % ---- (A)  fc RF ACPR----
    [mrf_raw, psdRF_raw] = calc_acpr_around_fc_from_psd(s_rf, Fs_dsm, rfCfg.fc, BWch, adjOffset, psdCfg);
    metrics.RF_ACPR_raw_L_dBc = mrf_raw.ACPR_L_dBc;
    metrics.RF_ACPR_raw_R_dBc = mrf_raw.ACPR_R_dBc;

    % ---- (B)  RF BPF----
    bw_pass = BWch * 1.10;   %  1.02 1.05~1.15
    bw_stop = BWch * 1.30;   %  1.10 1.2~1.5

    Fp1 = rfCfg.fc - bw_pass/2;
    Fp2 = rfCfg.fc + bw_pass/2;
    Fs1 = rfCfg.fc - bw_stop/2;
    Fs2 = rfCfg.fc + bw_stop/2;

    d_rf = designfilt('bandpassfir', ...
        'StopbandFrequency1', Fs1, ...
        'PassbandFrequency1', Fp1, ...
        'PassbandFrequency2', Fp2, ...
        'StopbandFrequency2', Fs2, ...
        'StopbandAttenuation1', 80, ...
        'StopbandAttenuation2', 80, ...
        'PassbandRipple', 0.1, ...
        'SampleRate', Fs_dsm);

    s_rf_bpf = filter(d_rf, s_rf);

    % ---- (C)  fc RF ACPR----
    [mrf_bpf, psdRF_bpf] = calc_acpr_around_fc_from_psd(s_rf_bpf, Fs_dsm, rfCfg.fc, BWch, adjOffset, psdCfg);
    metrics.RF_ACPR_bpf_L_dBc = mrf_bpf.ACPR_L_dBc;
    metrics.RF_ACPR_bpf_R_dBc = mrf_bpf.ACPR_R_dBc;    
    % Update dsm_signals with s_rf_bpf (now that it's generated)
    dsm_signals.s_rf_bpf = s_rf_bpf;
    fprintf('RF ACPR (around +fc) RAW (L/R) = [%.2f, %.2f] dBc\n', metrics.RF_ACPR_raw_L_dBc, metrics.RF_ACPR_raw_R_dBc);
    fprintf('RF ACPR (around +fc) BPF (L/R) = [%.2f, %.2f] dBc\n', metrics.RF_ACPR_bpf_L_dBc, metrics.RF_ACPR_bpf_R_dBc);

    % ---- (D) F  complex baseband  ACPR----
    [m_rfbb_raw, ~] = rf_acpr_via_downconvert(s_rf, Fs_dsm, rfCfg.fc, BWch, adjOffset, psdCfg);
    metrics.RFBB_ACPR_raw_L_dBc = m_rfbb_raw.ACPR_L_dBc;
    metrics.RFBB_ACPR_raw_R_dBc = m_rfbb_raw.ACPR_R_dBc;

    [m_rfbb_bpf, ~] = rf_acpr_via_downconvert(s_rf_bpf, Fs_dsm, rfCfg.fc, BWch, adjOffset, psdCfg);
    metrics.RFBB_ACPR_bpf_L_dBc = m_rfbb_bpf.ACPR_L_dBc;
    metrics.RFBB_ACPR_bpf_R_dBc = m_rfbb_bpf.ACPR_R_dBc;

    fprintf('RF->BB ACPR RAW (L/R) = [%.2f, %.2f] dBc  (recommended)\n', ...
        metrics.RFBB_ACPR_raw_L_dBc, metrics.RFBB_ACPR_raw_R_dBc);
    fprintf('RF->BB ACPR BPF (L/R) = [%.2f, %.2f] dBc  (recommended)\n', ...
        metrics.RFBB_ACPR_bpf_L_dBc, metrics.RFBB_ACPR_bpf_R_dBc);

    % ---- (E) Plot RF PSD---
    figure('Name','RF PSD (Raw vs BPF-filtered)');
    plot(psdRF_raw.f/1e6, 10*log10(psdRF_raw.Pxx+eps), 'DisplayName', 'Raw switching s_{RF}');
    hold on;
    plot(psdRF_bpf.f/1e6, 10*log10(psdRF_bpf.Pxx+eps), 'LineWidth', 1.2, 'DisplayName', 'After RF BPF');
    grid on; xlabel('Frequency (MHz)'); ylabel('PSD (dB/Hz)');
    title(sprintf('RF PSD (centered) @ fc=%.2f MHz', rfCfg.fc/1e6));
    legend('show');
end



metrics.ov = ov;
metrics.ov_note = ov_note;

% PSD 
figure('Name','DSM Output PSD (complex)');
plot(psdOut.f/1e6, 10*log10(psdOut.Pxx+eps), 'LineWidth', 1);
grid on; xlabel('Frequency (MHz)'); ylabel('PSD (dB/Hz)');
title('PSD of y_{DSM}(n) (complex baseband, centered)');

%% -----------------------------
% 6) Reconstruct + decimate to Fs_bb, then SNDR/EVM (paper-grade)
%% -----------------------------
recCfg = struct();
recCfg.OSR = OSR;
recCfg.Fs_dsm = Fs_dsm;
recCfg.Fs_bb  = Fs_bb;
recCfg.BWch   = BWch;

% + 
[x_rec, x_ref_bb] = reconstruct_and_decimate(y_bb, x_ref, recCfg);

%  + LS
[al] = align_and_ls_gain(x_rec, x_ref_bb);

% SNDR & EVM
metrics_q = calc_sndr_evm(al.y_aligned, al.x_aligned);

fprintf('In-band SNDR = %.2f dB\n', metrics_q.SNDR_dB);
fprintf('EVM_rms = %.2f %%\n', metrics_q.EVM_rms_percent);

% Crest factor after reconstruction
crest = 20*log10(max(abs(al.y_aligned))/rms(abs(al.y_aligned)));
fprintf('Crest factor (reconstructed) = %.2f dB\n', crest);

% Save reconstructed signal to dsm_signals struct (defined earlier)
dsm_signals.x_rec = al.y_aligned;
dsm_signals.x_ref_bb = al.x_aligned;
save(fullfile(out_signals, sprintf('stage2_signals_%s_order%d.mat', tag, order)), 'dsm_signals');
fprintf('Stage2 intermediate signals saved: stage2_signals_%s_order%d.mat\n', tag, order);

%% -----------------------------
% 7) Noise shaping slope estimate (OOB region fit)
%% -----------------------------
slopeCfg = struct();
slopeCfg.BWch = BWch;
slopeCfg.fmin = 1.3*(BWch/2);         % 
slopeCfg.fmax = 0.45*(Fs_dsm/2);      %  Nyquist
if exist('psdOut','var') && isstruct(psdOut) && isfield(psdOut,'f') && isfield(psdOut,'Pxx')
    metrics_slope = estimate_noise_slope(psdOut.f, psdOut.Pxx, slopeCfg);
    fprintf('Estimated OOB noise slope ~ %.1f dB/dec (rough)\n', metrics_slope.slope_dB_per_dec);
else
    warning('psdOut not found; skip slope estimation.');
    metrics_slope = struct('slope_dB_per_dec', NaN);
end


metrics.SNDR_dB = metrics_q.SNDR_dB;
metrics.EVM_rms_percent = metrics_q.EVM_rms_percent;
metrics.crest_dB = crest;
metrics.slope_dB_per_dec = metrics_slope.slope_dB_per_dec;
save(fullfile(out_res, sprintf('metrics_%s_order%d.mat', tag, order)), 'metrics');
%% -----------------------------
% 8) Plots (time snippets)
%% -----------------------------
Ns = min(2000, numel(yI));
figure('Name','DSM time snippets');
subplot(2,1,1); plot(yI(1:Ns)); grid on; title('yI (1-bit)'); ylim([-1.2 1.2]);
subplot(2,1,2); plot(yQ(1:Ns)); grid on; title('yQ (1-bit)'); ylim([-1.2 1.2]);

figure('Name','Reconstructed vs Ref (baseband, decimated)');
Nshow = min(2000, numel(al.x_aligned));
plot(real(al.x_aligned(1:Nshow)), 'LineWidth', 1); hold on;
plot(real(al.y_aligned(1:Nshow)), 'LineWidth', 1);
grid on; legend('Ref (decimated)','Reconstructed'); title('I-part after alignment');

fprintf('Stage-2 done. Outputs saved: dsm_out_dualpath_v2.mat, yI/yQ csv\n');

end % ===== end main function =====

%% ===================== Helper functions =====================

function [y, v_hist] = dsm1_lp_1bit_monitor(x)
% 1st-order 1-bit lowpass DSM with integrator monitor
    x = x(:);
    N = numel(x);
    y = zeros(N,1);
    v_hist = zeros(N,1);

    v = 0;
    for n = 1:N
        y(n) = 1; if v < 0, y(n) = -1; end
        v = v + x(n) - y(n);
        v_hist(n) = v;
    end
end

function x = read_coe_int16_hex(filename)
    x = lp_read_coe_int16_hex(filename);
end

function [m, out] = calc_acpr_aclr_from_psd(y, Fs, BWch, adjOffset, cfg)
    y = y(:);

    % --- Welch PSD (centered) ---
    [Pxx,f] = pwelch(y, cfg.window, cfg.overlap, cfg.nfft, Fs, 'centered');
    df = mean(diff(f));

    % --- integrate power in bands ---
    Pch  = band_power(Pxx,f, -BWch/2, +BWch/2, df);
    PadL = band_power(Pxx,f, -adjOffset-BWch/2, -adjOffset+BWch/2, df);
    PadR = band_power(Pxx,f, +adjOffset-BWch/2, +adjOffset+BWch/2, df);

    m = struct();
    m.Pch = Pch; m.PadjL = PadL; m.PadjR = PadR;
    m.ACPR_L_dBc = 10*log10((PadL+eps)/(Pch+eps));
    m.ACPR_R_dBc = 10*log10((PadR+eps)/(Pch+eps));


    % --- IMPORTANT: fixed field names ---
    out = struct();
    out.Pxx = Pxx;
    out.f   = f;
end

function [m, out] = calc_acpr_around_fc_from_psd(s_rf, Fs, fc, BWch, adjOffset, cfg)
    s_rf = s_rf(:);

    % Welch PSD (centered)
    [Pxx,f] = pwelch(s_rf, cfg.window, cfg.overlap, cfg.nfft, Fs, 'centered');
    df = mean(diff(f));

    % main channel centered at +fc
    Pch  = band_power(Pxx, f, fc-BWch/2,          fc+BWch/2,          df);
    PadL = band_power(Pxx, f, fc-adjOffset-BWch/2, fc-adjOffset+BWch/2, df);
    PadR = band_power(Pxx, f, fc+adjOffset-BWch/2, fc+adjOffset+BWch/2, df);

    m = struct();
    m.Pch = Pch; m.PadjL = PadL; m.PadjR = PadR;
    m.ACPR_L_dBc = 10*log10((PadL+eps)/(Pch+eps));
    m.ACPR_R_dBc = 10*log10((PadR+eps)/(Pch+eps));

    out = struct();
    out.Pxx = Pxx;
    out.f   = f;
end


function P = band_power(Pxx,f,f1,f2,df)
    idx = (f >= f1) & (f <= f2);
    P = sum(Pxx(idx)) * df;  % integrate PSD
end

function [y_bb, x_bb] = reconstruct_and_decimate(y_dsm, x_ref, cfg)
    [y_bb, x_bb] = lp_reconstruct_and_decimate(y_dsm, x_ref, cfg);
end


function al = align_and_ls_gain(y, x)
% Align by cross-correlation + LS complex gain
    y = y(:); x = x(:);
    L = min(numel(x), numel(y));
    x = x(1:L); y = y(1:L);

    % coarse alignment (limited lag)
    maxLag = min(2000, floor(L/4));
    [c,lags] = xcorr(y, x, maxLag, 'coeff');
    [~,im] = max(abs(c));
    lag = lags(im);

    if lag > 0
        y2 = y(1+lag:end);
        x2 = x(1:end-lag);
    elseif lag < 0
        y2 = y(1:end+lag);
        x2 = x(1-lag:end);
    else
        y2 = y; x2 = x;
    end

    L2 = min(numel(x2), numel(y2));
    x2 = x2(1:L2); y2 = y2(1:L2);

    % LS complex gain: minimize ||g*y - x||
    g = (y2' * x2) / (y2' * y2 + eps);
    y3 = g * y2;

    al = struct();
    al.lag = lag;
    al.gain = g;
    al.x_aligned = x2;
    al.y_aligned = y3;
end

function m = calc_sndr_evm(y_hat, x_ref)
% SNDR based on error power after alignment & gain
    m = lp_calc_sndr_evm(y_hat, x_ref);
end


function m = estimate_noise_slope(f, Pxx, cfg)
% Slope fit in OOB region: fit PSD(dB) vs log10(f)
    f = f(:); Pxx = Pxx(:);
    idx = (abs(f) >= cfg.fmin) & (abs(f) <= cfg.fmax);
    ff = abs(f(idx));
    pp = 10*log10(Pxx(idx)+eps);

    valid = ff > 0;
    ff = ff(valid); pp = pp(valid);

    x = log10(ff);
    p = polyfit(x, pp, 1);
    m = struct();
    m.slope_dB_per_dec = p(1);
end

function [y, v2_hist, v1_hist] = dsm2_lp_1bit_monitor(x, leak, v_limit)
% 2nd-order 1-bit LP DSM (two integrators) with monitor
% leak: 0~1e-4 (optional), v_limit: inf or small (e.g., 5)

if nargin<2, leak = 0; end
if nargin<3, v_limit = inf; end

x = x(:);
N = numel(x);
y = zeros(N,1);
v1_hist = zeros(N,1);
v2_hist = zeros(N,1);

v1 = 0; v2 = 0;
for n=1:N
    % quantizer on v2
    y(n) = 1; if v2 < 0, y(n) = -1; end

    % loop updates
    v1 = (1-leak)*v1 + x(n) - y(n);
    v2 = (1-leak)*v2 + v1   - y(n);

    % optional limiter (stability guard)
    if isfinite(v_limit)
        v1 = max(min(v1, v_limit), -v_limit);
        v2 = max(min(v2, v_limit), -v_limit);
    end

    v1_hist(n)=v1;
    v2_hist(n)=v2;
end
end

function [m_rfbb, psd_rfbb] = rf_acpr_via_downconvert(s_rf, Fs, fc, BWch, adjOffset, psdCfg)
    s_rf = s_rf(:);
    N = numel(s_rf);
    n = (0:N-1).';

    % Downconvert to complex BB
    z = s_rf .* exp(-1j*2*pi*fc/Fs*n);

    % ACPR
    [m_rfbb, psd_rfbb] = calc_acpr_aclr_from_psd(z, Fs, BWch, adjOffset, psdCfg);
end



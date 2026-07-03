%% ============================================================
% stage1_ofdm_qam_to_coe_lp_dsm_input_v3.m
% Stage-1: bits -> (NR-like) OFDM-QAM baseband IQ
%        -> interpolation (OSR) -> fixed-point (Q1.15)
%        -> export Vivado .coe for I/Q ROM (dual-path LPDSM input)
%
% v2 Fixes:
%   [FIX] (CP+) HannCPEVM/
%   [FIX] ROM_DEPTH  spurCPR/ACLR
%   [ADD]  mat  Stage-2 
%% ============================================================

function [fnameI, fnameQ, metaFile] = stage1_ofdm_qam_to_coe_lp_dsm_input_v3(OSR, ROM_DEPTH, enable_edge_taper)
%  run_sweep Stage1
% 
% [fi,fq,meta] = stage1_ofdm_qam_to_coe_lp_dsm_input_v3(32,65536,false);

if nargin<1, OSR = 16; end
if nargin<2, ROM_DEPTH = 65536; end
if nargin<3, enable_edge_taper = false; end


clc; close all;
rng(1);

%% -----------------------------
% 1. Communication / System Parameters
% -----------------------------
M = 16;                  % 16-QAM
k = log2(M);
Nfft = 64;
Ncp  = 16;
Nsym = 500;

% Keep the MATLAB nominal DSM rate aligned to the 100 MHz RTL/IP clock.
% With Nfft=64 and OSR=32 this implies Delta_f = 48.828125 kHz.
Fs_dsm_target = 100e6;
Delta_f = Fs_dsm_target / (Nfft * OSR);
Fs_bb   = Nfft * Delta_f;

%OSR   = 16;
Fs_dsm = Fs_bb * OSR;

active_bins = [-26:-1, 1:26]; %  DC NULL
used_sc = zeros(1, numel(active_bins));
for ii = 1:numel(active_bins)
    b = active_bins(ii);
    if b == 0
        used_sc(ii) = 1;            % bin0 -> index1
    elseif b > 0
        used_sc(ii) = b + 1;        % +m -> m+1
    else
        used_sc(ii) = Nfft + b + 1; % -m -> Nfft-m+1
    end
end
Nused = numel(used_sc);

W = 16;
scale = 2^(W-1)-1;

fprintf('Generate %d-QAM OFDM IQ (NR-like), Nfft=%d, Ncp=%d, Nsym=%d\n', M, Nfft, Ncp, Nsym);
fprintf('Fs_bb = %.3f MHz, OSR=%d => Fs_dsm = %.3f MHz\n', Fs_bb/1e6, OSR, Fs_dsm/1e6);
fprintf('Active subcarriers: %d\n', Nused);

%% -----------------------------
% 2. Bits -> QAM
% -----------------------------
Nb = Nsym * Nused * k;
bits = randi([0 1], Nb, 1);

qam_data = qammod_local(bits, M);
qam_data = reshape(qam_data, Nused, Nsym);

figure('Name','16-QAM Constellation');
plot(qam_data(:), '.'); grid on; axis square;
title('16-QAM Constellation'); xlabel('I'); ylabel('Q');

%% -----------------------------
% 3. OFDM (freq->time), DC null + guards
% -----------------------------
Xk = zeros(Nfft, Nsym);
Xk(used_sc, :) = qam_data;

ofdm_td = ifft(Xk, Nfft, 1);
ofdm_cp = [ofdm_td(end-Ncp+1:end, :); ofdm_td]; % (Nfft+Ncp) x Nsym

% ===== v2: optional edge taper (WOLA-like =====
if enable_edge_taper
    L = Nfft+Ncp;
    Nt = min(8, floor(L/8)); % taper
    w = ones(L,1);
    r = (0:Nt-1)'/Nt;
    taper = 0.5*(1-cos(pi*r));      % half-cosine ramp
    w(1:Nt) = taper;
    w(end-Nt+1:end) = flipud(taper);
    ofdm_cp = ofdm_cp .* w;
end

x_bb = ofdm_cp(:);
fprintf('Baseband IQ length = %d samples\n', length(x_bb));

% Normalize RMS (baseband stage)
x_bb = x_bb / rms(x_bb);

papr_bb = 10*log10(max(abs(x_bb).^2) / mean(abs(x_bb).^2));
fprintf('Baseband PAPR = %.2f dB (RMS-normalized)\n', papr_bb);

%% -----------------------------
% 4. Interpolation to Fs_dsm
% -----------------------------
use_resample = (exist('resample', 'file') == 2);
if use_resample
    try
        x_os = resample(x_bb, OSR, 1);
    catch
        use_resample = false;
    end
end
if ~use_resample
    x_up = upsample(x_bb, OSR);
    Nfir = 256;
    fc = 0.45/OSR;
    h = fir1(Nfir, fc);
    x_os = filter(h, 1, x_up);
    gd = floor(Nfir/2);
    x_os = x_os(gd+1:end);
end

fprintf('Interpolated IQ length = %d samples\n', length(x_os));
x_os = x_os / rms(x_os);

clip_val = 0.999;
headroom = 0.95;  % 5% 0.90~0.98
max_iq = max(abs([real(x_os); imag(x_os)]));
A_auto = headroom * clip_val / max_iq;

A = min(A_auto, 0.35);   % 0.35 A
x_os = A * x_os;

max_iq_scaled = max(abs([real(x_os); imag(x_os)]));
fprintf('Auto A = %.4f (max|I,Q| after scaling = %.4f)\n', A, max_iq_scaled);

papr_os = 10*log10(max(abs(x_os).^2) / mean(abs(x_os).^2));
fprintf('Interpolated PAPR = %.2f dB\n', papr_os);

%% -----------------------------
% 5. Fixed-point quantization (Q1.15)
% -----------------------------
I0 = real(x_os); Q0 = imag(x_os);
I = max(min(I0, clip_val), -clip_val);
Q = max(min(Q0, clip_val), -clip_val);

I_q = int16(round(I * scale));
Q_q = int16(round(Q * scale));
fprintf('I_q range: [%d, %d]\n', min(I_q), max(I_q));
fprintf('Q_q range: [%d, %d]\n', min(Q_q), max(Q_q));

%% -----------------------------
% 6. Fit to ROM depth (v2: default truncate only, avoid periodic spur)
% -----------------------------
fit_mode = 'truncate';  % 'truncate' | 'repeat_crossfade'
I_rom = fit_to_depth_v2(I_q, ROM_DEPTH, fit_mode);
Q_rom = fit_to_depth_v2(Q_q, ROM_DEPTH, fit_mode);
fprintf('ROM depth = %d samples (mode=%s)\n', ROM_DEPTH, fit_mode);

%% -----------------------------
% 7. Export COE + save meta
% -----------------------------
root_dir = fileparts(mfilename('fullpath'));
out_coe  = fullfile(root_dir,'coe');
out_meta = fullfile(root_dir,'meta');
if ~exist(out_coe,'dir'), mkdir(out_coe); end
if ~exist(out_meta,'dir'), mkdir(out_meta); end

%% ===================== Stage1: Save intermediate signals =====================

% Save all intermediate signals for analysis
tag = sprintf('M%d_Nfft%d_Ncp%d_Nsym%d_OSR%d_W%d_DEPTH%d', M,Nfft,Ncp,Nsym,OSR,W,ROM_DEPTH);
fnameI = fullfile(out_coe,  ['I_' tag '.coe']);
fnameQ = fullfile(out_coe,  ['Q_' tag '.coe']);
metaFile = fullfile(out_meta, ['stage1_meta_' tag '.mat']);

% Save intermediate signals to a separate file
out_signals = fullfile(root_dir,'signals');
if ~exist(out_signals,'dir'), mkdir(out_signals); end

% 
signals = struct();
signals.bits = bits;
signals.qam_data = qam_data;
signals.ofdm_cp = ofdm_cp;
signals.x_bb = x_bb;
signals.x_os = x_os;
signals.I_q = I_q;
signals.Q_q = Q_q;
signals.I_rom = I_rom;
signals.Q_rom = Q_rom;
signals.OSR = OSR;
signals.Fs_bb = Fs_bb;
signals.Fs_dsm = Fs_dsm;

save(fullfile(out_signals, ['stage1_signals_' tag '.mat']), 'signals');
fprintf('Intermediate signals saved: stage1_signals_%s.mat\n', tag);

write_coe_int16_hex(fnameI, I_rom);
write_coe_int16_hex(fnameQ, Q_rom);

meta = struct();
meta.M=M; meta.Nfft=Nfft; meta.Ncp=Ncp; meta.Nsym=Nsym;
meta.Delta_f=Delta_f; meta.Fs_bb=Fs_bb; meta.OSR=OSR; meta.Fs_dsm=Fs_dsm;
meta.active_bins=active_bins; meta.Nused=Nused; meta.A=A;
meta.W=W; meta.ROM_DEPTH=ROM_DEPTH; meta.fit_mode=fit_mode;
meta.enable_edge_taper=enable_edge_taper;
save(metaFile, 'meta');

fprintf('COE exported:\n  %s\n  %s\n', fnameI, fnameQ);
fprintf('Meta saved: stage1_meta_%s.mat\n', tag);

%% -----------------------------
% 8. Quick plots
% -----------------------------
Ns_view = min(2000, length(x_os));
figure('Name','Interpolated IQ (Time Domain)');
subplot(2,1,1); plot(real(x_os(1:Ns_view))); grid on; title('I[n]'); xlabel('n'); ylabel('amp');
subplot(2,1,2); plot(imag(x_os(1:Ns_view))); grid on; title('Q[n]'); xlabel('n'); ylabel('amp');

Nfft_psd = 4096;
[PSD,f] = pwelch(x_os, hamming(1024), 512, Nfft_psd, Fs_dsm, 'centered');
figure('Name','PSD (Interpolated IQ)');
plot(f/1e6, 10*log10(PSD+eps), 'LineWidth', 1.2);
grid on; xlabel('Frequency (MHz)'); ylabel('PSD (dB/Hz)');
title('Baseband PSD (after interpolation)');

fprintf('Stage-1 done.\n');

%% ===================== Helpers =====================

function s = qammod_local(bits, M)
    k = log2(M);
    if mod(numel(bits), k) ~= 0, error('bits length must be multiple of log2(M)'); end
    L = sqrt(M);
    if abs(L - round(L)) > eps, error('Only square QAM supported'); end
    L = round(L);

    b = reshape(bits(:), k, []).';
    bi = b(:,1:k/2);
    bq = b(:,k/2+1:k);

    map_pair = @(bb) ( ...
        (-3)*(bb(:,1)==0 & bb(:,2)==0) + ...
        (-1)*(bb(:,1)==0 & bb(:,2)==1) + ...
        (+1)*(bb(:,1)==1 & bb(:,2)==1) + ...
        (+3)*(bb(:,1)==1 & bb(:,2)==0) );

    if L==4
        xi = map_pair(bi);
        xq = map_pair(bq);
    else
        error('Only 16-QAM implemented here');
    end

    sc = sqrt((2/3)*(M-1));
    s = (xi + 1i*xq) / sc;
end

function y = fit_to_depth_v2(x, depth, mode)
    x = x(:);
    if numel(x) >= depth
        y = x(1:depth);
        return;
    end

    switch lower(mode)
        case 'truncate'
            %  repeat spur
            y = [x; zeros(depth-numel(x),1,'like',x)];
        case 'repeat_crossfade'
            rep = ceil(depth/numel(x));
            z = repmat(x, rep, 1);
            z = z(1:depth);

            % crossfade
            Lxf = min(64, floor(numel(x)/8));
            if Lxf > 4
                w = linspace(0,1,Lxf).';
                for kk = numel(x):numel(x):depth-Lxf
                    a = z(kk-Lxf+1:kk);
                    b = z(kk+1:kk+Lxf);
                    z(kk-Lxf+1:kk) = int16(round((1-w).*double(a) + w.*double(b)));
                end
            end
            y = z;
        otherwise
            error('Unknown fit mode');
    end
end

function write_coe_int16_hex(filename, x_int16)
    fid = fopen(filename, 'w');
    if fid < 0, error('Cannot open file: %s', filename); end
    fprintf(fid, 'memory_initialization_radix=16;\n');
    fprintf(fid, 'memory_initialization_vector=\n');
    u = typecast(int16(x_int16(:)), 'uint16');
    for i = 1:numel(u)
        if i < numel(u), fprintf(fid, '%04X,\n', u(i));
        else,            fprintf(fid, '%04X;\n', u(i));
        end
    end
    fclose(fid);
end
end % end of stage1_ofdm_qam_to_coe_lp_dsm_input_v3.m

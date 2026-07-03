function [y_bb, x_bb] = lp_reconstruct_and_decimate(y_dsm, x_ref, cfg)
% lp_reconstruct_and_decimate Low-pass reconstruct and OSR decimate
OSR = cfg.OSR;
Fnyq_bb = cfg.Fs_bb/2;
Fpass = min(0.98*(cfg.BWch/2), 0.95*Fnyq_bb);
Fstop = 0.995*Fnyq_bb;
if Fstop <= Fpass
    Fpass = 0.85*Fnyq_bb;
    Fstop = 0.95*Fnyq_bb;
end
if isfield(cfg, 'StopAtt')
    stopAtt = cfg.StopAtt;
else
    stopAtt = 80;
end
if isfield(cfg, 'UseFastFir')
    useFastFir = logical(cfg.UseFastFir);
else
    useFastFir = false;
end
if isfield(cfg, 'ZeroPhase')
    useZeroPhase = logical(cfg.ZeroPhase);
else
    useZeroPhase = false;
end

[b, gd] = local_lowpass_fir(Fpass, Fstop, cfg.Fs_dsm, stopAtt, useFastFir);
if useZeroPhase && exist('filtfilt', 'file') == 2
    yv = double(y_dsm(:));
    xv = double(x_ref(:));
    minLen = 3 * max(numel(b) - 1, 1);
    if numel(yv) > minLen && numel(xv) > minLen
        y_f = filtfilt(b, 1, yv);
        x_f = filtfilt(b, 1, xv);
    else
        y_f = filter(b, 1, yv);
        x_f = filter(b, 1, xv);
        y_f = y_f(gd+1:end);
        x_f = x_f(gd+1:end);
    end
else
    y_f = filter(b, 1, y_dsm);
    x_f = filter(b, 1, x_ref);
    y_f = y_f(gd+1:end);
    x_f = x_f(gd+1:end);
end
y_bb = y_f(1:OSR:end);
x_bb = x_f(1:OSR:end);
end

function [b, gd] = local_lowpass_fir(Fpass, Fstop, Fs, stopAtt, useFastFir)
if nargin < 5
    useFastFir = false;
end

persistent firCache
if isempty(firCache)
    firCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
key = sprintf('Fpass=%.9g;Fstop=%.9g;Fs=%.9g;Att=%.3g;Fast=%d', Fpass, Fstop, Fs, stopAtt, useFastFir);
if isKey(firCache, key)
    v = firCache(key);
    b = v{1};
    gd = v{2};
    return;
end

use_designfilt = (exist('designfilt', 'file') == 2);
if use_designfilt && ~useFastFir
    try
        d = designfilt('lowpassfir', ...
            'PassbandFrequency', Fpass, ...
            'StopbandFrequency', Fstop, ...
            'PassbandRipple', 0.1, ...
            'StopbandAttenuation', stopAtt, ...
            'SampleRate', Fs);
        b = d.Coefficients(:);
        gd = floor((numel(b)-1)/2);
        firCache(key) = {b, gd};
        return;
    catch
        % fallback to manual FIR design below
    end
end

% Toolbox-light fallback: windowed-sinc low-pass FIR
trans_bw = max(Fstop - Fpass, Fs/4096);
N = ceil(8*Fs/trans_bw); % practical order estimate
N = min(max(N, 63), 1023);
if mod(N, 2) == 1
    N = N + 1; % make order even => odd taps
end
M = N;
n = (0:M).';
fc = min(max((Fpass + Fstop)/2, 1), 0.49*Fs); % Hz
u = 2*fc/Fs;
h = u * sinc(u*(n - M/2));
w = 0.42 - 0.5*cos(2*pi*n/M) + 0.08*cos(4*pi*n/M); % Blackman
b = h .* w;
b = b / sum(b);
gd = floor((numel(b)-1)/2);
firCache(key) = {b, gd};
end

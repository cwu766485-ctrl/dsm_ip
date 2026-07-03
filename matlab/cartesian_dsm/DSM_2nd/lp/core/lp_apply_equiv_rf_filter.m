function y_eq = lp_apply_equiv_rf_filter(y_rf, Fs, BWch)
% lp_apply_equiv_rf_filter Equivalent RF low-pass for ACPR evaluation
Fpass = 0.50 * BWch;
Fstop = 1.00 * BWch;
if Fstop >= (Fs/2)*0.98
    Fstop = 0.95 * (Fs/2);
end
if Fpass >= Fstop
    Fpass = 0.8 * Fstop;
end
[b, gd] = local_lowpass_fir(Fpass, Fstop, Fs, 60);
y_eq_f = filter(b, 1, y_rf(:));
y_eq = y_eq_f(gd+1:end);
end

function [b, gd] = local_lowpass_fir(Fpass, Fstop, Fs, stopAtt)
use_designfilt = (exist('designfilt', 'file') == 2);
if use_designfilt
    try
        d = designfilt('lowpassfir', ...
            'PassbandFrequency', Fpass, ...
            'StopbandFrequency', Fstop, ...
            'PassbandRipple', 0.2, ...
            'StopbandAttenuation', stopAtt, ...
            'SampleRate', Fs);
        b = d.Coefficients(:);
        gd = floor((numel(b)-1)/2);
        return;
    catch
        % fallback below
    end
end

trans_bw = max(Fstop - Fpass, Fs/4096);
N = ceil(8*Fs/trans_bw);
N = min(max(N, 63), 1023);
if mod(N, 2) == 1
    N = N + 1;
end
M = N;
n = (0:M).';
fc = min(max((Fpass + Fstop)/2, 1), 0.49*Fs);
u = 2*fc/Fs;
h = u * sinc(u*(n - M/2));
w = 0.42 - 0.5*cos(2*pi*n/M) + 0.08*cos(4*pi*n/M);
b = h .* w;
b = b / sum(b);
gd = floor((numel(b)-1)/2);
end

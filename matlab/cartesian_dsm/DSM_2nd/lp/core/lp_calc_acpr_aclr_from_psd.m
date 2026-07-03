function m = lp_calc_acpr_aclr_from_psd(y, Fs, BWch, adjOffset, cfg)
% lp_calc_acpr_aclr_from_psd ACPR/ACLR from centered Welch PSD
y = y(:);
[Pxx,f] = pwelch(y, cfg.window, cfg.overlap, cfg.nfft, Fs, 'centered');
df = mean(diff(f));
Pch  = band_power(Pxx,f, -BWch/2, +BWch/2, df);
PadL = band_power(Pxx,f, -adjOffset-BWch/2, -adjOffset+BWch/2, df);
PadR = band_power(Pxx,f, +adjOffset-BWch/2, +adjOffset+BWch/2, df);
m = struct();
m.ACPR_L_dBc = 10*log10((PadL+eps)/(Pch+eps));
m.ACPR_R_dBc = 10*log10((PadR+eps)/(Pch+eps));
end

function P = band_power(Pxx, f, f1, f2, df)
idx = (f >= f1) & (f <= f2);
P = sum(Pxx(idx)) * df;
end

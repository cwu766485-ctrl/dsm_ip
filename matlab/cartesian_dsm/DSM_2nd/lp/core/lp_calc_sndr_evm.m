function m = lp_calc_sndr_evm(y_hat, x_ref)
% lp_calc_sndr_evm Compute SNDR and RMS EVM%
e = y_hat - x_ref;
Ps = mean(abs(x_ref).^2);
Pe = mean(abs(e).^2);
m = struct();
m.SNDR_dB = 10*log10((Ps+eps)/(Pe+eps));
m.EVM_rms_percent = sqrt((Pe+eps)/(Ps+eps))*100;
end

path_setup;
T = run_ai_assisted_dpd_sweep;
assert(height(T) >= 1);
assert(all(T.FixedDPD_EVM_percent < T.NoDPD_EVM_percent));
assert(all(T.FixedDPD_SNDR_dB > T.NoDPD_SNDR_dB));
assert(all(T.LUTDPD_EVM_percent < T.NoDPD_EVM_percent));
assert(all(T.LUTDPD_SNDR_dB > T.NoDPD_SNDR_dB));

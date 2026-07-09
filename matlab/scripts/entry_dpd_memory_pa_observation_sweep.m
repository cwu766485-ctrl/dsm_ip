% entry_dpd_memory_pa_observation_sweep
% Run memory-PA and RF-observation DPD diagnostic sweep.

path_setup;
T = run_dpd_memory_pa_observation_sweep();
assert(all(T.Native_OptimizedPoly_EVM_percent < T.Native_NoDPD_EVM_percent));
assert(all(T.Native_LUT_EVM_percent < T.Native_NoDPD_EVM_percent));
assert(all(T.RF_OptimizedPoly_EVM_percent <= T.RF_NoDPD_EVM_percent));

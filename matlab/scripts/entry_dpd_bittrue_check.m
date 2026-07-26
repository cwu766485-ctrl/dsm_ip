% Entry point for DPD MATLAB/RTL bit-true comparison after XSim.
path_setup;
T = compare_dpd_rtl_xsim;
disp(T);
assert(all(T.mismatch == 0));
T_memory = compare_dpd_memory_poly_rtl_xsim;
disp(T_memory);
assert(all(T_memory.mismatch == 0));
T7 = compare_dpd7_rtl_xsim;
disp(T7);
assert(all(T7.mismatch == 0));

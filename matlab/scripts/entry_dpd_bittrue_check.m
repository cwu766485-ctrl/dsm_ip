% Entry point for DPD MATLAB/RTL bit-true comparison after XSim.
path_setup;
T = compare_dpd_rtl_xsim;
disp(T);
assert(all(T.mismatch == 0));

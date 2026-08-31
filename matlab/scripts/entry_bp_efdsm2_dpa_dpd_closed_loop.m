% Entry point for the frozen BP-EFDSM2 behavioral switching-DPA DPD experiment.
cd(fileparts(fileparts(mfilename('fullpath'))));
path_setup;
[Results, Summary, Coefficients, Artifacts] = run_bp_efdsm2_dpa_dpd_closed_loop; %#ok<NASGU>
disp(Summary);

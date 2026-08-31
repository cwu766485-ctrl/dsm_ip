cd(fileparts(fileparts(mfilename('fullpath'))));
path_setup;
[Results, Best] = run_bp_efdsm2_parameter_sweep; %#ok<NASGU>

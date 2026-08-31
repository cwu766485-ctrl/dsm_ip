cd(fileparts(fileparts(mfilename('fullpath'))));
path_setup;
[Results, Summary] = run_bp_modulator_dpa_comparison; %#ok<NASGU>

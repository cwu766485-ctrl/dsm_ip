% Entry point for BP-EFDSM2 endpoint-stage diagnosis.
cd(fileparts(fileparts(mfilename('fullpath'))));
path_setup;
Summary = run_bp_efdsm2_dpa_stage_diagnostic; %#ok<NASGU>

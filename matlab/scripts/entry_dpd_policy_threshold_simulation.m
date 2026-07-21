% entry_dpd_policy_threshold_simulation
% Generate simulation-only PA/observation evidence for policy gate calibration.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));
path_setup();
T = run_dpd_policy_threshold_simulation();
assert(height(T) >= 6);
assert(numel(unique(T.pa_strength_db)) >= 2);
assert(any(T.feedback_pass) && any(~T.feedback_pass));

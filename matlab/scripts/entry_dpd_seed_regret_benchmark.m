% entry_dpd_seed_regret_benchmark
% Generate deterministic behavioral labels before any board replay or C export.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));
path_setup();
T = run_dpd_seed_regret_benchmark();
assert(height(T) == 1728);
assert(numel(unique(T.profile_id)) == 12);
assert(numel(unique(T.waveform_id)) == 8);
assert(numel(unique(T.simulation_seed)) == 3);
assert(isequal(unique(T.seed_package).', 0:5));
assert(all(T.candidate_count_local == 14));
assert(all(T.dsm_algorithm == 2));
assert(all(T.dsm_config_id == "efdsm_1bit_osr32_interp0"));
assert(all(T.initial_cost >= T.final_cost | T.local_search_regret == 0));
assert(all(T.best_seed >= 0 & T.best_seed <= 5));

% entry_dpd_pa_robustness_sweep
% Run the multi-axis memory-PA robustness study for policy-gate evaluation.
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, '..'));
path_setup();
T = run_dpd_pa_robustness_sweep();
assert(height(T) == 288);
assert(numel(unique(T.profile_id)) == 12);
assert(numel(unique(T.simulation_seed)) == 3);
assert(numel(unique(T.scenario_id)) == 96);
assert(any(T.feedback_pass) && any(~T.feedback_pass));
assert(all(ismember({'input_power', 'output_power', 'peak', 'avg_mag', ...
  'evm_proxy', 'acpr_proxy', 'spec_bin0', 'spec_bin1', 'spec_bin2', ...
  'spec_adj', 'clip', 'saturation', 'initial_cost', 'local_search_regret', ...
  'initial_feedback_pass'}, T.Properties.VariableNames)));
Gate = readtable(fullfile(here, '..', 'out', 'dpd', 'dpd_pa_monitor_gate_loso.csv'));
assert(height(Gate) == 12);
assert(all(Gate.monitor_false_direct <= Gate.legacy_false_direct));
Regret = readtable(fullfile(here, '..', 'out', 'dpd', 'dpd_pa_regret_policy_loso.csv'));
Decision = readtable(fullfile(here, '..', 'out', 'dpd', 'dpd_pa_regret_policy_decisions.csv'));
assert(height(Regret) == 12);
assert(height(Decision) == height(T));
assert(all(ismember({'direct', 'local_search'}, unique(string(Decision.gate_decision)))));
assert(all(Decision.candidate_count_model == 1 | Decision.candidate_count_model == 14));
Direct = Decision(string(Decision.gate_decision) == "direct", :);
assert(all(Direct.actual_regret <= Direct.regret_budget));
assert(all(Direct.nearest_feature_distance_ppm <= Direct.feature_distance_limit_ppm));

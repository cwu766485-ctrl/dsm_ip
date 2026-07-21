matlab_root = fileparts(fileparts(mfilename('fullpath')));
addpath(matlab_root);
path_setup;
T = run_dpd_memory_tinyml_dataset('profile_set', 'development', ...
  'output_tag', 'dpd_memory_tinyml_development_', 'export_package_header', false);
assert(height(T) == 1152);
assert(numel(unique(T.condition_id)) == 192);
assert(numel(unique(T.profile_id)) == 8);
[~, ~, condition_group] = unique(T.condition_id);
assert(all(accumarray(condition_group, 1) == 6));
assert(all(T.seed_package >= 0 & T.seed_package <= 5));

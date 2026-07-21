% entry_dpd_memory_poly_training_comparison
% Train and compare no-DPD, memoryless, and memory-polynomial paths.

matlab_root = fileparts(fileparts(mfilename('fullpath')));
addpath(matlab_root);
path_setup;
[Results, Summary, Coefficients, Artifacts] = ...
  run_dpd_memory_poly_training_comparison(); %#ok<ASGLU>
assert(height(Results) == 9);
assert(height(Summary) == 3);
assert(all(isfinite(Summary.Mean_EVM_percent)));
assert(Summary.Mean_EVM_percent(2) < Summary.Mean_EVM_percent(1));
assert(Summary.Mean_EVM_percent(3) < Summary.Mean_EVM_percent(2));
no_dpd = Results.EVM_percent(Results.Mode == "No DPD");
memoryless = Results.EVM_percent(Results.Mode == "Memoryless DPD");
memory_poly = Results.EVM_percent(Results.Mode == "Memory-polynomial DPD");
assert(all(memoryless < no_dpd));
assert(all(memory_poly < memoryless));
assert(Summary.Total_DPDSaturationCount(2) == 0);
assert(Summary.Total_DPDSaturationCount(3) == 0);
assert(Artifacts.memory_poly.validation.ACLR_avg_dBc <= ...
  Artifacts.memoryless.validation.ACLR_avg_dBc + 0.05);

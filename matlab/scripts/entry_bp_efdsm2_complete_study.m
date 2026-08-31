% Complete MATLAB-only study for the BP-EFDSM2 behavioral DPA project path.
% Runtime is longer than individual entries because it trains two DPD models,
% compares three BP modulators, and sweeps EFDSM2 operating points.
cd(fileparts(fileparts(mfilename('fullpath'))));
path_setup;

disp('=== 1/3 BP-EFDSM2 + analog RLC BPF + DPD comparison ===');
[DpdResults, DpdSummary, DpdCoefficients, DpdArtifacts] = ...
  run_bp_efdsm2_dpa_dpd_closed_loop; %#ok<NASGU>
disp(DpdSummary);

disp('=== 2/3 BP single-loop / EFDSM2 / native multilevel MASH11 filter-receiver study ===');
[ModulatorResults, ModulatorSummary] = ...
  run_bp_modulator_dpa_comparison; %#ok<NASGU>
disp(ModulatorSummary);

disp('=== 3/3 EFDSM2 nominal-backoff B1-B2 / dither parameter sweep ===');
[SweepResults, BestEfdsm2] = run_bp_efdsm2_parameter_sweep; %#ok<NASGU>
disp(BestEfdsm2);

disp('=== COMPLETE: inspect matlab/out/dpd/ ===');

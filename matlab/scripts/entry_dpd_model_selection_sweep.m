% Run the behavioral DPD complexity selection flow.
path_setup;
[Results, Recommendation] = run_dpd_model_selection_sweep;
disp(Recommendation);

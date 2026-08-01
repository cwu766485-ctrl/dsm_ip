function T = run_frontend_dsm_pareto_matrix_28(varargin)
% Produce the 24-point decision matrix plus four D4/MASH111 extension rows.
% The 24-point CSV remains the selection source; the 28-point CSV is the
% complete diagnostic record requested for the seven-DSM candidate set.

  main = run_frontend_dsm_pareto_matrix(varargin{:});
  ext = run_frontend_dsm_pareto_matrix( ...
    'dsm_ids', {'D4'}, ...
    'out_filename', 'frontend_dsm_pareto_d4_extension.csv', varargin{:});
  T = [main; ext];
  repo_matlab = fileparts(fileparts(mfilename('fullpath')));
  out_dir = fullfile(repo_matlab, 'out', 'frontend_dsm_pareto');
  writetable(T, fullfile(out_dir, 'frontend_dsm_pareto_matrix_28.csv'));
end

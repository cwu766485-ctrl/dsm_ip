repo = fileparts(fileparts(mfilename('fullpath')));
cd(repo);
path_setup;
run_frontend_dsm_pareto_matrix;

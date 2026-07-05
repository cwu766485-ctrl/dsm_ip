repo = fileparts(fileparts(mfilename('fullpath')));
cd(repo);
path_setup;
interp_frontend_system_eval;

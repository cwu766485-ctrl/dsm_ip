repo = fileparts(fileparts(mfilename('fullpath')));
cd(repo);
path_setup;
interp_frontend_float;
interp_frontend_fixed;

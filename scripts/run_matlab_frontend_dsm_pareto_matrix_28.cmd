@echo off
setlocal
set REPO=%~dp0..
matlab -batch "cd('%REPO%\matlab'); path_setup; run_frontend_dsm_pareto_matrix_28"
endlocal

@echo off
setlocal
set "REPO_ROOT=%~dp0.."
set "INPUT=%REPO_ROOT%\matlab\out\dpd\dpd_memory_tinyml_dataset.csv"
set "OUTPUT=%REPO_ROOT%\matlab\out\dpd\memory_tinyml_loso"
py -3 "%REPO_ROOT%\fpga\zu15eg\scripts\evaluate_memory_tinyml_loso.py" --input "%INPUT%" --out-dir "%OUTPUT%"
exit /b %ERRORLEVEL%

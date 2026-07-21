@echo off
setlocal
set "MATLAB_EXE=D:\MATLAB\R2025a\bin\matlab.exe"
set "REPO_ROOT=%~dp0.."
set "ENTRY_M=%REPO_ROOT%\matlab\scripts\entry_dpd_memory_tinyml_development_dataset.m"
if not exist "%MATLAB_EXE%" exit /b 1
"%MATLAB_EXE%" -batch "run('%ENTRY_M%')"
exit /b %ERRORLEVEL%

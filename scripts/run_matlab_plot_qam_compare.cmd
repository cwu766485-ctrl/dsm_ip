@echo off
setlocal

set "MATLAB_EXE=D:\MATLAB\R2025a\bin\matlab.exe"
set "REPO_ROOT=%~dp0.."
set "ENTRY_M=%REPO_ROOT%\matlab\scripts\entry_plot_qam16_64_256.m"

if not exist "%MATLAB_EXE%" (
  echo ERROR: MATLAB not found at "%MATLAB_EXE%". Update MATLAB_EXE in %~nx0.
  exit /b 1
)

"%MATLAB_EXE%" -batch "run('%ENTRY_M%')"
exit /b %ERRORLEVEL%
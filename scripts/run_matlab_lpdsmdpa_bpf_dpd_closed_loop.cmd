@echo off
setlocal

if "%MATLAB_EXE%"=="" set "MATLAB_EXE=D:\MATLAB\R2025a\bin\matlab.exe"
set "REPO_ROOT=%~dp0.."
set "MATLAB_ROOT=%REPO_ROOT%\matlab"
set "ENTRY_M=%REPO_ROOT%\matlab\scripts\entry_lpdsmdpa_bpf_dpd_closed_loop.m"

if not exist "%MATLAB_EXE%" (
  echo MATLAB not found at "%MATLAB_EXE%".
  exit /b 1
)

"%MATLAB_EXE%" -batch "cd('%MATLAB_ROOT%'); run('%ENTRY_M%')"
exit /b %ERRORLEVEL%

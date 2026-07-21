@echo off
setlocal
set "REPO_ROOT=%~dp0.."
set "OUT_DIR=%REPO_ROOT%\docs\evidence\dpd\safety_seed_policy_20260717"
python "%REPO_ROOT%\fpga\zu15eg\scripts\evaluate_memory_tinyml_safety_seed_policy.py" ^
  --base-train "%REPO_ROOT%\matlab\out\dpd\dpd_memory_tinyml_dataset.csv" ^
  --development "%REPO_ROOT%\matlab\out\dpd\dpd_memory_tinyml_development_dpd_memory_tinyml_dataset.csv" ^
  --blind "%REPO_ROOT%\matlab\out\dpd\dpd_memory_tinyml_blind_dpd_memory_tinyml_dataset.csv" ^
  --out-dir "%OUT_DIR%"
exit /b %ERRORLEVEL%

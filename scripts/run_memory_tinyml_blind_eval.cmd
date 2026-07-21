@echo off
setlocal
set "REPO_ROOT=%~dp0.."
set "TRAIN=%REPO_ROOT%\matlab\out\dpd\dpd_memory_tinyml_dataset.csv"
set "BLIND=%REPO_ROOT%\matlab\out\dpd\dpd_memory_tinyml_blind_dpd_memory_tinyml_dataset.csv"
set "MODEL=%REPO_ROOT%\docs\evidence\dpd\memory_tinyml_tree_q20_v2_20260715.json"
set "OUT=%REPO_ROOT%\docs\evidence\dpd"
python "%REPO_ROOT%\fpga\zu15eg\scripts\evaluate_memory_tinyml_blind.py" --allow-safety-fail --train "%TRAIN%" --blind "%BLIND%" --model "%MODEL%" --out-csv "%OUT%\memory_tinyml_blind_v2_20260717.csv" --out-json "%OUT%\memory_tinyml_blind_v2_20260717.json" --out-md "%OUT%\memory_tinyml_blind_v2_20260717.md"
if errorlevel 1 exit /b %ERRORLEVEL%
python "%REPO_ROOT%\fpga\zu15eg\scripts\finalize_memory_tinyml_hierarchy_policy.py" --blind-report "%OUT%\memory_tinyml_blind_v2_20260717.json" --header "%REPO_ROOT%\fpga\zu15eg\baremetal\src\dpd_tinyml_hierarchy_policy.h"
exit /b %ERRORLEVEL%

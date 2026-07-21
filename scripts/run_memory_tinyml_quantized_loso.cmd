@echo off
setlocal

set "REPO=%~dp0.."
python "%REPO%\fpga\zu15eg\scripts\evaluate_quantized_memory_tinyml_tree_loso.py" ^
  --input "%REPO%\matlab\out\dpd\dpd_memory_tinyml_dataset.csv" ^
  --out-csv "%REPO%\docs\evidence\dpd\memory_tinyml_tree_q20_loso_v2_20260715.csv" ^
  --out-json "%REPO%\docs\evidence\dpd\memory_tinyml_tree_q20_loso_v2_20260715.json"
exit /b %ERRORLEVEL%

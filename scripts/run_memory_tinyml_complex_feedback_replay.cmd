@echo off
setlocal

set "REPO=%~dp0.."
python "%REPO%\fpga\zu15eg\scripts\replay_memory_tinyml_complex_feedback.py" ^
  --input "%REPO%\matlab\out\dpd\dpd_memory_tinyml_dataset.csv" ^
  --model "%REPO%\docs\evidence\dpd\memory_tinyml_tree_q20_v2_20260715.json" ^
  --traces "%REPO%\matlab\out\dpd\dpd_memory_tinyml_complex_feedback_v2.csv" ^
  --out-csv "%REPO%\docs\evidence\dpd\memory_tinyml_complex_feedback_replay_v2_20260715.csv" ^
  --out-json "%REPO%\docs\evidence\dpd\memory_tinyml_complex_feedback_replay_v2_20260715.json"
exit /b %ERRORLEVEL%

@echo off
setlocal

set "REPO=%~dp0.."
set "MODEL=%REPO%\docs\evidence\dpd\memory_tinyml_tree_q20_20260715.json"
set "BOARD_DATA=%REPO%\fpga\zu15eg\out\dsm_aware_dataset\dsm_aware_dpd_dataset.csv"
set "OUT_CSV=%REPO%\docs\evidence\dpd\memory_tinyml_board_replay_20260715.csv"
set "OUT_JSON=%REPO%\docs\evidence\dpd\memory_tinyml_board_replay_20260715.json"
set "VECTORS=%REPO%\verif\vectors\dpd\memory_tinyml_board_replay_q20.txt"
set "C_EXE=%TEMP%\test_dpd_tinyml_board_replay.exe"

python "%REPO%\fpga\zu15eg\scripts\replay_memory_tinyml_tree_board.py" ^
  --model "%MODEL%" --board-dataset "%BOARD_DATA%" ^
  --out-csv "%OUT_CSV%" --out-json "%OUT_JSON%" --vectors-out "%VECTORS%"
if errorlevel 1 exit /b 1

gcc -std=c99 -Wall -Wextra -Werror ^
  -I "%REPO%\fpga\zu15eg\baremetal\src" ^
  "%REPO%\fpga\zu15eg\baremetal\src\dpd_tinyml_tree.c" ^
  "%REPO%\verif\c\test_dpd_tinyml_tree.c" -o "%C_EXE%"
if errorlevel 1 exit /b 1

"%C_EXE%" "%VECTORS%"
exit /b %ERRORLEVEL%

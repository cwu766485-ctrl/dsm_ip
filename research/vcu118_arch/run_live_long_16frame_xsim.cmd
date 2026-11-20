@echo off
setlocal EnableExtensions
if "%~1"=="" goto usage
if not exist "%~1\tb_vcu118_live_long_continuous_cdc_v4_vlog.prj" goto bad_dir
for %%F in (xvlog.log compile.log elaborate.log xsim_no_wave.log stage_status.txt serial_pa0.mem serial_pa1.mem run_all_no_wave.tcl) do if exist "%~1\%%F" goto refuse_overwrite

set "XILINX_VIVADO=D:\AMDDesignTools\2026.1\Vivado"
set "PATH=%XILINX_VIVADO%\bin;%XILINX_VIVADO%\bin\unwrapped\win64.o;%PATH%"
pushd "%~1"
if errorlevel 1 exit /b 2
>run_all_no_wave.tcl echo run all
>>run_all_no_wave.tcl echo quit

call xvlog --incr --relax -L uvm -prj tb_vcu118_live_long_continuous_cdc_v4_vlog.prj -log xvlog.log
set "SIM_RC=%ERRORLEVEL%"
>>stage_status.txt echo XSIM_COMPILE_RC=%SIM_RC%
if not "%SIM_RC%"=="0" goto done
type xvlog.log > compile.log

call xelab --incr --debug typical --relax --mt 2 -L xil_defaultlib -L gtwizard_ultrascale_v1_7_23 -L uvm -L unisims_ver -L unimacro_ver -L secureip -L xpm --snapshot tb_vcu118_live_long_continuous_cdc_v4_behav xil_defaultlib.tb_vcu118_live_long_continuous_cdc_v4 xil_defaultlib.glbl -log elaborate.log
set "SIM_RC=%ERRORLEVEL%"
>>stage_status.txt echo XSIM_ELABORATE_RC=%SIM_RC%
if not "%SIM_RC%"=="0" goto done

call xsim tb_vcu118_live_long_continuous_cdc_v4_behav -tclbatch run_all_no_wave.tcl -log xsim_no_wave.log
set "SIM_RC=%ERRORLEVEL%"
>>stage_status.txt echo XSIM_RUNNER_RC=%SIM_RC%
if not "%SIM_RC%"=="0" goto done
findstr /C:"LIVE_AXIS_PA_PREFILL_PASS words=84224 frames=16" xsim_no_wave.log >nul
if errorlevel 1 set "SIM_RC=3"
findstr /C:"GTY_TX_SERIAL_BITTRUE_PASS lanes=2 words=84224 bits_per_lane=5390336" xsim_no_wave.log >nul
if errorlevel 1 set "SIM_RC=3"
findstr /C:"GTY_RX_LOOPBACK_BITTRUE_PASS lanes=2 words=84224 bits_per_lane=5390336" xsim_no_wave.log >nul
if errorlevel 1 set "SIM_RC=3"
>>stage_status.txt echo PASS_MARKER_CHECK_RC=%SIM_RC%

:done
popd
exit /b %SIM_RC%

:usage
echo Usage: %~nx0 ^<fresh generated xsim run directory^>
exit /b 2

:bad_dir
echo ERROR: generated XSim project file list was not found.
exit /b 2

:refuse_overwrite
echo ERROR: output artifact exists; choose a fresh run directory.
exit /b 2

param([int]$Words=64,[int]$Seed=20260916,[int]$Threshold=8192)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
if(!(Test-Path $settings)){throw 'Vivado settings are unavailable.'}
$work=Join-Path $repo 'verif\out_xsim_tid32_thermo3_frontend_tx'; New-Item -ItemType Directory -Force $work|Out-Null
& 'D:\MATLAB\R2025a\bin\matlab.exe' -batch "addpath(genpath('$($repo.Replace('\','/'))/matlab/tx_bandpass_if')); gen_tid32_thermo3_frontend_bittrue_vectors('$($work.Replace('\','/'))',$Words,$Seed,$Threshold);"
if($LASTEXITCODE -ne 0){throw 'MATLAB frontend vector generation failed.'}
$src=@('rtl\gt\gt_tx_user_bridge.sv','rtl\gt\gt_tx_raw64_boundary.sv','rtl\dpd\dpd_poly.v','rtl\dpd\dpd_memory_poly.v','rtl\interp\dsm_interp_x2_polyphase_vector.sv','rtl\dpd\dpd_vector16_memory_poly.sv','rtl\tx_bandpass_if\tid32_cartesian_fs4_gt_tx.sv','rtl\tx_bandpass_if\tid32_thermo3_fs4_multipa_tx.sv','rtl\tx_bandpass_if\tid32_thermo3_frontend_tx.sv','verif\block\bp_dsm\tb\tb_tid32_thermo3_frontend_tx_bittrue.sv')|ForEach-Object{'"'+(Join-Path $repo $_)+'"'}
Push-Location $work
try { cmd.exe /d /c "call $settings >nul && xvlog -sv $($src -join ' ') > console_xvlog.log 2>&1 && xelab tb_tid32_thermo3_frontend_tx_bittrue -s sim_frontend > console_xelab.log 2>&1 && xsim sim_frontend -runall > console_xsim.log 2>&1"; if($LASTEXITCODE -ne 0){throw "frontend XSim failed: $LASTEXITCODE"} } finally {Pop-Location}
if(!(Select-String -Path "$work\console_xsim.log" -Pattern 'TID32_THERMO3_FRONTEND_BITTRUE_PASS' -Quiet)){throw 'frontend PASS marker is missing.'}
Write-Host "TID32 thermo3 frontend XSim PASS: $work\console_xsim.log"

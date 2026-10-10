param([int]$Words=64,[int]$Seed=20260918,[int]$Step=7168)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path ((Join-Path $PSScriptRoot "..\..\.."))).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
if(!(Test-Path $settings)){throw 'Vivado settings are unavailable.'}
$work=Join-Path $repo 'runs\thermo5_serdes_loopback_xsim'; New-Item -ItemType Directory -Force $work|Out-Null
& 'D:\MATLAB\R2025a\bin\matlab.exe' -batch "addpath(genpath('$($repo.Replace('\','/'))/matlab/tx_bandpass_if')); gen_tid32_thermo5_frontend_bittrue_vectors('$($work.Replace('\','/'))',$Words,$Seed,$Step,2);"
if($LASTEXITCODE -ne 0){throw 'MATLAB vector generation failed.'}
$src=@('rtl\frontend\dsm_frame_gain_vector.sv','rtl\gt\gt_tx_user_bridge.sv','rtl\gt\gt_tx_raw64_boundary.sv','rtl\dpd\dpd_poly.v','rtl\dpd\dpd_memory_poly.v','rtl\dpd\dpd_vector16_memory_poly.sv','rtl\dpd\dpd_vector_elastic_buffer.sv','rtl\interp\dsm_interp_x2_polyphase_vector.sv','rtl\tx_bandpass_if\tid32_cartesian_fs4_gt_tx.sv','rtl\tx_bandpass_if\tid32_thermo5_fs4_multipa_tx.sv','rtl\tx_bandpass_if\tid32_thermo5_frontend_tx.sv','dv\verif\models\raw64_serializer_loopback_model.sv','dv\verif\block\bp_dsm\tb\tb_tid32_thermo5_frontend_serdes_loopback.sv')|ForEach-Object{'"'+(Join-Path $repo $_)+'"'}
Push-Location $work
try { cmd.exe /d /c "call $settings >nul && xvlog -sv -log xvlog.log $($src -join ' ') && xelab tb_tid32_thermo5_frontend_serdes_loopback -s sim_thermo5_serdes -log xelab.log && xsim sim_thermo5_serdes -runall -log xsim.log"; if($LASTEXITCODE -ne 0){throw "Serializer loopback XSim failed: $LASTEXITCODE"} } finally {Pop-Location}
if(!(Select-String -Path "$work\xsim.log" -Pattern 'THERMO5_FOUR_PA_SERDES_LOOPBACK_PASS' -Quiet)){throw 'Serializer loopback PASS marker is missing.'}
Write-Host "Thermo5 four-PA serializer loopback XSim PASS: $work\xsim.log"


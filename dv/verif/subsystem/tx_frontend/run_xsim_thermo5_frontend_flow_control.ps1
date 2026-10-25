param([int]$Seed = 20261018)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$settings = 'D:\Xilinx\Vivado\2024.1\settings64.bat'
$matlab = 'D:\MATLAB\R2025a\bin\matlab.exe'
if (!(Test-Path -LiteralPath $settings)) { throw 'Vivado settings are unavailable.' }
if (!(Test-Path -LiteralPath $matlab)) { throw 'MATLAB R2025a is unavailable.' }

$tag = Get-Date -Format 'yyyyMMdd_HHmmss'
$work = Join-Path $repo "runs\thermo5_frontend_flow_control_xsim_$tag"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$repoMatlab = $repo.Replace('\', '/')
$workMatlab = $work.Replace('\', '/')
& $matlab -batch "addpath(genpath('$repoMatlab/matlab/tx_bandpass_if')); gen_tid32_thermo5_frontend_bittrue_vectors('$workMatlab',64,$Seed,7168,2);"
if ($LASTEXITCODE -ne 0) { throw 'Frontend flow-control MATLAB vector generation failed.' }

$sources = @(
  'rtl\frontend\dsm_frame_gain_vector.sv',
  'rtl\gt\gt_tx_user_bridge.sv', 'rtl\gt\gt_tx_raw64_boundary.sv',
  'rtl\dpd\dpd_poly.v', 'rtl\dpd\dpd_memory_poly.v', 'rtl\dpd\dpd_vector16_memory_poly.sv', 'rtl\dpd\dpd_vector_elastic_buffer.sv',
  'rtl\interp\dsm_interp_x2_centered_cubic_vector.sv',
  'rtl\interp\dsm_interp_x2_polyphase_vector.sv',
  'rtl\tx_bandpass_if\tid32_cartesian_fs4_gt_tx.sv',
  'rtl\tx_bandpass_if\tid32_cartesian_ef2_fs4_gt_tx.sv',
  'rtl\tx_bandpass_if\tid32_thermo5_fs4_multipa_tx.sv',
  'rtl\tx_bandpass_if\tid32_thermo5_frontend_tx.sv',
  'dv\verif\subsystem\tx_frontend\tb\tb_tid32_thermo5_frontend_tx_flow_control.sv'
) | ForEach-Object { '"' + (Join-Path $repo $_) + '"' }

Push-Location $work
try {
  $batch = "call `"$settings`" >nul && xvlog -sv -d TB_INTERP_2 -d TB_DPD_1 $($sources -join ' ') > console_xvlog.log 2>&1 && xelab tb_tid32_thermo5_frontend_tx_flow_control -s sim_thermo5_frontend_flow > console_xelab.log 2>&1 && xsim sim_thermo5_frontend_flow -runall > console_xsim.log 2>&1"
  cmd.exe /d /c $batch
  if ($LASTEXITCODE -ne 0) { throw "Frontend flow-control XSim failed: $LASTEXITCODE ($work)" }
} finally { Pop-Location }
if (!(Select-String -Path (Join-Path $work 'console_xsim.log') -Pattern 'TID32_THERMO5_FRONTEND_FLOW_CONTROL_PASS' -Quiet)) {
  throw "Frontend flow-control PASS marker is missing ($work)."
}
Write-Host "TID32 thermo5 frontend flow-control XSim PASS: $work\console_xsim.log"

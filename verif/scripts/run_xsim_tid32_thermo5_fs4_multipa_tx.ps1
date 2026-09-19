param([int]$Vectors = 128, [int]$Seed = 20260917, [int]$Step = 6144)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings = 'D:\Xilinx\Vivado\2024.1\settings64.bat'
if (!(Test-Path $settings)) { throw 'Vivado settings are unavailable.' }
$work = Join-Path $repo 'verif\out_xsim_tid32_thermo5_fs4_multipa_tx'
New-Item -Force -ItemType Directory $work | Out-Null
& 'D:\MATLAB\R2025a\bin\matlab.exe' -batch "addpath(genpath('$($repo.Replace('\','/'))/matlab/tx_bandpass_if')); gen_tid32_thermo5_bittrue_vectors('$($work.Replace('\','/'))',$Vectors,$Seed,$Step);"
if ($LASTEXITCODE -ne 0) { throw 'TID32 thermo5 MATLAB vector generation failed.' }
$sources = @(
  (Join-Path $repo 'rtl\gt\gt_tx_user_bridge.sv'),
  (Join-Path $repo 'rtl\gt\gt_tx_raw64_boundary.sv'),
  (Join-Path $repo 'rtl\tx_bandpass_if\tid32_cartesian_fs4_gt_tx.sv'),
  (Join-Path $repo 'rtl\tx_bandpass_if\tid32_thermo5_fs4_multipa_tx.sv'),
  (Join-Path $repo 'verif\block\bp_dsm\tb\tb_tid32_thermo5_fs4_multipa_tx_bittrue.sv')
)
Push-Location $work
try {
  $sourceArgs = ($sources | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $batch = "call `"$settings`" >nul && xvlog -sv $sourceArgs > console_xvlog.log 2>&1 && xelab tb_tid32_thermo5_fs4_multipa_tx_bittrue -s sim_tid32_thermo5 > console_xelab.log 2>&1 && xsim sim_tid32_thermo5 -runall > console_xsim.log 2>&1"
  cmd.exe /d /c $batch
  if ($LASTEXITCODE -ne 0) { throw "TID32 thermo5 XSim failed: $LASTEXITCODE" }
} finally { Pop-Location }
if (!(Select-String -Path "$work\console_xsim.log" -Pattern 'TID32_THERMO5_FS4_MULTIPA_BITTRUE_PASS' -Quiet)) { throw 'TID32 thermo5 PASS marker is missing.' }
Write-Host "TID32 thermo5 Fs/4 multi-PA XSim PASS: $work\console_xsim.log"

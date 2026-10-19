param([int]$Seed = 20261018)
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$settings = 'D:\Xilinx\Vivado\2024.1\settings64.bat'
$matlab = 'D:\MATLAB\R2025a\bin\matlab.exe'
if (!(Test-Path -LiteralPath $settings)) { throw 'Vivado settings are unavailable.' }
if (!(Test-Path -LiteralPath $matlab)) { throw 'MATLAB R2025a is unavailable.' }

$tag = Get-Date -Format 'yyyyMMdd_HHmmss'
$work = Join-Path $repo "runs\thermo5_fs4_multipa_backpressure_xsim_$tag"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$repoMatlab = $repo.Replace('\', '/')
$workMatlab = $work.Replace('\', '/')
& $matlab -batch "addpath(genpath('$repoMatlab/matlab/tx_bandpass_if')); gen_tid32_thermo5_bittrue_vectors('$workMatlab',128,$Seed,6144);"
if ($LASTEXITCODE -ne 0) { throw 'Backend backpressure MATLAB vector generation failed.' }

$sources = @(
  (Join-Path $repo 'rtl\gt\gt_tx_user_bridge.sv'),
  (Join-Path $repo 'rtl\gt\gt_tx_raw64_boundary.sv'),
  (Join-Path $repo 'rtl\tx_bandpass_if\tid32_cartesian_fs4_gt_tx.sv'),
  (Join-Path $repo 'rtl\tx_bandpass_if\tid32_thermo5_fs4_multipa_tx.sv'),
  (Join-Path $repo 'dv\verif\subsystem\tx_backend\tb\tb_tid32_thermo5_fs4_multipa_tx_backpressure.sv')
)

Push-Location $work
try {
  $sourceArgs = ($sources | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $batch = "call `"$settings`" >nul && xvlog -sv $sourceArgs > console_xvlog.log 2>&1 && xelab tb_tid32_thermo5_fs4_multipa_tx_backpressure -s sim_thermo5_backend_backpressure > console_xelab.log 2>&1 && xsim sim_thermo5_backend_backpressure -runall > console_xsim.log 2>&1"
  cmd.exe /d /c $batch
  if ($LASTEXITCODE -ne 0) { throw "Backend backpressure XSim failed: $LASTEXITCODE ($work)" }
} finally { Pop-Location }
if (!(Select-String -Path (Join-Path $work 'console_xsim.log') -Pattern 'TID32_THERMO5_FS4_MULTIPA_BACKPRESSURE_PASS' -Quiet)) {
  throw "Backend backpressure PASS marker is missing ($work)."
}
Write-Host "TID32 thermo5 backend backpressure XSim PASS: $work\console_xsim.log"

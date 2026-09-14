param(
  [int]$Vectors = 128,
  [int]$Seed = 20260913,
  [string]$Python = "python",
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings = Join-Path (Split-Path -Parent (Split-Path -Parent $VivadoBat)) 'settings64.bat'
if (!(Test-Path $VivadoBat) -or !(Test-Path $settings)) { throw 'Vivado installation is unavailable' }
$work = Join-Path $repo 'verif\out_xsim_ti64_lp1_fs4_gt_tx'
New-Item -Force -ItemType Directory $work | Out-Null
& $Python (Join-Path $repo 'uvm_verif\refmodel\python\generate_ti32_lp1_fs4_vectors.py') `
  --vectors $Vectors --lanes 64 --seed $Seed --output (Join-Path $work 'ti64_lp1_fs4_vectors.csv')
if ($LASTEXITCODE -ne 0) { throw 'TI64 vector generation failed' }
$sources = @(
  (Join-Path $repo 'rtl\tx_bandpass_if\ti32_lp1_fs4_dsm.sv'),
  (Join-Path $repo 'rtl\gt\gt_tx_user_bridge.sv'),
  (Join-Path $repo 'rtl\gt\gt_tx_raw64_boundary.sv'),
  (Join-Path $repo 'rtl\tx_bandpass_if\ti64_lp1_fs4_gt_tx.sv'),
  (Join-Path $repo 'verif\block\bp_dsm\tb\tb_ti64_lp1_fs4_gt_tx.sv')
)
Push-Location $work
try {
  Get-ChildItem -Force | Where-Object { $_.Name -ne 'ti64_lp1_fs4_vectors.csv' } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  $sourceArgs = ($sources | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $batch = "call `"$settings`" >nul && cd /d `"$work`" && xvlog -sv $sourceArgs > console_xvlog.log 2>&1 && xelab tb_ti64_lp1_fs4_gt_tx -s sim_ti64_lp1 > console_xelab.log 2>&1 && xsim sim_ti64_lp1 -runall > console_xsim.log 2>&1"
  & cmd.exe /d /c $batch
  $exitCode = $LASTEXITCODE
  if ($exitCode -ne 0) {
    Get-ChildItem -Filter '*.log' | ForEach-Object { Get-Content $_.FullName -Tail 100 }
    throw "TI64 GT XSim failed: $exitCode"
  }
} finally {
  Pop-Location
}
if (!(Select-String -Path "$work\console_xsim.log" -Pattern 'TI64_LP1_FS4_GT_TX_PASS' -Quiet)) {
  throw 'TI64 GT PASS marker missing'
}
Write-Host "TI64 LP1 Fs/4 GT XSim PASS: $work\console_xsim.log"

param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings = Join-Path (Split-Path -Parent (Split-Path -Parent $VivadoBat)) 'settings64.bat'
if (!(Test-Path $VivadoBat) -or !(Test-Path $settings)) { throw 'Vivado installation is unavailable' }
$work = Join-Path $repo 'verif\out_xsim_ti64_cartesian_x4_frontend_tx'
New-Item -Force -ItemType Directory $work | Out-Null
$sources = @()
$sources += @(Get-ChildItem (Join-Path $repo 'rtl\dpd\*.v') | ForEach-Object { $_.FullName })
$sources += @(
  (Join-Path $repo 'rtl\dpd\dpd_vector16_frontend.sv'),
  (Join-Path $repo 'rtl\interp\dsm_interp_x4_polyphase16.sv'),
  (Join-Path $repo 'rtl\tx_bandpass_if\ti32_lp1_fs4_dsm.sv'),
  (Join-Path $repo 'rtl\gt\gt_tx_user_bridge.sv'),
  (Join-Path $repo 'rtl\gt\gt_tx_raw64_boundary.sv'),
  (Join-Path $repo 'rtl\tx_bandpass_if\ti64_lp1_fs4_gt_tx.sv'),
  (Join-Path $repo 'rtl\tx_bandpass_if\ti64_cartesian_x4_frontend_tx.sv'),
  (Join-Path $repo 'verif\block\bp_dsm\tb\tb_ti64_cartesian_x4_frontend_tx.sv')
)
Push-Location $work
try {
  Get-ChildItem -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  $sourceArgs = ($sources | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $batch = "call `"$settings`" >nul && cd /d `"$work`" && xvlog -sv $sourceArgs > console_xvlog.log 2>&1 && xelab tb_ti64_cartesian_x4_frontend_tx -s sim_ti64_cartesian_x4 > console_xelab.log 2>&1 && xsim sim_ti64_cartesian_x4 -runall > console_xsim.log 2>&1"
  & cmd.exe /d /c $batch
  if ($LASTEXITCODE -ne 0) {
    Get-ChildItem -Filter '*.log' | ForEach-Object { Get-Content $_.FullName -Tail 100 }
    throw "TI64 Cartesian x4 frontend XSim failed: $LASTEXITCODE"
  }
} finally {
  Pop-Location
}
if (!(Select-String -Path "$work\console_xsim.log" -Pattern 'TI64_CARTESIAN_X4_FRONTEND_TX_PASS' -Quiet)) {
  throw 'TI64 Cartesian x4 frontend PASS marker missing'
}
Write-Host "TI64 Cartesian x4 frontend XSim PASS: $work\console_xsim.log"

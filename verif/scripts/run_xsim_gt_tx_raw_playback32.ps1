param([string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat")
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings = Join-Path (Split-Path -Parent (Split-Path -Parent $VivadoBat)) 'settings64.bat'
if (!(Test-Path $VivadoBat) -or !(Test-Path $settings)) { throw 'Vivado installation is unavailable' }
$work = Join-Path $repo 'verif\out_xsim_gt_tx_raw_playback32'
New-Item -Force -ItemType Directory $work | Out-Null
$sources = @('gt_tx_user_bridge.sv', 'gt_tx_raw64_boundary.sv', 'gt_tx_raw_playback.sv', 'gt_tx_raw_playback32.sv' | ForEach-Object { Join-Path $repo "rtl\gt\$_" })
$sources += Join-Path $repo 'verif\block\bp_dsm\tb\tb_gt_tx_raw_playback32.sv'
Push-Location $work
try {
  Get-ChildItem -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  $sourceArgs = ($sources | ForEach-Object { '"' + $_ + '"' }) -join ' '
  $batch = "call `"$settings`" >nul && cd /d `"$work`" && xvlog -sv $sourceArgs > console_xvlog.log 2>&1 && xelab tb_gt_tx_raw_playback32 -s sim_raw_playback32 > console_xelab.log 2>&1 && xsim sim_raw_playback32 -runall > console_xsim.log 2>&1"
  & cmd.exe /d /c $batch; $exitCode=$LASTEXITCODE
  if ($exitCode -ne 0) { Get-ChildItem -Filter '*.log' | ForEach-Object { Get-Content $_.FullName -Tail 100 }; throw "raw playback XSim failed: $exitCode" }
} finally { Pop-Location }
if (!(Select-String -Path "$work\console_xsim.log" -Pattern 'GT_TX_RAW_PLAYBACK32_PASS' -Quiet)) { throw 'raw playback PASS marker missing' }
Write-Host "GT raw playback32 XSim PASS: $work\console_xsim.log"

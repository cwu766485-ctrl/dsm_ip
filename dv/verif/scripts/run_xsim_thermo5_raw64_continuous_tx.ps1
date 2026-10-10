$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$settings = 'D:\Xilinx\Vivado\2024.1\settings64.bat'
if (!(Test-Path -LiteralPath $settings)) { throw 'Vivado 2024.1 settings unavailable.' }
$work = Join-Path $repo 'runs\thermo5_raw64_continuous_tx_xsim'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$rtl = '"' + (Join-Path $repo 'rtl\gt\thermo5_raw64_continuous_tx.sv') + '"'
$tb = '"' + (Join-Path $repo 'dv\verif\block\gt\tb_thermo5_raw64_continuous_tx.sv') + '"'
Push-Location $work
try {
  cmd.exe /d /c "call $settings >nul && xvlog -sv -log xvlog.log $rtl $tb && xelab tb_thermo5_raw64_continuous_tx -s sim_raw64 -log xelab.log && xsim sim_raw64 -runall -log xsim.log"
  if ($LASTEXITCODE -ne 0) { throw "Raw64 XSim failed: $LASTEXITCODE" }
  if (!(Select-String -LiteralPath 'xsim.log' -Pattern 'THERMO5_RAW64_CONTINUOUS_TX_PASS' -Quiet)) { throw 'PASS marker missing.' }
} finally { Pop-Location }
Write-Host "Raw64 continuous TX XSim PASS: $work\xsim.log"

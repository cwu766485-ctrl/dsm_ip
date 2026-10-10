$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
if (!(Test-Path -LiteralPath $settings)) { throw 'Vivado settings are unavailable.' }
$work=Join-Path $repo 'runs\dpd_identity_exhaustive_xsim'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$src=@(
  'rtl\dpd\dpd_poly.v',
  'rtl\dpd\dpd_memory_poly.v',
  'dv\verif\block\dpd\tb\tb_dpd_identity_exhaustive.sv'
) | ForEach-Object { '"'+(Join-Path $repo $_)+'"' }
Push-Location $work
try {
  cmd.exe /d /c "call $settings >nul && xvlog -sv -log xvlog.log $($src -join ' ') && xelab tb_dpd_identity_exhaustive -s sim_dpd_identity_exhaustive -log xelab.log && xsim sim_dpd_identity_exhaustive -runall -log xsim.log"
  if ($LASTEXITCODE -ne 0) { throw "DPD identity exhaustive XSim failed: $LASTEXITCODE" }
  if (!(Select-String -LiteralPath 'xsim.log' -Pattern 'DPD_IDENTITY_EXHAUSTIVE_PASS' -Quiet)) { throw 'DPD identity PASS marker is missing.' }
} finally { Pop-Location }
Write-Host "DPD identity exhaustive XSim PASS: $work\xsim.log"

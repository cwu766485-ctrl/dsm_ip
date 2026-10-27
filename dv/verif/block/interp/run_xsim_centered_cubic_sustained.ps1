$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$settings = 'D:\AMDDesignTools\2026.1\Vivado\settings64.bat'
if (!(Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }
$work = Join-Path $repo 'runs\centered_cubic_sustained_xsim'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$rtl = '"' + (Join-Path $repo 'rtl\interp\dsm_interp_x2_centered_cubic_vector.sv') + '"'
$tb = '"' + (Join-Path $repo 'dv\verif\block\interp\tb\tb_centered_cubic_sustained.sv') + '"'
Push-Location $work
try {
  cmd.exe /d /c "call `"$settings`" >nul && xvlog -sv -log xvlog.log $rtl $tb && xelab tb_centered_cubic_sustained -s sim_centered_cubic_sustained -log xelab.log && xsim sim_centered_cubic_sustained -runall -log xsim.log"
  if ($LASTEXITCODE -ne 0) { throw "Centered-cubic sustained XSim failed: $LASTEXITCODE" }
  if (!(Select-String -LiteralPath 'xsim.log' -Pattern 'CENTERED_CUBIC_SUSTAINED_PASS' -Quiet)) {
    throw 'Centered-cubic sustained PASS marker is missing.'
  }
} finally { Pop-Location }
Write-Host "Centered-cubic sustained throughput XSim PASS: $work\xsim.log"

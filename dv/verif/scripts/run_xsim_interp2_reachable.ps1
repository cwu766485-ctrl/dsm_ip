$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
if (!(Test-Path -LiteralPath $settings)) { throw 'Vivado settings are unavailable.' }
$work=Join-Path $repo 'runs\interp2_reachable_xsim'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$rtl='"'+(Join-Path $repo 'rtl\interp\dsm_interp_x2_polyphase_vector.sv')+'"'
$tb='"'+(Join-Path $repo 'dv\verif\block\interp\tb\tb_interp_x2_vector_reachable.sv')+'"'
Push-Location $work
try {
  cmd.exe /d /c "call $settings >nul && xvlog -sv -log xvlog.log $rtl $tb && xelab tb_interp_x2_vector_reachable -s sim_interp2_reachable -log xelab.log && xsim sim_interp2_reachable -runall -log xsim.log"
  if ($LASTEXITCODE -ne 0) { throw "Interpolator boundary XSim failed: $LASTEXITCODE" }
  if (!(Select-String -LiteralPath 'xsim.log' -Pattern 'INTERP_X2_REACHABLE_PASS' -Quiet)) { throw 'Interpolator PASS marker is missing.' }
} finally { Pop-Location }
Write-Host "Interpolator reset/empty-backpressure XSim PASS: $work\xsim.log"

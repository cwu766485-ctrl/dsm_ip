$ErrorActionPreference = 'Stop'
$vivadoBin = if ($env:XILINX_VIVADO) { Join-Path $env:XILINX_VIVADO 'bin' } else { 'D:\Xilinx\Vivado\2024.1\bin' }
$xvlog = Join-Path $vivadoBin 'xvlog.bat'
$xelab = Join-Path $vivadoBin 'xelab.bat'
$xsim = Join-Path $vivadoBin 'xsim.bat'
foreach ($tool in @($xvlog, $xelab, $xsim)) { if (!(Test-Path -LiteralPath $tool)) { throw "Vivado simulator tool not found: $tool" } }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$out = Join-Path $repo 'dv\verif\out_xsim_frame_power_ctrl'
New-Item -ItemType Directory -Force -Path $out | Out-Null
Push-Location $out
try {
  Remove-Item -LiteralPath 'xvlog.log','xelab.log','xsim_run.log','xsim.log' -Force -ErrorAction SilentlyContinue
  & $xvlog -sv (Join-Path $repo 'rtl\axis\dsm_frame_power_ctrl.sv') (Join-Path $repo 'dv\verif\block\axis\tb_dsm_frame_power_ctrl.sv')
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit $LASTEXITCODE" }
  & $xelab tb_dsm_frame_power_ctrl -s frame_power_ctrl_sim
  if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit $LASTEXITCODE" }
  $simLog = Join-Path $out 'xsim_run.log'
  & $xsim frame_power_ctrl_sim -runall -log $simLog
  if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit $LASTEXITCODE" }
  Copy-Item -LiteralPath $simLog -Destination (Join-Path $out 'xsim.log') -Force
  if (-not (Select-String -Path (Join-Path $out 'xsim.log') -Pattern 'DSM_FRAME_POWER_CTRL_PASS' -Quiet)) { throw 'PASS marker missing' }
} finally { Pop-Location }

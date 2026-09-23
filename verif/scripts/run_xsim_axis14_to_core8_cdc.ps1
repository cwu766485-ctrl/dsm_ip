$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
if(!(Test-Path $settings)){throw 'Vivado settings are unavailable.'}
$work=Join-Path $repo 'verif\out_xsim_axis14_to_core8_cdc'
New-Item -ItemType Directory -Force $work|Out-Null
$src=@(
  'rtl\axis\dsm_reset_sync.sv',
  'rtl\axis\dsm_async_fifo.sv',
  'rtl\axis\dsm_xpm_async_fifo.sv',
  'rtl\axis\dsm_axis14_to_core8_cdc.sv',
  'verif\block\axis\tb_dsm_axis14_to_core8_cdc.sv'
)|ForEach-Object{'"'+(Join-Path $repo $_)+'"'}
Push-Location $work
try {
  cmd.exe /d /c "call $settings >nul && xvlog -sv $($src -join ' ') > console_xvlog.log 2>&1 && xelab tb_dsm_axis14_to_core8_cdc -s sim_axis14_cdc > console_xelab.log 2>&1 && xsim sim_axis14_cdc -runall > console_xsim.log 2>&1"
  if($LASTEXITCODE -ne 0){throw "AXIS CDC XSim failed: $LASTEXITCODE"}
} finally {Pop-Location}
if(!(Select-String -Path "$work\console_xsim.log" -Pattern 'DSM_AXIS14_TO_CORE8_CDC_PASS' -Quiet)){throw 'AXIS CDC PASS marker is missing.'}
Write-Host "AXIS14-to-core8 CDC XSim PASS: $work\console_xsim.log"

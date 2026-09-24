$ErrorActionPreference='Stop'
$repo=(Resolve-Path ((Join-Path $PSScriptRoot "..\..\.."))).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
$xpmCdc='D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_cdc\hdl\xpm_cdc.sv'
$xpmMemory='D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_memory\hdl\xpm_memory.sv'
$xpm='D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_fifo\hdl\xpm_fifo.sv'
$glbl='D:\Xilinx\Vivado\2024.1\data\verilog\src\glbl.v'
if(!(Test-Path $settings)){throw 'Vivado settings are unavailable.'}
if(!(Test-Path $xpmCdc) -or !(Test-Path $xpmMemory) -or !(Test-Path $xpm) -or !(Test-Path $glbl)){throw 'XPM FIFO sources are unavailable.'}
$work=Join-Path $repo 'verif\out_xsim_axis14_to_core8_cdc_xpm'
New-Item -ItemType Directory -Force $work|Out-Null
$src=@(
  $glbl,
  $xpmCdc,
  $xpmMemory,
  $xpm,
  'rtl\axis\dsm_reset_sync.sv',
  'rtl\axis\dsm_async_fifo.sv',
  'rtl\axis\dsm_xpm_async_fifo.sv',
  'rtl\axis\dsm_axis14_to_core8_cdc.sv',
  'verif\block\axis\tb_dsm_axis14_to_core8_cdc.sv',
  'verif\block\axis\tb_dsm_axis14_to_core8_cdc_xpm.sv'
)|ForEach-Object{if([System.IO.Path]::IsPathRooted($_)){'"'+$_+'"'}else{'"'+(Join-Path $repo $_)+'"'}}
Push-Location $work
try {
  cmd.exe /d /c "call $settings >nul && xvlog -sv $($src -join ' ') > console_xvlog.log 2>&1 && xelab tb_dsm_axis14_to_core8_cdc_xpm glbl -s sim_axis14_cdc_xpm > console_xelab.log 2>&1 && xsim sim_axis14_cdc_xpm -runall > console_xsim.log 2>&1"
  if($LASTEXITCODE -ne 0){throw "AXIS CDC XPM XSim failed: $LASTEXITCODE"}
} finally {Pop-Location}
if(!(Select-String -Path "$work\console_xsim.log" -Pattern 'DSM_AXIS14_TO_CORE8_CDC_PASS' -Quiet)){throw 'AXIS CDC XPM PASS marker is missing.'}
Write-Host "AXIS14-to-core8 CDC XPM XSim PASS: $work\console_xsim.log"


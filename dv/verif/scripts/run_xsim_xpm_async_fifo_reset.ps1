$ErrorActionPreference='Stop'
$repo=(Resolve-Path ((Join-Path $PSScriptRoot '..\..\..'))).Path
$settings='D:\Xilinx\Vivado\2024.1\settings64.bat'
$xpmCdc='D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_cdc\hdl\xpm_cdc.sv'
$xpmMemory='D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_memory\hdl\xpm_memory.sv'
$xpm='D:\Xilinx\Vivado\2024.1\data\ip\xpm\xpm_fifo\hdl\xpm_fifo.sv'
$glbl='D:\Xilinx\Vivado\2024.1\data\verilog\src\glbl.v'
foreach($path in @($settings,$xpmCdc,$xpmMemory,$xpm,$glbl)){
  if(!(Test-Path -LiteralPath $path)){throw "Required Vivado/XPM file is unavailable: $path"}
}
$work=Join-Path $repo 'verif\out_xsim_xpm_async_fifo_reset'
New-Item -ItemType Directory -Force $work|Out-Null
$src=@(
  $glbl,$xpmCdc,$xpmMemory,$xpm,
  'rtl\axis\dsm_xpm_async_fifo.sv',
  'dv\verif\block\axis\tb_dsm_xpm_async_fifo_reset.sv'
)|ForEach-Object{if([System.IO.Path]::IsPathRooted($_)){ '"'+$_+'"' }else{ '"'+(Join-Path $repo $_)+'"' }}
Push-Location $work
try {
  cmd.exe /d /c "call $settings >nul && xvlog -sv $($src -join ' ') > console_xvlog.log 2>&1 && xelab tb_dsm_xpm_async_fifo_reset glbl -s sim_xpm_fifo_reset > console_xelab.log 2>&1 && xsim sim_xpm_fifo_reset -runall > console_xsim.log 2>&1"
  if($LASTEXITCODE -ne 0){throw "XPM async FIFO reset XSim failed: $LASTEXITCODE"}
} finally {Pop-Location}
if(!(Select-String -LiteralPath "$work\console_xsim.log" -Pattern 'DSM_XPM_ASYNC_FIFO_RESET_PASS' -Quiet)){
  throw "XPM async FIFO reset PASS marker is missing; inspect $work"
}
Write-Host "XPM async FIFO reset XSim PASS: $work\console_xsim.log"

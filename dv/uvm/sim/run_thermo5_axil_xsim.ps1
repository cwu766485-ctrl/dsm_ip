param(
  [switch]$XpmFifo,
  [switch]$CoefficientTransport,
  [int]$Seed = 101,
  [string]$OutDir = '',
  [string]$VivadoRoot = 'D:\Xilinx\Vivado\2024.1'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$impl = if ($XpmFifo) { 'xpm' } else { 'generic' }
$vectors = Join-Path $repo 'runs\uvm_thermo5_i2_d1\vectors'
$settings = Join-Path $VivadoRoot 'settings64.bat'
$uvmPackage = Join-Path $VivadoRoot 'data\system_verilog\uvm_1.2\xlnx_uvm_package.sv'

if (!(Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }
if (!(Test-Path -LiteralPath $uvmPackage)) { throw "Vivado UVM 1.2 package not found: $uvmPackage" }
if (!(Test-Path -LiteralPath (Join-Path $vectors 'tid32_thermo5_frontend_pa3.mem'))) {
  throw 'Generate the frozen thermo5 SKU vectors first.'
}

if ($OutDir -eq '') {
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $OutDir = Join-Path $repo "runs\thermo5_axil_uvm_xsim_${impl}_seed${Seed}_${stamp}"
} else {
  $OutDir = [System.IO.Path]::GetFullPath($OutDir)
  if (Test-Path -LiteralPath $OutDir) { throw "Refusing to overwrite existing run directory: $OutDir" }
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path

function Quote-CmdArg([string]$Value) {
  '"' + $Value + '"'
}

$compileArgs = [System.Collections.Generic.List[string]]::new()
$compileArgs.Add('-sv')
$compileArgs.Add('-d'); $compileArgs.Add('UVM_NO_DPI')
$compileArgs.Add('-d'); $compileArgs.Add('THERMO5_AXIL_CONTROL')
$compileArgs.Add('-d'); $compileArgs.Add('THERMO5_XSIM')
$compileArgs.Add((Join-Path $VivadoRoot 'data\system_verilog\uvm_1.2\xlnx_uvm_package.sv'))

$filelist = Join-Path $repo 'dv\uvm\sim\thermo5_sku_filelist.f'
foreach ($line in Get-Content -LiteralPath $filelist) {
  $entry = $line.Trim()
  if (!$entry -or $entry.StartsWith('#')) { continue }
  if ($entry.StartsWith('+incdir+')) {
    $compileArgs.Add('-i')
    $compileArgs.Add((Join-Path $repo $entry.Substring(8)))
  } else {
    $compileArgs.Add((Join-Path $repo $entry))
  }
}

if ($XpmFifo) {
  $compileArgs.Add('-d'); $compileArgs.Add('THERMO5_XPM_FIFO')
  $compileArgs.Add((Join-Path $VivadoRoot 'data\verilog\src\glbl.v'))
  $compileArgs.Add((Join-Path $VivadoRoot 'data\ip\xpm\xpm_cdc\hdl\xpm_cdc.sv'))
  $compileArgs.Add((Join-Path $VivadoRoot 'data\ip\xpm\xpm_memory\hdl\xpm_memory.sv'))
  $compileArgs.Add((Join-Path $VivadoRoot 'data\ip\xpm\xpm_fifo\hdl\xpm_fifo.sv'))
}

Push-Location $OutDir
try {
  $quotedArgs = ($compileArgs | ForEach-Object { Quote-CmdArg $_ }) -join ' '
  $compile = 'call ' + (Quote-CmdArg $settings) + ' >nul && xvlog ' + $quotedArgs + ' > console_xvlog.log 2>&1'
  & cmd.exe /d /c $compile
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed; see $OutDir\console_xvlog.log" }

  $snapshot = "sim_thermo5_axil_uvm_$impl"
  $tops = if ($XpmFifo) { 'work.thermo5_sku_uvm_tb glbl' } else { 'work.thermo5_sku_uvm_tb' }
  $elaborate = 'call ' + (Quote-CmdArg $settings) + " >nul && xelab $tops -s $snapshot -debug typical -timescale 1ns/1ps > console_xelab.log 2>&1"
  & cmd.exe /d /c $elaborate
  if ($LASTEXITCODE -ne 0) { throw "xelab failed; see $OutDir\console_xelab.log" }

  $vectorArg = 'VEC_DIR=' + $vectors.Replace('\', '/')
  $plusargs = @('-testplusarg', (Quote-CmdArg $vectorArg))
  $passMarker = 'THERMO5_AXIL_CONFIG_UVM_PASS'
  if ($CoefficientTransport) {
    $plusargs += @('-testplusarg', (Quote-CmdArg 'AXIL_COEFF_TRANSPORT'))
    $passMarker = 'THERMO5_AXIL_COEFF_TRANSPORT_UVM_PASS'
  }
  $run = 'call ' + (Quote-CmdArg $settings) + ' >nul && xsim ' + $snapshot +
    ' -runall -sv_seed ' + $Seed + ' ' + ($plusargs -join ' ') +
    ' > console_xsim.log 2>&1'
  & cmd.exe /d /c $run
  if ($LASTEXITCODE -ne 0) { throw "xsim failed; see $OutDir\console_xsim.log" }

  $log = Get-Content -LiteralPath (Join-Path $OutDir 'console_xsim.log') -Raw
  if ($log -notmatch $passMarker) {
    throw "AXI-Lite UVM PASS marker missing; see $OutDir\console_xsim.log"
  }
  if ($log -notmatch 'UVM_ERROR\s*:\s*0' -or $log -notmatch 'UVM_FATAL\s*:\s*0') {
    throw "UVM error/fatal count is nonzero; see $OutDir\console_xsim.log"
  }
  Write-Host "$passMarker fifo=$impl seed=$Seed log=$OutDir\console_xsim.log"
} finally {
  Pop-Location
}

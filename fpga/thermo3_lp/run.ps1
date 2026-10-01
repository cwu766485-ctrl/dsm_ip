param([string]$VivadoBat = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$log = Join-Path $here 'reports\build.log'
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
& $VivadoBat -mode batch -source (Join-Path $here 'build.tcl') *> $log
if ($LASTEXITCODE -ne 0) { throw "thermo3 LP Vivado failed: exit=$LASTEXITCODE; see $log" }
Import-Csv (Join-Path $here 'reports\summary.csv') | Format-Table -AutoSize

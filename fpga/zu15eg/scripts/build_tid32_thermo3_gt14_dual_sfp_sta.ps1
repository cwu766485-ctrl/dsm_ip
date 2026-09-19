param([string]$OutRoot = 'D:\TraeTemp')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$vivado = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
if (!(Test-Path $vivado)) { throw 'Vivado executable is unavailable.' }
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
$out = Join-Path $OutRoot ('tid32_thermo3_gt14_dual_sfp_sta_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
& $vivado -mode batch -source (Join-Path $repo 'fpga\zu15eg\scripts\build_tid32_thermo3_gt14_dual_sfp_sta.tcl') -tclargs $out
if ($LASTEXITCODE -ne 0) { throw "Dual-SFP thermo3 GTH build failed: $LASTEXITCODE" }
if (!(Test-Path (Join-Path $out 'timing_summary.rpt'))) { throw 'No timing report produced.' }
Write-Host "TID32 thermo3 dual-SFP GTH build complete: $out"

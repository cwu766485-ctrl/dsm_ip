param([string]$Part='xczu15eg-ffvb1156-2-i',[double]$TargetMHz=218.75,[ValidateSet(1,2,4,8)][int]$Steps=8,[switch]$AllowTimingFail)
$ErrorActionPreference='Stop'; $repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$vivado='D:\Xilinx\Vivado\2024.1\bin\vivado.bat'; if(!(Test-Path $vivado)){throw 'Vivado missing'}
$out=Join-Path $repo ('syn\out\crfb_temporal'+$Steps+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
& $vivado -mode batch -source (Join-Path $PSScriptRoot 'run_ooc_crfb_temporal8.tcl') -tclargs $Part $TargetMHz $Steps $out
if($LASTEXITCODE){throw 'CRFB temporal OOC implementation failed'}
$summary=Import-Csv (Join-Path $out 'summary.csv'); $summary | Format-Table -AutoSize
if($summary.status -ne 'PASS' -and -not $AllowTimingFail){throw "CRFB temporal$Steps OOC timing failed: WNS=$($summary.wns_ns) ns, WHS=$($summary.whs_ns) ns"}

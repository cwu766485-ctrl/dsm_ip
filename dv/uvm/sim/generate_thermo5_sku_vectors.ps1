param([int]$Seed=20260930)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$out=Join-Path $repo 'runs\uvm_thermo5_i2_d1\vectors'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$matlab='D:\MATLAB\R2025a\bin\matlab.exe'
if (!(Test-Path -LiteralPath $matlab)) { throw "MATLAB executable not found: $matlab" }
$matlabRoot=(Join-Path $repo 'matlab\tx_bandpass_if').Replace('\','/')
$matlabOut=$out.Replace('\','/')
& $matlab -batch "addpath(genpath('$matlabRoot')); gen_tid32_thermo5_frontend_bittrue_vectors('$matlabOut',56,$Seed,7168,2,[1,15,36]);"
if ($LASTEXITCODE -ne 0) { throw "MATLAB vector generation failed: $LASTEXITCODE" }
Write-Host "Generated 32 AXI beats / 56 core words at $out"

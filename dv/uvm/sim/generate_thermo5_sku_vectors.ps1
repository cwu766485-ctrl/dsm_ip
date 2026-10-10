param(
  [int]$Seed=20260930,
  [string]$OutDir='',
  [ValidateSet('random','extreme','range_stress')][string]$Profile='random',
  [int]$Words=56,
  [switch]$SaturatingGain
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if ($OutDir -eq '') { $OutDir=Join-Path $repo 'runs\uvm_thermo5_i2_d1\vectors' }
$out=[System.IO.Path]::GetFullPath($OutDir)
$runRoot=[System.IO.Path]::GetFullPath((Join-Path $repo 'runs'))
if($Words -lt 36 -or $Words % 7 -ne 0) { throw 'Words must be >=36 and a multiple of seven.' }
if (!$out.StartsWith($runRoot+[System.IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Output must be a child of runs/: $out"
}
New-Item -ItemType Directory -Force -Path $out | Out-Null
$matlab='D:\MATLAB\R2025a\bin\matlab.exe'
if (!(Test-Path -LiteralPath $matlab)) { throw "MATLAB executable not found: $matlab" }
$matlabRoot=(Join-Path $repo 'matlab\tx_bandpass_if').Replace('\','/')
$matlabOut=$out.Replace('\','/')
$gainArgument=''
if($SaturatingGain) {
  if($Profile -eq 'range_stress') { throw 'range_stress intentionally uses unity gain; choose extreme instead.' }
  $gainArgument=',[32767,-32768,24576]'
}
& $matlab -batch "addpath(genpath('$matlabRoot')); gen_tid32_thermo5_frontend_bittrue_vectors('$matlabOut',$Words,$Seed,7168,2,[1,15,36],'$Profile'$gainArgument);"
if ($LASTEXITCODE -ne 0) { throw "MATLAB vector generation failed: $LASTEXITCODE" }
Write-Host "Generated $([int]($Words*4/7)) AXI beats / $Words core words profile=$Profile at $out"

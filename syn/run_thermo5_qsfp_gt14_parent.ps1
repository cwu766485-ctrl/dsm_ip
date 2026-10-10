param(
  [ValidateSet('synth','route')][string]$Stage='synth',
  [string]$OutDir=''
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$vivado='D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
if (!(Test-Path -LiteralPath $vivado)) { throw 'Vivado 2024.1 is unavailable.' }
$out=if ($OutDir) { [System.IO.Path]::GetFullPath($OutDir) } else {
  Join-Path $repo ('runs\thermo5_qsfp_parent_'+(Get-Date -Format 'yyyyMMdd_HHmmss'))
}
New-Item -ItemType Directory -Force -Path $out | Out-Null
$tcl=Join-Path $repo 'syn\run_thermo5_qsfp_gt14_parent.tcl'
& $vivado -mode batch -source $tcl -tclargs $out $Stage *> (Join-Path $out 'vivado.stdout.log')
if ($LASTEXITCODE -ne 0) { throw "Parent $Stage failed; see $out\vivado.stdout.log" }
Write-Host "Parent $Stage completed: $out"

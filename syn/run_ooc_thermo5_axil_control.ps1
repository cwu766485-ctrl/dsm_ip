param(
  [ValidateSet('synth','quick','full','timing')][string]$Implementation = 'full',
  [string]$Part = 'xczu15eg-ffvb1156-2-i',
  [double]$CoreMHz = 218.75,
  [double]$AxilMHz = 100.0,
  [string]$OutDir = '',
  [string]$VivadoBat = 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat',
  [ValidateSet('causal','centered-cubic')][string]$Interpolation = 'causal',
  [ValidateSet(1,2)][int]$TidOrder = 1,
  [ValidateSet(5120,7168)][int]$Step = 7168
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado is unavailable: $VivadoBat" }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $repo "runs\thermo5_axil_ooc_${Implementation}_${Interpolation}_ef${TidOrder}_step${Step}_${stamp}"
} else {
  $OutDir = [System.IO.Path]::GetFullPath($OutDir)
  if (Test-Path -LiteralPath $OutDir) { throw "Refusing to overwrite existing OOC directory: $OutDir" }
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path
$tcl = Join-Path $repo 'syn\run_ooc_thermo5_axil_control.tcl'
$log = Join-Path $OutDir 'vivado.log'
$centered = if ($Interpolation -eq 'centered-cubic') { 1 } else { 0 }
& $VivadoBat -mode batch -source $tcl -tclargs $Part $CoreMHz $AxilMHz $OutDir $Implementation $centered $TidOrder $Step *> $log
if ($LASTEXITCODE -ne 0) { throw "AXI-Lite wrapper OOC failed; see $log" }
if ($Implementation -eq 'synth') {
  $checkpoint = Join-Path $OutDir 'synthesized.dcp'
  $utilization = Join-Path $OutDir 'synth_utilization.rpt'
  if (!(Test-Path -LiteralPath $checkpoint) -or !(Test-Path -LiteralPath $utilization)) {
    throw "AXI-Lite synthesis did not produce its checkpoint and utilization report; see $log"
  }
  Write-Host "THERMO5_AXIL_SYNTH_PASS checkpoint=$checkpoint utilization=$utilization log=$log"
  exit 0
}
$summary = Import-Csv -LiteralPath (Join-Path $OutDir 'summary.csv')
$summary | Format-Table -AutoSize
if ($summary.Status -ne 'PASS') { throw "AXI-Lite wrapper routed timing failed: $($summary.Status)" }
Write-Host "THERMO5_AXIL_OOC_PASS log=$log"

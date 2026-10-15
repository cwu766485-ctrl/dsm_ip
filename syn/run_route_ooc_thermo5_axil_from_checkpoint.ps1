param(
  [Parameter(Mandatory = $true)][string]$Checkpoint,
  [string]$OutDir = '',
  [ValidateSet('synth','optimized','placed','physopt')][string]$ResumeFrom = 'synth',
  [ValidateSet('Default','RuntimeOptimized','Quick')][string]$RouteDirective = 'Default',
  [switch]$NoPsir,
  [switch]$StopAfterPhysopt,
  [string]$VivadoBat = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado is unavailable: $VivadoBat" }
if (!(Test-Path -LiteralPath $Checkpoint -PathType Leaf)) {
  throw "Checkpoint is unavailable: $Checkpoint"
}
$Checkpoint = (Resolve-Path -LiteralPath $Checkpoint).Path
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $repo "runs\thermo5_axil_route_resume_${stamp}"
} else {
  $OutDir = [System.IO.Path]::GetFullPath($OutDir)
  if (Test-Path -LiteralPath $OutDir) {
    throw "Refusing to overwrite existing route output directory: $OutDir"
  }
}
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path
$tcl = Join-Path $repo 'syn\route_ooc_thermo5_axil_from_checkpoint.tcl'
$log = Join-Path $OutDir 'vivado.log'

$noPsirArg = if ($NoPsir) { '1' } else { '0' }
$stopAfterPhysoptArg = if ($StopAfterPhysopt) { '1' } else { '0' }
& $VivadoBat -mode batch -source $tcl -tclargs $Checkpoint $OutDir $ResumeFrom $RouteDirective $noPsirArg $stopAfterPhysoptArg *> $log
if ($LASTEXITCODE -ne 0) { throw "Checkpoint route failed; see $log" }

$expected = if ($StopAfterPhysopt) {
  @('physopt.dcp','physopt_timing_summary.rpt','physopt_timing_paths.rpt','physopt_utilization.rpt')
} else {
  @('routed.dcp','timing_summary.rpt','summary.csv')
}
foreach ($name in $expected) {
  if (!(Test-Path -LiteralPath (Join-Path $OutDir $name) -PathType Leaf)) {
    throw "Route flow did not produce $name; see $log"
  }
}
if ($StopAfterPhysopt) {
  Write-Host "THERMO5_AXIL_PHYSOPT_READY checkpoint=$(Join-Path $OutDir 'physopt.dcp') output=$OutDir log=$log"
  exit 0
}
$summary = Import-Csv -LiteralPath (Join-Path $OutDir 'summary.csv')
$summary | Format-Table -AutoSize
if ($summary.Status -ne 'PASS') { throw "Routed STA failed: $($summary.Status); see $OutDir" }
Write-Host "THERMO5_AXIL_ROUTE_PASS checkpoint=$Checkpoint output=$OutDir log=$log"

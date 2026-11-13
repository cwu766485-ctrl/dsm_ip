param(
  [string]$VivadoBat = 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat',
  [string]$OutRoot = '',
  [string]$RouteDirective = 'Default'
)

$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado is unavailable: $VivadoBat" }
if ($RouteDirective -notin @('Default','RuntimeOptimized','Quick')) {
  throw "Unsupported route directive: $RouteDirective"
}
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$vivadoVersion = (& $VivadoBat -version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($vivadoVersion)) {
  throw "Unable to identify Vivado version: $VivadoBat -version"
}
$sourceCommit = (& git -C $repo rev-parse HEAD).Trim()
$constraintInputs = @(
  (Join-Path $PSScriptRoot 'run_ooc_thermo5_axil_control.tcl'),
  (Join-Path $PSScriptRoot 'route_ooc_thermo5_axil_from_checkpoint.tcl')
)
$constraintHashes = @($constraintInputs | ForEach-Object {
  (Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash.ToLowerInvariant()
})
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutRoot)) {
  $OutRoot = Join-Path $repo "runs\thermo5_axil_ab_ppa_$stamp"
} else {
  $OutRoot = [System.IO.Path]::GetFullPath($OutRoot)
  if (Test-Path -LiteralPath $OutRoot) { throw "Refusing to overwrite existing PPA directory: $OutRoot" }
}
New-Item -ItemType Directory -Path $OutRoot | Out-Null
$OutRoot = (Resolve-Path -LiteralPath $OutRoot).Path
$rows = @(
  @{ Name = 'A_causal_first'; Interpolation = 'causal'; TidOrder = 1 },
  @{ Name = 'B_cubic_first'; Interpolation = 'centered-cubic'; TidOrder = 1 },
  @{ Name = 'C_causal_ef2'; Interpolation = 'causal'; TidOrder = 2 },
  @{ Name = 'D_cubic_ef2'; Interpolation = 'centered-cubic'; TidOrder = 2 }
)
$part = 'xczu15eg-ffvb1156-2-i'
$routeTcl = Join-Path $PSScriptRoot 'route_ooc_thermo5_axil_from_checkpoint.tcl'
$synthResults = @()

foreach ($row in $rows) {
  $dir = Join-Path $OutRoot $row.Name
  $log = Join-Path $OutRoot "$($row.Name)_synth.log"
  & (Join-Path $PSScriptRoot 'run_ooc_thermo5_axil_control.ps1') `
    -Implementation synth -Part $part -SourceMHz 125 -CoreMHz 218.75 -AxilMHz 100 `
    -OutDir $dir -VivadoBat $VivadoBat -Interpolation $row.Interpolation `
    -TidOrder $row.TidOrder -Step 5120 -DpdMaxTaps 1 -UseXpmFifo 1 *> $log
  $dcp = Join-Path $dir 'synthesized.dcp'
  $config = Join-Path $dir 'elaborated_configuration.txt'
  if (!(Test-Path -LiteralPath $dcp) -or !(Test-Path -LiteralPath $config)) {
    throw "Synthesis evidence missing for $($row.Name)"
  }
  $synthResults += [pscustomobject]@{ Name = $row.Name; Checkpoint = $dcp; Config = $config; Log = $log }
}

Write-Host 'THERMO5_AB_ALL_SYNTH_PASS; starting matched checkpoint routes.'
$routeResults = @()
foreach ($item in $synthResults) {
  $routeDir = Join-Path $OutRoot "$($item.Name)_route"
  New-Item -ItemType Directory -Path $routeDir | Out-Null
  $log = Join-Path $routeDir 'vivado_route.log'
  & $VivadoBat -mode batch -source $routeTcl -tclargs $item.Checkpoint $routeDir synth $RouteDirective *> $log
  if ($LASTEXITCODE -ne 0) { throw "Route failed for $($item.Name); see $log" }
  $summaryPath = Join-Path $routeDir 'summary.csv'
  if (!(Test-Path -LiteralPath $summaryPath)) { throw "Route summary missing for $($item.Name)" }
  $summary = Import-Csv -LiteralPath $summaryPath
  if ($summary.Status -ne 'PASS') { throw "Route timing failed for $($item.Name): $($summary.Status)" }
  $routeResults += [pscustomobject]@{
    Case = $item.Name
    Checkpoint = $item.Checkpoint
    Configuration = $item.Config
    RouteLog = $log
    SourceCommit = $sourceCommit
    VivadoVersion = ($vivadoVersion -replace '[\r\n,]+', ' ')
    ConstraintTclSha256 = ($constraintHashes -join ';')
    RouteDirective = $RouteDirective
    Summary = $summaryPath
    Utilization = (Join-Path $routeDir 'utilization.rpt')
    Timing = (Join-Path $routeDir 'timing_summary.rpt')
    Power = (Join-Path $routeDir 'vectorless_power.rpt')
    Activity = 'VIVADO_VECTORLESS_NO_SAIF'
  }
}
$routeResults | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $OutRoot 'ab_ppa_manifest.csv')
Write-Host "THERMO5_AB_ROUTED_PPA_PASS manifest=$(Join-Path $OutRoot 'ab_ppa_manifest.csv')"

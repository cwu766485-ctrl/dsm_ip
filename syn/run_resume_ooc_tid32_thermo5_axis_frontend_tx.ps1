param(
  [Parameter(Mandatory=$true)][ValidateSet('route','report')][string]$Stage,
  [Parameter(Mandatory=$true)][string]$OutDir,
  [string]$PhysoptCheckpoint = '',
  [string]$VivadoSettings = 'D:\Xilinx\Vivado\2024.1\settings64.bat'
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (!(Test-Path -LiteralPath $VivadoSettings)) {
  throw "Vivado settings are unavailable: $VivadoSettings"
}
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
if ($Stage -eq 'route') {
  if ([string]::IsNullOrWhiteSpace($PhysoptCheckpoint) -or !(Test-Path -LiteralPath $PhysoptCheckpoint)) {
    throw 'A valid -PhysoptCheckpoint is required for route stage.'
  }
  if (Test-Path -LiteralPath $OutDir) { throw "Refusing to reuse existing output directory: $OutDir" }
  New-Item -ItemType Directory -Path $OutDir | Out-Null
  $tcl = Join-Path $PSScriptRoot 'resume_ooc_tid32_thermo5_axis_frontend_tx_route.tcl'
  $vivadoCmd = "call `"$VivadoSettings`" >nul && vivado -mode batch -source `"$tcl`" -tclargs `"$PhysoptCheckpoint`" `"$OutDir`" > `"$(Join-Path $OutDir 'route.log')`" 2>&1"
  & cmd.exe /d /c $vivadoCmd
  if ($LASTEXITCODE -ne 0) { throw "Route resume failed: exit=$LASTEXITCODE; inspect $(Join-Path $OutDir 'route.log')" }
  if (!(Test-Path -LiteralPath (Join-Path $OutDir 'routed.dcp'))) { throw "Routed checkpoint missing: $OutDir" }
  if (!(Select-String -LiteralPath (Join-Path $OutDir 'route.log') -Pattern 'THERMO5_AXIS_RESUME_ROUTE_STATUS=PASS' -Quiet)) {
    throw "Route PASS marker missing; inspect $(Join-Path $OutDir 'route.log')"
  }
} else {
  if (!(Test-Path -LiteralPath $OutDir) -or !(Test-Path -LiteralPath (Join-Path $OutDir 'routed.dcp'))) {
    throw "Report stage requires an existing routed checkpoint: $OutDir"
  }
  $tcl = Join-Path $PSScriptRoot 'report_ooc_tid32_thermo5_axis_frontend_tx_routed.tcl'
  $vivadoCmd = "call `"$VivadoSettings`" >nul && vivado -mode batch -source `"$tcl`" -tclargs `"$OutDir`" > `"$(Join-Path $OutDir 'report.log')`" 2>&1"
  & cmd.exe /d /c $vivadoCmd
  if ($LASTEXITCODE -ne 0) { throw "Routed-report stage failed: exit=$LASTEXITCODE; inspect $(Join-Path $OutDir 'report.log')" }
  if (!(Select-String -LiteralPath (Join-Path $OutDir 'report.log') -Pattern 'THERMO5_AXIS_ROUTED_REPORT_STATUS=PASS' -Quiet)) {
    throw "Routed report PASS marker missing; inspect $(Join-Path $OutDir 'report.log')"
  }
}
if ($Stage -eq 'route') { Get-Content -LiteralPath (Join-Path $OutDir 'router_summary.csv') }
else { Get-Content -LiteralPath (Join-Path $OutDir 'summary.csv') }
Write-Output "Output directory: $OutDir"

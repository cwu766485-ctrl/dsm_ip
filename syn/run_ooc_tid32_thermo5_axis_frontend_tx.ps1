param(
  [string]$VivadoSettings = 'D:\Xilinx\Vivado\2024.1\settings64.bat',
  [string]$Part = 'xczu15eg-ffvb1156-2-i',
  [double]$SourceMHz = 125.0,
  [double]$CoreMHz = 218.75,
  [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (!(Test-Path -LiteralPath $VivadoSettings)) {
  throw "Vivado settings are unavailable: $VivadoSettings"
}
if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $repo (Join-Path 'runs' ("thermo5_full_axis_ooc_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss')))
}
$OutDir = [System.IO.Path]::GetFullPath($OutDir)
if (Test-Path -LiteralPath $OutDir) {
  throw "Refusing to reuse existing output directory: $OutDir"
}
New-Item -ItemType Directory -Path $OutDir | Out-Null
$tcl = Join-Path $PSScriptRoot 'run_ooc_tid32_thermo5_axis_frontend_tx.tcl'
$log = Join-Path $OutDir 'vivado.log'
$arguments = "call `"$VivadoSettings`" >nul && vivado -mode batch -source `"$tcl`" -tclargs $Part $SourceMHz $CoreMHz `"$OutDir`" > `"$log`" 2>&1"
& cmd.exe /d /c $arguments
if ($LASTEXITCODE -ne 0) {
  throw "Thermo5 full AXI-Stream OOC failed: exit=$LASTEXITCODE; inspect $log"
}
if (!(Select-String -LiteralPath $log -Pattern 'THERMO5_AXIS_OOC_STATUS=PASS' -Quiet)) {
  throw "Thermo5 OOC PASS marker missing; inspect $log"
}
if (!(Test-Path -LiteralPath (Join-Path $OutDir 'routed.dcp'))) {
  throw "PASS marker exists but routed checkpoint is absent: $OutDir"
}
Get-Content -LiteralPath (Join-Path $OutDir 'summary.csv')
Write-Output "OOC reports: $OutDir"

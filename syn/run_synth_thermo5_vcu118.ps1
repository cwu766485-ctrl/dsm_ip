param(
  [string]$Part = 'xcvu9p-flga2104-2L-e',
  [string]$VivadoBat = 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat',
  [string]$OutDir = ''
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (!(Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado is unavailable: $VivadoBat"
}
if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $repo "runs\thermo5_vcu118_synth_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
} else {
  $OutDir = [System.IO.Path]::GetFullPath($OutDir)
  if (Test-Path -LiteralPath $OutDir) {
    throw "Refusing to reuse existing output directory: $OutDir"
  }
}
New-Item -ItemType Directory -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path
$tcl = Join-Path $PSScriptRoot 'run_synth_thermo5_vcu118.tcl'
$log = Join-Path $OutDir 'vivado.log'
$command = 'call "{0}" -mode batch -source "{1}" -tclargs "{2}" "{3}" > "{4}" 2>&1' -f `
  $VivadoBat, $tcl, $Part, $OutDir, $log
& $env:ComSpec /d /c $command
$vivadoExit = $LASTEXITCODE
if ($vivadoExit -ne 0) {
  throw "Thermo5 VCU118 synthesis failed: exit=$vivadoExit; inspect $log"
}
if (!(Select-String -LiteralPath $log -Pattern 'THERMO5_VCU118_SYNTH_STATUS=PASS' -Quiet)) {
  throw "Thermo5 VCU118 synthesis PASS marker missing; inspect $log"
}
foreach ($artifact in @('synthesized.dcp', 'synth_utilization.rpt', 'synth_timing_summary.rpt')) {
  if (!(Test-Path -LiteralPath (Join-Path $OutDir $artifact))) {
    throw "Expected synthesis artifact is missing: $artifact"
  }
}
Write-Host "THERMO5_VCU118_SYNTH_PASS part=$Part top=tid32_thermo5_axis_frontend_tx output=$OutDir"

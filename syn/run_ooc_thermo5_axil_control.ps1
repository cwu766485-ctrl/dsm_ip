param(
  [ValidateSet('synth','quick','full','timing')][string]$Implementation = 'full',
  [string]$Part = 'xczu15eg-ffvb1156-2-i',
  [double]$CoreMHz = 218.75,
  [double]$SourceMHz = 125.0,
  [double]$AxilMHz = 100.0,
  [string]$OutDir = '',
  [string]$VivadoBat = 'D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat',
  [ValidateSet('causal','centered-cubic')][string]$Interpolation = 'causal',
  [ValidateSet(1,2)][int]$TidOrder = 1,
  [ValidateSet(5120)][int]$Step = 5120,
  [ValidateSet(1)][int]$DpdMaxTaps = 1,
  [ValidateSet(1)][int]$UseXpmFifo = 1
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
$stderr = Join-Path $OutDir 'vivado.stderr.log'
$arguments = @('-mode', 'batch', '-source', $tcl, '-tclargs', $Part, $SourceMHz,
  $CoreMHz, $AxilMHz, $OutDir, $Implementation, $centered, $TidOrder, $Step,
  $DpdMaxTaps, $UseXpmFifo)
$process = Start-Process -FilePath $VivadoBat -ArgumentList $arguments -Wait -PassThru `
  -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $stderr
if (Test-Path -LiteralPath $stderr) {
  Add-Content -LiteralPath $log -Value (Get-Content -LiteralPath $stderr)
  Remove-Item -LiteralPath $stderr
}
if ($process.ExitCode -ne 0) { throw "AXI-Lite wrapper OOC failed (exit=$($process.ExitCode)); see $log" }
if ($Implementation -eq 'synth') {
  $checkpoint = Join-Path $OutDir 'synthesized.dcp'
  $utilization = Join-Path $OutDir 'synth_utilization.rpt'
  $synthSummary = Join-Path $OutDir 'synth_summary.csv'
  $timing = @('synth_timing_summary.rpt', 'synth_timing_paths.rpt',
    'synth_unconstrained_paths.rpt', 'synth_check_timing.rpt')
  if (!(Test-Path -LiteralPath $checkpoint) -or !(Test-Path -LiteralPath $utilization) -or
      !(Test-Path -LiteralPath $synthSummary) -or
      @($timing | Where-Object { !(Test-Path -LiteralPath (Join-Path $OutDir $_)) }).Count -gt 0) {
    throw "AXI-Lite synthesis did not produce the expected DCP, utilization, and timing reports; see $log"
  }
  Write-Host "THERMO5_AXIL_SYNTH_PASS checkpoint=$checkpoint utilization=$utilization log=$log"
  exit 0
}
$summary = Import-Csv -LiteralPath (Join-Path $OutDir 'summary.csv')
$summary | Format-Table -AutoSize
if ($summary.Status -ne 'PASS') { throw "AXI-Lite wrapper routed timing failed: $($summary.Status)" }
Write-Host "THERMO5_AXIL_OOC_PASS log=$log"

param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [switch]$SkipRxCompare,
  [ValidateSet('Baseline','Stress','BadFrames')][string]$Scenario='Baseline',
  [ValidateRange(0,3)][int]$Pattern=2,
  [string]$VivadoBat='D:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out=[System.IO.Path]::GetFullPath($OutDir)
New-Item -ItemType Directory -Force -Path $out | Out-Null
$vivado=[System.IO.Path]::GetFullPath($VivadoBat)
if (!(Test-Path -LiteralPath $vivado)) { throw "Vivado executable is unavailable: $vivado" }
if ($Scenario -ne 'Baseline' -and !$SkipRxCompare) {
  throw 'Stress and BadFrames scenarios require -SkipRxCompare because GT RX recovery is not signed off.'
}
$tcl=Join-Path $repo 'syn\sim_thermo5_qsfp_gt14_parent.tcl'
$stdout=Join-Path $out 'sim_parent.stdout.log'
& $vivado -mode batch -source $tcl -tclargs $out ([int]$SkipRxCompare.IsPresent) $Scenario $Pattern *> $stdout
if ($LASTEXITCODE -ne 0) { throw "GT parent simulation failed; see $stdout" }
$simlog=Join-Path $out 'project\thermo5_qsfp_gt14_parent.sim\sim_1\behav\xsim\simulate.log'
if (!(Test-Path -LiteralPath $simlog)) { throw "Missing XSim result: $simlog" }
$result=Get-Content -LiteralPath $simlog -Raw
$passMarker = switch ($Scenario) {
  'Stress' { 'THERMO5_QSFP_GT14_STRESS_PASS' }
  'BadFrames' { 'THERMO5_QSFP_GT14_BAD_FRAMES_PASS' }
  default { if ($SkipRxCompare) { 'THERMO5_QSFP_GT14_PARENT_TX_SERIAL_SIM_PASS' } else { 'THERMO5_QSFP_GT14_PARENT_SIM_PASS' } }
}
if (!$result.Contains($passMarker) -or
    $result.Contains('Fatal:')) {
  throw "GT parent simulation did not pass; inspect $simlog"
}
Write-Host "GT parent simulation PASS: $simlog"

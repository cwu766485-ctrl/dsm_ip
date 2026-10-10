param(
  [Parameter(Mandatory=$true)][string]$OutDir,
  [switch]$SkipRxCompare
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$out=[System.IO.Path]::GetFullPath($OutDir)
$vivado='D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
if (!(Test-Path -LiteralPath $vivado)) { throw 'Vivado 2024.1 is unavailable.' }
$tcl=Join-Path $repo 'syn\sim_thermo5_qsfp_gt14_parent.tcl'
$stdout=Join-Path $out 'sim_parent.stdout.log'
& $vivado -mode batch -source $tcl -tclargs $out ([int]$SkipRxCompare.IsPresent) *> $stdout
if ($LASTEXITCODE -ne 0) { throw "GT parent simulation failed; see $stdout" }
$simlog=Join-Path $out 'project\thermo5_qsfp_gt14_parent.sim\sim_1\behav\xsim\simulate.log'
if (!(Test-Path -LiteralPath $simlog)) { throw "Missing XSim result: $simlog" }
$result=Get-Content -LiteralPath $simlog -Raw
$passMarker = if ($SkipRxCompare) { 'THERMO5_QSFP_GT14_PARENT_RESET_SIM_PASS' } else { 'THERMO5_QSFP_GT14_PARENT_SIM_PASS' }
if (!$result.Contains($passMarker) -or
    $result.Contains('Fatal:')) {
  throw "GT parent simulation did not pass; inspect $simlog"
}
Write-Host "GT parent simulation PASS: $simlog"

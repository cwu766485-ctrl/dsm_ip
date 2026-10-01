param(
  [ValidateSet('thermo3','thermo5')][string]$Flavour = 'thermo3',
  [string]$Part = 'xczu15eg-ffvb1156-2-i',
  [double]$CoreMHz = 218.75,
  [ValidateSet('continuous','burst','idle')][string]$Workload = 'continuous',
  [Parameter(Mandatory=$true)][string]$ActivityFile,
  [string]$VivadoBat = 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat'
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable is unavailable: $VivadoBat" }
$activity = (Resolve-Path -LiteralPath $ActivityFile).Path
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$rootOut = Join-Path $repo "syn\out\lp_power_compare_${Flavour}_${Workload}_${stamp}"
New-Item -ItemType Directory -Force -Path $rootOut | Out-Null
$tcl = Join-Path $repo 'syn\run_ooc_tid32_thermo_axis_frontend.tcl'
$rows = @()
foreach ($mode in @('baseline','lp')) {
  $block = if ($mode -eq 'baseline') { $Flavour } else { "${Flavour}_lp" }
  $out = Join-Path $rootOut $mode
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  $log = Join-Path $out 'vivado.log'
  & $VivadoBat -mode batch -source $tcl -tclargs $Part $CoreMHz $block $out full $activity *> $log
  if ($LASTEXITCODE -ne 0) { throw "$mode OOC failed; see $log" }
  $summary = Join-Path $out 'summary.csv'
  if (!(Test-Path $summary)) { throw "$mode did not produce summary.csv" }
  $rows += Import-Csv $summary | Select-Object *,@{N='Mode';E={$mode}},@{N='Workload';E={$Workload}}
}
$rows | Export-Csv (Join-Path $rootOut 'comparison.csv') -NoTypeInformation
@("activity_file=$activity","workload=$Workload") | Set-Content (Join-Path $rootOut 'manifest.txt')
$rows | Format-Table -AutoSize
Write-Host "LP comparison complete: $rootOut"

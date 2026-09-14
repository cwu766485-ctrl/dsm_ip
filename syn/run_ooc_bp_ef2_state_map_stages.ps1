param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [double]$TargetMHz = 218.75,
  [string]$OutRoot = ""
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable not found: $VivadoBat" }
if ([string]::IsNullOrWhiteSpace($OutRoot)) { $OutRoot = Join-Path $PSScriptRoot "reports" }
$OutRoot = [System.IO.Path]::GetFullPath($OutRoot)
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
$script = Join-Path $PSScriptRoot "run_ooc_bp_ef2_state_map_stage.tcl"
$label = ("{0:F2}" -f $TargetMHz).Replace('.', 'p')
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runRoot = Join-Path $OutRoot "bp_ef2_state_map_stages_ooc_$($Part.Replace('-','_').Replace('.','_'))_${label}mhz_$stamp"
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$stages = @('bp_ef2_state_map_leaf4_ooc', 'bp_ef2_state_map_compose8_ooc', 'bp_ef2_state_map_compose16_ooc', 'bp_ef2_state_map_compose32_ooc', 'bp_ef2_state_selector_ooc')
$rows = foreach ($stage in $stages) {
  $stageDir = Join-Path $runRoot $stage
  Write-Host "[ooc] $stage"
  & $VivadoBat -mode batch -source $script -tclargs $stage $Part $TargetMHz $stageDir
  if ($LASTEXITCODE -ne 0) { throw "State-map stage OOC failed for ${stage}: exit=$LASTEXITCODE" }
  $summary = Join-Path $stageDir 'summary.csv'
  if (-not (Test-Path -LiteralPath $summary)) { throw "No summary.csv was created for $stage" }
  Import-Csv -LiteralPath $summary
}
$rows | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $runRoot 'summary.csv')
$rows | Format-Table -AutoSize

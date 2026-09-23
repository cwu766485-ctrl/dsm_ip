param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [double]$CoreMHz = 218.75,
  [string]$OutRoot = ""
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable not found: $VivadoBat" }
if ([string]::IsNullOrWhiteSpace($OutRoot)) { $OutRoot = Join-Path $PSScriptRoot 'out' }
$OutRoot = [System.IO.Path]::GetFullPath($OutRoot)
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
$label = ("{0:F2}" -f $CoreMHz).Replace('.', 'p')
$outDir = Join-Path $OutRoot "dsm_axis14_to_core8_cdc_ooc_$($Part.Replace('-','_'))_${label}mhz_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
& $VivadoBat -mode batch -source (Join-Path $PSScriptRoot 'run_ooc_axis14_to_core8_cdc.tcl') -tclargs $Part $CoreMHz $outDir
if ($LASTEXITCODE -ne 0) { throw "AXIS14-to-core8 CDC OOC failed: exit=$LASTEXITCODE" }
$summary = Join-Path $outDir 'summary.csv'
if (!(Test-Path -LiteralPath $summary)) { throw 'No CDC OOC summary.csv was created' }
$row = Import-Csv -LiteralPath $summary
$row | Format-Table -AutoSize
if ($row.Status -ne 'PASS') { throw "AXIS14-to-core8 CDC OOC timing failed: $($row.Status)" }

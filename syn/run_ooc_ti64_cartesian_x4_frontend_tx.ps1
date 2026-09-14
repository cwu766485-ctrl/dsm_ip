param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [double]$TargetMHz = 218.75,
  [string]$OutRoot = ""
)

$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable not found: $VivadoBat" }
if ([string]::IsNullOrWhiteSpace($OutRoot)) { $OutRoot = Join-Path $PSScriptRoot 'reports' }
$OutRoot = [System.IO.Path]::GetFullPath($OutRoot)
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
$label = ("{0:F2}" -f $TargetMHz).Replace('.', 'p')
$outDir = Join-Path $OutRoot "ti64_cartesian_x4_frontend_tx_ooc_$($Part.Replace('-','_'))_${label}mhz_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
& $VivadoBat -mode batch -source (Join-Path $PSScriptRoot 'run_ooc_ti64_cartesian_x4_frontend_tx.tcl') -tclargs $Part $TargetMHz $outDir
if ($LASTEXITCODE -ne 0) { throw "TI64 Cartesian x4 frontend OOC failed: exit=$LASTEXITCODE" }
$summary = Join-Path $outDir 'summary.csv'
if (!(Test-Path -LiteralPath $summary)) { throw 'No OOC summary.csv was created' }
Import-Csv -LiteralPath $summary | Format-Table -AutoSize

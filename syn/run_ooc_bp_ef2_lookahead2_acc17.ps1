param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [double]$TargetMHz = 218.75
)
$ErrorActionPreference = "Stop"
$script = Join-Path $PSScriptRoot "run_ooc_bp_ef2_lookahead2_acc17.tcl"
if (-not (Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable not found: $VivadoBat" }
& $VivadoBat -mode batch -source $script -tclargs $Part $TargetMHz
$exitCode = $LASTEXITCODE
$label = ("{0:F2}" -f $TargetMHz).Replace('.', 'p')
$latest = Get-ChildItem (Join-Path $PSScriptRoot "reports") -Directory `
  -Filter "bp_ef2_lookahead2_acc17_ooc_*_${label}mhz_*" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $latest) { throw "No lookahead2_acc17 OOC output was created. Vivado exit=$exitCode" }
$summary = Join-Path $latest.FullName "summary.csv"
if (-not (Test-Path -LiteralPath $summary)) { throw "No lookahead2_acc17 summary.csv was created. Vivado exit=$exitCode" }
Write-Host "Lookahead2_acc17 OOC summary: $summary"
Get-Content -LiteralPath $summary
if ($exitCode -ne 0) { throw "Lookahead2_acc17 OOC tool failed: exit=$exitCode" }

param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [double]$TargetMHz = 218.75
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $VivadoBat)) { throw "Vivado executable not found: $VivadoBat" }
$script = Join-Path $PSScriptRoot "run_ooc_bp_ef2_parallel8.tcl"
& $VivadoBat -mode batch -source $script -tclargs $Part $TargetMHz
$exitCode = $LASTEXITCODE
$label = ("{0:F2}" -f $TargetMHz).Replace('.', 'p')
$latest = Get-ChildItem (Join-Path $PSScriptRoot "reports") -Directory `
  -Filter "bp_ef2_parallel8_ooc_*_${label}mhz_*" |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $latest) { throw "No parallel8 OOC output was created. Vivado exit=$exitCode" }
$summary = Join-Path $latest.FullName "summary.csv"
if (-not (Test-Path -LiteralPath $summary)) { throw "No parallel8 summary.csv was created. Vivado exit=$exitCode" }
$row = Import-Csv -LiteralPath $summary
Write-Host "Parallel8 OOC summary: $summary"
if ($exitCode -ne 0 -or $row.Status -ne "PASS") { throw "Parallel8 OOC failed: status=$($row.Status) exit=$exitCode" }
Write-Host "Parallel8 OOC PASS: WNS=$($row.WNS_ns) ns Fmax=$($row.Fmax_est_MHz) MHz"

param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [double]$TargetMHz = 100.0
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado executable not found: $VivadoBat"
}
if ($TargetMHz -le 0.0) {
  throw "TargetMHz must be positive."
}

$script = Join-Path $PSScriptRoot "run_performance_sku_routed.tcl"
& $VivadoBat -mode batch -source $script -tclargs $Part $TargetMHz
if ($LASTEXITCODE -ne 0) {
  throw "Performance SKU routed implementation failed."
}

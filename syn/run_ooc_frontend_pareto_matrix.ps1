param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xc7z020clg400-1"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado executable not found: $VivadoBat"
}

$script = Join-Path $PSScriptRoot "run_ooc_frontend_pareto_matrix.tcl"
& $VivadoBat -mode batch -source $script -tclargs $Part
if ($LASTEXITCODE -ne 0) {
  throw "Frontend Pareto OOC matrix run failed"
}

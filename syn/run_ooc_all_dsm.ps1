param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xc7z020clg400-1"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado executable not found: $VivadoBat"
}

$script = Join-Path $PSScriptRoot "run_ooc_all_dsm.tcl"
& $VivadoBat -mode batch -source $script -tclargs $Part
if ($LASTEXITCODE -ne 0) {
  throw "Vivado OOC run failed"
}

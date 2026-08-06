param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xczu15eg-ffvb1156-2-i"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado executable not found: $VivadoBat"
}

$script = Join-Path $PSScriptRoot "run_ooc_bp_ef2_axi.tcl"
& $VivadoBat -mode batch -source $script -tclargs $Part
if ($LASTEXITCODE -ne 0) {
  throw "BP EFDSM2 AXI OOC synthesis failed"
}

param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $VivadoBat)) {
  throw "Vivado executable not found: $VivadoBat"
}

$script = Join-Path $PSScriptRoot "package_vivado_ip.tcl"
& $VivadoBat -mode batch -source $script
if ($LASTEXITCODE -ne 0) {
  throw "Vivado IP packaging failed"
}

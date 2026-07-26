param(
  [string]$Vivado = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Vivado)) { throw "Vivado was not found: $Vivado" }
& $Vivado -mode batch -source (Join-Path $PSScriptRoot "package_dpd_observer_bridge.tcl")
if ($LASTEXITCODE -ne 0) { throw "DPD observer bridge IP packaging failed with exit code $LASTEXITCODE" }

param(
  [string]$Vivado = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Vivado)) { throw "Vivado was not found: $Vivado" }
$root = Split-Path -Parent $PSScriptRoot
& $Vivado -mode batch -source (Join-Path $PSScriptRoot "run_ooc_dpd_matrix.tcl")
if ($LASTEXITCODE -ne 0) { throw "DPD OOC matrix failed with exit code $LASTEXITCODE" }

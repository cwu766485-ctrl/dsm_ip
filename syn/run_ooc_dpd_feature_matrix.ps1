param(
  [string]$Part = "xczu15eg-ffvb1156-2-i",
  [string]$Config = "",
  [string]$Vivado = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Vivado)) { throw "Vivado was not found: $Vivado" }

Push-Location $PSScriptRoot
try {
  & $Vivado -mode batch -source (Join-Path $PSScriptRoot "run_ooc_dpd_feature_matrix.tcl") -tclargs $Part $Config
  if ($LASTEXITCODE -ne 0) { throw "DPD feature-gate OOC matrix failed with exit code $LASTEXITCODE" }
} finally {
  Pop-Location
}

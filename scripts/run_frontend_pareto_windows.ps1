param(
  [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat",
  [string]$Part = "xc7z020clg400-1",
  [switch]$Run28Only
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if ($Run28Only) {
  Write-Host "[1/1] MATLAB 28-point diagnostic matrix (24 primary + D4 extension)"
  & (Join-Path $repo "scripts\run_matlab_frontend_dsm_pareto_matrix_28.cmd")
  if ($LASTEXITCODE -ne 0) { throw "MATLAB 28-point diagnostic matrix failed" }
  return
}

Write-Host "[1/3] MATLAB 24-point I0/I1/I2/I3 x D0/D1/D2/D3/D5/D6 quality matrix"
& (Join-Path $repo "scripts\run_matlab_frontend_dsm_pareto_matrix.cmd")
if ($LASTEXITCODE -ne 0) { throw "MATLAB Pareto matrix failed" }

Write-Host "[2/3] XSim I0/I1/I2/I3 bit-true and valid/ready regression"
powershell -NoProfile -ExecutionPolicy Bypass -File `
  (Join-Path $repo "verif\scripts\run_xsim_interp_frontend.ps1")

Write-Host "[3/3] Vivado module OOC: I0/I1/I2/I3, D0..D6, Memory-Poly5"
powershell -NoProfile -ExecutionPolicy Bypass -File `
  (Join-Path $repo "syn\run_ooc_frontend_pareto_matrix.ps1") `
  -VivadoBat $VivadoBat -Part $Part

Write-Host "Stage 1 complete. Review matlab\out\frontend_dsm_pareto and syn\reports\ooc_frontend_pareto_* before selecting 4-6 full-synthesis finalists."

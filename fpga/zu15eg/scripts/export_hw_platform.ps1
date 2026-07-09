param(
    [string]$Project = ".\fpga\zu15eg\local_hw\pl_ps_gpio_test\pl_ps_gpio_test.xpr",
    [string]$OutXsa = ".\fpga\zu15eg\out\dsm_dpd_zu15eg.xsa",
    [string]$VivadoBat = "D:\Xilinx\Vivado\2024.1\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$projectPath = Resolve-Path (Join-Path $repoRoot $Project)
$outPath = Join-Path $repoRoot $OutXsa
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if (!(Test-Path $VivadoBat)) {
    throw "Vivado not found: $VivadoBat"
}

$env:ZU15EG_PROJECT = $projectPath.Path
$env:ZU15EG_OUT_XSA = $outPath

& $VivadoBat -mode batch -source (Join-Path $PSScriptRoot "export_hw_platform.tcl")
if ($LASTEXITCODE -ne 0) {
    throw "Vivado hardware platform export failed with exit code $LASTEXITCODE"
}

if (!(Test-Path $outPath)) {
    throw "Expected XSA was not created: $outPath"
}

Write-Host "Exported XSA: $outPath"

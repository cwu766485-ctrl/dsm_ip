param(
    [string]$Xsa = ".\fpga\zu15eg\out\dsm_dpd_zu15eg.xsa",
    [string]$Workspace = ".\fpga\zu15eg\out\vitis_baremetal",
    [string]$VitisBat = "D:\Xilinx\Vitis\2024.1\bin\vitis.bat"
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")
$xsaPath = Resolve-Path (Join-Path $repoRoot $Xsa)
$workspacePath = Join-Path $repoRoot $Workspace

if (!(Test-Path $VitisBat)) {
    throw "Vitis not found: $VitisBat"
}

New-Item -ItemType Directory -Force -Path $workspacePath | Out-Null

$env:DSM_REPO_ROOT = $repoRoot.Path
$env:DSM_XSA = $xsaPath.Path
$env:DSM_VITIS_WS = $workspacePath

& $VitisBat -s (Join-Path $PSScriptRoot "build_baremetal_smoke.py")
if ($LASTEXITCODE -ne 0) {
    throw "Vitis bare-metal build failed with exit code $LASTEXITCODE"
}

$elf = Get-ChildItem -Path $workspacePath -Recurse -Filter "dsm_dpd_baremetal_smoke.elf" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $elf) {
    throw "Expected ELF was not created under: $workspacePath"
}

Write-Host "Built ELF: $($elf.FullName)"

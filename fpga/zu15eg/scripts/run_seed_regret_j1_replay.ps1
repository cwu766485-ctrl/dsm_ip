param(
    [string]$Report = ".\matlab\out\dpd\final_policy\dpd_ai_final_policy.json",
    [string]$CReference = ".\fpga\zu15eg\baremetal\src\dpd_ai_policy.h",
    [string]$Elf = ".\fpga\zu15eg\out\vitis_baremetal\dsm_dpd_baremetal_smoke\build\dsm_dpd_baremetal_smoke.elf",
    [switch]$PrintOnly
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$reportPath = Resolve-Path (Join-Path $repoRoot $Report)
$referencePath = Join-Path $repoRoot $CReference
$reportData = Get-Content -Raw $reportPath | ConvertFrom-Json

if (-not $reportData.simulation_only -or -not $reportData.deployment_qualified) {
    throw "J1 replay is blocked: the final AI seed policy did not pass grouped simulation gates."
}
if ($reportData.dsm_config_id -ne "efdsm_1bit_osr32_interp0") {
    throw "J1 replay is blocked: the report does not have EFDSM provenance."
}
if (-not (Test-Path $referencePath)) {
    throw "J1 replay is blocked: the generated AI policy header is absent."
}
if ($reportData.direct_allowed) {
    throw "J1 replay is blocked: the qualified policy must keep direct execution disabled."
}

Write-Host "Simulation gate passed. J1 replay uses AI seed selection plus mandatory bounded search."
Write-Host "The resulting trace is a PL monitor proxy only; it is not RF EVM/ACLR evidence."
$runner = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.ps1"
& $runner -Elf $Elf -PrintOnly:$PrintOnly
if ($LASTEXITCODE -ne 0) {
    throw "J1 replay launch failed with exit code $LASTEXITCODE."
}

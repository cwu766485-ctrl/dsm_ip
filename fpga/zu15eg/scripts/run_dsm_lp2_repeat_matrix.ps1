param(
    [string]$Project = ".\fpga\zu15eg\local_hw\pl_ps_gpio_test\pl_ps_gpio_test.xpr",
    [string]$StabilityReport = ".\fpga\zu15eg\out\dsm_repeat_matrix\dataset\initial_repeat_statistics.md",
    [string]$OutRoot = ".\fpga\zu15eg\out\dsm_repeat_matrix\lpdsm2_1bit_osr32_interp0",
    [int]$WaveformSeed = 101,
    [int]$TargetRepeats = 3,
    [switch]$SkipBitstreamBuild,
    [switch]$SkipXsaExport,
    [switch]$SkipProgram
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$reportPath = if ([IO.Path]::IsPathRooted($StabilityReport)) { $StabilityReport } else { Join-Path $repoRoot $StabilityReport }
if (!(Test-Path $reportPath)) { throw "Stability report does not exist: $reportPath" }
if ((Get-Content -Raw $reportPath) -notmatch 'Third DSM collection allowed: `1`') {
    throw "LPDSM2 collection is blocked: the repeat-stability gate has not passed."
}

$outPath = if ([IO.Path]::IsPathRooted($OutRoot)) { $OutRoot } else { Join-Path $repoRoot $OutRoot }
$manifest = Join-Path $outPath "manifest.csv"
$localRoot = Join-Path $outPath "policy_local_search"
$package = Join-Path $repoRoot "ip\package_vivado_ip.ps1"
$rebuild = Join-Path $repoRoot "fpga\zu15eg\scripts\rebuild_dsm_board_bitstream.ps1"
$exportXsa = Join-Path $repoRoot "fpga\zu15eg\scripts\export_hw_platform.ps1"
$fullMatrix = Join-Path $repoRoot "fpga\zu15eg\scripts\run_trace_matrix.ps1"
$localMatrix = Join-Path $repoRoot "fpga\zu15eg\scripts\run_repeat_policy_local_search_matrix.ps1"
New-Item -ItemType Directory -Force -Path $outPath | Out-Null

if (!$SkipBitstreamBuild) {
    # Keep the 1-bit output and monitor semantics comparable to EFDSM and EFDSM2.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $package
    if ($LASTEXITCODE -ne 0) { throw "Vivado IP packaging failed." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $rebuild -Project $Project -Algorithm 1 -InterpMode 0
    if ($LASTEXITCODE -ne 0) { throw "LPDSM2 bitstream build failed." }
}
if (!$SkipXsaExport) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $exportXsa -Project $Project
    if ($LASTEXITCODE -ne 0) { throw "LPDSM2 XSA export failed." }
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $fullMatrix `
    -ManifestCsv $manifest -DsmConfigId "lpdsm2_1bit_osr32_interp0" `
    -DsmAlgorithm 1 -DsmQuantizerBits 1 -DsmInterpMode 0 -DsmOsr 32 `
    -WaveformSeed $WaveformSeed -RepeatsPerScenario $TargetRepeats -SkipProgram:$SkipProgram
if ($LASTEXITCODE -ne 0) { throw "LPDSM2 full-calibration repeat matrix failed." }

& powershell -NoProfile -ExecutionPolicy Bypass -File $localMatrix `
    -ManifestCsv $manifest -OutRoot $localRoot -TargetRepeats $TargetRepeats `
    -WaveformSeed $WaveformSeed -GenerateLosoPolicy -SkipProgram:$SkipProgram
if ($LASTEXITCODE -ne 0) { throw "LPDSM2 bounded-search repeat matrix failed." }

Write-Host "PASS LPDSM2 repeat matrix complete: $outPath"

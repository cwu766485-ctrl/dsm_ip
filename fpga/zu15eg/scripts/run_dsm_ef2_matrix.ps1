param(
    [string]$Project = ".\fpga\zu15eg\local_hw\pl_ps_gpio_test\pl_ps_gpio_test.xpr",
    [string]$OutRoot = ".\fpga\zu15eg\out\dsm_ef2_1bit_osr32_interp0",
    [int]$WaveformSeed = 101,
    [switch]$SkipBitstreamBuild,
    [switch]$SkipXsaExport,
    [switch]$SkipProgram
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$outPath = if ([System.IO.Path]::IsPathRooted($OutRoot)) { $OutRoot } else { Join-Path $repoRoot $OutRoot }
$manifest = Join-Path $outPath "manifest_ef2_1bit_osr32_interp0.csv"
$fullRoot = Join-Path $outPath "full_calibration"
$localRoot = Join-Path $outPath "policy_local_search"
$package = Join-Path $repoRoot "ip\package_vivado_ip.ps1"
$rebuild = Join-Path $repoRoot "fpga\zu15eg\scripts\rebuild_dsm_board_bitstream.ps1"
$exportXsa = Join-Path $repoRoot "fpga\zu15eg\scripts\export_hw_platform.ps1"
$fullMatrix = Join-Path $repoRoot "fpga\zu15eg\scripts\run_trace_matrix.ps1"
$localMatrix = Join-Path $repoRoot "fpga\zu15eg\scripts\run_policy_local_search_matrix.ps1"

New-Item -ItemType Directory -Force -Path $outPath | Out-Null

if (!$SkipBitstreamBuild) {
    # EFDSM2 changes only the DSM loop order; waveform, DPD, DUC, and interpolation remain fixed.
    & powershell -NoProfile -ExecutionPolicy Bypass -File $package
    if ($LASTEXITCODE -ne 0) { throw "Vivado IP packaging failed." }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $rebuild -Project $Project -Algorithm 3 -InterpMode 0
    if ($LASTEXITCODE -ne 0) { throw "EFDSM2 bitstream build failed." }
}

if (!$SkipXsaExport) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $exportXsa -Project $Project
    if ($LASTEXITCODE -ne 0) { throw "EFDSM2 XSA export failed." }
}

& powershell -NoProfile -ExecutionPolicy Bypass -File $fullMatrix `
    -ManifestCsv $manifest `
    -DsmConfigId "ef2_1bit_osr32_interp0" `
    -DsmAlgorithm 3 `
    -DsmQuantizerBits 1 `
    -DsmInterpMode 0 `
    -DsmOsr 32 `
    -WaveformSeed $WaveformSeed `
    -SkipProgram:$SkipProgram
if ($LASTEXITCODE -ne 0) { throw "EFDSM2 full-calibration matrix failed." }

& powershell -NoProfile -ExecutionPolicy Bypass -File $localMatrix `
    -ManifestCsv $manifest `
    -OutRoot $localRoot `
    -WaveformSeed $WaveformSeed `
    -GenerateLosoPolicy `
    -SkipProgram:$SkipProgram
if ($LASTEXITCODE -ne 0) { throw "EFDSM2 policy/local-search matrix failed." }

Write-Host "PASS EFDSM2 matrix complete: $outPath"

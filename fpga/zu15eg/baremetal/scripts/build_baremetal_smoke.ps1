param(
    [string]$Xsa = ".\fpga\zu15eg\out\dsm_dpd_zu15eg.xsa",
    [string]$Workspace = ".\fpga\zu15eg\out\vitis_baremetal",
    [string]$VitisBat = "D:\Xilinx\Vitis\2024.1\bin\vitis.bat",
    [string[]]$Define = @(),
    [double]$SeedQam = -1,
    [double]$SeedUsedSubcarriers = -1,
    [double]$SeedInputBackoff = -1,
    [double]$PolicyQam = -1,
    [double]$PolicyUsedSubcarriers = -1,
    [double]$PolicyInputBackoff = -1,
    [string[]]$PolicyTraceCsv = @(),
    [int]$WaveformQam = -1,
    [int]$WaveformUsedSubcarriers = -1,
    [double]$WaveformInputBackoff = -1,
    [int]$WaveformFftSize = 256,
    [int]$WaveformSeed = 1
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")
$xsaPath = Resolve-Path (Join-Path $repoRoot $Xsa)
$workspacePath = Join-Path $repoRoot $Workspace

if (!(Test-Path $VitisBat)) {
    throw "Vitis not found: $VitisBat"
}

$seedArgs = @($SeedQam, $SeedUsedSubcarriers, $SeedInputBackoff) |
    Where-Object { $_ -ge 0 }
$seedArgsProvided = @($seedArgs).Count
if ($seedArgsProvided -ne 0 -and $seedArgsProvided -ne 3) {
    throw "SeedQam, SeedUsedSubcarriers, and SeedInputBackoff must be supplied together."
}

if ($seedArgsProvided -eq 3) {
    $seedGenerator = Join-Path $repoRoot "fpga\zu15eg\scripts\generate_dpd_seed_table.py"
    $seedHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\dpd_seed.h"
    & python $seedGenerator --qam $SeedQam --used-subcarriers $SeedUsedSubcarriers --input-backoff $SeedInputBackoff --header $seedHeader --prefix "dpd_seed_build"
    if ($LASTEXITCODE -ne 0) {
        throw "DPD seed header generation failed with exit code $LASTEXITCODE"
    }
}

$policyArgs = @($PolicyQam, $PolicyUsedSubcarriers, $PolicyInputBackoff) |
    Where-Object { $_ -ge 0 }
$policyArgsProvided = @($policyArgs).Count
if ($policyArgsProvided -ne 0 -and $policyArgsProvided -ne 3) {
    throw "PolicyQam, PolicyUsedSubcarriers, and PolicyInputBackoff must be supplied together."
}

if ($policyArgsProvided -eq 3) {
    $policyTrainer = Join-Path $repoRoot "fpga\zu15eg\scripts\train_dpd_trace_policy.py"
    $policyHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\dpd_trace_policy.h"
    $policyArgs = @("--qam", $PolicyQam, "--used-subcarriers", $PolicyUsedSubcarriers,
                    "--input-backoff", $PolicyInputBackoff, "--header", $policyHeader,
                    "--prefix", "dpd_trace_policy_build")
    foreach ($trace in $PolicyTraceCsv) {
        $policyArgs += @("--trace-csv", $trace)
    }
    & python $policyTrainer @policyArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Trace policy generation failed with exit code $LASTEXITCODE"
    }
}

$waveformArgs = @($WaveformQam, $WaveformUsedSubcarriers, $WaveformInputBackoff) |
    Where-Object { $_ -ge 0 }
$waveformArgsProvided = @($waveformArgs).Count
if ($waveformArgsProvided -ne 0 -and $waveformArgsProvided -ne 3) {
    throw "WaveformQam, WaveformUsedSubcarriers, and WaveformInputBackoff must be supplied together."
}

if ($waveformArgsProvided -eq 3) {
    $waveformGenerator = Join-Path $repoRoot "fpga\zu15eg\scripts\generate_dpd_tx_waveform.py"
    $waveformHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\dpd_tx_waveform.h"
    & python $waveformGenerator --qam $WaveformQam --used-subcarriers $WaveformUsedSubcarriers `
        --input-backoff $WaveformInputBackoff --fft-size $WaveformFftSize --seed $WaveformSeed `
        --header $waveformHeader
    if ($LASTEXITCODE -ne 0) {
        throw "DPD TX waveform generation failed with exit code $LASTEXITCODE"
    }
} else {
    # Avoid silently reusing a waveform from a different calibration condition.
    $waveformHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\dpd_tx_waveform.h"
    if (Test-Path $waveformHeader) {
        Remove-Item -LiteralPath $waveformHeader -Force
    }
}

New-Item -ItemType Directory -Force -Path $workspacePath | Out-Null

$env:DSM_REPO_ROOT = $repoRoot.Path
$env:DSM_XSA = $xsaPath.Path
$env:DSM_VITIS_WS = $workspacePath
$env:DSM_CAL_DEFINES = ($Define -join ";")

& $VitisBat -s (Join-Path $PSScriptRoot "build_baremetal_smoke.py")
if ($LASTEXITCODE -ne 0) {
    throw "Vitis bare-metal build failed with exit code $LASTEXITCODE"
}

$elf = Get-ChildItem -Path $workspacePath -Recurse -Filter "dsm_dpd_baremetal_smoke.elf" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $elf) {
    throw "Expected ELF was not created under: $workspacePath"
}

Write-Host "Built ELF: $($elf.FullName)"

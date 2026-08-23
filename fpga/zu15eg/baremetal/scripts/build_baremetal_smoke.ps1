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
    [int]$WaveformSeed = 1,
    [switch]$IlaGolden
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")
$xsaPath = Resolve-Path (Join-Path $repoRoot $Xsa)
$workspacePath = Join-Path $repoRoot $Workspace
$ilaGoldenHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\ila_golden_waveform.h"

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
    # Keep the checked-in deterministic smoke waveform. A board build must not
    # silently delete a tracked source artifact when no new waveform is asked
    # for; callers that need a labelled condition pass all waveform arguments.
    $waveformHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\dpd_tx_waveform.h"
    if (-not (Test-Path $waveformHeader)) {
        throw "No deterministic DMA waveform found: $waveformHeader. Supply all Waveform* arguments."
    }
}

if ($IlaGolden) {
    $ilaGenerator = Join-Path $repoRoot "fpga\zu15eg\scripts\generate_ila_golden.py"
    $ilaOutDir = Join-Path $repoRoot "fpga\zu15eg\out\ila_golden_memory_pkg0"
    & python $ilaGenerator --out-dir $ilaOutDir --header $ilaGoldenHeader
    if ($LASTEXITCODE -ne 0) {
        throw "ILA golden-vector generation failed with exit code $LASTEXITCODE"
    }
    $Define += "CAL_ILA_GOLDEN_ONLY=1"
} elseif (Test-Path $ilaGoldenHeader) {
    Remove-Item -LiteralPath $ilaGoldenHeader -Force
}

New-Item -ItemType Directory -Force -Path $workspacePath | Out-Null

# Vitis 2024.1's Python client decodes its launcher output as UTF-8. On a
# Windows account whose profile path contains non-ASCII characters, that can
# fail before platform creation. Keep this build's tool state in repository
# local ASCII paths; this only affects the Vitis child process launched below.
$vitisStateRoot = Join-Path $repoRoot ".Xil\vitis_baremetal_state"
$vitisTempRoot = Join-Path $repoRoot ".Xil\vitis_baremetal_tmp"
New-Item -ItemType Directory -Force -Path $vitisStateRoot, $vitisTempRoot | Out-Null
$env:USERPROFILE = $vitisStateRoot
$env:HOME = $vitisStateRoot
$env:APPDATA = $vitisStateRoot
$env:LOCALAPPDATA = $vitisStateRoot
$env:TEMP = $vitisTempRoot
$env:TMP = $vitisTempRoot

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

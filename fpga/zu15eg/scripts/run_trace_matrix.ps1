param(
    [string]$ManifestCsv = ".\fpga\zu15eg\out\trace_matrix\manifest_waveform_only.csv",
    [string]$PaProfile = "nominal_no_external_feedback",
    [double]$PaStrengthDb = 0.0,
    [string]$CalibrationProfile = "default_v1",
    [string]$DsmConfigId = "efdsm_1bit_osr32_interp0",
    [ValidateRange(0, 13)]
    [int]$DsmAlgorithm = 2,
    [ValidateRange(1, 16)]
    [int]$DsmQuantizerBits = 1,
    [ValidateRange(0, 4)]
    [int]$DsmInterpMode = 0,
    [ValidateRange(1, 4096)]
    [int]$DsmOsr = 32,
    [int]$WaveformSeed = 101,
    [int]$RepeatsPerScenario = 1,
    [switch]$SkipProgram
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$outRoot = Join-Path $repoRoot "fpga\zu15eg\out\trace_matrix"
$builder = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\build_baremetal_direct.ps1"
$runner = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.ps1"
$capture = Join-Path $repoRoot "fpga\zu15eg\scripts\capture_calibration_trace.ps1"
$targetCheck = Join-Path $repoRoot "fpga\zu15eg\scripts\xsdb_require_targets.tcl"
$xsdb = "D:\Xilinx\Vitis\2024.1\bin\xsdb.bat"

New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
if ($RepeatsPerScenario -lt 1) { throw "RepeatsPerScenario must be at least 1." }
$manifestPath = if ([System.IO.Path]::IsPathRooted($ManifestCsv)) { $ManifestCsv } else { Join-Path $repoRoot $ManifestCsv }
$completedScenarioCounts = @{}
if (Test-Path $manifestPath) {
    Import-Csv $manifestPath | ForEach-Object {
        $id = $_.scenario_id
        $completedScenarioCounts[$id] = 1 + [int]($completedScenarioCounts[$id])
    }
}

# Keep DSM configurations and PA conditions disjoint in a combined manifest.
if ($PaProfile -eq "nominal_no_external_feedback" -and $PaStrengthDb -eq 0.0) {
    $scenarioPrefix = if ($DsmConfigId -eq "efdsm_1bit_osr32_interp0") {
        "board_nominal"
    } else {
        "board_${DsmConfigId}_nominal"
    }
} else {
    $profileId = ($PaProfile.ToLowerInvariant() -replace "[^a-z0-9]+", "_").Trim("_")
    $strengthId = if ($PaStrengthDb -lt 0.0) {
        "m$([math]::Round([math]::Abs($PaStrengthDb) * 10))"
    } else {
        "p$([math]::Round($PaStrengthDb * 10))"
    }
    $scenarioPrefix = "board_${DsmConfigId}_${profileId}_pa_${strengthId}"
}

$scenarios = @(
    @{ Qam = 16; BandwidthMhz = 20; UsedSubcarriers = 48; InputBackoff = 0.58 },
    @{ Qam = 16; BandwidthMhz = 20; UsedSubcarriers = 48; InputBackoff = 0.70 },
    @{ Qam = 16; BandwidthMhz = 40; UsedSubcarriers = 96; InputBackoff = 0.58 },
    @{ Qam = 16; BandwidthMhz = 40; UsedSubcarriers = 96; InputBackoff = 0.70 },
    @{ Qam = 64; BandwidthMhz = 20; UsedSubcarriers = 48; InputBackoff = 0.58 },
    @{ Qam = 64; BandwidthMhz = 20; UsedSubcarriers = 48; InputBackoff = 0.70 },
    @{ Qam = 64; BandwidthMhz = 40; UsedSubcarriers = 96; InputBackoff = 0.58 },
    @{ Qam = 64; BandwidthMhz = 40; UsedSubcarriers = 96; InputBackoff = 0.70 }
)

$programmed = $SkipProgram.IsPresent
foreach ($scenario in $scenarios) {
    $backoffId = [int][math]::Round($scenario.InputBackoff * 100)
    $scenarioId = "${scenarioPrefix}_qam$($scenario.Qam)_bw$($scenario.BandwidthMhz)_bo$backoffId"
    $scenarioDir = Join-Path $outRoot $scenarioId
    $completed = [int]$completedScenarioCounts[$scenarioId]
    if ($completed -ge $RepeatsPerScenario) {
        Write-Host "SKIP $scenarioId ($completed repeat(s) already registered)"
        continue
    }
    $elf = Join-Path $scenarioDir "dsm_dpd_baremetal_smoke.elf"

    Write-Host "==== $scenarioId ===="
    & powershell -NoProfile -ExecutionPolicy Bypass -File $builder `
        -OutDir $scenarioDir `
        -WaveformQam $scenario.Qam `
        -WaveformUsedSubcarriers $scenario.UsedSubcarriers `
        -WaveformInputBackoff $scenario.InputBackoff `
        -WaveformSeed $WaveformSeed
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $scenarioId" }

    while ($completed -lt $RepeatsPerScenario) {
        $runId = Get-Date -Format "yyyyMMdd_HHmmss"
        $traceCsv = Join-Path $scenarioDir "calibration_trace_$runId.csv"
        $runArgs = @("-Elf", $elf)
        if ($programmed) { $runArgs += "-SkipProgram" }
        $runSucceeded = $false
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $runner @runArgs
            if ($LASTEXITCODE -eq 0) {
                $runSucceeded = $true
                break
            }
            Write-Warning "Board run $scenarioId failed on attempt $attempt; restarting local JTAG services."
            Get-Process hw_server, xsdb -ErrorAction SilentlyContinue | Stop-Process -Force
            Start-Sleep -Seconds 2
            & $xsdb $targetCheck
            if ($LASTEXITCODE -ne 0) { throw "JTAG did not recover after failed run of $scenarioId" }
        }
        if (-not $runSucceeded) { throw "Board run failed after three attempts for $scenarioId" }
        $programmed = $true

        $waveformId = "qam$($scenario.Qam)_ofdm_bw$($scenario.BandwidthMhz)_fft256_seed$WaveformSeed"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $capture `
            -Elf $elf -OutCsv $traceCsv `
            -ManifestCsv $ManifestCsv `
            -ScenarioId $scenarioId `
            -PaProfile $PaProfile `
            -PaStrengthDb $PaStrengthDb `
            -Qam $scenario.Qam `
            -BandwidthMhz $scenario.BandwidthMhz `
            -UsedSubcarriers $scenario.UsedSubcarriers `
            -InputBackoff $scenario.InputBackoff `
            -WaveformId $waveformId `
            -CalibrationProfile $CalibrationProfile `
            -DsmConfigId $DsmConfigId `
            -DsmAlgorithm $DsmAlgorithm `
            -DsmQuantizerBits $DsmQuantizerBits `
            -DsmInterpMode $DsmInterpMode `
            -DsmOsr $DsmOsr `
            -RunId $runId
        if ($LASTEXITCODE -ne 0) { throw "Trace capture failed for $scenarioId" }
        $completed++
    }
}

Write-Host "PASS trace matrix complete: $ManifestCsv"

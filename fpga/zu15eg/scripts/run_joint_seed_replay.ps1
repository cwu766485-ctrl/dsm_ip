param(
    [string]$OutDir = ".\fpga\zu15eg\out\dsm_repeat_matrix\joint_seed_replays",
    [string]$DsmConfigId = "ef2_1bit_osr32_interp0",
    [int]$DsmAlgorithm = 3,
    [int]$Qam = 16,
    [double]$BandwidthMhz = 40.0,
    [int]$UsedSubcarriers = 96,
    [double]$InputBackoff = 0.58,
    [int]$WaveformSeed = 101,
    [int]$DpdMode = 1,
    [int]$DpdPackage = 0,
    [int]$PredictedCost = 343185,
    [string]$PaProfile = "nominal_no_external_feedback",
    [double]$PaStrengthDb = 0.0,
    [string]$WaveformId = "qam16_ofdm_bw40_fft256_seed101",
    [string]$SourceFullTrace = ".\fpga\zu15eg\out\trace_matrix\board_ef2_1bit_osr32_interp0_nominal_qam16_bw40_bo58\calibration_trace_20260713_163605.csv",
    [switch]$SkipProgram
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$outPath = if ([IO.Path]::IsPathRooted($OutDir)) { $OutDir } else { Join-Path $repoRoot $OutDir }
$builder = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\build_baremetal_direct.ps1"
$runner = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.ps1"
$capture = Join-Path $repoRoot "fpga\zu15eg\scripts\capture_calibration_trace.ps1"
$policyHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\dpd_trace_policy.h"

if ($DpdMode -ne 1) { throw "This bounded replay supports polynomial mode 1 only." }
if ($DpdPackage -lt 0 -or $DpdPackage -gt 5) { throw "DPD package must be in the exported package range 0..5." }
if (!(Test-Path $SourceFullTrace)) { throw "Source full trace does not exist: $SourceFullTrace" }

New-Item -ItemType Directory -Force -Path $outPath | Out-Null
$replayId = Get-Date -Format "yyyyMMdd_HHmmss"
$buildDir = Join-Path $outPath "build_$replayId"
$tracePath = Join-Path $outPath "joint_seed_replay_trace_$replayId.csv"
$evidencePath = Join-Path $outPath "joint_seed_replays.csv"
$backup = Join-Path $env:TEMP ("joint_seed_policy_" + [guid]::NewGuid().ToString("N") + ".h")
Copy-Item $policyHeader $backup -Force

try {
    $header = Get-Content -Raw $policyHeader
    $header = $header -replace '(?m)^#define DSM_DPD_TRACE_POLICY_MODE \d+U$', "#define DSM_DPD_TRACE_POLICY_MODE $DpdMode`U"
    $header = $header -replace '(?m)^#define DSM_DPD_TRACE_POLICY_PACKAGE_IDX \d+U$', "#define DSM_DPD_TRACE_POLICY_PACKAGE_IDX $DpdPackage`U"
    $header = $header -replace '(?m)^#define DSM_DPD_TRACE_POLICY_PREDICTED_COST \d+U$', "#define DSM_DPD_TRACE_POLICY_PREDICTED_COST $PredictedCost`U"
    $header = $header -replace '(?m)^#define DSM_DPD_TRACE_POLICY_DIRECT \d+U$', "#define DSM_DPD_TRACE_POLICY_DIRECT 0U"
    Set-Content -Path $policyHeader -Value $header -Encoding ascii

    & $builder -OutDir $buildDir -WaveformQam $Qam -WaveformUsedSubcarriers $UsedSubcarriers `
        -WaveformInputBackoff $InputBackoff -WaveformSeed $WaveformSeed `
        -Define @("CAL_TRACE_POLICY_ONLY=1", "CAL_FORCE_POLICY_LOCAL_SEARCH=1", "CAL_USE_SOFTWARE_SEED=0")
    if ($LASTEXITCODE -ne 0) { throw "Joint seed replay build failed." }
    $elf = Join-Path $buildDir "dsm_dpd_baremetal_smoke.elf"
    if ($SkipProgram) { & $runner -Elf $elf -SkipProgram } else { & $runner -Elf $elf }
    if ($LASTEXITCODE -ne 0) { throw "Joint seed replay board run failed." }
    & $capture -Elf $elf -OutCsv $tracePath
    if ($LASTEXITCODE -ne 0) { throw "Joint seed replay trace export failed." }

    $records = @(Import-Csv $tracePath)
    $policy = @($records | Where-Object stage -eq "policy")
    $search = @($records | Where-Object stage -eq "search")
    $final = @($records | Where-Object stage -eq "final")
    $unsafe = @($records | Where-Object { [uint64]$_.stall -ne 0 -or [uint64]$_.error -ne 0 -or [uint64]$_.clip -ne 0 -or [uint64]$_.saturation -ne 0 })
    if ($records.Count -ne 14 -or $policy.Count -ne 1 -or $search.Count -ne 12 -or $final.Count -ne 1 -or $unsafe.Count -ne 0) {
        throw "Joint seed replay did not produce a safe 14-record trace."
    }
    if ([int]$policy[0].mode -ne $DpdMode -or [int]$policy[0].package -ne $DpdPackage) {
        throw "Joint seed replay policy does not match the requested mode/package."
    }

    $evidence = [PSCustomObject]@{
        replay_id = $replayId; pa_profile = $PaProfile; pa_strength_db = $PaStrengthDb
        qam = $Qam; bandwidth_mhz = $BandwidthMhz; used_subcarriers = $UsedSubcarriers
        input_backoff = $InputBackoff; waveform_id = $WaveformId
        dsm_config_id = $DsmConfigId; dsm_algorithm = $DsmAlgorithm
        dpd_mode = $DpdMode; dpd_package = $DpdPackage; predicted_cost = $PredictedCost
        records = $records.Count; policy_cost = $policy[0].cost; final_cost = $final[0].cost
        trace_csv = $tracePath; source_full_calibration_trace = (Resolve-Path $SourceFullTrace).Path
        nonzero_stall = 0; nonzero_error = 0; nonzero_clip = 0; nonzero_saturation = 0
    }
    if (Test-Path $evidencePath) {
        $evidence | Export-Csv -NoTypeInformation -Encoding ascii -Append -Path $evidencePath
    } else {
        $evidence | Export-Csv -NoTypeInformation -Encoding ascii -Path $evidencePath
    }
    Write-Host "PASS joint seed replay: $evidencePath"
} finally {
    Copy-Item $backup $policyHeader -Force
    Remove-Item $backup -Force
}

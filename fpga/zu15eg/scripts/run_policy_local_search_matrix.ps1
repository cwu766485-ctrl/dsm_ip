param(
    [string]$ManifestCsv = ".\fpga\zu15eg\out\trace_matrix\manifest_waveform_only_clean.csv",
    [string]$OutRoot = ".\fpga\zu15eg\out\policy_local_search_matrix",
    [int]$WaveformSeed = 101,
    [Alias("ScenarioId")]
    [string[]]$SelectedScenarioId = @(),
    [switch]$GenerateLosoPolicy,
    [switch]$SkipProgram
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$manifestPath = if ([System.IO.Path]::IsPathRooted($ManifestCsv)) {
    $ManifestCsv
} else {
    Join-Path $repoRoot $ManifestCsv
}
$outPath = if ([System.IO.Path]::IsPathRooted($OutRoot)) { $OutRoot } else {
    Join-Path $repoRoot $OutRoot
}
$builder = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\build_baremetal_direct.ps1"
$runner = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.ps1"
$capture = Join-Path $repoRoot "fpga\zu15eg\scripts\capture_calibration_trace.ps1"
$policyHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\dpd_trace_policy.h"
$policyTrainer = Join-Path $repoRoot "fpga\zu15eg\scripts\train_dpd_trace_policy.py"
$policyBackup = Join-Path $env:TEMP ("dsm_dpd_trace_policy_" + [guid]::NewGuid().ToString("N") + ".h")

if (!(Test-Path $manifestPath)) { throw "Manifest does not exist: $manifestPath" }
if (!(Test-Path $policyHeader)) { throw "Static trace-policy header does not exist: $policyHeader" }
if (!$GenerateLosoPolicy -and (Get-Content -Raw $policyHeader) -notmatch "DSM_DPD_TRACE_POLICY_MODE 1U") {
    throw "The current static trace policy is not polynomial; 14-candidate fallback is unsupported."
}

$allScenarios = @(Import-Csv $manifestPath | Sort-Object scenario_id)
$selectedScenarioIds = @($SelectedScenarioId)
if ($allScenarios.Count -ne 8) { throw "Expected exactly eight retained scenarios, found $($allScenarios.Count)." }
$scenarios = @(if ($selectedScenarioIds.Count -eq 0) {
    $allScenarios
} else {
    @($allScenarios | Where-Object { $selectedScenarioIds -contains $_.scenario_id })
})
if ($scenarios.Count -eq 0) { throw "No selected scenario_id exists in the manifest." }
if ($selectedScenarioIds.Count -ne 0 -and $scenarios.Count -ne $selectedScenarioIds.Count) {
    throw "One or more selected scenario_id values are absent from the manifest."
}
$hasDsmProvenance = $scenarios[0].PSObject.Properties.Name -contains "dsm_config_id"
if ($GenerateLosoPolicy -and !$hasDsmProvenance) {
    throw "-GenerateLosoPolicy requires explicit DSM provenance in the manifest."
}
if ($GenerateLosoPolicy -and !(Test-Path $policyTrainer)) {
    throw "Trace-policy trainer does not exist: $policyTrainer"
}
if ($GenerateLosoPolicy) {
    Copy-Item -LiteralPath $policyHeader -Destination $policyBackup -Force
}
New-Item -ItemType Directory -Force -Path $outPath | Out-Null
$summaryPath = Join-Path $outPath "policy_local_search_matrix_summary.csv"
$summary = @()
$programmed = $SkipProgram.IsPresent

try {
foreach ($scenario in $scenarios) {
    $scenarioId = $scenario.scenario_id
    $scenarioDir = Join-Path $outPath $scenarioId
    $buildDir = Join-Path $scenarioDir "build"
    $runId = Get-Date -Format "yyyyMMdd_HHmmss"
    $traceCsv = Join-Path $scenarioDir "policy_local_search_trace_$runId.csv"
    New-Item -ItemType Directory -Force -Path $scenarioDir | Out-Null

    Write-Host "==== ${scenarioId}: forced 14-candidate policy local search ===="
    if ($GenerateLosoPolicy) {
        & python $policyTrainer `
            --manifest-csv $manifestPath `
            --held-out-scenario $scenarioId `
            --allowed-mode 1 `
            --header $policyHeader `
            --out-dir $scenarioDir `
            --prefix "policy_loso_$scenarioId"
        if ($LASTEXITCODE -ne 0) { throw "LOSO policy generation failed for $scenarioId" }
        if ((Get-Content -Raw $policyHeader) -notmatch "DSM_DPD_TRACE_POLICY_MODE 1U") {
            throw "LOSO policy selected a non-polynomial mode for $scenarioId; 14-candidate fallback is unsupported."
        }
    }
    & $builder `
        -OutDir $buildDir `
        -WaveformQam ([int]$scenario.qam) `
        -WaveformUsedSubcarriers ([int]$scenario.used_subcarriers) `
        -WaveformInputBackoff ([double]$scenario.input_backoff) `
        -WaveformSeed $WaveformSeed `
        -Define @("CAL_TRACE_POLICY_ONLY=1", "CAL_FORCE_POLICY_LOCAL_SEARCH=1", "CAL_USE_SOFTWARE_SEED=0")
    if ($LASTEXITCODE -ne 0) { throw "Build failed for $scenarioId" }

    $elf = Join-Path $buildDir "dsm_dpd_baremetal_smoke.elf"
    if ($programmed) {
        & $runner -Elf $elf -SkipProgram
    } else {
        & $runner -Elf $elf
    }
    if ($LASTEXITCODE -ne 0) { throw "Board run failed for $scenarioId" }
    $programmed = $true

    # No manifest append: this is a policy-only 14-candidate measurement.
    & $capture -Elf $elf -OutCsv $traceCsv
    if ($LASTEXITCODE -ne 0) { throw "JTAG trace capture failed for $scenarioId" }

    $records = @(Import-Csv $traceCsv)
    $policy = @($records | Where-Object stage -eq "policy")
    $search = @($records | Where-Object stage -eq "search")
    $final = @($records | Where-Object stage -eq "final")
    if ($records.Count -ne 14 -or $policy.Count -ne 1 -or $search.Count -ne 12 -or $final.Count -ne 1) {
        throw "Expected 14 records (1 policy, 12 search, 1 final) for $scenarioId; got $($records.Count), $($policy.Count), $($search.Count), $($final.Count)."
    }
    $summary += [PSCustomObject]@{
        scenario_id = $scenarioId
        dsm_config_id = if ($hasDsmProvenance) { $scenario.dsm_config_id } else { "unknown_legacy_manifest" }
        dsm_algorithm = if ($hasDsmProvenance) { $scenario.dsm_algorithm } else { "" }
        dsm_quantizer_bits = if ($hasDsmProvenance) { $scenario.dsm_quantizer_bits } else { "" }
        dsm_interp_mode = if ($hasDsmProvenance) { $scenario.dsm_interp_mode } else { "" }
        dsm_osr = if ($hasDsmProvenance) { $scenario.dsm_osr } else { "" }
        qam = $scenario.qam
        bandwidth_mhz = $scenario.bandwidth_mhz
        used_subcarriers = $scenario.used_subcarriers
        input_backoff = $scenario.input_backoff
        static_policy_mode = $policy[0].mode
        static_policy_package = $policy[0].package
        policy_cost = $policy[0].cost
        final_cost = $final[0].cost
        local_search_cost_delta = [int64]$final[0].cost - [int64]$policy[0].cost
        records = $records.Count
        policy_records = $policy.Count
        search_records = $search.Count
        final_records = $final.Count
        min_recorded_cost = ($records | ForEach-Object { [uint64]$_.cost } | Measure-Object -Minimum).Minimum
        nonzero_stall = @($records | Where-Object { [uint64]$_.stall -ne 0 }).Count
        nonzero_error = @($records | Where-Object { [uint64]$_.error -ne 0 }).Count
        nonzero_clip = @($records | Where-Object { [uint64]$_.clip -ne 0 }).Count
        nonzero_saturation = @($records | Where-Object { [uint64]$_.saturation -ne 0 }).Count
        trace_csv = $traceCsv
        source_full_calibration_trace = $scenario.trace_csv
        regret_predictor_constants_deployed = 0
        loso_policy_generated = [int]$GenerateLosoPolicy.IsPresent
    }
}

$priorSummary = if (Test-Path $summaryPath) { @(Import-Csv $summaryPath) } else { @() }
$updatedScenarioIds = @($summary | ForEach-Object { $_.scenario_id })
$mergedSummary = @($priorSummary | Where-Object { $updatedScenarioIds -notcontains $_.scenario_id }) +
                 @($summary)
$mergedSummary | Sort-Object scenario_id | Export-Csv -NoTypeInformation -Encoding ascii -Path $summaryPath
Write-Host "PASS forced policy local-search matrix complete: $summaryPath"
} finally {
    if ($GenerateLosoPolicy -and (Test-Path $policyBackup)) {
        Copy-Item -LiteralPath $policyBackup -Destination $policyHeader -Force
        Remove-Item -LiteralPath $policyBackup -Force
    }
}

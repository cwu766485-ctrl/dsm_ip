param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestCsv,
    [Parameter(Mandatory = $true)]
    [string]$OutRoot,
    [ValidateRange(1, 16)]
    [int]$TargetRepeats = 3,
    [int]$WaveformSeed = 101,
    [switch]$GenerateLosoPolicy,
    [switch]$SkipProgram
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$manifestPath = if ([IO.Path]::IsPathRooted($ManifestCsv)) { $ManifestCsv } else { Join-Path $repoRoot $ManifestCsv }
$outPath = if ([IO.Path]::IsPathRooted($OutRoot)) { $OutRoot } else { Join-Path $repoRoot $OutRoot }
$builder = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\build_baremetal_direct.ps1"
$runner = Join-Path $repoRoot "fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.ps1"
$capture = Join-Path $repoRoot "fpga\zu15eg\scripts\capture_calibration_trace.ps1"
$trainer = Join-Path $repoRoot "fpga\zu15eg\scripts\train_dpd_trace_policy.py"
$policyHeader = Join-Path $repoRoot "fpga\zu15eg\baremetal\src\dpd_trace_policy.h"

if (!(Test-Path $manifestPath)) { throw "Manifest does not exist: $manifestPath" }
$entries = @(Import-Csv $manifestPath)
if ($entries.Count -ne (8 * $TargetRepeats)) { throw "Expected $($TargetRepeats * 8) full-trace rows, got $($entries.Count)" }
foreach ($field in @("dsm_config_id", "dsm_algorithm", "dsm_quantizer_bits", "dsm_interp_mode", "dsm_osr")) {
    if ($entries[0].PSObject.Properties.Name -notcontains $field) { throw "Manifest lacks DSM provenance: $field" }
}
$groups = @($entries | Group-Object scenario_id)
if ($groups.Count -ne 8 -or @($groups | Where-Object { $_.Count -ne $TargetRepeats }).Count -ne 0) {
    throw "Manifest must contain $TargetRepeats full-trace repeats for each of eight scenarios."
}
New-Item -ItemType Directory -Force -Path $outPath | Out-Null
$summaryPath = Join-Path $outPath "policy_local_search_repeat_summary.csv"
$existing = if (Test-Path $summaryPath) { @(Import-Csv $summaryPath) } else { @() }
$doneSources = @{}
$existing | ForEach-Object { $doneSources[$_.source_full_calibration_trace.ToLowerInvariant()] = $true }
$backup = Join-Path $env:TEMP ("dsm_repeat_policy_" + [guid]::NewGuid().ToString("N") + ".h")
Copy-Item $policyHeader $backup -Force
$summary = @($existing)
$programmed = $SkipProgram.IsPresent

try {
    foreach ($group in $groups) {
        $scenario = @($group.Group)[0]
        $scenarioDir = Join-Path $outPath $scenario.scenario_id
        $buildDir = Join-Path $scenarioDir "build"
        New-Item -ItemType Directory -Force -Path $scenarioDir | Out-Null
        if ($GenerateLosoPolicy) {
            & python $trainer --manifest-csv $manifestPath --held-out-scenario $scenario.scenario_id `
                --allowed-mode 1 --header $policyHeader --out-dir $scenarioDir `
                --prefix "repeat_policy_loso_$($scenario.scenario_id)"
            if ($LASTEXITCODE -ne 0) { throw "LOSO policy generation failed: $($scenario.scenario_id)" }
        }
        & $builder -OutDir $buildDir -WaveformQam ([int]$scenario.qam) `
            -WaveformUsedSubcarriers ([int]$scenario.used_subcarriers) `
            -WaveformInputBackoff ([double]$scenario.input_backoff) -WaveformSeed $WaveformSeed `
            -Define @("CAL_TRACE_POLICY_ONLY=1", "CAL_FORCE_POLICY_LOCAL_SEARCH=1", "CAL_USE_SOFTWARE_SEED=0")
        if ($LASTEXITCODE -ne 0) { throw "Build failed: $($scenario.scenario_id)" }
        $elf = Join-Path $buildDir "dsm_dpd_baremetal_smoke.elf"
        foreach ($entry in @($group.Group | Sort-Object run_id)) {
            $source = $entry.trace_csv
            if ($doneSources.ContainsKey($source.ToLowerInvariant())) { continue }
            $runId = Get-Date -Format "yyyyMMdd_HHmmss"
            $trace = Join-Path $scenarioDir "policy_local_search_trace_$runId.csv"
            if ($programmed) { & $runner -Elf $elf -SkipProgram } else { & $runner -Elf $elf }
            if ($LASTEXITCODE -ne 0) { throw "Board run failed: $($entry.scenario_id) / $($entry.run_id)" }
            $programmed = $true
            & $capture -Elf $elf -OutCsv $trace
            if ($LASTEXITCODE -ne 0) { throw "Trace capture failed: $($entry.scenario_id) / $($entry.run_id)" }
            $records = @(Import-Csv $trace)
            $policy = @($records | Where-Object stage -eq "policy")
            $search = @($records | Where-Object stage -eq "search")
            $final = @($records | Where-Object stage -eq "final")
            $unsafe = @($records | Where-Object { [uint64]$_.stall -ne 0 -or [uint64]$_.error -ne 0 -or [uint64]$_.clip -ne 0 -or [uint64]$_.saturation -ne 0 })
            if ($records.Count -ne 14 -or $policy.Count -ne 1 -or $search.Count -ne 12 -or $final.Count -ne 1 -or $unsafe.Count -ne 0) {
                throw "Invalid or unsafe bounded trace: $($entry.scenario_id) / $($entry.run_id)"
            }
            $summary += [PSCustomObject]@{
                scenario_id=$entry.scenario_id; run_id=$entry.run_id; dsm_config_id=$entry.dsm_config_id
                dsm_algorithm=$entry.dsm_algorithm; dsm_quantizer_bits=$entry.dsm_quantizer_bits; dsm_interp_mode=$entry.dsm_interp_mode; dsm_osr=$entry.dsm_osr
                qam=$entry.qam; bandwidth_mhz=$entry.bandwidth_mhz; used_subcarriers=$entry.used_subcarriers; input_backoff=$entry.input_backoff
                policy_cost=$policy[0].cost; final_cost=$final[0].cost; local_search_cost_delta=([int64]$final[0].cost-[int64]$policy[0].cost)
                records=$records.Count; policy_records=$policy.Count; search_records=$search.Count; final_records=$final.Count
                min_recorded_cost=($records | ForEach-Object {[uint64]$_.cost} | Measure-Object -Minimum).Minimum
                nonzero_stall=0; nonzero_error=0; nonzero_clip=0; nonzero_saturation=0
                trace_csv=$trace; source_full_calibration_trace=$source; loso_policy_generated=[int]$GenerateLosoPolicy.IsPresent
            }
        }
    }
    $summary | Sort-Object source_full_calibration_trace | Export-Csv -NoTypeInformation -Encoding ascii -Path $summaryPath
    Write-Host "PASS repeat local-search matrix: $summaryPath"
} finally {
    Copy-Item $backup $policyHeader -Force
    Remove-Item $backup -Force
}

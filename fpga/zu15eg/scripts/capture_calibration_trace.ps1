param(
    [string]$Elf = ".\fpga\zu15eg\out\vitis_baremetal\dsm_dpd_baremetal_smoke\build\dsm_dpd_baremetal_smoke.elf",
    [string]$OutCsv = "",
    [string]$OutMarkdown = "",
    [string]$ManifestCsv = "",
    [string]$ScenarioId = "",
    [string]$PaProfile = "",
    [double]$PaStrengthDb = [double]::NaN,
    [int]$Qam = -1,
    [double]$BandwidthMhz = [double]::NaN,
    [int]$UsedSubcarriers = -1,
    [double]$InputBackoff = [double]::NaN,
    [string]$WaveformId = "",
    [string]$CalibrationProfile = "",
    [string]$DsmConfigId = "",
    [int]$DsmAlgorithm = -1,
    [int]$DsmQuantizerBits = -1,
    [int]$DsmInterpMode = -1,
    [int]$DsmOsr = -1,
    [string]$RunId = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..\..")
$outDir = Join-Path $repoRoot "fpga\zu15eg\out"
$elfPath = Resolve-Path $(if ([System.IO.Path]::IsPathRooted($Elf)) { $Elf } else { Join-Path $repoRoot $Elf })

if ([string]::IsNullOrWhiteSpace($OutCsv)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutCsv = Join-Path $outDir "calibration_trace_jtag_$timestamp.csv"
}
if ([string]::IsNullOrWhiteSpace($OutMarkdown)) {
    $OutMarkdown = [System.IO.Path]::ChangeExtension($OutCsv, ".md")
}

$nmCandidates = @(
    "D:\Xilinx\Vitis\2024.1\gnu\aarch64\nt\aarch64-none\bin\aarch64-none-elf-nm.exe",
    "D:\Xilinx\Vivado\2024.1\gnu\aarch64\nt\aarch64-none\bin\aarch64-none-elf-nm.exe"
)
$nm = $nmCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $nm) { throw "aarch64-none-elf-nm was not found." }

$symbolLine = & $nm -n $elfPath.Path | Where-Object { $_ -match '\bg_cal_trace_buffer$' } | Select-Object -First 1
if (-not $symbolLine) { throw "ELF does not export g_cal_trace_buffer: $($elfPath.Path)" }
$symbolAddress = ($symbolLine -split '\s+')[0]
$env:CAL_TRACE_BASE = "0x$symbolAddress"
$env:CAL_TRACE_CSV = [System.IO.Path]::GetFullPath($OutCsv)

$xsdbCandidates = @(
    "D:\Xilinx\Vitis\2024.1\bin\xsdb.bat",
    "D:\Xilinx\Vivado\2024.1\bin\xsdb.bat"
)
$xsdb = $xsdbCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $xsdb) { throw "xsdb was not found." }

Write-Host "ELF             = $($elfPath.Path)"
Write-Host "CAL_TRACE_BASE  = $env:CAL_TRACE_BASE"
Write-Host "CAL_TRACE_CSV   = $env:CAL_TRACE_CSV"
& $xsdb (Join-Path $scriptDir "capture_calibration_trace.tcl")
if ($LASTEXITCODE -ne 0) { throw "JTAG calibration trace capture failed with exit code $LASTEXITCODE" }

$rows = @(Import-Csv $env:CAL_TRACE_CSV)
$accepted = @($rows | Where-Object decision -eq "accept")
$rejected = @($rows | Where-Object decision -eq "reject")
$seed = $rows | Where-Object stage -eq "software_seed" | Select-Object -First 1
$policy = $rows | Where-Object stage -eq "policy" | Select-Object -Last 1
$final = $rows | Where-Object decision -eq "selected" | Select-Object -Last 1
$best = $rows | Sort-Object { [uint64]$_.cost } | Select-Object -First 1

$lines = @(
    "# JTAG Calibration Trace Summary",
    "",
    "- Records: $($rows.Count)",
    "- Accepted: $($accepted.Count)",
    "- Rejected: $($rejected.Count)",
    "- Software seed records: $(@($rows | Where-Object stage -eq 'software_seed').Count)",
    ""
)
if ($seed) {
    $lines += @(
        "## Software Seed", "",
        "- Package: ``$($seed.package)``",
        "- C1/C3/C5: ``$($seed.c1)`` / ``$($seed.c3)`` / ``$($seed.c5)``",
        "- Cost: ``$($seed.cost)``",
        "- Decision: ``$($seed.decision)`` ($($seed.reason))", ""
    )
}
if ($best) {
    $lines += @(
        "## Lowest Recorded Cost", "",
        "- Candidate/stage: ``$($best.candidate_id)`` / ``$($best.stage)``",
        "- Mode/package: ``$($best.mode)`` / ``$($best.package)``",
        "- Cost: ``$($best.cost)``", ""
    )
}
if ($policy) {
    $lines += @(
        "## Policy Replay", "",
        "- Mode/package: ``$($policy.mode)`` / ``$($policy.package)``",
        "- Cost: ``$($policy.cost)``",
        "- Stall/error/saturation: ``$($policy.stall)`` / ``$($policy.error)`` / ``$($policy.saturation)``", ""
    )
}
if ($final) {
    $lines += @(
        "## Final Selection", "",
        "- Mode/package: ``$($final.mode)`` / ``$($final.package)``",
        "- C1/C3/C5: ``$($final.c1)`` / ``$($final.c3)`` / ``$($final.c5)``",
        "- Cost: ``$($final.cost)``",
        "- Stall/error/saturation: ``$($final.stall)`` / ``$($final.error)`` / ``$($final.saturation)``", ""
    )
}
$lines | Set-Content -Path $OutMarkdown -Encoding ascii
Write-Host "Calibration trace CSV:      $env:CAL_TRACE_CSV"
Write-Host "Calibration trace Markdown: $([System.IO.Path]::GetFullPath($OutMarkdown))"

if (-not [string]::IsNullOrWhiteSpace($ManifestCsv)) {
    $required = @($ScenarioId, $PaProfile, $WaveformId, $CalibrationProfile, $DsmConfigId) |
        Where-Object { [string]::IsNullOrWhiteSpace($_) }
    if ($required.Count -ne 0 -or [double]::IsNaN($PaStrengthDb) -or $Qam -le 0 -or
        [double]::IsNaN($BandwidthMhz) -or $BandwidthMhz -le 0 -or $UsedSubcarriers -le 0 -or
        [double]::IsNaN($InputBackoff) -or $InputBackoff -le 0 -or $DsmAlgorithm -lt 0 -or
        $DsmQuantizerBits -lt 1 -or $DsmInterpMode -lt 0 -or $DsmOsr -lt 1) {
        throw "Manifest capture requires waveform, PA, and DSM configuration provenance."
    }
    if (@($rows | Where-Object stage -eq "package").Count -eq 0 -or
        @($rows | Where-Object stage -eq "final").Count -eq 0) {
        throw "Refusing to register a non-full calibration trace: package and final rows are required."
    }

    $manifestPath = [System.IO.Path]::GetFullPath($ManifestCsv)
    $manifestDir = Split-Path -Parent $manifestPath
    New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $RunId = Get-Date -Format "yyyyMMdd_HHmmss"
    }
    $record = [PSCustomObject]@{
        scenario_id = $ScenarioId
        pa_profile = $PaProfile
        pa_strength_db = $PaStrengthDb
        qam = $Qam
        bandwidth_mhz = $BandwidthMhz
        used_subcarriers = $UsedSubcarriers
        input_backoff = $InputBackoff
        waveform_id = $WaveformId
        calibration_profile = $CalibrationProfile
        dsm_config_id = $DsmConfigId
        dsm_algorithm = $DsmAlgorithm
        dsm_quantizer_bits = $DsmQuantizerBits
        dsm_interp_mode = $DsmInterpMode
        dsm_osr = $DsmOsr
        trace_csv = $env:CAL_TRACE_CSV
        run_id = $RunId
    }
    if (Test-Path $manifestPath) {
        $record | Export-Csv -Path $manifestPath -NoTypeInformation -Encoding utf8 -Append
    } else {
        $record | Export-Csv -Path $manifestPath -NoTypeInformation -Encoding utf8
    }
    Write-Host "Appended full-calibration trace manifest: $manifestPath"
}

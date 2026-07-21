param(
    [string]$DsmBase = "0xA0010000",
    [string]$ExpectedSamples = "0x00001000",
    [string]$ExpectedDpdCtrl = "0x00000002",
    [string]$OutCsv = "",
    [switch]$PrintOnly
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zu15egDir = Resolve-Path (Join-Path $scriptDir "..")
$outDir = Join-Path $zu15egDir "out"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if ([string]::IsNullOrWhiteSpace($OutCsv)) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutCsv = Join-Path $outDir "dsm_replay_counters_$timestamp.csv"
}

$xsdbCandidates = @()
$cmd = Get-Command xsdb -ErrorAction SilentlyContinue
if ($cmd) {
    $xsdbCandidates += $cmd.Source
}
$xsdbCandidates += @(
    "D:\Xilinx\Vitis\2024.1\bin\xsdb.bat",
    "D:\Xilinx\Vivado\2024.1\bin\xsdb.bat"
)
$xsdb = $xsdbCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $xsdb) {
    throw "xsdb was not found. Install Vitis/Vivado or add xsdb.bat to PATH."
}

$env:DSM_BASE = $DsmBase
$env:EXPECTED_SAMPLES = $ExpectedSamples
$env:EXPECTED_DPD_CTRL = $ExpectedDpdCtrl
$env:REPLAY_CSV = $OutCsv

$tcl = Join-Path $scriptDir "capture_dsm_replay_counters.tcl"
Write-Host "DSM_BASE          = $env:DSM_BASE"
Write-Host "EXPECTED_SAMPLES  = $env:EXPECTED_SAMPLES"
Write-Host "EXPECTED_DPD_CTRL = $env:EXPECTED_DPD_CTRL"
Write-Host "REPLAY_CSV        = $env:REPLAY_CSV"
Write-Host "XSDB_SCRIPT       = $tcl"

if ($PrintOnly) {
    Write-Host "PrintOnly set; XSDB was not launched."
    exit 0
}

& $xsdb $tcl
if ($LASTEXITCODE -ne 0) {
    throw "Replay counter capture failed with exit code $LASTEXITCODE"
}

Write-Host "Replay counter CSV: $OutCsv"

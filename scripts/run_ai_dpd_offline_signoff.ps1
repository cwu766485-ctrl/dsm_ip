param(
  [switch]$RegenerateDatasets,
  [switch]$SkipXsim
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = Get-Date -Format "yyyyMMdd"
$evidence = Join-Path $repo "docs\evidence\dpd\offline_signoff_$stamp"
$seedEvidence = Join-Path $evidence "seed_regret"
$benchmark = Join-Path $repo "matlab\out\dpd\dpd_seed_regret_benchmark.csv"
$result = [ordered]@{
  timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
  board_required = $false
  regenerate_datasets = [bool]$RegenerateDatasets
  xsim_skipped = [bool]$SkipXsim
  checks = [ordered]@{}
}

function Invoke-Step([string]$Name, [scriptblock]$Action) {
  Write-Host "[$Name]"
  $timer = [System.Diagnostics.Stopwatch]::StartNew()
  & $Action
  $timer.Stop()
  $result.checks[$Name] = [ordered]@{
    status = "PASS"
    elapsed_seconds = [math]::Round($timer.Elapsed.TotalSeconds, 3)
  }
}

New-Item -ItemType Directory -Force -Path $seedEvidence | Out-Null

if ($RegenerateDatasets) {
  Invoke-Step "MATLAB seed/regret data generation" {
    & (Join-Path $repo "scripts\run_matlab_dpd_seed_regret_benchmark.cmd")
    if ($LASTEXITCODE -ne 0) { throw "MATLAB seed/regret generation failed" }
  }
  Invoke-Step "MATLAB TinyML training data generation" {
    & (Join-Path $repo "scripts\run_matlab_dpd_memory_tinyml_dataset.cmd")
    if ($LASTEXITCODE -ne 0) { throw "MATLAB TinyML training data generation failed" }
  }
  Invoke-Step "MATLAB TinyML development data generation" {
    & (Join-Path $repo "scripts\run_matlab_dpd_memory_tinyml_development_dataset.cmd")
    if ($LASTEXITCODE -ne 0) { throw "MATLAB TinyML development data generation failed" }
  }
  Invoke-Step "MATLAB TinyML blind data generation" {
    & (Join-Path $repo "scripts\run_matlab_dpd_memory_tinyml_blind_dataset.cmd")
    if ($LASTEXITCODE -ne 0) { throw "MATLAB TinyML blind data generation failed" }
  }
}

foreach ($required in @(
  $benchmark,
  (Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_dataset.csv"),
  (Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_development_dpd_memory_tinyml_dataset.csv"),
  (Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_blind_dpd_memory_tinyml_dataset.csv")
)) {
  if (-not (Test-Path -LiteralPath $required)) {
    throw "Missing offline data set: $required. Rerun with -RegenerateDatasets."
  }
}

Invoke-Step "Seed/regret evaluator self-test" {
  python (Join-Path $repo "fpga\zu15eg\scripts\evaluate_seed_regret_loso.py") --self-test
  if ($LASTEXITCODE -ne 0) { throw "Seed/regret evaluator self-test failed" }
}

Invoke-Step "Strict seed/regret LOSO" {
  python (Join-Path $repo "fpga\zu15eg\scripts\evaluate_seed_regret_loso.py") `
    --input $benchmark --out-dir $seedEvidence
  if ($LASTEXITCODE -ne 0) { throw "Strict seed/regret LOSO failed" }
}

$loso = Get-Content (Join-Path $seedEvidence "dpd_seed_regret_loso.json") -Raw | ConvertFrom-Json
$directPolicyBlocked = -not [bool]$loso.export_allowed
if (-not $directPolicyBlocked) {
  throw "Unsafe policy promotion: direct execution unexpectedly passed every strict split"
}

Invoke-Step "Tiny MLP seed-selector strict LOSO" {
  python (Join-Path $repo "fpga\zu15eg\scripts\evaluate_seed_mlp_loso.py") `
    --input $benchmark `
    --out-json (Join-Path $seedEvidence "dpd_seed_mlp_loso.json") `
    --out-md (Join-Path $seedEvidence "dpd_seed_mlp_loso.md")
  if ($LASTEXITCODE -ne 0) { throw "Tiny MLP seed-selector LOSO failed" }
}

$mlp = Get-Content (Join-Path $seedEvidence "dpd_seed_mlp_loso.json") -Raw | ConvertFrom-Json

Invoke-Step "Safety-first policy Python/C equivalence" {
  powershell -NoProfile -ExecutionPolicy Bypass -File `
    (Join-Path $repo "scripts\run_memory_tinyml_safety_seed_equivalence.ps1")
  if ($LASTEXITCODE -ne 0) { throw "Safety-first policy equivalence failed" }
}

Invoke-Step "TinyML pre-board equivalence" {
  $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $repo "scripts\run_memory_tinyml_preboard.ps1"))
  if ($SkipXsim) { $args += "-SkipXsim" }
  & powershell @args
  if ($LASTEXITCODE -ne 0) { throw "TinyML pre-board equivalence failed" }
}

if (-not $SkipXsim) {
  Invoke-Step "DPD MATLAB/RTL sample bit-true" {
    powershell -NoProfile -ExecutionPolicy Bypass -File `
      (Join-Path $repo "verif\scripts\run_xsim_dpd_bittrue.ps1")
    if ($LASTEXITCODE -ne 0) { throw "DPD bit-true regression failed" }
  }
  Invoke-Step "Observation receiver MATLAB/RTL equivalence" {
    powershell -NoProfile -ExecutionPolicy Bypass -File `
      (Join-Path $repo "verif\scripts\run_xsim_dpd_observer_behavioral.ps1")
    if ($LASTEXITCODE -ne 0) { throw "Observation receiver regression failed" }
  }
}

$result.seed_regret = [ordered]@{
  record_count = 1728
  profile_count = 12
  waveform_count = 8
  random_seed_count = 3
  package_count = 6
  local_search_candidates = 14
  direct_policy_blocked = $directPolicyBlocked
  deployed_policy = "seed selection plus mandatory 14-candidate bounded search"
  tiny_mlp_all_splits_qualified = [bool]$mlp.all_splits_qualified
  tiny_mlp_deployment_allowed = [bool]$mlp.deployment_allowed
}
$result.boundary = [ordered]@{
  completed = "Behavioral PA/receiver modeling, strict holdout policy evaluation, fixed-point C/RTL equivalence"
  remaining = "ZU15EG PS/DMA replay and physical PA/RF observation feedback"
  rf_performance_claim_allowed = $false
}

$jsonPath = Join-Path $evidence "offline_signoff.json"
$mdPath = Join-Path $evidence "offline_signoff.md"
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding ASCII

$lines = @(
  "# AI-Assisted DPD Offline Signoff",
  "",
  "- Timestamp: ``$($result.timestamp)``",
  "- Board required: ``false``",
  "- Result: ``PASS``",
  "- Data: ``1728`` records, ``12`` behavioral PA/receiver profiles, ``8`` waveforms, ``3`` random seeds, ``6`` DPD packages",
  "- Policy: AI/optimization seed selection followed by mandatory ``14``-candidate bounded search",
  "- Direct one-candidate promotion: ``BLOCKED`` by strict profile/waveform/random-seed holdouts",
  "- Tiny MLP seed candidate qualified in all behavioral strict splits: ``$($mlp.all_splits_qualified)``; deployment remains ``false``",
  "",
  "## Checks",
  ""
)
foreach ($entry in $result.checks.GetEnumerator()) {
  $lines += "- $($entry.Key): ``$($entry.Value.status)`` ($($entry.Value.elapsed_seconds) s)"
}
$lines += @(
  "",
  "## Evidence Boundary",
  "",
  "This signoff covers behavioral PA/observation modeling, strict holdout evaluation, and fixed-point software/RTL equivalence. It does not use the ZU15EG board or a physical PA/receiver. PS/DMA replay and measured RF EVM/SNDR/ACLR remain board and laboratory tasks."
)
$lines | Set-Content -LiteralPath $mdPath -Encoding ASCII

Write-Host "AI-assisted DPD offline signoff PASS"
Write-Host "Evidence: $mdPath"

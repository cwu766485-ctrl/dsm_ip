$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outDir = Join-Path $repo "docs\evidence\dpd\safety_seed_policy_20260717"
$base = Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_dataset.csv"
$development = Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_development_dpd_memory_tinyml_dataset.csv"
$blind = Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_blind_dpd_memory_tinyml_dataset.csv"
$report = Join-Path $outDir "memory_tinyml_safety_seed_policy.json"
$blindDecisions = Join-Path $outDir "memory_tinyml_safety_seed_blind_decisions.csv"
$header = Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_safety_seed_policy.h"
$vectors = Join-Path $repo "verif\vectors\dpd\memory_tinyml_safety_seed_policy_q20.txt"
$summary = Join-Path $outDir "memory_tinyml_safety_seed_policy_c_constants.json"
$work = Join-Path $repo "verif\out_safety_seed_policy"

foreach ($path in @($base, $development, $blind, $report, $blindDecisions)) {
  if (-not (Test-Path $path)) { throw "Missing safety-policy input: $path" }
}

python (Join-Path $repo "fpga\zu15eg\scripts\generate_memory_tinyml_safety_seed_policy.py") `
  --base-train $base --development $development --blind $blind `
  --policy-report $report --blind-decisions $blindDecisions `
  --header $header --vectors $vectors --summary $summary
if ($LASTEXITCODE -ne 0) { throw "Safety-policy C constant generation failed" }

New-Item -ItemType Directory -Force -Path $work | Out-Null
$test = Join-Path $work "test_dpd_safety_seed_policy.exe"
gcc -std=c99 -Wall -Wextra -Werror `
  -I (Join-Path $repo "fpga\zu15eg\baremetal\src") `
  (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_safety_seed_policy.c") `
  (Join-Path $repo "verif\c\test_dpd_safety_seed_policy.c") -o $test
if ($LASTEXITCODE -ne 0) { throw "Safety-policy host C build failed" }

& $test $vectors
if ($LASTEXITCODE -ne 0) { throw "Safety-policy Python/C equivalence failed" }
Write-Host "Python/C safety-first seed policy equivalence PASS"

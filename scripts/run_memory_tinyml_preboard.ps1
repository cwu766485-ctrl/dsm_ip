param(
  [switch]$SkipXsim
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Write-Host "[1/4] strict quantized PA-profile LOSO"
& (Join-Path $repo "scripts\run_memory_tinyml_quantized_loso.cmd")
if ($LASTEXITCODE -ne 0) { throw "Quantized TinyML LOSO failed" }
$losoReport = Get-Content `
  (Join-Path $repo "docs\evidence\dpd\memory_tinyml_tree_q20_loso_v2_20260715.json") `
  -Raw | ConvertFrom-Json
if (-not $losoReport.hybrid_promotion_allowed) {
  throw "Hybrid tree/LUT policy did not meet the promotion rule"
}

Write-Host "[2/4] fixed model export and C/RTL source generation"
python (Join-Path $repo "fpga\zu15eg\scripts\export_memory_tinyml_tree.py") `
  --input (Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_dataset.csv") `
  --model-out (Join-Path $repo "docs\evidence\dpd\memory_tinyml_tree_q20_v2_20260715.json") `
  --vectors-out (Join-Path $repo "verif\vectors\dpd\memory_tinyml_tree_q20_v2.txt")
if ($LASTEXITCODE -ne 0) { throw "TinyML tree export failed" }
python (Join-Path $repo "fpga\zu15eg\scripts\generate_memory_tinyml_tree_sources.py") `
  --model (Join-Path $repo "docs\evidence\dpd\memory_tinyml_tree_q20_v2_20260715.json") `
  --c-out (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_tinyml_tree.c") `
  --rtl-out (Join-Path $repo "rtl\dpd\dpd_tinyml_tree.v")
if ($LASTEXITCODE -ne 0) { throw "TinyML C/RTL generation failed" }

python (Join-Path $repo "fpga\zu15eg\scripts\generate_memory_tinyml_lut_header.py") `
  --input (Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_dataset.csv") `
  --header (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_tinyml_lut_v2.h")
if ($LASTEXITCODE -ne 0) { throw "TinyML LUT fallback generation failed" }

Write-Host "[3/4] host C equivalence and retained board replay"
$cTest = Join-Path $env:TEMP "test_dpd_tinyml_preboard.exe"
gcc -std=c99 -Wall -Wextra -Werror `
  -I (Join-Path $repo "fpga\zu15eg\baremetal\src") `
  (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_tinyml_tree.c") `
  (Join-Path $repo "verif\c\test_dpd_tinyml_tree.c") -o $cTest
if ($LASTEXITCODE -ne 0) { throw "TinyML C reference build failed" }
& $cTest (Join-Path $repo "verif\vectors\dpd\memory_tinyml_tree_q20_v2.txt")
if ($LASTEXITCODE -ne 0) { throw "TinyML C equivalence failed" }

python (Join-Path $repo "fpga\zu15eg\scripts\export_memory_tinyml_feature_vectors.py") `
  --input (Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_dataset.csv") `
  --model (Join-Path $repo "docs\evidence\dpd\memory_tinyml_tree_q20_v2_20260715.json") `
  --out (Join-Path $repo "verif\vectors\dpd\memory_tinyml_features_raw_v2.txt")
if ($LASTEXITCODE -ne 0) { throw "TinyML raw feature vector export failed" }
$featureTest = Join-Path $env:TEMP "test_dpd_tinyml_features.exe"
gcc -std=c99 -Wall -Wextra -Werror `
  -I (Join-Path $repo "fpga\zu15eg\baremetal\src") `
  (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_tinyml_features.c") `
  (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_tinyml_tree.c") `
  (Join-Path $repo "verif\c\test_dpd_tinyml_features.c") -o $featureTest
if ($LASTEXITCODE -ne 0) { throw "TinyML feature reference build failed" }
& $featureTest (Join-Path $repo "verif\vectors\dpd\memory_tinyml_features_raw_v2.txt")
if ($LASTEXITCODE -ne 0) { throw "TinyML feature/tree equivalence failed" }
& (Join-Path $repo "scripts\run_memory_tinyml_complex_feedback_replay.cmd")
if ($LASTEXITCODE -ne 0) { throw "Aligned complex-feedback replay failed" }

Write-Host "[4/4] XSim equivalence"
if ($SkipXsim) {
  Write-Warning "XSim skipped: host pre-signoff passed, RTL signoff remains incomplete"
  exit 0
}
powershell -NoProfile -ExecutionPolicy Bypass -File `
  (Join-Path $repo "verif\scripts\run_tinyml_tree_equivalence.ps1")
if ($LASTEXITCODE -ne 0) { throw "TinyML RTL equivalence failed" }

Write-Host "TinyML pre-board signoff PASS"

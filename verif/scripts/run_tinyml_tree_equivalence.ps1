$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$vivadoSettings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
$dataset = Join-Path $repo "matlab\out\dpd\dpd_memory_tinyml_dataset.csv"
$model = Join-Path $repo "docs\evidence\dpd\memory_tinyml_tree_q20_v2_20260715.json"
$vectors = Join-Path $repo "verif\vectors\dpd\memory_tinyml_tree_q20_v2.txt"
$work = Join-Path $repo "verif\out_xsim_tinyml_tree"

if (-not (Test-Path $dataset)) {
  throw "TinyML dataset not found. Run scripts\run_matlab_dpd_memory_tinyml_dataset.cmd first."
}
if (-not (Test-Path $vivadoSettings)) {
  throw "Vivado settings not found at $vivadoSettings."
}

Write-Host "[python] freeze Q12.20 tree and generate golden decisions"
python (Join-Path $repo "fpga\zu15eg\scripts\export_memory_tinyml_tree.py") `
  --input $dataset --model-out $model --vectors-out $vectors
if ($LASTEXITCODE -ne 0) { throw "Python TinyML tree export failed" }

python (Join-Path $repo "fpga\zu15eg\scripts\generate_memory_tinyml_tree_sources.py") `
  --model $model `
  --c-out (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_tinyml_tree.c") `
  --rtl-out (Join-Path $repo "rtl\dpd\dpd_tinyml_tree.v")
if ($LASTEXITCODE -ne 0) { throw "TinyML C/RTL source generation failed" }

python (Join-Path $repo "fpga\zu15eg\scripts\generate_memory_tinyml_lut_header.py") `
  --input $dataset `
  --header (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_tinyml_lut_v2.h")
if ($LASTEXITCODE -ne 0) { throw "TinyML LUT fallback generation failed" }

New-Item -ItemType Directory -Force -Path $work | Out-Null
$cTest = Join-Path $work "test_dpd_tinyml_tree.exe"
Write-Host "[c] compile host reference"
gcc -std=c99 -Wall -Wextra -Werror `
  -I (Join-Path $repo "fpga\zu15eg\baremetal\src") `
  (Join-Path $repo "fpga\zu15eg\baremetal\src\dpd_tinyml_tree.c") `
  (Join-Path $repo "verif\c\test_dpd_tinyml_tree.c") `
  -o $cTest
if ($LASTEXITCODE -ne 0) { throw "C TinyML tree build failed" }

Write-Host "[c] compare every decision with Python golden vectors"
& $cTest $vectors
if ($LASTEXITCODE -ne 0) { throw "C TinyML tree equivalence failed" }

Copy-Item $vectors (Join-Path $work "memory_tinyml_tree_q20.txt") -Force
Set-Location $work

function Invoke-VivadoCmd($cmd, $logName) {
  $log = Join-Path $work $logName
  Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
  $bat = "@echo off`r`n" +
         "call `"$vivadoSettings`" >nul`r`n" +
         "$cmd -log `"$log`"`r`n"
  $tmp = Join-Path $env:TEMP ("run_tinyml_tree_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -Path $tmp -Value $bat -Encoding ASCII
  try {
    cmd.exe /c $tmp
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
    if (-not (Test-Path -LiteralPath $log)) { throw "Missing tool log: $log" }
    if (Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch) {
      throw "Vivado reported an error while running: $cmd"
    }
  } finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "[rtl] compile and elaborate fixed-point tree"
Invoke-VivadoCmd "xvlog -sv `"$repo\rtl\dpd\dpd_tinyml_tree.v`" `"$repo\verif\tb\tb_dpd_tinyml_tree.sv`"" "xvlog.log"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_tinyml_tree -s sim_tb_dpd_tinyml_tree" "xelab.log"
Write-Host "[rtl] compare every decision with Python golden vectors"
Invoke-VivadoCmd "xsim sim_tb_dpd_tinyml_tree -runall" "xsim.log"
if (-not (Select-String -LiteralPath (Join-Path $work "xsim.log") `
    -Pattern "RTL TinyML tree PASS:" -SimpleMatch)) {
  throw "RTL PASS marker not found in XSim log"
}

Write-Host "Python/C/RTL TinyML tree equivalence PASS"

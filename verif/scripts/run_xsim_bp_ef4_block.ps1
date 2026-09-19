param([int]$Samples = 2048, [string]$Python = "python", [int]$Seed = 20260915)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }
$work = Join-Path $repo "verif\out_xsim_bp_ef4_block"
New-Item -ItemType Directory -Force -Path $work | Out-Null
& $Python (Join-Path $repo "uvm_verif\refmodel\python\generate_bp_ef4_vectors.py") --samples $Samples --seed $Seed --output (Join-Path $work "bp_ef4_equivalence.csv")
if ($LASTEXITCODE -ne 0) { throw "BP EFDSM4 vector generation failed." }
$rtl = Join-Path $repo "rtl\tx_bandpass_if\dsm_core_bp_ef4.sv"
$tb = Join-Path $repo "verif\block\bp_dsm\tb\tb_dsm_core_bp_ef4_bittrue.sv"
Push-Location $work
try {
  $cmd = Join-Path $env:TEMP ("run_bp_ef4_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -LiteralPath $cmd -Encoding ASCII -Value ("@echo off`r`ncall `"$settings`" >nul`r`nxvlog -sv `"$rtl`" `"$tb`" -log xvlog.log`r`nif errorlevel 1 exit /b 1`r`nxelab -debug typical tb_dsm_core_bp_ef4_bittrue -s sim_bp_ef4 -log xelab.log`r`nif errorlevel 1 exit /b 1`r`nxsim sim_bp_ef4 -runall -log xsim.log")
  cmd.exe /c $cmd
  if ($LASTEXITCODE -ne 0) { throw "BP EFDSM4 XSim failed." }
} finally { Remove-Item -LiteralPath $cmd -Force -ErrorAction SilentlyContinue; Pop-Location }
if (-not (Select-String -LiteralPath (Join-Path $work "xsim.log") -Pattern "BP_EFDSM4_BLOCK_BITTRUE_PASS" -Quiet)) { throw "BP EFDSM4 PASS marker was not found." }
Write-Host "BP EFDSM4 Python-to-RTL block bit-true passed: $Samples samples."

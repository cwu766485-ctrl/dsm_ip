$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }
$work = Join-Path $repo "verif\out_xsim_mash11_multipa"
New-Item -ItemType Directory -Force -Path $work | Out-Null
Remove-Item -LiteralPath (Join-Path $work "xsim.dir") -Recurse -Force -ErrorAction SilentlyContinue
$core = Join-Path $repo "rtl\dsm\singlebit\dsm_core_mash11.sv"
$rtl = Join-Path $repo "rtl\tx_bandpass_if\mash11_multipa_tx.sv"
$tb = Join-Path $repo "verif\block\bp_dsm\tb\tb_mash11_multipa_tx.sv"
Push-Location $work
try {
  $cmd = Join-Path $env:TEMP ("run_mash11_multipa_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -LiteralPath $cmd -Encoding ASCII -Value ("@echo off`r`ncall `"$settings`" >nul && xvlog -sv `"$core`" `"$rtl`" `"$tb`" -log xvlog.log && xelab -debug typical tb_mash11_multipa_tx -s sim_mash11_multipa -log xelab.log && xsim sim_mash11_multipa -runall -log xsim.log")
  cmd.exe /c $cmd
  if ($LASTEXITCODE -ne 0) { throw "MASH11 multi-PA XSim failed" }
} finally { Remove-Item -LiteralPath $cmd -Force -ErrorAction SilentlyContinue; Pop-Location }
if (-not (Select-String -LiteralPath (Join-Path $work "xsim.log") -Pattern "MASH11_MULTIPA_INTERFACE_PASS" -Quiet)) { throw "MASH11 multi-PA PASS marker missing" }
Write-Host "MASH11 multi-PA interface XSim PASS."

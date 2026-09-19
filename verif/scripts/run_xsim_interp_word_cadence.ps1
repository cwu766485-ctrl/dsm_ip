$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }
$work = Join-Path $repo "verif\out_xsim_interp_word_cadence"
New-Item -ItemType Directory -Force -Path $work | Out-Null
Remove-Item -LiteralPath (Join-Path $work "xsim.dir") -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $work "xsim.log") -Force -ErrorAction SilentlyContinue
$rtl = Join-Path $repo "rtl\interp\dsm_interp_word_cadence16.sv"
$tb = Join-Path $repo "verif\block\interp\tb\tb_dsm_interp_word_cadence16.sv"
Push-Location $work
try {
  $cmd = Join-Path $env:TEMP ("run_interp_cadence_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -LiteralPath $cmd -Encoding ASCII -Value ("@echo off`r`ncall `"$settings`" >nul && xvlog -sv `"$rtl`" `"$tb`" -log xvlog.log && xelab -debug typical tb_dsm_interp_word_cadence16 -s sim_interp_cadence -log xelab.log && xsim sim_interp_cadence -runall -log xsim.log")
  cmd.exe /c $cmd
  if ($LASTEXITCODE -ne 0) { throw "interpolator cadence XSim failed" }
} finally { Remove-Item -LiteralPath $cmd -Force -ErrorAction SilentlyContinue; Pop-Location }
foreach ($log in @("xvlog.log", "xelab.log", "xsim.log")) {
  if ((Test-Path -LiteralPath (Join-Path $work $log)) -and
      (Select-String -LiteralPath (Join-Path $work $log) -Pattern "ERROR:" -Quiet)) {
    throw "Vivado reported an error in $log"
  }
}
if (-not (Select-String -LiteralPath (Join-Path $work "xsim.log") -Pattern "INTERP_WORD_CADENCE16_PASS" -Quiet)) { throw "cadence PASS marker missing" }
Write-Host "Interpolator word cadence XSim PASS."

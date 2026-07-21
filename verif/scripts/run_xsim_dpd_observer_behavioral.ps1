param([switch]$SkipMatlabPrep)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }

if (-not $SkipMatlabPrep) {
  matlab -batch "cd('$($repo.Replace('\','/'))/matlab'); path_setup; prepare_dpd_observer_behavioral_vectors;"
  if ($LASTEXITCODE -ne 0) { throw "MATLAB observer vector preparation failed" }
}

$work = Join-Path $repo "verif\out_xsim_dpd_observer"
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
Copy-Item (Join-Path $repo "matlab\out\dpd\observer\*.csv") $work -Force
Set-Location $work

function Invoke-Xilinx([string]$Command) {
  $cmdFile = Join-Path $env:TEMP ("run_observer_" + [guid]::NewGuid() + ".cmd")
  Set-Content -LiteralPath $cmdFile -Encoding ASCII -Value ("@echo off`r`ncall `"$settings`" >nul`r`n$Command`r`n")
  try {
    cmd.exe /c $cmdFile
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
  } finally {
    Remove-Item -LiteralPath $cmdFile -Force -ErrorAction SilentlyContinue
  }
}

$rtl = Join-Path $repo "rtl\dpd\dpd_observer.v"
$tb = Join-Path $repo "verif\tb\tb_dpd_observer_behavioral.sv"
Invoke-Xilinx "xvlog -sv `"$rtl`" `"$tb`""
Invoke-Xilinx "xelab -debug typical tb_dpd_observer_behavioral -s sim_dpd_observer_behavioral"
Invoke-Xilinx "xsim sim_dpd_observer_behavioral -runall"
$xsimLog = Join-Path $work "xsim.log"
if (Select-String -LiteralPath $xsimLog -Pattern "Fatal:" -SimpleMatch) {
  throw "Behavioral PA observer simulation reported a fatal failure"
}
if (-not (Select-String -LiteralPath $xsimLog -Pattern "Behavioral PA observer PASS" -SimpleMatch)) {
  throw "Behavioral PA observer simulation did not report PASS"
}
Write-Host "[xsim] behavioral PA observation loop PASS"

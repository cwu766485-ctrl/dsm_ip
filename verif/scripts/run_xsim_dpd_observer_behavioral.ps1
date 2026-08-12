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
$originalLocation = Get-Location
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

try {
  $rtl = Join-Path $repo "rtl\dpd\dpd_observer.v"
  $tb = Join-Path $repo "verif\block\monitor\tb\tb_dpd_observer_behavioral.sv"
  $tbRandom = Join-Path $repo "verif\block\monitor\tb\tb_dpd_observer_random_protocol.sv"
  Invoke-Xilinx "xvlog -sv `"$rtl`" `"$tb`" `"$tbRandom`""
  Invoke-Xilinx "xelab -debug typical tb_dpd_observer_behavioral -s sim_dpd_observer_behavioral"
  Invoke-Xilinx "xsim sim_dpd_observer_behavioral -log behavioral_xsim.log -runall"
  Invoke-Xilinx "xelab -debug typical tb_dpd_observer_random_protocol -s sim_dpd_observer_random_protocol"
  Invoke-Xilinx "xsim sim_dpd_observer_random_protocol -log random_xsim.log -runall"
  $behavioralLog = Join-Path $work "behavioral_xsim.log"
  $randomLog = Join-Path $work "random_xsim.log"
  if (Select-String -LiteralPath $behavioralLog,$randomLog -Pattern "Fatal:" -SimpleMatch) {
    throw "Behavioral PA observer simulation reported a fatal failure"
  }
  if (-not (Select-String -LiteralPath $behavioralLog -Pattern "Behavioral PA observer PASS" -SimpleMatch)) {
    throw "Behavioral PA observer simulation did not report PASS"
  }
  if (-not (Select-String -LiteralPath $randomLog -Pattern "DPD_OBSERVER_RANDOM_PROTOCOL_PASS" -SimpleMatch)) {
    throw "Observer random protocol simulation did not report PASS"
  }
  Write-Host "[xsim] behavioral PA observation loop PASS"
} finally {
  Set-Location $originalLocation
}

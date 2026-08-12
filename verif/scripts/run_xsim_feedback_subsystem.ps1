$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }

$work = Join-Path $repo "verif\out_xsim_feedback_subsystem"
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
$files = @(
  (Join-Path $repo "rtl\dpd\dpd_observer_async_bridge.v"),
  (Join-Path $repo "rtl\dpd\dpd_observer.v"),
  (Join-Path $repo "verif\subsystem\feedback\tb\tb_feedback_bridge_observer.sv")
)

function Invoke-XsimTool([string]$Command, [string]$LogName) {
  $cmdFile = Join-Path $env:TEMP ("run_feedback_subsystem_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -LiteralPath $cmdFile -Encoding ASCII -Value ("@echo off`r`ncall `"$settings`" >nul`r`n$Command`r`n")
  try {
    cmd.exe /c $cmdFile
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
    $log = Join-Path $work $LogName
    if (-not (Test-Path -LiteralPath $log)) { throw "Missing XSim log: $LogName" }
    if (Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch -Quiet) {
      throw "XSim reported ERROR in $LogName"
    }
  } finally {
    Remove-Item -LiteralPath $cmdFile -Force -ErrorAction SilentlyContinue
  }
}

Push-Location $work
try {
  $quotedFiles = ($files | ForEach-Object { '"' + $_ + '"' }) -join ' '
  Invoke-XsimTool "xvlog -sv -log xvlog.log $quotedFiles" "xvlog.log"
  Invoke-XsimTool "xelab -debug typical -log xelab.log tb_feedback_bridge_observer -s sim_feedback_subsystem" "xelab.log"
  Invoke-XsimTool "xsim sim_feedback_subsystem -log xsim.log -runall" "xsim.log"
} finally {
  Pop-Location
}
if (-not (Select-String -LiteralPath (Join-Path $work "xsim.log") -Pattern "FEEDBACK_SUBSYSTEM_PASS" -Quiet)) {
  throw "Feedback subsystem PASS marker was not found."
}
Write-Host "Feedback bridge-to-observer subsystem passed."

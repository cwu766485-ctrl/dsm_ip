param(
  [int]$IfDsmSamples = 4096,
  [int]$TxInputs = 97,
  [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

& (Join-Path $PSScriptRoot "run_xsim_if_dsm_bittrue.ps1") -Samples $IfDsmSamples -Python $Python
if ($LASTEXITCODE -ne 0) { throw "IF/DSM subsystem regression failed." }

& (Join-Path $PSScriptRoot "run_xsim_tx_frontend_bittrue.ps1") -Inputs $TxInputs -Python $Python
if ($LASTEXITCODE -ne 0) { throw "TX frontend subsystem regression failed." }

& (Join-Path $PSScriptRoot "run_xsim_feedback_subsystem.ps1")
if ($LASTEXITCODE -ne 0) { throw "Feedback subsystem regression failed." }

Write-Host "[subsystem-signoff] PASS: IF/DSM, TX frontend, and feedback regressions completed."

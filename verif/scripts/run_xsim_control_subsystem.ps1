param(
  [switch]$KeepWork
)

$ErrorActionPreference = "Stop"

# Control functions are meaningful only in the AXI-wrapped IP context.  The
# runner below compiles the complete wrapper and executes the control TB under
# verif/subsystem/control/tb, in addition to the retained IP-top smoke.
$args = @()
if ($KeepWork) { $args += "-KeepWork" }
& (Join-Path $PSScriptRoot "run_xsim_ip_smoke.ps1") @args
if ($LASTEXITCODE -ne 0) { throw "Control subsystem regression failed." }

Write-Host "Control subsystem regression passed."

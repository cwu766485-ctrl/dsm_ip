param(
  [string]$BridgeRoot = $env:DSM_UVM_BRIDGE_ROOT
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($BridgeRoot)) {
  throw "Pass -BridgeRoot <shared-folder> or set DSM_UVM_BRIDGE_ROOT."
}
$linuxCommand = Join-Path $PSScriptRoot "run_control_coverage_linux.sh"
$commandFile = Join-Path $BridgeRoot "command.sh"
$activeFile = Join-Path $BridgeRoot "command.active.sh"
$statusFile = Join-Path $BridgeRoot "status.txt"

if (!(Test-Path -LiteralPath $linuxCommand)) {
  throw "Repository command script is missing: $linuxCommand"
}
if (!(Test-Path -LiteralPath $statusFile)) {
  throw "Bridge is not running: $statusFile is missing. Start the Linux bridge first."
}
if ((Test-Path -LiteralPath $commandFile) -or (Test-Path -LiteralPath $activeFile)) {
  throw "Bridge already has a pending or active command. Inspect $statusFile before submitting another task."
}

# The Linux bridge owns execution under its existing user and EDA environment.
# This script only submits repository-owned commands over the shared F: drive.
Copy-Item -LiteralPath $linuxCommand -Destination $commandFile -Force
Write-Host "Submitted control UVM coverage command to $BridgeRoot"
Get-Content -LiteralPath $statusFile
Write-Host "Wait for last_exit=0, then inspect $BridgeRoot\result.log"

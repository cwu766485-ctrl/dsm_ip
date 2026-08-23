param(
  [string]$BridgeRoot = $env:DSM_UVM_BRIDGE_ROOT
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($BridgeRoot)) {
  throw "Pass -BridgeRoot <shared-folder> or set DSM_UVM_BRIDGE_ROOT."
}
$linuxCommand = Join-Path $PSScriptRoot "run_subsystem_vcs_linux.sh"
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

Copy-Item -LiteralPath $linuxCommand -Destination $commandFile -Force
Write-Host "Submitted subsystem VCS regression to $BridgeRoot"
Get-Content -LiteralPath $statusFile
Write-Host "Wait for last_exit=0, then inspect $BridgeRoot\result.log"

param(
  [ValidateSet("wsl", "ssh")]
  [string]$Mode = "wsl",
  [string]$Target = "",
  [string]$RemoteRepo = "/mnt/e/workspace/chip/dsm_ip",
  [Parameter(Mandatory = $true)]
  [string]$Command
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Command)) {
  throw "-Command must contain a Linux command"
}

if ($Mode -eq "wsl") {
  if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "wsl.exe is not available"
  }
  & wsl.exe --cd $RemoteRepo -- bash -lc $Command
  exit $LASTEXITCODE
}

if ([string]::IsNullOrWhiteSpace($Target)) {
  throw "-Target user@host is required for SSH mode"
}
if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) {
  throw "ssh.exe is not available"
}

# Authentication remains in the user's SSH config/agent. This file stores no
# password, private key, host address, license path, or server credential.
$remoteCommand = "cd '$RemoteRepo' && $Command"
& ssh.exe -- $Target $remoteCommand
exit $LASTEXITCODE

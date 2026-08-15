param(
  [string]$Distro = "Rocky-8.10"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($repo -notmatch '^([A-Za-z]):(.*)$') {
  throw "Expected a drive-qualified Windows repository path: $repo"
}

$drive = $Matches[1].ToLowerInvariant()
$tail = $Matches[2].Replace('\', '/')
$linuxRepo = "/mnt/$drive$tail"
$linuxRunner = "uvm_verif/formal/run_dsm_ip_fpv_linux.sh"
& wsl.exe -d $Distro --cd $linuxRepo bash -ic "bash $linuxRunner"
exit $LASTEXITCODE

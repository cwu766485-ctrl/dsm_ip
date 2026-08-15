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

& wsl.exe -d $Distro --cd $linuxRepo bash -ic `
  "bash uvm_verif/formal/check_formal_tools_linux.sh"
exit $LASTEXITCODE

param(
    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [string]$User = "root",
    [string]$DsmBase = "0xA0010000",
    [ValidateSet("status", "bypass", "poly", "lut")]
    [string]$Mode = "status",
    [string]$RemoteDir = "/tmp/dsm_ip_ps",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$localScript = Join-Path $scriptDir "dsm_dpd_ps_control.py"
if (-not (Test-Path $localScript)) {
    throw "Missing local script: $localScript"
}

$target = "$User@$HostName"
$ssh = Get-Command ssh -ErrorAction Stop
$scp = Get-Command scp -ErrorAction Stop

& $ssh.Source $target "mkdir -p $RemoteDir"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to create remote directory on $target"
}

& $scp.Source $localScript "${target}:$RemoteDir/"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to copy PS control script to $target"
}

$remoteScript = "$RemoteDir/dsm_dpd_ps_control.py"
$common = "python3 $remoteScript --dsm-base $DsmBase"
if ($DryRun) {
    $common = "$common --dry-run"
}

switch ($Mode) {
    "status" { $cmd = "$common status" }
    "bypass" { $cmd = "$common bypass" }
    "poly" { $cmd = "$common poly --c1 0xFFFB4009 --c3 0xF1A41F6F --c5 0xDE503A39" }
    "lut" { $cmd = "$common lut --lut-default 0x00004000" }
}

Write-Host "Running on ${target}: $cmd"
& $ssh.Source $target $cmd
if ($LASTEXITCODE -ne 0) {
    throw "Remote PS DPD control command failed"
}

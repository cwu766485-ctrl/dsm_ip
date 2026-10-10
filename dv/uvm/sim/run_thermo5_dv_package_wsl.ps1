param(
  [string]$Distro='Rocky-8.10',
  [string]$XpmRoot='/mnt/d/Xilinx/Vivado/2024.1',
  [string]$RangeVectors='runs/thermo5_gap_vectors_20261006/range_long',
  [int]$RangeWords=2072,
  [string]$GainVectors='',
  [switch]$UnboundedCounter,
  [string]$OutDir='',
  [switch]$DryRun
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if($OutDir -eq '') {$OutDir='runs/thermo5_dv_package_'+(Get-Date -Format 'yyyyMMdd_HHmmss')}
if($repo -notmatch '^([A-Za-z]):(.*)$'){throw 'Expected drive-qualified workspace'}
$linuxRepo='/mnt/'+$Matches[1].ToLowerInvariant()+$Matches[2].Replace('\','/')
foreach($value in @($XpmRoot,$RangeVectors,$OutDir)) {
  if($value -notmatch '^[A-Za-z0-9_./:-]+$'){throw 'Use paths without shell metacharacters or spaces'}
}
$command="python3.12 dv/uvm/sim/run_thermo5_dv_package.py --xpm-root $XpmRoot --range-vectors $RangeVectors --out-dir $OutDir"
$command+=" --range-words $RangeWords"
if($GainVectors -ne '') {
  if($GainVectors -notmatch '^[A-Za-z0-9_./:-]+$'){throw 'Use GainVectors without shell metacharacters or spaces'}
  $command+=" --gain-vectors $GainVectors"
}
if($UnboundedCounter){$command+=' --unbounded-counter'}
if($DryRun){$command+=' --dry-run'}
& wsl.exe -d $Distro --cd $linuxRepo -- bash -lic $command
exit $LASTEXITCODE

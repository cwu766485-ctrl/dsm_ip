param(
  [int]$BpSamples = 4096,
  [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$runner = Join-Path $repo "verif\scripts"

function Invoke-BlockRunner([string]$Name, [scriptblock]$Command) {
  Write-Host "[block-signoff] $Name"
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "Block signoff failed: $Name" }
}

Invoke-BlockRunner "DPD" {
  & (Join-Path $runner "run_xsim_dpd_bittrue.ps1")
}
Invoke-BlockRunner "Interpolation" {
  & (Join-Path $runner "run_xsim_interp_frontend.ps1")
}
Invoke-BlockRunner "Fs/4 mixer" {
  & (Join-Path $runner "run_xsim_fs4_mixer_block.ps1")
}
Invoke-BlockRunner "BP EFDSM2" {
  & (Join-Path $runner "run_xsim_bp_dsm_block.ps1") -Samples $BpSamples -Python $Python
}
Invoke-BlockRunner "Observer/monitor" {
  & (Join-Path $runner "run_xsim_dpd_observer_behavioral.ps1")
}

Write-Host "[block-signoff] PASS: all block exit criteria completed."

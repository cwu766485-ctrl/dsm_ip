# Backward-compatible entry point. Canonical runner lives with the GT-user block.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\block\gt\run_xsim_thermo5_raw64_continuous_tx.ps1')

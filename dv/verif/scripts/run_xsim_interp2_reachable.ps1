# Backward-compatible entry point. Canonical runner lives with the interpolation block.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\block\interp\run_xsim_interp2_reachable.ps1')

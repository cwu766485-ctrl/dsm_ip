# Backward-compatible entry point. Canonical runner lives with the AXIS/FIFO block.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\block\axis\run_xsim_axis14_to_core8_cdc.ps1')

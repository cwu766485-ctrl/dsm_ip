# Backward-compatible entry point. Canonical runner lives with the AXIS/FIFO block.
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\block\axis\run_xsim_frame_power_ctrl.ps1')

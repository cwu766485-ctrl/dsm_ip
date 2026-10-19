param([int]$Vectors = 128, [int]$Seed = 20260915)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\block\tid32\run_xsim_tid32_cartesian_fs4_gt_tx.ps1') @PSBoundParameters

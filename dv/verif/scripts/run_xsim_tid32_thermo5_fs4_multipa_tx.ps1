param([int]$Vectors = 128, [int]$Seed = 20260917, [int]$Step = 6144)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\subsystem\tx_backend\run_xsim_tid32_thermo5_fs4_multipa_tx.ps1') @PSBoundParameters

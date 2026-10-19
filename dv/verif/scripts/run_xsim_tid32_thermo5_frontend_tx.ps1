param([int]$Words = 64, [int]$Seed = 20260918, [int]$Step = 7168)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\subsystem\tx_frontend\run_xsim_tid32_thermo5_frontend_tx.ps1') @PSBoundParameters

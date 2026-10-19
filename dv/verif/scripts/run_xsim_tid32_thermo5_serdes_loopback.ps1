param([int]$Words = 64, [int]$Seed = 20260918, [int]$Step = 7168)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\integration\serializer_loopback\run_xsim_tid32_thermo5_serdes_loopback.ps1') @PSBoundParameters

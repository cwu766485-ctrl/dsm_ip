param(
  [switch]$StressPaReady,
  [switch]$XpmFifo,
  [switch]$ProbeInterp1EmptyBlocked,
  [switch]$AxilControl,
  [int]$Seed = 1,
  [int]$Words = 56,
  [string]$VectorDir = ''
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\subsystem\tx_frontend\run_xsim_thermo5_i2_d1_axis.ps1') @PSBoundParameters

$ErrorActionPreference = "Stop"

# run_xsim_p0.ps1
# Purpose:
#   Template runner for Vivado xsim using the 100 MHz release filelist.
#
# Prereq:
#   - Vivado installed and `xvlog/xelab/xsim` on PATH (or source settings64.bat)
#
# Usage (PowerShell):
#   cd verif/scripts
#   ./run_xsim_p0.ps1

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Resolve-Path (Join-Path $here "..\..\..")
$work = Join-Path $repo "verif\out_xsim_p0"

New-Item -ItemType Directory -Force -Path $work | Out-Null
Set-Location $work

$filelist = Join-Path $repo "rtl\filelist_p0.f"

Write-Host "[xsim] Compile (xvlog) using filelist: $filelist"
xvlog -sv -f $filelist

Write-Host "[xsim] Elaborate (xelab)"
xelab -debug typical tb_p0_lp1 -s tb_p0_lp1
xsim tb_p0_lp1 -runall

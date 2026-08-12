param(
  [switch]$SkipMatlabPrep,
  [switch]$SkipMatlabCompare
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$vivadoSettings = 'D:\Xilinx\Vivado\2024.1\settings64.bat'
if (-not (Test-Path -LiteralPath $vivadoSettings)) {
  throw "Vivado settings not found at $vivadoSettings. Update this script for the local installation."
}

$vecDir = Join-Path $repo 'matlab\out\dpd\lpdsmdpa_bpf_bittrue'
$work = Join-Path $repo 'verif\out_xsim_lpdsmdpa_bpf_dpd'
New-Item -ItemType Directory -Force -Path $work | Out-Null

if (-not $SkipMatlabPrep) {
  $repoForMatlab = $repo.Replace('\', '/')
  & matlab -batch "cd('$repoForMatlab/matlab'); path_setup; entry_lpdsmdpa_bpf_dpd_bittrue_prepare;"
  if ($LASTEXITCODE -ne 0) { throw 'MATLAB release-vector generation failed.' }
}

foreach ($name in @('dpd_mp_input_iq.csv', 'dpd_mp_coefficients.csv', 'dpd_mp_expected_iq.csv')) {
  $source = Join-Path $vecDir $name
  if (-not (Test-Path -LiteralPath $source)) {
    throw "Missing release-gated MATLAB vector: $source"
  }
  Copy-Item -LiteralPath $source -Destination (Join-Path $work $name) -Force
}

function Invoke-VivadoCmd([string]$Command) {
  $bat = Join-Path $env:TEMP ('run_lpdsmdpa_dpd_' + [guid]::NewGuid().ToString() + '.cmd')
  Set-Content -LiteralPath $bat -Encoding ASCII -Value "@echo off`r`ncall `"$vivadoSettings`" >nul`r`n$Command`r`n"
  try {
    cmd.exe /c $bat
    if ($LASTEXITCODE -ne 0) { throw "Vivado command failed: $Command" }
  } finally {
    Remove-Item -LiteralPath $bat -Force -ErrorAction SilentlyContinue
  }
}

$poly = Join-Path $repo 'rtl\dpd\dpd_poly.v'
$memory = Join-Path $repo 'rtl\dpd\dpd_memory_poly.v'
$tb = Join-Path $repo 'verif\block\dpd\tb\tb_dpd_memory_poly_bittrue.sv'
Remove-Item -LiteralPath (Join-Path $work 'xsim.dir') -Recurse -Force -ErrorAction SilentlyContinue
Push-Location $work
try {
  Write-Host '[xsim] compile release-gated LPDSM2 DPA+BPF Memory-Poly DPD'
  Invoke-VivadoCmd "xvlog -sv `"$poly`" `"$memory`" `"$tb`""
  Write-Host '[xsim] elaborate release-gated Memory-Poly DPD'
  Invoke-VivadoCmd 'xelab -debug typical tb_dpd_memory_poly_bittrue -s sim_lpdsmdpa_bpf_dpd'
  Write-Host '[xsim] run release-gated Memory-Poly DPD'
  Invoke-VivadoCmd 'xsim sim_lpdsmdpa_bpf_dpd -runall'
} finally {
  Pop-Location
}

$rtlDump = Join-Path $work 'dpd_mp_rtl_iq.csv'
if (-not (Test-Path -LiteralPath $rtlDump)) {
  throw "XSim completed without producing $rtlDump"
}

if (-not $SkipMatlabCompare) {
  $repoForMatlab = $repo.Replace('\', '/')
  & matlab -batch "cd('$repoForMatlab/matlab'); path_setup; entry_lpdsmdpa_bpf_dpd_bittrue_compare;"
  if ($LASTEXITCODE -ne 0) { throw 'MATLAB release-vector comparison failed.' }
} else {
  Write-Host '[xsim] MATLAB compare skipped by request.'
}

Write-Host "[xsim] LPDSM2 DPA+BPF release bit-true flow complete: $work"

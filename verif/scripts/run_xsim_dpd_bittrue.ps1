param(
  [switch]$SkipMatlabPrep
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$vivadoSettings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path $vivadoSettings)) {
  throw "Vivado settings not found at $vivadoSettings. Update run_xsim_dpd_bittrue.ps1."
}

$work = Join-Path $repo "verif\out_xsim_dpd"
New-Item -ItemType Directory -Force -Path $work | Out-Null

if (-not $SkipMatlabPrep) {
  matlab -batch "cd('$($repo.Replace('\','/'))/matlab'); path_setup; prepare_dpd_bittrue_vectors('n_input',256); prepare_dpd_memory_poly_bittrue_vectors('n_input',256);"
  if ($LASTEXITCODE -ne 0) { throw "MATLAB DPD vector preparation failed" }
}

$vecDir = Join-Path $repo "matlab\out\dpd\bittrue"
Copy-Item (Join-Path $vecDir "dpd_input_iq.csv") (Join-Path $work "dpd_input_iq.csv") -Force
Copy-Item (Join-Path $vecDir "dpd_coefficients.csv") (Join-Path $work "dpd_coefficients.csv") -Force
Copy-Item (Join-Path $vecDir "dpd_mp_input_iq.csv") (Join-Path $work "dpd_mp_input_iq.csv") -Force
Copy-Item (Join-Path $vecDir "dpd_mp_coefficients.csv") (Join-Path $work "dpd_mp_coefficients.csv") -Force

Set-Location $work

function Invoke-VivadoCmd($cmd) {
  $log = $null
  if ($cmd -like "xvlog *") {
    $log = Join-Path (Get-Location) "xvlog.log"
  } elseif ($cmd -like "xelab *") {
    $log = Join-Path (Get-Location) "xelab.log"
  } elseif ($cmd -like "xsim *") {
    $log = Join-Path (Get-Location) "xsim.log"
  }
  if ($log) {
    Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue
  }

  $bat = "@echo off`r`n" +
         "call `"$vivadoSettings`" >nul`r`n" +
         "$cmd`r`n"
  $tmp = Join-Path $env:TEMP ("run_xsim_dpd_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -Path $tmp -Value $bat -Encoding ASCII
  try {
    cmd.exe /c $tmp
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
    if ($log -and (Test-Path -LiteralPath $log)) {
      $errors = Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch
      if ($errors) { throw "Vivado reported errors while running: $cmd" }
      $fatals = Select-String -LiteralPath $log -Pattern "Fatal:" -SimpleMatch
      if ($fatals) { throw "Simulation reported fatal failures while running: $cmd" }
    }
  } finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

$dpdPoly = Join-Path $repo "rtl\dpd\dpd_poly.v"
$dpdLut = Join-Path $repo "rtl\dpd\dpd_lut.v"
$dpdMemory = Join-Path $repo "rtl\dpd\dpd_memory_poly.v"
$dpdFrontend = Join-Path $repo "rtl\dpd\dpd_frontend.v"
$tb = Join-Path $repo "verif\tb\tb_dpd_frontend.sv"
$tbMemory = Join-Path $repo "verif\tb\tb_dpd_memory_poly_bittrue.sv"

Write-Host "[xsim] compile DPD bit-true"
Invoke-VivadoCmd "xvlog -sv `"$dpdPoly`" `"$dpdLut`" `"$dpdMemory`" `"$dpdFrontend`" `"$tb`" `"$tbMemory`""

Write-Host "[xsim] elaborate DPD bit-true"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_frontend -s sim_tb_dpd_frontend"

Write-Host "[xsim] run DPD bit-true"
Invoke-VivadoCmd "xsim sim_tb_dpd_frontend -runall"

Write-Host "[xsim] elaborate DPD memory-polynomial bit-true"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_memory_poly_bittrue -s sim_tb_dpd_memory_poly_bittrue"

Write-Host "[xsim] run DPD memory-polynomial bit-true"
Invoke-VivadoCmd "xsim sim_tb_dpd_memory_poly_bittrue -runall"

matlab -batch "cd('$($repo.Replace('\','/'))/matlab'); path_setup; entry_dpd_bittrue_check;"
if ($LASTEXITCODE -ne 0) { throw "MATLAB DPD bit-true compare failed" }

Write-Host "[xsim] DPD bit-true done. Outputs in $work"

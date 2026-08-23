param(
  [switch]$SkipMatlabPrep,
  [switch]$CompileOnly,
  [switch]$SkipPoly7,
  [switch]$SkipMatlabCompare
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
  matlab -batch "cd('$($repo.Replace('\','/'))/matlab'); path_setup; prepare_dpd_bittrue_vectors('n_input',256); prepare_dpd7_bittrue_vectors('n_input',256); prepare_dpd_memory_poly_bittrue_vectors('n_input',256);"
  if ($LASTEXITCODE -ne 0) { throw "MATLAB DPD vector preparation failed" }
}

$originalLocation = Get-Location
try {
Set-Location $work

function Invoke-VivadoCmd([string]$cmd, [string]$ExpectedMarker = "") {
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
    if ($cmd -notmatch '(^|\s)-log(\s|$)') {
      $cmd += " -log `"$log`""
    }
  }

  $bat = "@echo off`r`n" +
         "call `"$vivadoSettings`" >nul`r`n" +
         "$cmd`r`n" +
         "exit /b %ERRORLEVEL%`r`n"
  $tmp = Join-Path $env:TEMP ("run_xsim_dpd_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -Path $tmp -Value $bat -Encoding ASCII
  try {
    cmd.exe /c $tmp
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd" }
    if ($log -and -not (Test-Path -LiteralPath $log)) {
      throw "Vivado emitted no log for: $cmd. The launcher or tool did not start correctly; do not treat this as a simulation pass."
    }
    if ($log) {
      $errors = Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch
      if ($errors) { throw "Vivado reported errors while running: $cmd" }
      $fatals = Select-String -LiteralPath $log -Pattern "Fatal:" -SimpleMatch
      if ($fatals) { throw "Simulation reported fatal failures while running: $cmd" }
      if ($ExpectedMarker -and -not (Select-String -LiteralPath $log -Pattern $ExpectedMarker -SimpleMatch)) {
        throw "Expected pass marker '$ExpectedMarker' was not found in $log."
      }
    }
  } finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  }
}

$dpdPoly = Join-Path $repo "rtl\dpd\dpd_poly.v"
$dpdLut = Join-Path $repo "rtl\dpd\dpd_lut.v"
$dpdMemory = Join-Path $repo "rtl\dpd\dpd_memory_poly.v"
$dpdObserver = Join-Path $repo "rtl\dpd\dpd_observer.v"
$dpdSeedPredictor = Join-Path $repo "rtl\dpd\dpd_seed_predictor.v"
$dpdAsyncBridge = Join-Path $repo "rtl\dpd\dpd_observer_async_bridge.v"
$dpdFrontend = Join-Path $repo "rtl\dpd\dpd_frontend.v"
$tb = Join-Path $repo "verif\block\dpd\tb\tb_dpd_frontend.sv"
$tbMemory = Join-Path $repo "verif\block\dpd\tb\tb_dpd_memory_poly_bittrue.sv"
$tbMemoryRandom = Join-Path $repo "verif\block\dpd\tb\tb_dpd_memory_poly_random_protocol.sv"
$tbSafety = Join-Path $repo "verif\block\dpd\tb\tb_dpd_frontend_safety.sv"
$tbProtocol = Join-Path $repo "verif\block\dpd\tb\tb_dpd_frontend_protocol.sv"
$tbRandomProtocol = Join-Path $repo "verif\block\dpd\tb\tb_dpd_frontend_random_protocol.sv"
$tbPoly7 = Join-Path $repo "verif\block\dpd\tb\tb_dpd_poly7_bittrue.sv"
$tbPoly7Directed = Join-Path $repo "verif\block\dpd\tb\tb_dpd_poly7_directed.sv"
$tbAsyncBridge = Join-Path $repo "verif\block\observer\tb\tb_dpd_observer_async_bridge.sv"
$tbAsyncBridgeRandom = Join-Path $repo "verif\block\observer\tb\tb_dpd_observer_async_bridge_random.sv"
$tbV11 = Join-Path $repo "verif\block\dpd\tb\tb_dpd_v11.sv"
$tbFeatureGates = Join-Path $repo "verif\block\dpd\tb\tb_dpd_feature_gates.sv"
$tbCompileMatrix = Join-Path $repo "verif\block\dpd\tb\tb_dpd_compile_matrix.sv"

Write-Host "[xsim] compile DPD bit-true"
Invoke-VivadoCmd "xvlog -sv `"$dpdPoly`" `"$dpdLut`" `"$dpdMemory`" `"$dpdObserver`" `"$dpdSeedPredictor`" `"$dpdAsyncBridge`" `"$dpdFrontend`" `"$tb`" `"$tbMemory`" `"$tbMemoryRandom`" `"$tbSafety`" `"$tbProtocol`" `"$tbRandomProtocol`" `"$tbPoly7`" `"$tbPoly7Directed`" `"$tbAsyncBridge`" `"$tbAsyncBridgeRandom`" `"$tbV11`" `"$tbFeatureGates`" `"$tbCompileMatrix`""

if ($CompileOnly) {
  Write-Host "[xsim] compile command returned success; no elaboration artifact was checked."
  return
}

Write-Host "[xsim] elaborate directed seventh-order DPD"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_poly7_directed -s sim_tb_dpd_poly7_directed"

Write-Host "[xsim] run directed seventh-order DPD"
Invoke-VivadoCmd "xsim sim_tb_dpd_poly7_directed -runall"

$vecDir = Join-Path $repo "matlab\out\dpd\bittrue"
Copy-Item (Join-Path $vecDir "dpd_input_iq.csv") (Join-Path $work "dpd_input_iq.csv") -Force
Copy-Item (Join-Path $vecDir "dpd_coefficients.csv") (Join-Path $work "dpd_coefficients.csv") -Force
if (-not $SkipPoly7) {
  Copy-Item (Join-Path $vecDir "dpd7_input_iq.csv") (Join-Path $work "dpd7_input_iq.csv") -Force
  Copy-Item (Join-Path $vecDir "dpd7_expected_iq.csv") (Join-Path $work "dpd7_expected_iq.csv") -Force
  Copy-Item (Join-Path $vecDir "dpd7_coefficients.csv") (Join-Path $work "dpd7_coefficients.csv") -Force
}
Copy-Item (Join-Path $vecDir "dpd_mp_input_iq.csv") (Join-Path $work "dpd_mp_input_iq.csv") -Force
Copy-Item (Join-Path $vecDir "dpd_mp_coefficients.csv") (Join-Path $work "dpd_mp_coefficients.csv") -Force

Write-Host "[xsim] elaborate DPD bit-true"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_frontend -s sim_tb_dpd_frontend"

Write-Host "[xsim] run DPD bit-true"
Invoke-VivadoCmd "xsim sim_tb_dpd_frontend -runall"

if (-not $SkipPoly7) {
  Write-Host "[xsim] elaborate seventh-order DPD bit-true"
  Invoke-VivadoCmd "xelab -debug typical tb_dpd_poly7_bittrue -s sim_tb_dpd_poly7_bittrue"

  Write-Host "[xsim] run seventh-order DPD bit-true"
  Invoke-VivadoCmd "xsim sim_tb_dpd_poly7_bittrue -runall"
}

Write-Host "[xsim] elaborate DPD memory-polynomial bit-true"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_memory_poly_bittrue -s sim_tb_dpd_memory_poly_bittrue"

Write-Host "[xsim] run DPD memory-polynomial bit-true"
Invoke-VivadoCmd "xsim sim_tb_dpd_memory_poly_bittrue -runall"

Write-Host "[xsim] elaborate randomized Memory-Poly flow control"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_memory_poly_random_protocol -s sim_tb_dpd_memory_poly_random_protocol"

Write-Host "[xsim] run randomized Memory-Poly flow control"
Invoke-VivadoCmd "xsim sim_tb_dpd_memory_poly_random_protocol -runall" "DPD_MEMORY_RANDOM_PROTOCOL_PASS"

Write-Host "[xsim] elaborate DPD safety"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_frontend_safety -s sim_tb_dpd_frontend_safety"

Write-Host "[xsim] run DPD safety"
Invoke-VivadoCmd "xsim sim_tb_dpd_frontend_safety -runall"

Write-Host "[xsim] elaborate DPD protocol assertions"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_frontend_protocol -s sim_tb_dpd_frontend_protocol"

Write-Host "[xsim] run DPD protocol assertions"
Invoke-VivadoCmd "xsim sim_tb_dpd_frontend_protocol -runall"

Write-Host "[xsim] elaborate randomized DPD protocol"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_frontend_random_protocol -s sim_tb_dpd_frontend_random_protocol"

Write-Host "[xsim] run randomized DPD protocol"
Invoke-VivadoCmd "xsim sim_tb_dpd_frontend_random_protocol -runall"

Write-Host "[xsim] elaborate DPD asynchronous observer bridge"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_observer_async_bridge -s sim_tb_dpd_observer_async_bridge"

Write-Host "[xsim] run DPD asynchronous observer bridge"
Invoke-VivadoCmd "xsim sim_tb_dpd_observer_async_bridge -runall"

Write-Host "[xsim] elaborate randomized DPD asynchronous observer bridge"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_observer_async_bridge_random -s sim_tb_dpd_observer_async_bridge_random"

Write-Host "[xsim] run randomized DPD asynchronous observer bridge"
Invoke-VivadoCmd "xsim sim_tb_dpd_observer_async_bridge_random -runall"

Write-Host "[xsim] elaborate DPD v1.1 observer/predictor boundary test"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_v11 -s sim_tb_dpd_v11"

Write-Host "[xsim] run DPD v1.1 observer/predictor boundary test"
Invoke-VivadoCmd "xsim sim_tb_dpd_v11 -runall"

Write-Host "[xsim] elaborate DPD feature gates"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_feature_gates -s sim_tb_dpd_feature_gates"

Write-Host "[xsim] run DPD feature gates"
Invoke-VivadoCmd "xsim sim_tb_dpd_feature_gates -runall"

Write-Host "[xsim] elaborate DPD compile-time configuration matrix"
Invoke-VivadoCmd "xelab -debug typical tb_dpd_compile_matrix -s sim_tb_dpd_compile_matrix"

Write-Host "[xsim] run DPD compile-time configuration matrix"
Invoke-VivadoCmd "xsim sim_tb_dpd_compile_matrix -runall"

if (-not $SkipMatlabCompare) {
  if ($SkipPoly7) {
    matlab -batch "cd('$($repo.Replace('\','/'))/matlab'); path_setup; T=compare_dpd_rtl_xsim; disp(T); assert(T.mismatch==0); Tm=compare_dpd_memory_poly_rtl_xsim; disp(Tm); assert(Tm.mismatch==0);"
  } else {
    matlab -batch "cd('$($repo.Replace('\','/'))/matlab'); path_setup; entry_dpd_bittrue_check;"
  }
  if ($LASTEXITCODE -ne 0) { throw "MATLAB DPD bit-true compare failed" }
} else {
  Write-Host "[xsim] MATLAB compare skipped by request."
}

Write-Host "[xsim] DPD bit-true done. Outputs in $work"
} finally {
  Set-Location $originalLocation
}

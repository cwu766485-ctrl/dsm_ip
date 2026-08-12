param(
  [int]$Inputs = 97,
  [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }

$work = Join-Path $repo "verif\out_xsim_tx_frontend"
if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null
$generator = Join-Path $repo "uvm_verif\refmodel\python\generate_tx_frontend_vectors.py"
& $Python $generator --inputs $Inputs --mode 1 --output (Join-Path $work "tx_frontend_equivalence.csv")
if ($LASTEXITCODE -ne 0) { throw "TX frontend Python vector generation failed." }

$files = @(
  (Join-Path $repo "rtl\dpd\dpd_poly.v"),
  (Join-Path $repo "rtl\dpd\dpd_lut.v"),
  (Join-Path $repo "rtl\dpd\dpd_memory_poly.v"),
  (Join-Path $repo "rtl\dpd\dpd_frontend.v"),
  (Join-Path $repo "rtl\interp\dsm_interp_fir_fixed.sv"),
  (Join-Path $repo "rtl\interp\dsm_interp2_halfband.sv"),
  (Join-Path $repo "rtl\interp\dsm_interp_frontend.sv"),
  (Join-Path $repo "verif\subsystem\tx_frontend\tb_tx_frontend_python_bittrue.sv")
)

function Invoke-XsimTool([string]$Command, [string]$LogName) {
  $cmdFile = Join-Path $env:TEMP ("run_tx_frontend_" + [guid]::NewGuid().ToString() + ".cmd")
  Set-Content -LiteralPath $cmdFile -Encoding ASCII -Value ("@echo off`r`ncall `"$settings`" >nul`r`n$Command`r`n")
  try {
    cmd.exe /c $cmdFile
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $Command" }
    $log = Join-Path $work $LogName
    if (-not (Test-Path -LiteralPath $log)) { throw "Missing XSim log: $LogName" }
    if (Select-String -LiteralPath $log -Pattern "ERROR:" -SimpleMatch -Quiet) {
      throw "XSim reported ERROR in $LogName"
    }
  } finally {
    Remove-Item -LiteralPath $cmdFile -Force -ErrorAction SilentlyContinue
  }
}

Push-Location $work
try {
  $quotedFiles = ($files | ForEach-Object { '"' + $_ + '"' }) -join ' '
  Invoke-XsimTool "xvlog -sv -log xvlog.log $quotedFiles" "xvlog.log"
  Invoke-XsimTool "xelab -debug typical -log xelab.log tb_tx_frontend_python_bittrue -s sim_tx_frontend" "xelab.log"
  Invoke-XsimTool "xsim sim_tx_frontend -log xsim.log -runall" "xsim.log"
} finally {
  Pop-Location
}
if (-not (Select-String -LiteralPath (Join-Path $work "xsim.log") -Pattern "TX_FRONTEND_PYTHON_BITTRUE_PASS" -Quiet)) {
  throw "TX frontend PASS marker was not found."
}
Write-Host "TX frontend Python-to-RTL bit-true passed: $Inputs inputs."

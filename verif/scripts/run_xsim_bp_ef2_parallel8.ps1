param(
  [int]$Vectors = 32,
  [int]$Seed = 20260904,
  [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$settings = "D:\Xilinx\Vivado\2024.1\settings64.bat"
if (-not (Test-Path -LiteralPath $settings)) { throw "Vivado settings not found: $settings" }

$work = Join-Path $repo "verif\out_xsim_bp_dsm_parallel8"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$generator = Join-Path $repo "uvm_verif\refmodel\python\generate_bp_ef2_parallel8_vectors.py"
$vector = Join-Path $work "bp_ef2_parallel8_vectors.csv"
& $Python $generator --vectors $Vectors --seed $Seed --output $vector
if ($LASTEXITCODE -ne 0) { throw "Parallel8 Python vector generation failed." }

$rtl = Join-Path $repo "rtl\tx_bandpass_if\bp_ef2_parallel8.sv"
$tb = Join-Path $repo "verif\block\bp_dsm\tb\tb_bp_ef2_parallel8.sv"
Push-Location $work
try {
  $cmdFile = Join-Path $env:TEMP ("run_xsim_parallel8_" + [guid]::NewGuid().ToString() + ".cmd")
  # Keep the same settings-first invocation used by the existing XSim flows.
  # The local wrapper may terminate the batch context in the restricted
  # automation shell; the GUI Tcl entry point remains the authoritative path.
  $batch = "@echo off`r`ncall `"$settings`" >nul`r`ncd /d `"$work`"`r`nxvlog -sv `"$rtl`" `"$tb`" > xvlog.log 2>&1`r`nif errorlevel 1 exit /b 1`r`nxelab -debug typical tb_bp_ef2_parallel8 -s sim_bp_ef2_parallel8 > xelab.log 2>&1`r`nif errorlevel 1 exit /b 1`r`nxsim sim_bp_ef2_parallel8 -runall > xsim.log 2>&1`r`nif errorlevel 1 exit /b 1`r`n"
  Set-Content -LiteralPath $cmdFile -Encoding ASCII -Value $batch
  try {
    cmd.exe /d /c $cmdFile
    if ($LASTEXITCODE -ne 0) {
      Get-ChildItem -Path . -Filter '*.log' | ForEach-Object { Get-Content $_.FullName -Tail 80 }
      throw "XSim parallel8 command failed."
    }
  } finally {
    Remove-Item -LiteralPath $cmdFile -Force -ErrorAction SilentlyContinue
  }
} finally {
  Pop-Location
}
if (-not (Test-Path -LiteralPath (Join-Path $work "xsim.log"))) {
  throw "XSim did not create xsim.log."
}
if (-not (Select-String -LiteralPath (Join-Path $work "xsim.log") -Pattern "BP_EF2_PARALLEL8_BITTRUE_PASS" -Quiet)) {
  throw "Parallel8 PASS marker was not found."
}
Write-Host "BP EFDSM2 parallel8 Python-to-RTL bit-true passed: vectors=$Vectors samples=$($Vectors * 8)"

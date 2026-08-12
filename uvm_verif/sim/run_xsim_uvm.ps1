param(
  [string]$VivadoRoot = "D:\Xilinx\Vivado\2024.1",
  [string]$TestName = "dsm_bp_test",
  [int]$Seed = 1
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$work = Join-Path $PSScriptRoot "out\xsim"
$filelist = Join-Path $PSScriptRoot "uvm_filelist.f"
$xvlog = Join-Path $VivadoRoot "bin\xvlog.bat"
$xelab = Join-Path $VivadoRoot "bin\xelab.bat"
$xsim = Join-Path $VivadoRoot "bin\xsim.bat"
$vectorDir = Join-Path $repo "uvm_verif\refmodel\python\out"

foreach ($tool in @($xvlog, $xelab, $xsim)) {
  if (-not (Test-Path -LiteralPath $tool)) {
    throw "Vivado simulator tool not found: $tool"
  }
}

New-Item -ItemType Directory -Force -Path $work | Out-Null
& python (Join-Path $repo "uvm_verif\refmodel\python\generate_performance_sku_vectors.py")
if ($LASTEXITCODE -ne 0) { throw "Python system-vector generation failed with exit code $LASTEXITCODE" }
$compileArgs = @("-sv", "-L", "uvm")
foreach ($line in Get-Content -LiteralPath $filelist) {
  $entry = $line.Trim()
  if (-not $entry -or $entry.StartsWith("#")) { continue }
  if ($entry.StartsWith("+incdir+")) {
    $compileArgs += @("-i", (Join-Path $repo $entry.Substring(8)))
  } else {
    $compileArgs += (Join-Path $repo $entry)
  }
}

Push-Location $work
try {
  & $xvlog @compileArgs 2>&1 | Tee-Object -FilePath "compile.log"
  if ($LASTEXITCODE -ne 0) { throw "xvlog failed with exit code $LASTEXITCODE" }

  & $xelab -L uvm -timescale 1ns/1ps dsm_uvm_tb -s dsm_uvm_tb_snapshot `
    2>&1 | Tee-Object -FilePath "elaborate.log"
  if ($LASTEXITCODE -ne 0) { throw "xelab failed with exit code $LASTEXITCODE" }

  # XSim 2024.1 on Windows splits testplusarg values containing '='.  The TB
  # accepts this '+' separator in addition to the standard VCS form.
  & $xsim dsm_uvm_tb_snapshot -testplusarg "UVM_TESTNAME+$TestName" `
    -testplusarg ("DSM_VECTOR_DIR+" + ($vectorDir -replace "\\", "/")) `
    -sv_seed $Seed -runall `
    2>&1 | Tee-Object -FilePath "run.log"
  if ($LASTEXITCODE -ne 0) { throw "xsim failed with exit code $LASTEXITCODE" }

  $summary = Get-Content -LiteralPath "run.log" -Raw
  if ($summary -match "UVM_ERROR\s*:\s*[1-9]" -or
      $summary -match "UVM_FATAL\s*:\s*[1-9]" -or
      $summary -match "Assertion failed") {
    throw "UVM test reported errors or fatals; see $work\run.log"
  }
  Write-Host "PASS: $TestName seed $Seed completed with no UVM errors or fatals."
} finally {
  Pop-Location
}

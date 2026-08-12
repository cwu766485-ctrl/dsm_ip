param(
  [int]$Samples = 2048,
  [string]$Python = "python",
  [switch]$KeepWork
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$vivadoBin = "D:\Xilinx\Vivado\2024.1\bin"
$xvlog = Join-Path $vivadoBin "xvlog.bat"
$xelab = Join-Path $vivadoBin "xelab.bat"
$xsim = Join-Path $vivadoBin "xsim.bat"
foreach ($tool in @($xvlog, $xelab, $xsim)) {
  if (-not (Test-Path -LiteralPath $tool)) { throw "Vivado tool not found: $tool" }
}

$work = Join-Path $repo "verif\out_xsim_if_dsm_bittrue"
if ((Test-Path -LiteralPath $work) -and -not $KeepWork) {
  Remove-Item -LiteralPath $work -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $work | Out-Null

$generator = Join-Path $repo "uvm_verif\refmodel\python\generate_bp_ef2_vectors.py"
$vectors = Join-Path $work "bp_ef2_equivalence.csv"
& $Python $generator --samples $Samples --output $vectors
if ($LASTEXITCODE -ne 0) { throw "Python vector generation failed." }

$files = @(
  (Join-Path $repo "rtl\dsm\singlebit\dsm_core_ef2.sv"),
  (Join-Path $repo "rtl\tx_bandpass_if\bp_fs4_iq_mixer.sv"),
  (Join-Path $repo "rtl\tx_bandpass_if\dsm_core_bp_ef2.sv"),
  (Join-Path $repo "rtl\tx_bandpass_if\dsm_core_bp_single.sv"),
  (Join-Path $repo "rtl\tx_bandpass_if\tx_bp_if_top.sv"),
  (Join-Path $repo "verif\subsystem\if_dsm\tb\tb_if_dsm_python_bittrue.sv")
)
$oldLocation = Get-Location
try {
  Set-Location $work
  & $xvlog -sv -log xvlog.log @files
  if ($LASTEXITCODE -ne 0) { throw "IF/DSM XSim compile failed." }
  & $xelab -log xelab.log tb_if_dsm_python_bittrue -s sim_if_dsm_bittrue
  if ($LASTEXITCODE -ne 0) { throw "IF/DSM XSim elaboration failed." }
  & $xsim sim_if_dsm_bittrue -log xsim.log -runall
  if ($LASTEXITCODE -ne 0) { throw "IF/DSM XSim run failed." }
} finally {
  Set-Location $oldLocation
}

$log = Join-Path $work "xsim.log"
if (-not (Test-Path -LiteralPath $log)) {
  throw "XSim launcher returned without producing $log."
}
if (-not (Select-String -LiteralPath $log -Pattern "IF_DSM_PYTHON_BITTRUE_PASS" -Quiet)) {
  throw "IF/DSM bit-true PASS marker was not found."
}
Write-Host "IF/DSM Python-to-RTL bit-true passed: $Samples samples."
